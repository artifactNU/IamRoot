#!/usr/bin/env bash
# check-cuda-compat.sh
# Purpose: Check NVIDIA driver, CUDA toolkit, and common compatibility issues
# Usage:   ./check-cuda-compat.sh
# Exit:    0 OK, 1 WARN, 2 DEGRADED

set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

STATUS="OK"
EXIT_CODE=0
REASONS=()

set_status() {
  local new="$1"
  case "$new" in
    OK) return ;;
    WARN)
      [[ "$STATUS" == "OK" ]] && STATUS="WARN" && EXIT_CODE=1
      ;;
    DEGRADED)
      STATUS="DEGRADED"
      EXIT_CODE=2
      ;;
  esac
}

add_reason() { REASONS+=("$1"); }

echo "=== CUDA / NVIDIA Compatibility Check ==="
echo "Date: $(date)"
echo

# ---------------- NVIDIA driver ----------------
if have nvidia-smi; then
  DRIVER_VERSION="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)"
  echo "NVIDIA driver version: ${DRIVER_VERSION:-unknown}"
else
  echo "NVIDIA driver: nvidia-smi not found"
  set_status DEGRADED
  add_reason "nvidia-smi missing (driver not installed or not loaded)"
fi
echo

# ---------------- CUDA runtime ----------------
CUDA_RUNTIME="none"
if have nvcc; then
  CUDA_RUNTIME="$(nvcc --version | awk -F'release ' '/release/ {print $2}' | awk '{print $1}')"
  echo "CUDA toolkit (nvcc): ${CUDA_RUNTIME}"
elif [[ -e /usr/local/cuda/version.txt ]]; then
  CUDA_RUNTIME="$(sed 's/CUDA Version //' /usr/local/cuda/version.txt 2>/dev/null)"
  echo "CUDA toolkit (/usr/local/cuda): ${CUDA_RUNTIME}"
else
  echo "CUDA toolkit: not found"
  set_status WARN
  add_reason "CUDA toolkit not detected"
fi
echo

# ---------------- Multiple CUDA installs ----------------
CUDA_PATHS=$(ls -d /usr/local/cuda-* 2>/dev/null || true)
CUDA_DIR_COUNT=$(echo "$CUDA_PATHS" | grep -c '^/usr/local/cuda-' || echo 0)
if [[ "$CUDA_DIR_COUNT" -gt 1 ]]; then
  echo "Multiple CUDA installations detected:"
  # shellcheck disable=SC2001
  echo "$CUDA_PATHS" | sed 's/^/  /'
  set_status WARN
  add_reason "multiple CUDA toolkits installed"
elif [[ "$CUDA_DIR_COUNT" -eq 1 ]]; then
  echo "CUDA install: $CUDA_PATHS"
fi
echo

# ---------------- Kernel module vs driver ----------------
if have lsmod && have nvidia-smi; then
  if ! lsmod | grep -q '^nvidia'; then
    echo "WARNING: NVIDIA kernel module not loaded"
    set_status DEGRADED
    add_reason "NVIDIA kernel module not loaded"
  fi
fi

# ---------------- CUDA + driver sanity ----------------
if [[ -n "${DRIVER_VERSION:-}" && "$CUDA_RUNTIME" != "none" ]]; then
  echo "Driver / CUDA pairing detected"
  echo "  Driver: ${DRIVER_VERSION}"
  echo "  CUDA:   ${CUDA_RUNTIME}"
  echo
  echo "NOTE: Exact compatibility depends on CUDA release notes."
  echo "      This script checks for obvious mismatches only."
fi

# ---------------- Python visibility (best effort) ----------------
echo
echo "=== Python CUDA visibility (best effort) ==="

if have python3; then
  python3 - <<'EOF'
import sys
print("Python:", sys.version.split()[0])
try:
    import torch
    print("PyTorch:", torch.__version__)
    print("  CUDA available:", torch.cuda.is_available())
    print("  CUDA version:", torch.version.cuda)
except Exception:
    print("PyTorch: not installed or failed to import")

try:
    import tensorflow as tf
    print("TensorFlow:", tf.__version__)
    print("  GPUs visible:", tf.config.list_physical_devices('GPU'))
except Exception:
    print("TensorFlow: not installed or failed to import")
EOF
else
  echo "python3 not available"
fi

# ---------------- Summary ----------------
echo
echo "=== Summary ==="
echo "Status: ${STATUS}"

if ((${#REASONS[@]} > 0)); then
  echo "Reasons:"
  for r in "${REASONS[@]}"; do
    echo " - $r"
  done
fi

exit "$EXIT_CODE"
