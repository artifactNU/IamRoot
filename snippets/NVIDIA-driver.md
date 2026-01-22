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

## Check What's on Hold

# Show all packages on hold
apt-mark showhold

# Check if specific NVIDIA packages are held
apt-mark showhold | grep nvidia

# Unhold a package (if needed)
sudo apt-mark unhold nvidia-driver-535

---

## Check Installed NVIDIA Package Versions

# List all installed NVIDIA packages
dpkg -l | grep nvidia

# Check specific driver version
dpkg -l | grep nvidia-driver

# Check if 535 or another version is installed
apt list --installed | grep nvidia-driver

# Show detailed package info
apt show nvidia-driver-535

# Check available driver versions
apt search nvidia-driver-[0-9]

---

## Troubleshooting & Maintenance

# Check if NVIDIA kernel modules are loaded
lsmod | grep nvidia

# View NVIDIA driver version from nvidia-smi
nvidia-smi --query-gpu=driver_version --format=csv,noheader

# Check for conflicting nouveau driver
lsmod | grep nouveau

# View DKMS status (Dynamic Kernel Module Support)
dkms status | grep nvidia

# Check for NVIDIA processes
fuser -v /dev/nvidia*

# View CUDA version (if CUDA installed)
nvcc --version

# Check GPU temperature and utilization
nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv

---

## Common Issues

# If upgrade wants to remove NVIDIA packages
# First, check what's trying to be removed:
sudo apt upgrade --dry-run

# If NVIDIA packages conflict, unhold temporarily:
sudo apt-mark unhold $(apt-mark showhold | grep nvidia)
sudo apt upgrade
# Then re-hold after verifying nvidia-smi works

# If driver not loading after kernel update:
sudo dkms autoinstall
sudo reboot

---

## Notes

- Do not install nvidia-utils without the full driver
- Do not install NVIDIA drivers if no NVIDIA hardware is detected
- Always reboot immediately after driver installation
- Hold NVIDIA packages once the driver is verified
- Check held packages before system upgrades to avoid conflicts
- Different Ubuntu versions may have different driver versions available (e.g., 535, 545, 550)
