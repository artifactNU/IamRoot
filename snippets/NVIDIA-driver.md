## NVIDIA GPU Preflight & Install Order (APT)

Quick reference for verifying GPU presence and installing NVIDIA drivers safely on Ubuntu.

### Before You Start

**Verify GPU hardware:**
```bash
lspci | grep -i nvidia
lspci -nn | grep -Ei 'vga|3d|display'
```
Expected: NVIDIA Corporation → GPU-capable host  
No NVIDIA device → **do NOT install drivers**

**Check current state:**
```bash
lsmod | grep nvidia
command -v nvidia-smi
uname -r
lsb_release -a
```

### Installation Steps

```bash
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
```

### Package Management

**Check held packages:**
```bash
apt-mark showhold
apt-mark showhold | grep nvidia
```

**Unhold if needed:**
```bash
sudo apt-mark unhold nvidia-driver-535
```

**Check installed versions:**
```bash
dpkg -l | grep nvidia
apt list --installed | grep nvidia-driver
apt show nvidia-driver-535
apt search nvidia-driver-[0-9]
```

### Diagnostics

```bash
# Check kernel modules
lsmod | grep nvidia
lsmod | grep nouveau

# Driver info
nvidia-smi --query-gpu=driver_version --format=csv,noheader
nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv

# DKMS and processes
dkms status | grep nvidia
fuser -v /dev/nvidia*

# CUDA version (if installed)
nvcc --version
```

**Common fixes:**
```bash
# If upgrade wants to remove NVIDIA packages:
sudo apt upgrade --dry-run

# If packages conflict, temporarily unhold:
sudo apt-mark unhold $(apt-mark showhold | grep nvidia)
sudo apt upgrade
# Then re-hold after verifying nvidia-smi works

# If driver not loading after kernel update:
sudo dkms autoinstall
sudo reboot
```

**Important notes:**
- Always reboot immediately after driver installation
- Hold NVIDIA packages once verified
- Don't install drivers if no NVIDIA hardware detected
- Check held packages before system upgrades
