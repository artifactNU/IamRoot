# Boot Problems

Diagnosing and fixing systems that won't boot.

---

## Why This Matters

Boot problems are critical:
- System is completely unavailable
- Limited diagnostic tools available
- Time pressure to restore service
- Risk of data loss if handled incorrectly

Understanding the boot process helps you identify where it's failing.

---

## Linux Boot Process Overview

```
1. BIOS/UEFI
   ↓
2. Bootloader (GRUB)
   ↓
3. Kernel Loading
   ↓
4. initramfs/initrd
   ↓
5. Root Filesystem Mount
   ↓
6. Init System (systemd/init)
   ↓
7. System Services
   ↓
8. Login Prompt
```

**Each stage depends on the previous one.**

Identify which stage is failing to narrow down the cause.

---

## Stage 1: BIOS/UEFI Issues

### Symptoms
- No POST (Power-On Self-Test)
- Beep codes
- "No bootable device" message
- Boot device not found

### Diagnosis

**Check boot order:**
1. Enter BIOS/UEFI (usually Del, F2, F12 during boot)
2. Check boot device priority
3. Verify hard drive is detected

**Hardware checks:**
```bash
# From another system or rescue disk
# Check if disk is detected
lsblk
fdisk -l

# SMART status
smartctl -a /dev/sda
```

### Common Fixes

**Boot order wrong:**
- Set correct hard drive as first boot device
- Save BIOS/UEFI settings

**Disk not detected:**
- Check cables (if physical access)
- Check disk in another system
- Disk may be failed (check SMART)

---

## Stage 2: GRUB Bootloader Issues

### Symptoms
- "GRUB" on black screen
- "error: no such partition"
- "error: file not found"
- Drops to GRUB rescue prompt

### GRUB Rescue Mode

If you see `grub rescue>` prompt:

```bash
# List available partitions
grub rescue> ls

# Example output: (hd0) (hd0,msdos1) (hd0,msdos2)

# Find the partition with /boot
grub rescue> ls (hd0,msdos1)/
grub rescue> ls (hd0,msdos2)/boot/

# Once found, set root
grub rescue> set root=(hd0,msdos2)
grub rescue> set prefix=(hd0,msdos2)/boot/grub

# Load normal mode
grub rescue> insmod normal
grub rescue> normal
```

### Reinstall GRUB

Boot from live CD/USB:

```bash
# Mount root filesystem
mount /dev/sda2 /mnt

# Mount boot if separate partition
mount /dev/sda1 /mnt/boot

# Mount system directories
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

# Chroot into system
chroot /mnt

# Reinstall GRUB
# For BIOS/MBR:
grub-install /dev/sda

# For UEFI:
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu

# Update GRUB configuration
update-grub

# Exit and reboot
exit
umount /mnt/boot /mnt/dev /mnt/proc /mnt/sys /mnt
reboot
```

### GRUB Configuration Issues

```bash
# Edit GRUB at boot time (temporary fix)
# At GRUB menu, press 'e' to edit

# Common fixes:
# Change: root=UUID=xxxx
# To: root=/dev/sda2

# Or change:
# quiet splash
# To:
# nomodeset

# Press Ctrl+X or F10 to boot

# Once booted, fix permanently:
sudo update-grub
```

---

## Stage 3: Kernel Panic

### Symptoms
- "Kernel panic - not syncing"
- "VFS: Cannot open root device"
- "Unable to mount root fs"
- System freezes during boot

### Common Causes

1. **Wrong root device in GRUB**
2. **Missing kernel modules**
3. **Corrupted initramfs**
4. **Hardware driver issues**

### Boot to Previous Kernel

At GRUB menu:
1. Select "Advanced options"
2. Choose older kernel version
3. If this works, problem is with new kernel

### Fix initramfs

Boot from live CD/USB:

```bash
# Mount root
mount /dev/sda2 /mnt
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

# Chroot
chroot /mnt

# Rebuild initramfs
update-initramfs -u -k all

# Or for specific kernel
update-initramfs -u -k 5.15.0-56-generic

# Exit and reboot
exit
reboot
```

### Kernel Parameters

Try adding boot parameters:

```bash
# At GRUB menu, press 'e' to edit

# Add to linux line:
init=/bin/bash         # Boot to shell
single                 # Single user mode
nomodeset             # Disable graphics drivers
acpi=off              # Disable ACPI
noapic                # Disable APIC
```

---

## Stage 4: Filesystem Mount Issues

### Symptoms
- "Cannot mount root filesystem"
- "Failed to mount /dev/sda2"
- Drops to emergency shell
- Read-only filesystem

### Emergency Shell

If dropped to emergency shell:

```bash
# Check what's mounted
mount | grep ' / '

# Try to remount root as read-write
mount -o remount,rw /

# Check filesystem
fsck /dev/sda2

# Check /etc/fstab
cat /etc/fstab

# Try to mount all from fstab
mount -a

# View errors
dmesg | tail -50
journalctl -xb
```

### /etc/fstab Errors

**Wrong UUID or device:**

```bash
# Check current UUIDs
blkid

# Compare with /etc/fstab
cat /etc/fstab

# Fix /etc/fstab if mismatch
nano /etc/fstab

# Update UUIDs to match blkid output
```

**Wrong filesystem type:**

```bash
# Check actual filesystem type
blkid /dev/sda2

# Update in /etc/fstab
```

### Filesystem Corruption

```bash
# Boot from live CD/USB
# DO NOT mount the corrupted filesystem

# Check filesystem
fsck -y /dev/sda2

# For ext4 specifically
e2fsck -f -y /dev/sda2

# If superblock is damaged
e2fsck -b 32768 /dev/sda2

# Reboot and try again
reboot
```

---

## Stage 5: systemd/Init Issues

### Symptoms
- Boot hangs at "Loading"
- "Failed to start" messages
- Timeout errors
- Black screen after kernel messages

### Check systemd Status

Boot to rescue/emergency mode:

```bash
# At GRUB, add to kernel line:
systemd.unit=rescue.target
# or
systemd.unit=emergency.target

# Once booted, check what failed
systemctl list-units --failed
systemctl status <failed_unit>

# View detailed logs
journalctl -xb
journalctl -u <service_name>
```

### Common systemd Issues

**Service dependency loops:**
```bash
# Check dependencies
systemctl list-dependencies <service>

# Disable problematic service temporarily
systemctl mask <service>

# Reboot and diagnose
```

**Timeout during boot:**
```bash
# Identify slow service
systemd-analyze blame
systemd-analyze critical-chain

# Increase timeout temporarily
systemctl edit <service>

# Add:
[Service]
TimeoutStartSec=300
```

### Recover from Broken systemd

```bash
# Boot to shell
# At GRUB, add: init=/bin/bash

# Remount root as read-write
mount -o remount,rw /

# Fix the issue
# ...

# Reboot properly
exec /sbin/init
```

---

## Single User Mode / Recovery Mode

### Enter Single User Mode

**Method 1: GRUB parameter**
```bash
# At GRUB, press 'e'
# Add to linux line:
single
# or
systemd.unit=rescue.target

# Boot with Ctrl+X
```

**Method 2: Recovery mode**
- Select "Advanced options" at GRUB
- Choose "Recovery mode"
- Select "root" for root shell

### What You Can Do

```bash
# Remount root as read-write
mount -o remount,rw /

# Reset root password
passwd root

# Fix /etc/fstab
nano /etc/fstab

# Reinstall packages
apt-get install --reinstall <package>

# Check filesystem
fsck -y /dev/sda2

# Check and repair GRUB
update-grub
grub-install /dev/sda
```

---

## Specific Boot Problems

### Black Screen After GRUB

**Graphics driver issue:**

```bash
# At GRUB, add kernel parameter:
nomodeset

# If this works, fix permanently:
sudo nano /etc/default/grub

# Add to GRUB_CMDLINE_LINUX_DEFAULT:
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nomodeset"

# Update GRUB
sudo update-grub
```

### Boot Hangs at Logo

**Disable quiet splash to see errors:**

```bash
# At GRUB, edit kernel line
# Remove: quiet splash
# Or add: debug

# See what's happening
# Usually a service timeout
```

### System Reboots During Boot

**Check for kernel panic in logs:**

```bash
# Boot from live CD
# Mount root filesystem
mount /dev/sda2 /mnt

# Check kernel logs
cat /mnt/var/log/kern.log
cat /mnt/var/log/syslog

# Look for:
# - Kernel panic
# - Hardware errors
# - Driver issues
```

### Cannot Find Root Device

**UUID changed (after cloning disk):**

```bash
# Boot from live CD
# Find new UUIDs
blkid

# Mount root
mount /dev/sda2 /mnt

# Update /etc/fstab
nano /mnt/etc/fstab

# Update GRUB
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt
update-grub
exit
reboot
```

---

## UEFI Boot Issues

### UEFI Boot Order

**Boot entry missing:**

```bash
# Install efibootmgr
apt-get install efibootmgr

# List boot entries
efibootmgr -v

# Create new entry
efibootmgr -c -d /dev/sda -p 1 -L "Ubuntu" -l "\EFI\ubuntu\grubx64.efi"

# Set boot order
efibootmgr -o 0000,0001,0002
```

### Secure Boot Issues

**Unsigned kernel or driver:**

```bash
# Disable Secure Boot in BIOS/UEFI
# Or sign kernel modules (advanced)
```

---

## Dual Boot Issues

### Windows Overwrote GRUB

**Restore GRUB:**

```bash
# Boot from Ubuntu live CD
# Reinstall GRUB (see GRUB section above)

# Detect Windows
sudo os-prober

# Update GRUB
sudo update-grub
```

### Missing Windows Entry

```bash
# Install os-prober
apt-get install os-prober

# Enable os-prober
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub

# Update GRUB
update-grub
```

---

## Data Recovery Boot

### Access Data Without Booting System

```bash
# Boot from live CD/USB

# Find partitions
lsblk
fdisk -l

# Mount partition
mkdir /mnt/recovery
mount /dev/sda2 /mnt/recovery

# Access files
cd /mnt/recovery/home/username

# Copy important data
cp -r /mnt/recovery/home/username/Documents /media/usb/
```

### Mount Encrypted Partition

```bash
# For LUKS encrypted disk
cryptsetup luksOpen /dev/sda2 cryptroot
mount /dev/mapper/cryptroot /mnt/recovery
```

---

## Prevention and Best Practices

### Regular Backups

```bash
# Backup GRUB config
cp /boot/grub/grub.cfg /root/grub.cfg.backup

# Backup /etc/fstab
cp /etc/fstab /root/fstab.backup

# Test backups regularly
```

### Keep Old Kernels

```bash
# Don't auto-remove all old kernels
# Keep at least 2-3 previous versions

# Debian/Ubuntu - set in /etc/apt/apt.conf.d/01autoremove
APT::NeverAutoRemove::regex "^linux-image.*";
```

### Document Changes

Keep notes of:
- Disk partition changes
- Bootloader modifications
- Kernel parameter changes
- Hardware changes

---

## Quick Reference

**Boot to rescue:**
```bash
# GRUB parameter:
systemd.unit=rescue.target        # Rescue mode
single                            # Single user
init=/bin/bash                    # Direct shell
```

**Common fixes:**
```bash
mount -o remount,rw /             # Remount root rw
fsck -y /dev/sda2                 # Check filesystem
update-grub                       # Regenerate GRUB
update-initramfs -u               # Rebuild initramfs
grub-install /dev/sda             # Reinstall GRUB
```

**Check what failed:**
```bash
journalctl -xb                    # Boot logs
systemctl --failed                # Failed services
dmesg | less                      # Kernel messages
```

---

## Further Reading

- `man grub-install` - Install GRUB
- `man fsck` - Filesystem check
- `man systemd` - System and service manager
- GRUB Manual: https://www.gnu.org/software/grub/manual/
