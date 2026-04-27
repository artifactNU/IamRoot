#!/usr/bin/env bash
# what-changed-recently.sh
# Purpose: Read-only summary of recent system changes (reboots, apt/dpkg activity, kernels, NVIDIA)
# Usage:   ./what-changed-recently.sh [--days N]
# Exit:    0 OK, 1 WARN

set -euo pipefail

DAYS=7
while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="${2:-7}"; shift 2;;
    -h|--help)
      echo "Usage: $0 [--days N]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
hdr() { echo; echo "=== $* ==="; }
kv() { printf "%-22s %s\n" "$1:" "$2"; }

HOST="$(hostname -s 2>/dev/null || hostname)"
NOW_ISO="$(date -Is)"
KERNEL="$(uname -r 2>/dev/null || echo unknown)"

# Cutoff date for dpkg.log comparisons (format YYYY-MM-DD ...)
if have date && date -d "${DAYS} days ago" +%Y-%m-%d >/dev/null 2>&1; then
  CUTOFF_DATE="$(date -d "${DAYS} days ago" +%Y-%m-%d)"
else
  CUTOFF_DATE="$(date +%Y-%m-%d)"
fi

# Read rotated logs (plain + .gz)
cat_maybe_gz() {
  local f="$1"
  if [[ "$f" == *.gz ]]; then
    if have zcat; then
      zcat "$f" 2>/dev/null || true
    else
      gzip -dc "$f" 2>/dev/null || true
    fi
  else
    cat "$f" 2>/dev/null || true
  fi
}

echo "=== RECENT CHANGES REPORT ==="
kv "Hostname" "$HOST"
kv "Date" "$NOW_ISO"
kv "Lookback" "${DAYS} day(s)"
kv "Cutoff date" "$CUTOFF_DATE"
kv "Kernel" "$KERNEL"

hdr "Reboots / Boots (since cutoff)"
# last -x output varies. We filter by date string "YYYY-MM-DD" using the cutoff date.
# If last output does not include YYYY-MM-DD, fall back to journalctl list-boots.
if have last; then
  # Try modern last format with YYYY-MM-DD first (like in your output).
  REBOOTS="$(
    last -x 2>/dev/null | grep -E 'reboot|shutdown' \
      | awk -v cutoff="$CUTOFF_DATE" '
          # match "YYYY-MM-DD" anywhere in the line
          match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/, m) {
            if (m[0] >= cutoff) print $0
          }
        ' \
      | head -n 10
  )"
  if [ -n "${REBOOTS:-}" ]; then
    echo "$REBOOTS"
  else
    echo "(no reboot/shutdown entries since cutoff in last -x)"
  fi
elif have journalctl; then
  journalctl --list-boots 2>/dev/null | tail -n 10 || true
else
  echo "(no last/journalctl available)"
fi

hdr "APT activity (from /var/log/apt/history.log*, filtered)"
# Read rotated + compressed APT history logs, print only key lines per transaction.
# Only include transactions whose Start-Date is >= cutoff.
if ls /var/log/apt/history.log* >/dev/null 2>&1; then
  APT_OUT="$(
    {
      for f in /var/log/apt/history.log*; do
        [ -e "$f" ] || continue
        cat_maybe_gz "$f"
      done
    } | awk -v cutoff="$CUTOFF_DATE" '
        function flush_block() {
          if (keep && start != "") {
            print start
            if (cmd != "")   print cmd
            if (inst != "")  print inst
            if (upg != "")   print upg
            if (rem != "")   print rem
            if (pur != "")   print pur
            if (end != "")   print end
            print "----"
          }
          start=cmd=inst=upg=rem=pur=end=""
          keep=0
        }

        /^Start-Date:/ {
          flush_block()
          start=$0
          datepart=$2
          if (datepart >= cutoff) keep=1
          next
        }

        /^Commandline:/ { cmd=$0; next }
        /^Install:/     { inst=$0; next }
        /^Upgrade:/     { upg=$0; next }
        /^Remove:/      { rem=$0; next }
        /^Purge:/       { pur=$0; next }
        /^End-Date:/    { end=$0; next }

        END { flush_block() }
      ' | tail -n 200
  )"

  if [ -n "${APT_OUT:-}" ]; then
    echo "$APT_OUT"
  else
    echo "(no APT history entries since cutoff)"
  fi
else
  echo "(no /var/log/apt/history.log* found)"
fi

hdr "dpkg activity (install/upgrade/remove since cutoff)"
# dpkg.log is usually the most reliable record of package state changes.
if ls /var/log/dpkg.log* >/dev/null 2>&1; then
  {
    for f in /var/log/dpkg.log*; do
      [ -e "$f" ] || continue
      cat_maybe_gz "$f"
    done
  } | awk -v cutoff="$CUTOFF_DATE" '
        $1 >= cutoff && ($3=="install" || $3=="upgrade" || $3=="remove" || $3=="purge") {
          pkg=$4
          sub(/:.*/, "", pkg)
          printf "%s %s  %-7s %s\n", $1, $2, $3, pkg
        }
      ' | tail -n 200
else
  echo "(no /var/log/dpkg.log* found)"
fi

hdr "Recently installed packages (unique, since cutoff)"
if ls /var/log/dpkg.log* >/dev/null 2>&1; then
  {
    for f in /var/log/dpkg.log*; do
      [ -e "$f" ] || continue
      cat_maybe_gz "$f"
    done
  } | awk -v cutoff="$CUTOFF_DATE" '
        $1 >= cutoff && $3=="install" {
          pkg=$4
          sub(/:.*/, "", pkg)
          print pkg
        }
      ' | sort -u | tail -n 200
else
  echo "(no dpkg logs available)"
fi

hdr "Kernel packages (installed)"
if have dpkg-query; then
  dpkg-query -W -f='${Status}\t${Package}\t${Version}\n' 2>/dev/null \
    | awk '$1=="install" && $2=="ok" && $3=="installed" {print $4"\t"$5}' \
    | grep -Ei '^(linux-image|linux-headers|linux-modules)' \
    | tail -n 40 || true
else
  echo "(dpkg-query not available)"
fi

hdr "NVIDIA/CUDA packages (installed)"
if have dpkg-query; then
  dpkg-query -W -f='${Status}\t${Package}\t${Version}\n' 2>/dev/null \
    | awk '$1=="install" && $2=="ok" && $3=="installed" {print $4"\t"$5}' \
    | grep -Ei '^nvidia|cuda|libnvidia|xserver-xorg-video-nvidia' \
    | sort || echo "(no NVIDIA/CUDA packages detected)"
else
  echo "(dpkg-query not available)"
fi

hdr "APT service outcomes (useful, not noisy)"
# Instead of grepping the entire journal (which drags in unrelated lines),
# query only apt-related units, and only show "result" type lines.
# This stays small and actually answers: did apt run, and did it fail?
if have journalctl; then
  JOUT="$(
    journalctl --since "${DAYS} days ago" --no-pager --output=short 2>/dev/null \
      -u apt-daily.service \
      -u apt-daily-upgrade.service \
      -u unattended-upgrades.service \
      -u packagekit.service \
      | grep -Ei 'failed|failure|error|finished|succeeded|result=|exit-code|packages? (upgraded|installed|removed)|unattended-upgrades' \
      | tail -n 80
  )"
  if [ -n "${JOUT:-}" ]; then
    echo "$JOUT"
  else
    echo "(no notable apt/unattended-upgrades service outcomes in journal)"
  fi
else
  echo "(journalctl not available)"
fi

hdr "Notes"
echo "- The APT section shows human-readable transactions (install/upgrade/remove) from apt history logs."
echo "- The dpkg section is the source of truth for what actually changed on disk."
echo "- Reboots are filtered to entries that include a YYYY-MM-DD date >= cutoff."
echo "- This is a read-only report; no changes are made to the system."
