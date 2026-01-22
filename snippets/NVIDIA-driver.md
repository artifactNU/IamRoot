# NVIDIA GPU Preflight & Install Order (APT)

Quick reference for verifying GPU presence and installing NVIDIA drivers safely on Ubuntu.
Use this when promoting a host from CPU-only to GPU-capable.

---

## Preflight: Verify GPU Hardware

lspci | grep -i nvidia
lspci -nn | grep -Ei 'vga|3d|display'

Expected:
- NVIDIA Corporation → GPU-capable host
- No NVIDIA device → do NOT install drivers

---

## Preflight: Verify Current NVIDIA State

lsmod | grep nvidia
command -v nvidia-smi

---

## Preflight: Check Kernel & OS

uname -r
lsb_release -a

---

## Install Order (GPU Node)

# 1. Install NVIDIA driver
sudo apt install nvidia-driver-535

# 2. Reboot immediately
sudo reboot

# 3. Verify driver
nvidia-smi

# 4. Freeze NVIDIA packages to prevent partial upgrades
sudo apt-mark hold \
  nvidia-driver-535 \
  nvidia-dkms-535 \
  libnvidia-compute-535 \
  libnvidia-gl-535 \
  nvidia-utils-535

# 5. Run normal system upgrade
sudo apt upgrade

---

## Notes

- Do not install nvidia-utils without the full driver
- Do not install NVIDIA drivers if no NVIDIA hardware is detected
- Always reboot immediately after driver installation
- Hold NVIDIA packages once the driver is verified
