#!/usr/bin/env bash
# network-troubleshoot.sh
# Purpose: Diagnose why this machine cannot reach a host or the internet
# Usage:   ./network-troubleshoot.sh [TARGET] [--trace]
# Exit:    0 all checks passed, 1 issues detected

set -euo pipefail

TARGET=""
TRACE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --trace) TRACE=1; shift ;;
    -h|--help)
      cat <<'EOF'
network-troubleshoot.sh [TARGET] [--trace]
Diagnose network connectivity on this machine.
Checks: interfaces, default gateway, DNS, internet reachability, MTU.
If TARGET is given, also diagnoses connectivity to that specific host.

  TARGET    Hostname or IP to test (optional)
  --trace   Run traceroute to TARGET (or default gateway if no TARGET)
EOF
      exit 0
      ;;
    -*) echo "Unknown arg: $1" >&2; exit 2 ;;
    *)  TARGET="$1"; shift ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
hdr()  { echo; echo "=== $* ==="; }
kv()   { printf "%-28s %s\n" "$1:" "$2"; }

ISSUES=0
ok()   { printf "  [OK]   %s\n" "$*"; }
fail() { printf "  [FAIL] %s\n" "$*"; ISSUES=1; }
warn() { printf "  [WARN] %s\n" "$*"; }

try_ping() {
  local host="$1" label="$2"
  if ping -c 3 -W 2 -q "$host" >/dev/null 2>&1; then
    ok "ping ${label}"
    return 0
  else
    fail "ping ${label} — unreachable or ICMP blocked"
    return 1
  fi
}

try_resolve() {
  local name="$1"
  if have host; then
    host "$name" 2>/dev/null | awk '/has address/{print $4; exit}' || true
  elif have dig; then
    dig +short +time=3 "$name" 2>/dev/null | grep -v '^;;' | head -n1 || true
  elif have nslookup; then
    nslookup "$name" 2>/dev/null | awk '/^Address:/ && !/127\./{print $2; exit}' || true
  fi
}

echo "=== NETWORK TROUBLESHOOTER ==="
kv "Hostname"  "$(hostname -s 2>/dev/null || hostname)"
kv "Timestamp" "$(date -Is 2>/dev/null || date)"
[[ -n "$TARGET" ]] && kv "Target" "$TARGET"

# --- Interfaces ---
hdr "Interfaces"
if have ip; then
  ip -br addr show 2>/dev/null | awk '{
    marker = ($2 == "UP") ? "[UP]  " : "[DOWN]"
    printf "  %s %-20s %s\n", marker, $1, $3
  }' || true
  UP_COUNT="$(ip -br link show 2>/dev/null | awk '/\sUP\s/{c++} END{print c+0}')"
  [[ "$UP_COUNT" -eq 0 ]] && fail "no interfaces are UP"
else
  warn "ip not available — cannot check interface state"
fi

# --- Default gateway ---
hdr "Default Gateway"
GATEWAY=""
if have ip; then
  GATEWAY="$(ip route show default 2>/dev/null | awk '/default via/{print $3; exit}' || true)"
  if [[ -n "$GATEWAY" ]]; then
    kv "Gateway" "$GATEWAY"
    try_ping "$GATEWAY" "gateway (${GATEWAY})" || true
  else
    fail "no default gateway configured"
    warn "check: ip route show"
  fi
else
  warn "ip not available"
fi

# --- DNS ---
hdr "DNS"
if [[ -r /etc/resolv.conf ]]; then
  DNS_SERVERS="$(awk '/^nameserver/{printf "%s ", $2}' /etc/resolv.conf 2>/dev/null || true)"
  SEARCH="$(awk '/^(search|domain)/{print $2; exit}' /etc/resolv.conf 2>/dev/null || true)"
  if [[ -n "$DNS_SERVERS" ]]; then
    kv "Nameservers" "$DNS_SERVERS"
  else
    fail "no nameservers in /etc/resolv.conf"
  fi
  [[ -n "$SEARCH" ]] && kv "Search domain" "$SEARCH"
else
  warn "/etc/resolv.conf not readable"
fi

TEST_NAME="one.one.one.one"
RESOLVED="$(try_resolve "$TEST_NAME")"
if [[ -n "$RESOLVED" ]]; then
  ok "DNS resolves ${TEST_NAME} → ${RESOLVED}"
elif have host || have dig || have nslookup; then
  fail "DNS resolution failed for ${TEST_NAME}"
  warn "test with known resolver: host ${TEST_NAME} 8.8.8.8"
else
  warn "no DNS tool available (host/dig/nslookup)"
fi

# --- Internet connectivity ---
hdr "Internet Connectivity"
if ! try_ping "1.1.1.1" "internet (1.1.1.1, Cloudflare)"; then
  try_ping "8.8.8.8" "internet (8.8.8.8, Google — alternate)" || true
fi

# --- MTU ---
hdr "Path MTU"
if [[ -n "$GATEWAY" ]]; then
  MTU_TARGET="$GATEWAY"
  MTU_LABEL="gateway (${GATEWAY})"
else
  MTU_TARGET="1.1.1.1"
  MTU_LABEL="1.1.1.1"
fi
# 1472 = 1500 (Ethernet MTU) - 20 (IP header) - 8 (ICMP header), DF bit set
if ping -c 1 -W 3 -M 'do' -s 1472 "$MTU_TARGET" >/dev/null 2>&1; then
  ok "full MTU 1500B to ${MTU_LABEL}"
elif ping -c 1 -W 3 -M 'do' -s 1024 "$MTU_TARGET" >/dev/null 2>&1; then
  fail "MTU below 1500B — 1472B fails but 1024B OK (possible PMTUD black hole)"
  warn "try: sudo ip link set <iface> mtu 1400"
elif ping -c 1 -W 3 -M 'do' -s 576 "$MTU_TARGET" >/dev/null 2>&1; then
  fail "MTU severely limited — 1024B fails but 576B OK"
elif ping -c 1 -W 3 "$MTU_TARGET" >/dev/null 2>&1; then
  warn "MTU test inconclusive — ICMP DF may be blocked or unsupported"
else
  warn "cannot reach ${MTU_LABEL} for MTU test"
fi

# --- Target-specific checks ---
if [[ -n "$TARGET" ]]; then
  hdr "Target: ${TARGET}"

  # DNS resolution if target is a hostname, not a raw IP
  if [[ ! "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    TARGET_IP="$(try_resolve "$TARGET")"
    if [[ -n "$TARGET_IP" ]]; then
      ok "DNS: ${TARGET} → ${TARGET_IP}"
    elif have host || have dig || have nslookup; then
      fail "DNS: cannot resolve ${TARGET}"
      warn "if this is the only failure, the issue may be the hostname itself"
    else
      warn "no DNS tool available — skipping resolution check"
    fi
  fi

  try_ping "$TARGET" "$TARGET" || true

  if (( TRACE )); then
    hdr "Traceroute: ${TARGET}"
    if have traceroute; then
      traceroute -n -w 2 -m 20 "$TARGET" 2>/dev/null || warn "traceroute failed"
    elif have tracepath; then
      tracepath -n "$TARGET" 2>/dev/null || warn "tracepath failed"
    else
      warn "no traceroute tool available — install with: sudo apt install traceroute"
    fi
  fi
fi

# --- Summary ---
hdr "Summary"
if [[ "$ISSUES" -eq 0 ]]; then
  echo "All checks passed."
  [[ -z "$TARGET" ]] && echo "For target-specific diagnosis: $(basename "$0") <hostname-or-ip>"
else
  echo "Issues detected — review [FAIL] lines above."
  echo
  echo "Quick references:"
  echo "  No gateway:    check 'ip route' and network manager"
  echo "  Ping blocked:  ICMP may be filtered — try 'curl -Is https://1.1.1.1'"
  echo "  DNS failure:   test with 'host one.one.one.one 8.8.8.8'"
  echo "  MTU issues:    try 'sudo ip link set <iface> mtu 1400'"
fi

exit "$ISSUES"
