#!/usr/bin/env bash
# check-open-ports.sh
# Purpose: Show what ports this machine is exposing, and whether each is network-accessible or loopback-only
# Usage:   ./check-open-ports.sh [--udp] [--nmap]
# Exit:    0 (read-only, best-effort)

set -euo pipefail

SHOW_UDP=0
USE_NMAP=0

while [ $# -gt 0 ]; do
  case "$1" in
    --udp)  SHOW_UDP=1; shift ;;
    --nmap) USE_NMAP=1; shift ;;
    -h|--help)
      cat <<'EOF'
check-open-ports.sh [--udp] [--nmap]
Show what ports this machine is currently exposing and on which interfaces.
Read-only. Run as root to see process names for all ports.

  --udp    Also show listening UDP ports
  --nmap   Run a local nmap self-scan for an external perspective (requires nmap)
EOF
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
hdr()  { echo; echo "=== $* ==="; }
kv()   { printf "%-24s %s\n" "$1:" "$2"; }

echo "=== OPEN PORTS ==="
kv "Hostname"  "$(hostname -s 2>/dev/null || hostname)"
kv "Timestamp" "$(date -Is 2>/dev/null || date)"

# --- Interfaces ---
hdr "Network Interfaces"
if have ip; then
  ip -br addr show 2>/dev/null | awk '{printf "  %-12s %-8s %s\n", $1, $2, $3}' || true
elif have ifconfig; then
  ifconfig 2>/dev/null | grep -E '(^[a-zA-Z]|inet )' || true
else
  echo "(ip/ifconfig not available)"
fi

# --- TCP: all listening ---
hdr "Listening TCP Ports"
if have ss; then
  ss -tlnp 2>/dev/null || echo "(ss failed)"
  [[ "${EUID}" -ne 0 ]] && echo "(note: run as root to see process names for system services)"
elif have netstat; then
  netstat -tlnp 2>/dev/null || echo "(netstat failed)"
else
  echo "(ss/netstat not available)"
fi

# --- TCP: network-exposed only ---
hdr "Network-Exposed TCP Ports (non-loopback)"
if have ss; then
  # Exclude loopback-bound addresses: 127.x.x.x, [::1], and lo-scoped variants
  EXPOSED="$(ss -tlnp 2>/dev/null \
    | awk 'NR>1 && $4 !~ /^127\./ && $4 !~ /^\[::1\]/ && $4 !~ /^::1/ {print $0}' \
    || true)"
  if [[ -n "${EXPOSED}" ]]; then
    echo "${EXPOSED}"
  else
    echo "None — all listening TCP ports are loopback-only"
  fi
else
  echo "(ss not available)"
fi

# --- UDP ---
if (( SHOW_UDP )); then
  hdr "Listening UDP Ports"
  if have ss; then
    ss -ulnp 2>/dev/null || echo "(ss failed)"
    [[ "${EUID}" -ne 0 ]] && echo "(note: run as root to see process names for system services)"
  elif have netstat; then
    netstat -ulnp 2>/dev/null || echo "(netstat failed)"
  else
    echo "(ss/netstat not available)"
  fi
fi

# --- nmap self-scan ---
if (( USE_NMAP )); then
  hdr "nmap Self-Scan (external perspective on localhost)"
  if have nmap; then
    nmap -sT --open localhost 2>/dev/null || echo "(nmap scan failed)"
  else
    echo "(nmap not available — install with: sudo apt install nmap)"
  fi
fi

exit 0
