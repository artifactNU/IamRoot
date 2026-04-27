#!/usr/bin/env bash
# whats-happening.sh
# Purpose: Real-time snapshot of active sessions, processes, network activity, and service health
# Usage:   ./whats-happening.sh [--verbose|-v]
# Exit:    0 (read-only, best-effort)

set -euo pipefail

VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --verbose|-v) VERBOSE=1; shift ;;
    -h|--help)
      cat <<'EOF'
whats-happening.sh [--verbose|-v]
Real-time snapshot of active sessions, top processes, network connections,
service health, and recent errors. Read-only. Exit code always 0.

  --verbose/-v   Also show: full established connections, running services, recent logins
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
hdr()  { echo; echo "=== $* ==="; }
kv()   { printf "%-24s %s\n" "$1:" "$2"; }

echo "=== MACHINE ACTIVITY SNAPSHOT ==="
kv "Hostname"       "$(hostname -s 2>/dev/null || hostname)"
kv "Timestamp"      "$(date -Is 2>/dev/null || date)"
kv "Uptime"         "$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo 'unknown')"
kv "Load (1/5/15m)" "$(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || echo 'unknown')"

# --- Active sessions ---
hdr "Active Sessions"
if have w; then
  w 2>/dev/null || echo "(w failed)"
elif have who; then
  who 2>/dev/null || echo "(who failed)"
else
  echo "(w/who not available)"
fi

# --- Top processes ---
hdr "Top Processes (CPU)"
if have ps; then
  ps -eo pid,user,stat,pcpu,pmem,comm --sort=-pcpu 2>/dev/null | head -n 11 || echo "(ps failed)"
else
  echo "(ps not available)"
fi

hdr "Top Processes (Memory)"
if have ps; then
  ps -eo pid,user,stat,pcpu,pmem,comm --sort=-pmem 2>/dev/null | head -n 11 || echo "(ps failed)"
else
  echo "(ps not available)"
fi

# --- Network ---
hdr "Listening Ports"
if have ss; then
  ss -tlnp 2>/dev/null || echo "(ss failed)"
elif have netstat; then
  netstat -tlnp 2>/dev/null || echo "(netstat failed)"
else
  echo "(ss/netstat not available)"
fi

hdr "Established Connections"
if have ss; then
  CONN_COUNT="$(ss -tnp state established 2>/dev/null | tail -n +2 | wc -l || echo '?')"
  echo "Total: ${CONN_COUNT}"
  if (( VERBOSE )); then
    echo
    ss -tnp state established 2>/dev/null | head -n 20 || true
  fi
else
  echo "(ss not available)"
fi

# --- Services ---
hdr "Failed Services"
if have systemctl; then
  FAILED="$(systemctl list-units --state=failed --no-legend --no-pager 2>/dev/null || true)"
  if [[ -z "${FAILED}" ]]; then
    echo "None"
  else
    echo "${FAILED}"
  fi
else
  echo "(systemctl not available)"
fi

if (( VERBOSE )); then
  hdr "Running Services"
  if have systemctl; then
    systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null \
      | awk '{print $1}' | sort \
      || echo "(systemctl failed)"
  else
    echo "(systemctl not available)"
  fi
fi

# --- Recent errors ---
hdr "Recent Errors (last 15)"
if have journalctl; then
  journalctl -p err..emerg -n 15 --no-pager --output=short 2>/dev/null \
    || echo "(journalctl failed — try sudo)"
else
  echo "(journalctl not available)"
  if [[ -r /var/log/syslog ]]; then
    grep -iE 'error|crit|emerg' /var/log/syslog 2>/dev/null | tail -n 15 || true
  elif [[ -r /var/log/messages ]]; then
    grep -iE 'error|crit|emerg' /var/log/messages 2>/dev/null | tail -n 15 || true
  fi
fi

# --- Recent logins (verbose only) ---
if (( VERBOSE )); then
  hdr "Recent Logins"
  if have last; then
    last -n 15 2>/dev/null | head -n 15 || echo "(last failed)"
  else
    echo "(last not available)"
  fi
fi

exit 0
