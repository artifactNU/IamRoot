#!/usr/bin/env bash
# logs-error-signals.sh
# Purpose: Collect recent log/error signals for silent failures and regressions
# Usage:   ./logs-error-signals.sh [--since "24h"] [--public]
# Output:  logs_error_signals_<hostname>_<timestamp>.md

set -euo pipefail

SINCE="24h"
PUBLIC_MODE=0

usage() {
  cat <<'USAGE'
Usage: ./logs-error-signals.sh [--since "24h"] [--public]

Options:
  --since "24h"   Time range to search (journalctl-compatible). Default: 24h
  --public        Redact likely sensitive values (usernames/IPs) in log excerpts
  -h, --help      Show help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --since)
      SINCE="${2:-}"; shift 2 ;;
    --public)
      PUBLIC_MODE=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage; exit 1 ;;
  esac
done

HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
TS="$(date -Is | tr ':' '-')"
OUTFILE="logs_error_signals_${HOSTNAME}_${TS}.md"

have() { command -v "$1" >/dev/null 2>&1; }

md_h1() { echo "# $*"; echo; }
md_h2() { echo "## $*"; echo; }
md_h3() { echo "### $*"; echo; }
md_kv() { echo "- **$1:** $2"; }
md_code() { echo '```'; cat; echo '```'; echo; }
md_note() { echo "> $*"; echo; }

pluralize() {
  local count="$1"; shift
  local word="$1"; shift
  if [ "$count" -eq 1 ]; then
    echo "$count $word"
  else
    echo "$count ${word}s"
  fi
}

redact() {
  if [ "$PUBLIC_MODE" -eq 0 ]; then
    cat
    return 0
  fi

  # Best-effort redaction of usernames and IPv4 addresses.
  # This is intentionally conservative and may over-redact.
  sed -E \
    -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IP]/g' \
    -e 's/(user(name)?|account|uid)=?([[:space:]]*)[^[:space:],;]+/\1\3[REDACTED]/Ig' \
    -e 's/(for|by)[[:space:]]+user[[:space:]]+[^[:space:],;]+/\1 user [REDACTED]/Ig' \
    -e 's/(for|by)[[:space:]]+[^[:space:],;]+[[:space:]]+(from|by|on|via)/\1 [REDACTED] \2/Ig'
}

run_section() {
  local title="$1"; shift
  local max_lines=200
  local output

  # Allow override of line limit for specific sections
  if [[ "$1" == "--lines" ]]; then
    max_lines="$2"
    shift 2
  fi

  md_h3 "$title"
  if output="$("$@")" 2>/dev/null; then
    if [ -n "${output:-}" ]; then
      echo "$output" | redact | tail -n "$max_lines" | md_code
    else
      md_note "No matching entries found."
    fi
  else
    md_note "Unable to collect data for this section."
  fi
}

boot_boundary_note() {
  if ! have journalctl; then
    return 1
  fi

  local boots_in_range
  local boot_count

  # Use journalctl's native --list-boots with --since for cleaner parsing
  boots_in_range="$(journalctl --list-boots --since "$SINCE" --no-pager 2>/dev/null)"

  if [ -z "${boots_in_range:-}" ]; then
    echo "No boots found in the specified time range."
    return 0
  fi

  boot_count="$(echo "$boots_in_range" | wc -l)"

  echo "Journal entries since ${SINCE} span $(pluralize "$boot_count" "boot")."
  echo
  echo "Boot history (most recent first):"
  echo "$boots_in_range"
  echo
  echo "Current boot:"
  journalctl --list-boots --no-pager 2>/dev/null | grep -E '^\s*0\s' || echo "Unable to determine current boot."
}

journal_or_dmesg() {
  local grep_expr="$1"
  if have journalctl; then
    journalctl -k --since "$SINCE" --no-pager | grep -Ei "$grep_expr" || true
  elif have dmesg; then
    dmesg | grep -Ei "$grep_expr" || true
  else
    return 1
  fi
}

kernel_warnings() {
  if have dmesg; then
    if dmesg --help 2>/dev/null | grep -q -- '--level'; then
      dmesg --level=warn,err,crit,alert,emerg
    else
      dmesg | grep -Ei 'warn|error|fail|critical|alert|emerg' || true
    fi
  else
    return 1
  fi
}

systemd_failures() {
  if have systemctl; then
    {
      systemctl --failed --no-legend 2>/dev/null || true
      echo
      if have journalctl; then
        journalctl --since "$SINCE" -p err --no-pager || true
      fi
    } | sed '/^[[:space:]]*$/N;/^\n$/D'
  else
    return 1
  fi
}

oom_killer_signals() {
  if have journalctl; then
    # Use short-iso format for precise timestamps to correlate OOM events with other issues
    journalctl --since "$SINCE" --no-pager -o short-iso \
      | grep -Ei 'oom-killer|out of memory|invoked oom-killer|oom_reaper|Memory cgroup out of memory' || true
    return 0
  fi

  if have dmesg; then
    # dmesg with human-readable timestamps if supported
    if dmesg --help 2>/dev/null | grep -q -- '-T'; then
      dmesg -T | grep -Ei 'oom-killer|out of memory|invoked oom-killer|oom_reaper|Memory cgroup out of memory' || true
    else
      dmesg | grep -Ei 'oom-killer|out of memory|invoked oom-killer|oom_reaper|Memory cgroup out of memory' || true
    fi
    return 0
  fi

  return 1
}

rate_limited_kernel_warnings() {
  if have journalctl; then
    journalctl -k --since "$SINCE" --no-pager | grep -Ei 'rate limit|ratelimit|suppressed|printk' || true
    return 0
  fi

  if have dmesg; then
    dmesg | grep -Ei 'rate limit|ratelimit|suppressed|printk' || true
    return 0
  fi

  return 1
}

gpu_driver_errors() {
  # Check if GPU hardware exists before searching logs
  local has_gpu=0

  if [ -f /proc/driver/nvidia/version ]; then
    has_gpu=1
  elif have lspci; then
    if lspci 2>/dev/null | grep -qi 'vga\|3d\|display.*nvidia\|display.*amd\|display.*intel'; then
      has_gpu=1
    fi
  fi

  if [ "$has_gpu" -eq 0 ]; then
    echo "No GPU hardware detected on this system."
    return 0
  fi

  # Look for NVIDIA (NVRM, Xid), AMD (amdgpu), Intel (i915), and open-source (nouveau) driver errors
  journal_or_dmesg 'NVRM|Xid|amdgpu|i915|GPU HANG|ring gfx|GPU reset|nouveau' || true
}

disk_io_errors() {
  # Disk I/O errors are critical for bioinformatics workloads with large datasets
  if have journalctl; then
    journalctl -k --since "$SINCE" --no-pager -o short-iso \
      | grep -Ei 'blk_update_request|ata.*error|nvme.*error|sd.*I/O error|I/O error.*dev|medium error|unrecoverable read error|sense key.*medium error' || true
    return 0
  fi

  if have dmesg; then
    if dmesg --help 2>/dev/null | grep -q -- '-T'; then
      dmesg -T | grep -Ei 'blk_update_request|ata.*error|nvme.*error|sd.*I/O error|I/O error.*dev|medium error|unrecoverable read error|sense key.*medium error' || true
    else
      dmesg | grep -Ei 'blk_update_request|ata.*error|nvme.*error|sd.*I/O error|I/O error.*dev|medium error|unrecoverable read error|sense key.*medium error' || true
    fi
    return 0
  fi

  return 1
}

cpu_throttling() {
  # CPU throttling causes silent performance degradation in compute workloads
  local throttle_pattern='CPU.*throttled|thermal.*trip|above.*threshold|critical temperature reached|processor.*throttling|Package power limit|PROCHOT|temperature.*critical|thermal shutdown|CPU clock throttled'
  
  if have journalctl; then
    journalctl -k --since "$SINCE" --no-pager -o short-iso \
      | grep -Ei "$throttle_pattern" || true
    return 0
  fi

  if have dmesg; then
    if dmesg --help 2>/dev/null | grep -q -- '-T'; then
      dmesg -T | grep -Ei "$throttle_pattern" || true
    else
      dmesg | grep -Ei "$throttle_pattern" || true
    fi
    return 0
  fi

  return 1
}

network_errors() {
  # Network issues can cause silent failures in distributed bioinformatics pipelines
  local network_pattern='firmware crash|network.*unreachable|NIC.*error|transmit timeout|TX timeout|eth[0-9].*failed|ib[0-9].*failed|mlx[0-9].*failed|infiniband.*failed|rdma.*failed|link flap|reset adapter|hardware error.*eth|hardware error.*ib|CRC error|rx.*error|tx.*error'
  
  if have journalctl; then
    journalctl --since "$SINCE" --no-pager -o short-iso \
      | grep -Ei "$network_pattern" || true
    return 0
  fi

  if have dmesg; then
    if dmesg --help 2>/dev/null | grep -q -- '-T'; then
      dmesg -T | grep -Ei "$network_pattern" || true
    else
      dmesg | grep -Ei "$network_pattern" || true
    fi
    return 0
  fi

  return 1
}

auth_errors() {
  # Focus on actual authentication failures, not routine successful operations
  local auth_pattern='authentication failure|Failed password|permission denied|NOT in sudoers|su: FAILED|pam.*fail|authentication error|invalid user|access denied|polkit.*not authorized|Connection closed by authenticating user|maximum authentication attempts|Account locked'
  
  if have journalctl; then
    journalctl --since "$SINCE" --no-pager \
      | grep -Ei "$auth_pattern" || true
    return 0
  fi

  if [ -f /var/log/auth.log ]; then
    grep -Ei "$auth_pattern" /var/log/auth.log || true
    return 0
  fi

  if [ -f /var/log/secure ]; then
    grep -Ei "$auth_pattern" /var/log/secure || true
    return 0
  fi

  return 1
}

segfaults_and_coredumps() {
  if have coredumpctl; then
    {
      coredumpctl list --since "$SINCE" 2>/dev/null || true
      echo
      journalctl --since "$SINCE" --no-pager | grep -Ei 'segfault|core dumped' || true
    } | sed '/^[[:space:]]*$/N;/^\n$/D'
  elif have journalctl; then
    journalctl --since "$SINCE" --no-pager | grep -Ei 'segfault|core dumped' || true
  else
    return 1
  fi
}

{
  md_h1 "Logs & Error Signals"

  md_h2 "Summary"
  md_kv "Hostname" "$HOSTNAME"
  md_kv "Date" "$(date -Is)"
  md_kv "Since" "$SINCE"
  md_kv "Public mode" "$([ "$PUBLIC_MODE" -eq 1 ] && echo "enabled" || echo "disabled")"
  echo
  md_note "This report is read-only and may contain sensitive log data. Use --public to redact likely identifiers."

  md_h2 "Kernel ring buffer warnings"
  run_section "dmesg warnings/errors" kernel_warnings

  md_h2 "Journal boot boundaries"
  run_section "Boot span annotation" boot_boundary_note

  md_h2 "Rate-limited kernel warnings"
  run_section "Ratelimit/suppressed kernel messages" rate_limited_kernel_warnings

  md_h2 "Hardware error logs (MCE, PCIe, EDAC)"
  run_section "Kernel hardware errors" journal_or_dmesg 'mce|machine check|hardware error|pcie|aer|edac'

  md_h2 "Disk I/O errors"
  run_section "Block device and controller errors" --lines 300 disk_io_errors

  md_h2 "Filesystem warnings"
  run_section "Filesystem-related errors" journal_or_dmesg 'ext[234]-fs error|xfs.*(corrupt|error|shutdown)|btrfs.*(error|corrupt|failed)|buffer i/o error|read-only file system|remount.*read-only'

  md_h2 "OOM killer activity"
  run_section "Out-of-memory killer signals" --lines 500 oom_killer_signals

  md_h2 "CPU thermal throttling"
  run_section "Thermal events and CPU throttling" cpu_throttling

  md_h2 "Network interface errors"
  run_section "Link failures and network errors" network_errors

  md_h2 "Systemd service failures"
  run_section "Failed units and error-level logs" systemd_failures

  md_h2 "Authentication and permission errors"
  run_section "Auth/PAM/sudo/permission errors" auth_errors

  md_h2 "GPU driver crashes"
  run_section "NVRM/amdgpu/i915 related errors" gpu_driver_errors

  md_h2 "Recent segfaults or core dumps"
  run_section "Segfault and coredump signals" segfaults_and_coredumps

  echo "---"
  md_note "End of report."
} >"$OUTFILE"

echo "Done. Wrote: $OUTFILE"
