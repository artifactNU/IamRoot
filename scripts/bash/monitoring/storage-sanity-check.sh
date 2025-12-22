#!/usr/bin/env bash
# storage-sanity-check.sh
# Purpose: Read-only storage sanity checks (space, inodes, biggest dirs/files, deleted-but-open files)
# Usage:   ./storage-sanity-check.sh [path] [--top N]
# Exit:    0 OK, 1 WARN

set -euo pipefail

PATH_TO_CHECK="/"
TOPN=10

while [ $# -gt 0 ]; do
  case "$1" in
    --top) TOPN="${2:-10}"; shift 2;;
    -h|--help)
      echo "Usage: $0 [path] [--top N]"
      exit 0
      ;;
    *)
      # first positional arg is path
      if [[ "$1" == /* ]]; then
        PATH_TO_CHECK="$1"
        shift
      else
        echo "Unknown arg: $1" >&2
        exit 2
      fi
      ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
hdr() { echo; echo "=== $* ==="; }

echo "=== STORAGE SANITY CHECK ==="
echo "Hostname: $(hostname -s 2>/dev/null || hostname)"
echo "Date:     $(date -Is)"
echo "Path:     ${PATH_TO_CHECK}"
echo

hdr "Filesystem usage (space)"
if have df; then
  df -hT "${PATH_TO_CHECK}" 2>/dev/null || df -hT 2>/dev/null || true
else
  echo "(df not available)"
fi

hdr "Filesystem usage (inodes)"
if have df; then
  df -ih "${PATH_TO_CHECK}" 2>/dev/null || df -ih 2>/dev/null || true
else
  echo "(df not available)"
fi

hdr "Top directories by apparent size (within ${PATH_TO_CHECK})"
if have du; then
  # Stay shallow for speed; ignore permission errors.
  du -x -h --max-depth=2 "${PATH_TO_CHECK}" 2>/dev/null | sort -h | tail -n "${TOPN}" || true
else
  echo "(du not available)"
fi

hdr "Large files (top ${TOPN})"
if have find; then
  # Only regular files; stay on same filesystem (-xdev) for sanity.
  # Note: this can be slow on huge trees, but ok for workstation roots.
  find "${PATH_TO_CHECK}" -xdev -type f -printf '%s\t%p\n' 2>/dev/null \
    | sort -n \
    | tail -n "${TOPN}" \
    | awk '
        function human(x) {
          s="B KiB MiB GiB TiB PiB"
          split(s,u," ")
          i=1
          while (x>=1024 && i<6) { x/=1024; i++ }
          return sprintf("%.2f %s", x, u[i])
        }
        { printf "%s\t%s\n", human($1), $2 }
      ' || true
else
  echo "(find not available)"
fi

hdr "Deleted-but-open disk files (top ${TOPN} by size)"
# This section is only useful for "df shows full but I can't find files".
# Desktop systems create lots of memfd/anon files that are NOT real disk usage.
if have lsof; then
  TMP="$(mktemp -t storage-lsof.XXXXXX)"
  trap 'rm -f "$TMP"' EXIT

  # +L1 => files with link count < 1 (deleted)
  # We:
  # - keep only regular files (TYPE=REG)
  # - keep only real paths (no memfd/anon_inode)
  # - drop obvious tmpfs locations (/run, /dev/shm)
  # - sort by size descending, show top N
  lsof -nP +L1 2>/dev/null \
    | awk '
        NR==1 {next}
        $5=="REG" {
          name=""
          for (i=9; i<=NF; i++) name = name (i==9 ? "" : " ") $i

          # Drop memfd/anon/in-memory stuff
          if (name ~ /^\/memfd:/) next
          if (name ~ /^memfd:/) next
          if (name ~ /^anon_inode:/) next
          if (name ~ /\/memfd:/) next

          # Drop tmpfs-ish paths where space isnt your root filesystem
          if (name ~ /^\/run\//) next
          if (name ~ /^\/dev\/shm\//) next

          # SIZE/OFF is column 7 in lsof default output
          size=$7
          if (size ~ /^[0-9]+$/ && size > 0) {
            printf "%s\t%s\t%s\t%s\n", size, $1, $2, $3, name
          }
        }
      ' >"$TMP"

  if [ -s "$TMP" ]; then
    sort -nr "$TMP" | head -n "${TOPN}" | awk '
      function human(x) {
        s="B KiB MiB GiB TiB PiB"
        split(s,u," ")
        i=1
        while (x>=1024 && i<6) { x/=1024; i++ }
        return sprintf("%.2f %s", x, u[i])
      }
      {
        size=$1; cmd=$2; pid=$3; user=$4;
        name=""
        for(i=5;i<=NF;i++) name=name (i==5?"":" ") $i
        printf "%s\tPID=%s\tUSER=%s\tCMD=%s\t%s\n", human(size), pid, user, cmd, name
      }
    '
  else
    echo "(none detected)"
  fi
else
  echo "(lsof not available)"
fi

hdr "Notes"
echo "- If a filesystem is full but you can't find large files, deleted-but-open files can be the cause."
echo "- This script filters out memfd/anon/tmpfs noise to keep that section actionable."
echo "- Inode exhaustion looks like 'No space left on device' even when df shows free space."
