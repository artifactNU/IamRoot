#!/usr/bin/env bash
# find-large-data.sh
# Purpose: Find large user-owned files that commonly fill disks on workstations
# Usage:   ./find-large-data.sh [-s SIZE_GB] [-p PATH] [-n NUM]
# Exit:    0 OK, 2 invalid usage

set -euo pipefail

# Defaults
MIN_SIZE_GB=5
SEARCH_PATH="/home"
MAX_RESULTS=20

usage() {
  cat <<EOF
find-large-data.sh [-s SIZE_GB] [-p PATH] [-n NUM]

  -s SIZE_GB   Minimum file size in GB (default: ${MIN_SIZE_GB})
  -p PATH      Path to search (default: ${SEARCH_PATH})
  -n NUM       Max results to show (default: ${MAX_RESULTS})
EOF
}

while getopts ":s:p:n:h" opt; do
  case "$opt" in
    s) MIN_SIZE_GB="$OPTARG" ;;
    p) SEARCH_PATH="$OPTARG" ;;
    n) MAX_RESULTS="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if ! [[ "$MIN_SIZE_GB" =~ ^[0-9]+$ ]]; then
  echo "ERROR: SIZE_GB must be an integer" >&2
  exit 2
fi

if [[ ! -d "$SEARCH_PATH" ]]; then
  echo "ERROR: Path not found: $SEARCH_PATH" >&2
  exit 2
fi

MIN_SIZE_BYTES=$(( MIN_SIZE_GB * 1024 * 1024 * 1024 ))

echo "Finding files >= ${MIN_SIZE_GB}GB under ${SEARCH_PATH}"
echo "Showing top ${MAX_RESULTS} results"
echo

# Exclusions: virtual / noisy paths
EXCLUDES=(
  "/proc"
  "/sys"
  "/dev"
  "/run"
  "/tmp"
  "/var/lib/docker"
  "/var/lib/snapd"
)

PRUNE_ARGS=()
for e in "${EXCLUDES[@]}"; do
  PRUNE_ARGS+=( -path "$e" -o )
done
unset 'PRUNE_ARGS[${#PRUNE_ARGS[@]}-1]'

# Find large regular files, print size (bytes), owner, path
# Suppress permission noise; this is best-effort
find "$SEARCH_PATH" \
  \( "${PRUNE_ARGS[@]}" \) -prune -o \
  -type f -size +"${MIN_SIZE_BYTES}c" \
  -printf '%s %u %p\n' 2>/dev/null \
| sort -nr \
| head -n "$MAX_RESULTS" \
| awk '
  function human(bytes) {
    split("B KB MB GB TB PB", unit)
    for (i=1; bytes>=1024 && i<6; i++) bytes/=1024
    return sprintf("%.1f %s", bytes, unit[i])
  }
  {
    printf "%-10s %-12s %s\n", human($1), $2, $3
  }
'

