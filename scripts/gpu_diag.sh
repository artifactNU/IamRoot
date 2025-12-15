#!/usr/bin/env bash
# gpu_diag.sh
# Purpose: Collect read-only NVIDIA GPU and system diagnostics for troubleshooting
# Usage:   ./gpu_diag.sh
# Output:  gpu_diagnostics_<hostname>_<YYYYMMDD_HHMMSS>.txt

OUTFILE="gpu_diagnostics_$(hostname)_$(date +%Y%m%d_%H%M%S).txt"

echo "=== GPU & SYSTEM DIAGNOSTICS ===" | tee "$OUTFILE"
echo "Date: $(date)" | tee -a "$OUTFILE"
echo "" | tee -a "$OUTFILE"

echo "=== BASIC SYSTEM INFO ===" | tee -a "$OUTFILE"
{
  echo "Hostname:"
  hostname
  echo ""
  echo "Hostnamectl:"
  hostnamectl || echo "hostnamectl not available"
  echo ""
  echo "Kernel version:"
  uname -r
  echo ""
  echo "OS release:"
  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -a 2>/dev/null
  else
    cat /etc/os-release 2>/dev/null
  fi
  echo ""
} >> "$OUTFILE"

echo "=== GPU / NVIDIA INFO ===" | tee -a "$OUTFILE"
{
  echo "lspci | grep -i nvidia:"
  lspci | grep -i nvidia || echo "No NVIDIA devices found (or lspci not available)"
  echo ""

  echo "nvidia-smi:"
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi || echo "nvidia-smi failed to run"
  else
    echo "nvidia-smi not found in PATH"
  fi
  echo ""

  echo "Loaded NVIDIA modules (lsmod | grep nvidia):"
  lsmod | grep nvidia || echo "No NVIDIA modules loaded"
  echo ""

  echo "modinfo nvidia (first lines):"
  modinfo nvidia 2>/dev/null | head || echo "modinfo nvidia failed (module not found?)"
  echo ""

  echo "/proc/driver/nvidia/version:"
  cat /proc/driver/nvidia/version 2>/dev/null || echo "No /proc/driver/nvidia/version (driver not loaded?)"
  echo ""
} >> "$OUTFILE"

echo "=== DKMS STATUS (if available) ===" | tee -a "$OUTFILE"
{
  if command -v dkms >/dev/null 2>&1; then
    dkms status 2>/dev/null || echo "dkms status command failed"
  else
    echo "dkms command not found"
  fi
  echo ""
} >> "$OUTFILE"

echo "=== RECENT NVIDIA-RELATED LOGS ===" | tee -a "$OUTFILE"
{
  if command -v journalctl >/dev/null 2>&1; then
    echo "Using journalctl:" 
    journalctl -b | grep -i nvidia | tail -n 100 || echo "No NVIDIA messages found in journal (or insufficient permissions)"
  else
    echo "journalctl not available, checking dmesg instead:"
    dmesg | grep -i nvidia | tail -n 50 || echo "No NVIDIA messages found in dmesg"
  fi
  echo ""
} >> "$OUTFILE"

echo "=== DISK / SSD INFO ===" | tee -a "$OUTFILE"
{
  echo "lsblk:"
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null || echo "lsblk failed"
  echo ""
  echo "df -h:"
  df -h 2>/dev/null || echo "df -h failed"
  echo ""
} >> "$OUTFILE"

echo "Diagnostics saved to $OUTFILE"
