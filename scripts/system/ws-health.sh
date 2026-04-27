#!/usr/bin/env bash
# workstation-health.sh
# Purpose: Quick, read-only health snapshot for Ubuntu research workstations
# Usage:   ./workstation-health.sh [--verbose] [--json]
# Exit:    0 OK, 1 WARN, 2 DEGRADED

set -euo pipefail

VERBOSE=0
JSON=0

for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --json) JSON=1 ;;
    --help|-h)
      cat <<'EOF'
workstation-health.sh [--verbose|-v] [--json]
Outputs a read-only workstation health summary.
Exit codes: 0 OK, 1 WARN, 2 DEGRADED
EOF
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- Collectors ----------
get_os() {
  local os="unknown"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os="${PRETTY_NAME:-$NAME ${VERSION:-}}"
  elif have lsb_release; then
    os="$(lsb_release -ds 2>/dev/null || true)"
  fi
  echo "$os"
}

get_uptime() {
  if have uptime; then
    uptime -p 2>/dev/null || true
  elif [[ -r /proc/uptime ]]; then
    awk '{printf "up %.0f seconds\n",$1}' /proc/uptime
  else
    echo "unknown"
  fi
}

get_load() {
  if [[ -r /proc/loadavg ]]; then
    awk '{print $1" "$2" "$3}' /proc/loadavg
  else
    echo "unknown"
  fi
}

get_mem() {
  if have free; then
    free -h | awk '
      /^Mem:/ {print $2, $3, $4, $7}
    '
  else
    echo "unknown unknown unknown unknown"
  fi
}

get_swap() {
  if have free; then
    free -h | awk '
      /^Swap:/ {print $2, $3, $4}
    '
  else
    echo "unknown unknown unknown"
  fi
}

get_disk_lines() {
  # Only local filesystems; exclude tmpfs/devtmpfs/squashfs/overlay where possible
  df -h -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null \
    | awk 'NR==1 || $NF ~ /^\// {print}'
}

reboot_required() {
  [[ -e /var/run/reboot-required ]] && echo "yes" || echo "no"
}

apt_health() {
  # Read-only checks: dpkg interrupted, half-configured, held packages
  local issues=()
  if have dpkg; then
    if dpkg --audit 2>/dev/null | grep -q .; then
      issues+=("dpkg-audit")
    fi
    # interrupted dpkg/apt
    [[ -e /var/lib/dpkg/lock-frontend || -e /var/lib/dpkg/lock ]] && issues+=("dpkg-lock-present")
    # held packages
    if have apt-mark && apt-mark showhold 2>/dev/null | grep -q .; then
      issues+=("held-packages")
    fi
  else
    issues+=("dpkg-missing")
  fi

  if ((${#issues[@]} == 0)); then
    echo "ok"
  else
    printf "%s" "${issues[*]}"
  fi
}

gpu_summary() {
  # Prefer nvidia-smi if present
  if have nvidia-smi; then
    # Compact: GPU name, driver, utilization, mem used/total
    local driver
    driver="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 || true)"
    local rows
    rows="$(nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || true)"
    if [[ -n "$rows" ]]; then
      echo "nvidia-smi|driver=${driver:-unknown}|gpus=$(echo "$rows" | wc -l | tr -d ' ')"
      if ((VERBOSE)); then
        echo "$rows" | awk -F',' '{gsub(/^ +| +$/,"",$0); printf "  GPU %s: %s | util %s%% | mem %s/%s MiB\n",$1,$2,$3,$4,$5}'
      fi
      return 0
    fi
  fi

  # Fallback: lspci hint
  if have lspci; then
    if lspci 2>/dev/null | grep -qi 'nvidia'; then
      echo "nvidia-present|nvidia-smi-missing"
      return 0
    fi
  fi

  echo "none-detected"
}

top_cpu_mem() {
  # best-effort; safe read-only snapshot
  if have ps; then
    ps -eo user,pid,ppid,stat,pcpu,pmem,comm --sort=-pcpu 2>/dev/null | head -n 6
  fi
}

# ---------- Health evaluation ----------
STATUS="OK"
EXIT_CODE=0
REASONS=()

set_status() {
  # Order: OK < WARN < DEGRADED
  local new="$1"
  case "$new" in
    OK) return 0 ;;
    WARN)
      if [[ "$STATUS" == "OK" ]]; then STATUS="WARN"; EXIT_CODE=1; fi
      ;;
    DEGRADED)
      STATUS="DEGRADED"; EXIT_CODE=2
      ;;
  esac
}

add_reason() { REASONS+=("$1"); }

# thresholds (tweak as needed)
DISK_WARN_PCT=85
DISK_DEGRADED_PCT=95
MEM_WARN_PCT=90
SWAP_WARN_PCT=50

evaluate_disk() {
  local out
  out="$(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null || true)"
  [[ -z "$out" ]] && return 0

  # Skip header, check usage%
  while read -r fs _blocks used _avail usep mount; do
    [[ "$fs" == "Filesystem" ]] && continue
    local pct="${usep%\%}"
    [[ -z "$pct" ]] && continue
    if (( pct >= DISK_DEGRADED_PCT )); then
      set_status DEGRADED
      add_reason "disk ${mount} at ${pct}%"
    elif (( pct >= DISK_WARN_PCT )); then
      set_status WARN
      add_reason "disk ${mount} at ${pct}%"
    fi
  done <<<"$out"
}

evaluate_mem() {
  if have free; then
    # percent used = used/total
    local total used
    total="$(free -b | awk '/^Mem:/ {print $2}')"
    used="$(free -b | awk '/^Mem:/ {print $3}')"
    if [[ -n "$total" && -n "$used" && "$total" -gt 0 ]]; then
      local pct=$(( used * 100 / total ))
      if (( pct >= MEM_WARN_PCT )); then
        set_status WARN
        add_reason "memory usage ${pct}%"
      fi
    fi

    # swap usage check (only if swap exists)
    local st su
    st="$(free -b | awk '/^Swap:/ {print $2}')"
    su="$(free -b | awk '/^Swap:/ {print $3}')"
    if [[ -n "$st" && "$st" -gt 0 ]]; then
      local spct=$(( su * 100 / st ))
      if (( spct >= SWAP_WARN_PCT )); then
        set_status WARN
        add_reason "swap usage ${spct}%"
      fi
    fi
  fi
}

evaluate_reboot() {
  if [[ "$(reboot_required)" == "yes" ]]; then
    set_status WARN
    add_reason "reboot required"
  fi
}

evaluate_gpu() {
  # If NVIDIA present but nvidia-smi missing, warn (often driver/tooling issue)
  local g
  g="$(gpu_summary | head -n1)"
  if [[ "$g" == "nvidia-present|nvidia-smi-missing" ]]; then
    set_status WARN
    add_reason "NVIDIA detected but nvidia-smi not available"
  fi
}

evaluate_apt() {
  local a
  a="$(apt_health)"
  if [[ "$a" != "ok" ]]; then
    set_status WARN
    add_reason "apt/dpkg issues: $a"
  fi
}

evaluate_disk
evaluate_mem
evaluate_reboot
evaluate_gpu
evaluate_apt

# ---------- Output ----------
emit_text() {
  local os kernel host now
  os="$(get_os)"
  kernel="$(uname -r 2>/dev/null || echo unknown)"
  host="$(hostname 2>/dev/null || echo unknown)"
  now="$(date -Is 2>/dev/null || date || echo unknown)"

  echo "Workstation Health: ${STATUS}"
  echo "Timestamp: ${now}"
  echo "Host: ${host}"
  echo "OS: ${os}"
  echo "Kernel: ${kernel}"
  echo "Uptime: $(get_uptime)"
  echo "Load (1/5/15m): $(get_load)"

  local mem_total mem_used mem_free mem_avail
  read -r mem_total mem_used mem_free mem_avail <<<"$(get_mem)"
  echo "Memory (total/used/free/avail): ${mem_total} / ${mem_used} / ${mem_free} / ${mem_avail}"

  local sw_total sw_used sw_free
  read -r sw_total sw_used sw_free <<<"$(get_swap)"
  echo "Swap (total/used/free): ${sw_total} / ${sw_used} / ${sw_free}"

  echo "Reboot required: $(reboot_required)"
  echo "APT health: $(apt_health)"

  echo "GPU: $(gpu_summary | head -n1)"
  if ((VERBOSE)); then
    echo
    echo "Disk:"
    get_disk_lines
    echo
    echo "Top processes (by CPU):"
    top_cpu_mem || true
    echo
    if have nvidia-smi; then
      # verbose GPU details already printed by gpu_summary (if any),
      # but only when called. Call again to show details.
      gpu_summary >/dev/null || true
    fi
  fi

  if ((${#REASONS[@]} > 0)); then
    echo
    echo "Reasons:"
    for r in "${REASONS[@]}"; do
      echo " - $r"
    done
  fi
}

json_escape() {
  # minimal JSON escaping
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e $'s/\t/\\t/g' -e $'s/\r/\\r/g' -e $'s/\n/\\n/g'
}

emit_json() {
  local os kernel host now load uptime reboot apt gpu
  os="$(get_os)"
  kernel="$(uname -r 2>/dev/null || echo unknown)"
  host="$(hostname 2>/dev/null || echo unknown)"
  now="$(date -Is 2>/dev/null || date || echo unknown)"
  load="$(get_load)"
  uptime="$(get_uptime)"
  reboot="$(reboot_required)"
  apt="$(apt_health)"
  gpu="$(gpu_summary | head -n1)"

  local reasons_json="[]"
  if ((${#REASONS[@]} > 0)); then
    reasons_json="["
    local first=1
    for r in "${REASONS[@]}"; do
      if ((first)); then first=0; else reasons_json+=", "; fi
      reasons_json+="\"$(printf "%s" "$r" | json_escape)\""
    done
    reasons_json+="]"
  fi

  # memory fields
  local mem_total mem_used mem_free mem_avail
  read -r mem_total mem_used mem_free mem_avail <<<"$(get_mem)"
  local sw_total sw_used sw_free
  read -r sw_total sw_used sw_free <<<"$(get_swap)"

  cat <<EOF
{
  "status": "$(printf "%s" "$STATUS" | json_escape)",
  "exit_code": ${EXIT_CODE},
  "timestamp": "$(printf "%s" "$now" | json_escape)",
  "host": "$(printf "%s" "$host" | json_escape)",
  "os": "$(printf "%s" "$os" | json_escape)",
  "kernel": "$(printf "%s" "$kernel" | json_escape)",
  "uptime": "$(printf "%s" "$uptime" | json_escape)",
  "load": "$(printf "%s" "$load" | json_escape)",
  "memory": {
    "total": "$(printf "%s" "$mem_total" | json_escape)",
    "used": "$(printf "%s" "$mem_used" | json_escape)",
    "free": "$(printf "%s" "$mem_free" | json_escape)",
    "available": "$(printf "%s" "$mem_avail" | json_escape)"
  },
  "swap": {
    "total": "$(printf "%s" "$sw_total" | json_escape)",
    "used": "$(printf "%s" "$sw_used" | json_escape)",
    "free": "$(printf "%s" "$sw_free" | json_escape)"
  },
  "reboot_required": "$(printf "%s" "$reboot" | json_escape)",
  "apt_health": "$(printf "%s" "$apt" | json_escape)",
  "gpu": "$(printf "%s" "$gpu" | json_escape)",
  "reasons": ${reasons_json}
}
EOF
}

if ((JSON)); then
  emit_json
else
  emit_text
fi

exit "$EXIT_CODE"
