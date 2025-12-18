#!/usr/bin/env bash
# gpu-diagnostics.sh
# Purpose: Collect read-only NVIDIA GPU diagnostics for troubleshooting
# Usage:   ./gpu-diagnostics.sh
# Exit:    0 OK, 1 WARN

set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

echo "=== NVIDIA GPU DIAGNOSTICS ==="
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo

echo "=== GPU HARDWARE DETECTION ==="
if have lspci; then
  lspci | grep -i nvidia || echo "No NVIDIA devices found via lspci"
else
  echo "lspci not available"
fi
echo

echo "=== NVIDIA DRIVER STATUS ==="
if have nvidia-smi; then
  nvidia-smi || echo "nvidia-smi failed to run"
else
  echo "nvidia-smi not found (driver likely not installed)"
fi
echo

echo "=== LOADED NVIDIA KERNEL MODULES ==="
if have lsmod; then
  lsmod | grep nvidia || echo "No NVIDIA kernel modules loaded"
else
  echo "lsmod not available"
fi
echo

echo "=== NVIDIA MODULE INFORMATION ==="
if have modinfo; then
  modinfo nvidia 2>/dev/null | head || echo "modinfo nvidia failed (module not present)"
else
  echo "modinfo not available"
fi
echo

echo "=== /proc NVIDIA DRIVER VERSION ==="
if [ -r /proc/driver/nvidia/version ]; then
  cat /proc/driver/nvidia/version
else
  echo "/proc/driver/nvidia/version not present (driver not loaded)"
fi
echo

echo "=== DKMS STATUS (NVIDIA) ==="
if have dkms; then
  dkms status 2>/dev/null | grep -i nvidia || echo "No NVIDIA DKMS entries found"
else
  echo "dkms not available"
fi
echo

echo "=== RECENT NVIDIA-RELATED LOGS ==="
if have journalctl; then
  journalctl -b | grep -i nvidia | tail -n 100 \
    || echo "No NVIDIA messages found in journal"
else
  dmesg | grep -i nvidia | tail -n 50 \
    || echo "No NVIDIA messages found in dmesg"
fi
echo

echo "=== END OF GPU DIAGNOSTICS ==="
