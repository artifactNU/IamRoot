#!/usr/bin/env bash
# ws_audit_md.sh
# Purpose: Collect read-only workstation inventory/config info and write a Markdown report
# Usage:   ./ws_audit_md.sh
# Output:  ws_<hostname>_<timestamp>.md

set -euo pipefail

HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
TS="$(date -Is | tr ':' '-')"
OUTFILE="ws_${HOSTNAME}_${TS}.md"

# Helpers
have() { command -v "$1" >/dev/null 2>&1; }

md_h1() { echo "# $*"; echo; }
md_h2() { echo "## $*"; echo; }
md_h3() { echo "### $*"; echo; }

md_kv() { echo "- **$1:** $2"; }
md_code() { echo '```'; cat; echo '```'; echo; }
md_note() { echo "> $*"; echo; }

# Gather OS details
OS_PRETTY="unknown"
if [ -f /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_PRETTY="${PRETTY_NAME:-unknown}"
fi

# Temp files
TMP_USER_CRON="$(mktemp -t ws_usercron.XXXXXX)"
TMP_SYS_CRON="$(mktemp -t ws_syscron.XXXXXX)"
cleanup() { rm -f "$TMP_USER_CRON" "$TMP_SYS_CRON"; }
trap cleanup EXIT

# --- Readability-focused extractors ---

primary_ipv4() {
  # Prints: "<iface>: <ipv4/cidr>" or "(unknown)"
  # Requires: ip
  local dev ip4
  dev="$(ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
  if [ -n "${dev:-}" ]; then
    ip4="$(ip -o -4 addr show dev "$dev" 2>/dev/null | awk '{print $4}' | head -n1)"
    if [ -n "${ip4:-}" ]; then
      echo "${dev}: ${ip4}"
      return 0
    fi
    echo "${dev}: (no IPv4)"
    return 0
  fi
  echo "(unknown)"
}

net_table_ipv4_only() {
  # Outputs a Markdown table: iface, state, MAC, IPv4
  # Requires: ip
  echo "| Interface | State | MAC address | IPv4 address(es) |"
  echo "|---|---|---|---|"

  while IFS= read -r ifc; do
    [ -z "$ifc" ] && continue
    [ "$ifc" = "lo" ] && continue

    state="$(ip -o link show dev "$ifc" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="state"){print $(i+1); exit}}')"
    mac="$(ip -o link show dev "$ifc" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="link/ether"){print $(i+1); exit}}')"
    [ -z "${mac:-}" ] && mac="(n/a)"
    [ -z "${state:-}" ] && state="(unknown)"

    ipv4="$(ip -o -4 addr show dev "$ifc" 2>/dev/null | awk '{print $4}' | paste -sd ", " -)"
    [ -z "${ipv4:-}" ] && ipv4="(none)"

    echo "| \`$ifc\` | $state | \`$mac\` | \`$ipv4\` |"
  done < <(ip -o link show | awk -F': ' '{print $2}' | awk '{print $1}')
  echo
}

gpu_model() {
  # Best-effort single-line GPU model detection
  if have lspci; then
    lspci -nn 2>/dev/null | awk -F': ' '
      /VGA compatible controller|3D controller|Display controller/ {print $2; found=1}
      END { if (!found) exit 1 }
    ' | head -n1
    return $?
  fi
  return 1
}

disk_mounts_clean() {
  # Cleaner disks & mounts:
  # - show storage table
  # - omit Snap loop mounts (/snap/*) and unmounted loop devices
  # - add a note if Snap mounts were omitted
  #
  # Requires: lsblk

  local snap_count
  snap_count="$(
    lsblk -rno NAME,TYPE,MOUNTPOINT 2>/dev/null \
      | awk '$2=="loop" && $3 ~ /^\/snap\// {c++} END{print c+0}'
  )"

  echo "| Name | Size | Type | FS | Mountpoint |"
  echo "|---|---:|---|---|---|"

  lsblk -rno NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null \
    | awk '
        # skip snap loop mounts
        $3=="loop" && $5 ~ /^\/snap\// {next}

        # skip unmounted loop devices (noise)
        $3=="loop" && $5=="" {next}

        {printf "| `%s` | `%s` | %s | %s | `%s` |\n",
                $1, $2, $3, ($4==""?"-":$4), ($5==""?"-":$5)}
      '
  echo

  if [ "${snap_count:-0}" -gt 0 ]; then
    md_note "Snap mounts detected: ${snap_count}. They were omitted from the table to reduce clutter."
  fi
}

disk_usage_short_table() {
  # Short table: real filesystems only, sorted by %used (desc), top 10
  # Requires: df
  echo "| Mount | Used | Size | Use% | Filesystem |"
  echo "|---|---:|---:|---:|---|"
  df -hT 2>/dev/null \
    | awk 'NR==1 {next}
           $1 ~ /^tmpfs$/ {next}
           $1 ~ /^devtmpfs$/ {next}
           $2 ~ /^tmpfs$/ {next}
           $2 ~ /^devtmpfs$/ {next}
           {print}' \
    | awk '{printf "%s\t%s\t%s\t%s\t%s\n", $7, $4, $3, $6, $2}' \
    | sort -t$'\t' -k4,4V -r \
    | head -n 10 \
    | awk -F'\t' '{printf "| `%s` | `%s` | `%s` | `%s` | `%s` |\n", $1,$2,$3,$4,$5}'
  echo
}

human_users_list() {
  awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd | paste -sd ", " -
}

sudo_users_list() {
  # Prefer sudo group; fall back to wheel if sudo not present.
  if have getent; then
    if getent group sudo >/dev/null 2>&1; then
      getent group sudo | awk -F: '{print $4}' | tr ',' '\n' | awk 'NF' | paste -sd ", " -
      return 0
    fi
    if getent group wheel >/dev/null 2>&1; then
      getent group wheel | awk -F: '{print $4}' | tr ',' '\n' | awk 'NF' | paste -sd ", " -
      return 0
    fi
  fi
  echo ""
}

echo "Collecting Markdown report for ${HOSTNAME}..."

{
  md_h1 "Workstation Audit Report"

  md_h2 "Summary"
  md_kv "Hostname" "$HOSTNAME"
  md_kv "Date" "$(date -Is)"
  md_kv "OS" "$OS_PRETTY"
  md_kv "Kernel" "$(uname -r 2>/dev/null || echo 'unknown')"
  md_kv "Uptime" "$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo 'unknown')"
  if have ip; then
    md_kv "Primary IPv4" "$(primary_ipv4)"
  else
    md_kv "Primary IPv4" "(unknown: ip not available)"
  fi
  if have uptime; then
    LA="$(uptime 2>/dev/null | sed -n 's/.*load average: //p' || true)"
    [ -n "$LA" ] && md_kv "Load average" "$LA"
  fi
  echo

  md_h2 "Hostname & DNS"
  md_kv "Short hostname" "$(hostname -s 2>/dev/null || hostname)"
  md_kv "DNS domain" "$(hostname -d 2>/dev/null || echo 'N/A')"
  md_kv "FQDN" "$(hostname -f 2>/dev/null || echo 'N/A')"
  echo

  if [ -r /etc/resolv.conf ]; then
    SEARCH_DOMAINS="$(grep -E '^[[:space:]]*search[[:space:]]+' /etc/resolv.conf 2>/dev/null | head -n1 | sed 's/^[[:space:]]*search[[:space:]]*//')"
    if [ -n "${SEARCH_DOMAINS:-}" ]; then
      md_kv "Search domains (/etc/resolv.conf)" "$SEARCH_DOMAINS"
    else
      md_kv "Search domains (/etc/resolv.conf)" "(none)"
    fi
    NAMESERVERS="$(grep -E '^[[:space:]]*nameserver[[:space:]]+' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | paste -sd ", " -)"
    [ -n "${NAMESERVERS:-}" ] && md_kv "Nameservers (/etc/resolv.conf)" "$NAMESERVERS"
  else
    md_kv "/etc/resolv.conf" "not readable"
  fi
  echo

  md_h2 "Network"
  if have ip; then
    md_h3 "Interfaces (IPv4 + MAC)"
    net_table_ipv4_only
  else
    md_note "\`ip\` not found; cannot report interfaces."
  fi

  md_h2 "Hardware"

  md_h3 "CPU"
  if have lscpu; then
    CPU_MODEL="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
    CPU_SOCKETS="$(lscpu 2>/dev/null | awk -F: '/Socket\(s\)/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
    CPU_CORES="$(lscpu 2>/dev/null | awk -F: '/^CPU\(s\)/ {gsub(/^[ \t]+/,"",$2); print $2; exit}')"
    md_kv "Model" "${CPU_MODEL:-unknown}"
    md_kv "CPUs" "${CPU_CORES:-unknown}"
    md_kv "Sockets" "${CPU_SOCKETS:-unknown}"
    echo
  else
    md_note "\`lscpu\` not available."
  fi

  md_h3 "RAM"
  if have free; then
    free -h | md_code
  else
    md_note "\`free\` not available."
  fi

  md_h3 "Disks & Mounts (clean)"
  if have lsblk; then
    disk_mounts_clean
  else
    md_note "\`lsblk\` not available."
  fi

  md_h3 "Filesystem Usage (Top 10 by % used)"
  if have df; then
    disk_usage_short_table
  else
    md_note "\`df\` not available."
  fi

  md_h3 "GPU"
  GPU_LINE="$(gpu_model || true)"
  if [ -n "${GPU_LINE:-}" ]; then
    md_kv "Model" "$GPU_LINE"
    echo
  else
    md_note "GPU model not detected (missing tools or no PCI graphics controller found)."
  fi

  md_h2 "Users & Privilege"

  md_h3 "User Summary"
  ALL_HUMANS="$(human_users_list || true)"
  [ -z "${ALL_HUMANS:-}" ] && ALL_HUMANS="(none found)"
  md_kv "Human users" "$ALL_HUMANS"

  SUDO_ALL="$(sudo_users_list || true)"
  if [ -n "${SUDO_ALL:-}" ]; then
    md_kv "Sudo-capable users (group members)" "$SUDO_ALL"
  else
    md_kv "Sudo-capable users (group members)" "(none found / group missing)"
  fi
  echo

  md_h3 "Local Human Users (UID >= 1000 and < 65534)"
  echo "| User | UID | GID | Home | Shell |"
  echo "|---|---:|---:|---|---|"
  awk -F: '$3 >= 1000 && $3 < 65534 {printf "| %s | %s | %s | %s | %s |\n", $1,$3,$4,$6,$7}' /etc/passwd
  echo

  md_h2 "Scheduled Tasks"

  md_h3 "Per-user Crontabs (local human users)"
  ANY_USER_CRON=0
  while IFS=: read -r uname _ uid _ _ _ _; do
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ]; then
      if have crontab && crontab -u "$uname" -l >"$TMP_USER_CRON" 2>/dev/null; then
        if [ -s "$TMP_USER_CRON" ]; then
          ANY_USER_CRON=1
          echo "**User: \`$uname\`**"
          sed 's/^/    /' "$TMP_USER_CRON" | md_code
        fi
      fi
    fi
  done < /etc/passwd

  if [ "$ANY_USER_CRON" -eq 0 ]; then
    md_note "No per-user crontabs found (or insufficient permissions to read them)."
  fi

  md_h3 "System Cron (non-default-looking entries)"
  : >"$TMP_SYS_CRON"

  FILES_TO_CHECK=()
  [ -f /etc/crontab ] && FILES_TO_CHECK+=("/etc/crontab")
  if [ -d /etc/cron.d ]; then
    # shellcheck disable=SC2206
    FILES_TO_CHECK+=(/etc/cron.d/*)
  fi

  for f in "${FILES_TO_CHECK[@]:-}"; do
    [ -f "$f" ] || continue
    awk '
      $0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*#/ {
        if (NF >= 7) {
          user = $6
          cmd = ""
          for (i = 7; i <= NF; i++) cmd = cmd " " $i
          if (user != "root" || cmd ~ /(\/home\/|\/usr\/local\/|\/opt\/|\/srv\/|\/data\/)/) {
            print FILENAME ":" $0
          }
        }
      }
    ' "$f" >>"$TMP_SYS_CRON"
  done

  if [ -s "$TMP_SYS_CRON" ]; then
    cat "$TMP_SYS_CRON" | md_code
  else
    md_note "No non-default-looking system cron lines found."
  fi

  echo "---"
  md_note "End of report."
} >"$OUTFILE"

echo "Done. Wrote: $OUTFILE"