#!/usr/bin/env bash
# inventory-workstation.sh
# Purpose: Generate a Markdown inventory page for a workstation (doc-friendly)
# Usage:   ./inventory-workstation.sh [--public] [--out FILE]
# Exit:    0 OK, 2 usage/error

set -euo pipefail

PUBLIC=0
OUTFILE=""

usage() {
  cat <<'EOF'
inventory-workstation.sh [--public] [--out FILE]

  --public    Redact sensitive fields (IPs, MACs, owners/contact)
  --out FILE  Write output to FILE (default: stdout)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --public) PUBLIC=1; shift ;;
    --out)
      OUTFILE="${2:-}"
      [[ -n "$OUTFILE" ]] || { usage >&2; exit 2; }
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# If writing to a file, redirect all output there
if [[ -n "$OUTFILE" ]]; then
  : >"$OUTFILE"
  exec >"$OUTFILE"
fi

# ---------- Metadata (human curated) ----------
META_FILE="/etc/iamroot/inventory.conf"
LOCATION="${LOCATION:-}"
ROLE="${ROLE:-}"
OWNER_GROUP="${OWNER_GROUP:-}"
CONTACT="${CONTACT:-}"
NOTES="${NOTES:-}"

if [[ -r "$META_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$META_FILE"
fi

# ---------- Collect facts ----------
HOST="$(hostname 2>/dev/null || echo unknown)"
FQDN="$(hostname -f 2>/dev/null || echo "$HOST")"

OS="unknown"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS="${PRETTY_NAME:-unknown}"
fi

KERNEL="$(uname -r 2>/dev/null || echo unknown)"
UPTIME="$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo unknown)"

CPU_MODEL="unknown"
CPU_CORES="unknown"
if have lscpu; then
  CPU_MODEL="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' || true)"
  CPU_CORES="$(lscpu 2>/dev/null | awk -F: '/^CPU\(s\)/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' || true)"
fi

RAM_TOTAL="unknown"
if have free; then
  RAM_TOTAL="$(free -h 2>/dev/null | awk '/^Mem:/ {print $2; exit}' || true)"
fi

# Storage summary: disks only (robust, handles empty/spaceful MODEL)
STORAGE_LINES=""
if have lsblk; then
  # -P outputs KEY="VALUE" pairs; safe to parse without field-shifting issues
  # -d only top-level devices; -n no header
  # We select disks and then print a stable table ourselves.
  DISK_ROWS="$(lsblk -dnP -o NAME,SIZE,MODEL,TYPE 2>/dev/null | grep 'TYPE="disk"' || true)"
  if [[ -n "$DISK_ROWS" ]]; then
    STORAGE_LINES="NAME\tSIZE\tMODEL\tTYPE"
    while IFS= read -r row; do
      # shellcheck disable=SC1090
      eval "$row"   # sets NAME, SIZE, MODEL, TYPE variables from KEY="VALUE" pairs
      MODEL="${MODEL:-}"
      # Normalize empty model
      [[ -z "$MODEL" ]] && MODEL="(unknown)"
      STORAGE_LINES+=$'\n'"${NAME}\t${SIZE}\t${MODEL}\t${TYPE}"
    done <<< "$DISK_ROWS"
  fi
fi

# Filesystems (useful even when disk view is odd)
FS_LINES=""
if have df; then
  FS_LINES="$(df -h -x tmpfs -x devtmpfs 2>/dev/null || true)"
fi

# GPU summary (NVIDIA)
NVIDIA_DRIVER=""
GPU_LIST=""
if have nvidia-smi; then
  NVIDIA_DRIVER="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 || true)"
  GPU_LIST="$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || true)"
fi

# CUDA toolkit version (best-effort)
CUDA_VER=""
if have nvcc; then
  CUDA_VER="$(nvcc --version 2>/dev/null | awk -F'release ' '/release/ {print $2}' | awk '{print $1}' || true)"
elif [[ -r /usr/local/cuda/version.txt ]]; then
  CUDA_VER="$(sed 's/CUDA Version //' /usr/local/cuda/version.txt 2>/dev/null || true)"
fi

# Network info (redactable)
NET_LINES=""
if have ip; then
  NET_LINES="$(ip -brief addr show 2>/dev/null || true)"
fi

MAC_LINES=""
if [[ "$PUBLIC" -eq 0 ]] && have ip; then
  MAC_LINES="$(ip -brief link show 2>/dev/null | awk '{print $1, $3}' || true)"
fi

# ---------- Render Markdown ----------
echo "# Workstation Inventory: ${HOST}"
echo

echo "## Identity"
echo "- Hostname: ${HOST}"
if [[ "$PUBLIC" -eq 1 ]]; then
  echo "- FQDN: (redacted)"
else
  echo "- FQDN: ${FQDN}"
fi
echo "- Role: ${ROLE:-"(unset)"}"
echo "- Location: ${LOCATION:-"(unset)"}"
echo "- Notes: ${NOTES:-"(none)"}"

if [[ "$PUBLIC" -eq 0 ]]; then
  echo "- Owners: ${OWNER_GROUP:-"(unset)"}"
  echo "- Contact: ${CONTACT:-"(unset)"}"
fi
echo

echo "## System"
echo "- OS: ${OS}"
echo "- Kernel: ${KERNEL}"
echo "- Uptime: ${UPTIME}"
echo

echo "## Hardware"
echo "- CPU: ${CPU_MODEL} (${CPU_CORES} cores)"
echo "- RAM: ${RAM_TOTAL}"
echo

echo "### Storage"
if [[ -n "$STORAGE_LINES" ]]; then
  echo '```text'
  # Print tabbed table; expand tabs for readability where supported
  echo "$STORAGE_LINES" | expand -t 2 2>/dev/null || echo "$STORAGE_LINES"
  echo '```'
else
  echo "- (no physical disks detected via lsblk)"
fi

if [[ -n "$FS_LINES" ]]; then
  echo
  echo "#### Filesystems"
  echo '```text'
  echo "$FS_LINES"
  echo '```'
fi
echo

echo "### GPU"
if [[ -n "$GPU_LIST" ]]; then
  echo "- NVIDIA GPUs detected"
  echo '```text'
  echo "$GPU_LIST"
  echo '```'
else
  echo "- (none detected or nvidia-smi not available)"
fi
echo

echo "## Software (relevant)"
echo "- NVIDIA driver: ${NVIDIA_DRIVER:-"(unknown or not installed)"}"
echo "- CUDA toolkit: ${CUDA_VER:-"(not detected)"}"
echo

if [[ -n "$NET_LINES" ]]; then
  echo "## Network"
  if [[ "$PUBLIC" -eq 1 ]]; then
    echo "- Interfaces: (addresses redacted)"
    echo '```text'
    echo "$NET_LINES" | awk '{print $1, $2}'
    echo '```'
  else
    echo '```text'
    echo "$NET_LINES"
    echo '```'
    if [[ -n "$MAC_LINES" ]]; then
      echo
      echo "### MAC addresses"
      echo '```text'
      echo "$MAC_LINES"
      echo '```'
    fi
  fi
  echo
fi

echo "---"
echo "Generated: $(date -Is 2>/dev/null || date)"

if [[ -n "$OUTFILE" ]]; then
  echo "Wrote: $OUTFILE" >&2
fi
