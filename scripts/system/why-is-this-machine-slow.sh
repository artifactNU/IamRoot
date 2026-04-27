#!/usr/bin/env bash
# why-is-this-machine-slow.sh
# Purpose: Read-only triage to explain why a Linux machine feels slow (CPU, memory, IO, thermals)
# Usage:   ./why-is-this-machine-slow.sh [--seconds N] [--top N]
# Exit:    0 OK, 1 WARN

set -euo pipefail

SECONDS_SAMPLE=5
TOPN=10

while [ $# -gt 0 ]; do
  case "$1" in
    --seconds) SECONDS_SAMPLE="${2:-5}"; shift 2;;
    --top) TOPN="${2:-10}"; shift 2;;
    -h|--help)
      echo "Usage: $0 [--seconds N] [--top N]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

hdr() { echo; echo "=== $* ==="; }
kv() { printf "%-28s %s\n" "$1:" "$2"; }

# Keep a simple warning flag for a non-zero exit when we detect suspicious conditions.
exit_code=0
warn() { exit_code=1; }

echo "=== PERFORMANCE TRIAGE ==="
kv "Hostname" "$(hostname -s 2>/dev/null || hostname)"
kv "Date" "$(date -Is)"
kv "Kernel" "$(uname -r 2>/dev/null || echo 'unknown')"
kv "Uptime" "$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo 'unknown')"

hdr "Load and CPU"
if have uptime; then
  LA="$(uptime 2>/dev/null | sed -n 's/.*load average: //p' || true)"
  [ -n "${LA:-}" ] && kv "Load average" "$LA"
fi

CPU_CORES="unknown"
if have nproc; then CPU_CORES="$(nproc 2>/dev/null || echo unknown)"; fi
kv "CPU cores" "$CPU_CORES"

if have mpstat; then
  mpstat 1 "${SECONDS_SAMPLE}" 2>/dev/null || true
elif have vmstat; then
  vmstat 1 "${SECONDS_SAMPLE}" 2>/dev/null || true
else
  echo "(mpstat/vmstat not available)"
fi

hdr "Top processes (CPU)"
if have ps; then
  ps -eo pid,user,comm,%cpu,%mem,stat,etime --sort=-%cpu 2>/dev/null | head -n $((TOPN+1)) || true
else
  echo "(ps not available)"
fi

hdr "Memory"
if have free; then
  free -h 2>/dev/null || true
else
  echo "(free not available)"
fi

if have vmstat; then
  echo
  echo "vmstat (swap in/out, IO wait):"
  vmstat 1 "${SECONDS_SAMPLE}" 2>/dev/null || true
fi

hdr "Disk IO"
if have iostat; then
  iostat -xz 1 "${SECONDS_SAMPLE}" 2>/dev/null || true
else
  echo "(iostat not available; install 'sysstat' for better IO visibility)"
fi

hdr "Filesystems (space + mount type)"
if have df; then
  df -hT 2>/dev/null | awk 'NR==1 || ($2 !~ /tmpfs|devtmpfs/)' || true

  # Basic heuristic: warn if any filesystem is above 90%
  if df -P 2>/dev/null | awk 'NR>1 {gsub(/%/,"",$5); if ($5+0 >= 90) exit 10}'; then
    : # ok
  else
    echo "WARN: One or more filesystems are >= 90% used."
    warn
  fi
else
  echo "(df not available)"
fi

hdr "OOM / Kill signals / kernel warnings (this boot)"
PATTERN='oom|out of memory|killed process|blocked for more than|hung task|i/o error|nvme|ext4 error|xfs error|btrfs|thermal|throttl|segfault'
if have journalctl; then
  journalctl -b --no-pager 2>/dev/null \
    | grep -Ei "${PATTERN}" \
    | tail -n 80 || echo "(no obvious matches)"
else
  dmesg 2>/dev/null \
    | grep -Ei "${PATTERN}" \
    | tail -n 80 || echo "(no obvious matches)"
fi

hdr "Thermals / Throttling (best-effort)"
if have sensors; then
  sensors 2>/dev/null || true
else
  echo "(sensors not available; install 'lm-sensors' if needed)"
fi

if [ -d /sys/devices/system/cpu/cpu0/cpufreq ] && have cat; then
  if [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
    CURF="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || true)"
    [ -n "${CURF:-}" ] && kv "CPU0 current freq (kHz)" "$CURF"
  fi
fi

hdr "Hints"
echo "- High load with low CPU usage can indicate IO wait, locks, or stuck tasks."
echo "- High 'wa' in vmstat or high disk util in iostat suggests storage bottlenecks."
echo "- OOM messages indicate memory pressure; check biggest RSS processes."
echo "- Throttling/thermal events can make the system feel slow even if CPU is idle."

exit "$exit_code"
