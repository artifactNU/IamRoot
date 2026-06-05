#!/usr/bin/env bash
# check-cert-expiry.sh
# Purpose: Check TLS certificate expiry for remote hosts and local cert files
# Usage:   ./check-cert-expiry.sh [--warn DAYS] [--critical DAYS] [-v] <host[:port]|file> [...]
# Exit:    0 all OK, 1 warn, 2 critical/expired

set -euo pipefail

WARN_DAYS=30
CRIT_DAYS=7
VERBOSE=0
EXIT_CODE=0

have() { command -v "$1" >/dev/null 2>&1; }
hdr()  { echo; echo "=== $* ==="; }
kv()   { printf "%-22s %s\n" "$1:" "$2"; }

TARGETS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --warn|-w)     WARN_DAYS="$2"; shift 2 ;;
    --critical|-c) CRIT_DAYS="$2"; shift 2 ;;
    -v|--verbose)  VERBOSE=1; shift ;;
    -h|--help)
      cat <<'EOF'
check-cert-expiry.sh [--warn DAYS] [--critical DAYS] [-v] <host[:port]|file> [...]

Check TLS certificate expiry for remote hosts or local certificate files.
Read-only. Requires openssl.

  --warn DAYS, -w      Warn threshold in days        (default: 30)
  --critical DAYS, -c  Critical threshold in days    (default: 7)
  -v, --verbose        Also show subject CN and issuer

Arguments:
  hostname          Check HTTPS on port 443
  hostname:port     Check TLS on specified port
  /path/to/cert.pem Read a local PEM certificate file

Exit codes:
  0  All certificates OK
  1  One or more expire within --warn threshold
  2  One or more expired or within --critical threshold

Examples:
  ./check-cert-expiry.sh example.com
  ./check-cert-expiry.sh example.com:8443 --warn 60
  ./check-cert-expiry.sh /etc/ssl/certs/myapp.pem
  ./check-cert-expiry.sh example.com /etc/letsencrypt/live/example.com/cert.pem
EOF
      exit 0
      ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *)  TARGETS+=("$1"); shift ;;
  esac
done

if ! have openssl; then
  echo "ERROR: openssl is required but not found" >&2
  exit 2
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
  echo "Usage: $(basename "$0") [--warn DAYS] [--critical DAYS] <host[:port]|file> [...]" >&2
  echo "Run with --help for details." >&2
  exit 2
fi

fetch_remote_cert() {
  local host="$1" port="$2"
  echo | timeout 10 openssl s_client \
    -connect "${host}:${port}" \
    -servername "${host}" \
    2>/dev/null \
    | openssl x509 2>/dev/null || true
}

fetch_file_cert() {
  openssl x509 -in "$1" 2>/dev/null || true
}

check_cert() {
  local label="$1" cert="$2"

  if [ -z "$cert" ]; then
    printf "%-44s  %-8s  %s\n" "$label" "ERROR" "no certificate retrieved"
    EXIT_CODE=2
    return
  fi

  local end_date days_left status
  end_date=$(echo "$cert" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

  local expiry_epoch now_epoch
  expiry_epoch=$(date -d "$end_date" +%s)
  now_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

  if   [ "$days_left" -le 0 ];            then status="EXPIRED"
  elif [ "$days_left" -le "$CRIT_DAYS" ]; then status="CRITICAL"
  elif [ "$days_left" -le "$WARN_DAYS" ]; then status="WARN"
  else                                         status="OK"
  fi

  case "$status" in
    EXPIRED|CRITICAL) [ "$EXIT_CODE" -lt 2 ] && EXIT_CODE=2 ;;
    WARN)             [ "$EXIT_CODE" -lt 1 ] && EXIT_CODE=1 ;;
  esac

  printf "%-44s  %-8s  %4d days  %s\n" "$label" "$status" "$days_left" "$end_date"

  if (( VERBOSE )); then
    local cn issuer
    cn=$(echo "$cert" | openssl x509 -noout -subject 2>/dev/null \
      | grep -oP '(?<=CN\s=\s)[^,/]+' || echo "(unknown)")
    issuer=$(echo "$cert" | openssl x509 -noout -issuer 2>/dev/null \
      | grep -oP '(?<=O\s=\s)[^,/]+' | head -1 || echo "(unknown)")
    printf "    CN: %-36s  Issuer: %s\n" "$cn" "$issuer"
  fi
}

echo "=== TLS CERTIFICATE EXPIRY ==="
kv "Timestamp"  "$(date -Is 2>/dev/null || date)"
kv "Warn"       "${WARN_DAYS} days"
kv "Critical"   "${CRIT_DAYS} days"

hdr "Results"
printf "%-44s  %-8s  %9s  %s\n" "TARGET" "STATUS" "EXPIRES" "EXPIRY DATE"
printf "%-44s  %-8s  %9s  %s\n" "------" "------" "-------" "-----------"

for target in "${TARGETS[@]}"; do
  if [ -f "$target" ]; then
    cert=$(fetch_file_cert "$target") || true
    check_cert "$target" "$cert"
  else
    host="${target%%:*}"
    port="${target##*:}"
    [ "$port" = "$target" ] && port=443
    cert=$(fetch_remote_cert "$host" "$port") || true
    check_cert "${host}:${port}" "$cert"
  fi
done

echo
case $EXIT_CODE in
  0) echo "All certificates OK." ;;
  1) echo "WARNING: Certificate(s) expiring within ${WARN_DAYS} days." ;;
  2) echo "CRITICAL: Certificate(s) expired or expiring within ${CRIT_DAYS} days." ;;
esac

exit $EXIT_CODE
