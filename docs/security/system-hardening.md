# System Hardening

Reducing attack surface and securing Linux systems.

---

## Why This Matters

**Hardening** means making your system more difficult to compromise:
- Remove unnecessary services and software
- Apply security configurations
- Restrict access appropriately
- Keep systems updated

Most breaches exploit:
- Unpatched vulnerabilities
- Default configurations
- Unnecessary services
- Weak access controls

Hardening reduces these opportunities.

---

## Principle of Least Privilege

**Only grant the minimum permissions necessary.**

This applies to:
- User accounts
- File permissions
- Service capabilities
- Network access
- sudo rights

**Example:** Web server process shouldn't run as root, read home directories, or access SSH keys.

---

## Remove Unnecessary Software

### List Installed Packages

```bash
# Debian/Ubuntu
dpkg -l | less
apt list --installed

# RHEL/CentOS
rpm -qa | less
yum list installed
```

### Find Large or Unused Packages

```bash
# Debian/Ubuntu - sort by size
dpkg-query -W --showformat='${Installed-Size}\t${Package}\n' | sort -n

# Show package size in MB
dpkg-query -W --showformat='${Installed-Size;10}\t${Package}\n' | awk '{printf "%.2f MB\t%s\n", $1/1024, $2}' | sort -n
```

### Remove Unnecessary Packages

```bash
# Debian/Ubuntu
apt-get remove package-name
apt-get purge package-name        # Also removes config files
apt-get autoremove                # Remove orphaned dependencies

# RHEL/CentOS
yum remove package-name
```

### Common Packages to Consider Removing

**If not needed:**
- `telnet`, `rsh`, `rlogin` - Insecure remote access
- `ftp` - Insecure file transfer
- `xinetd` - Legacy internet super-server
- `avahi-daemon` - Service discovery (rarely needed on servers)
- `cups` - Printing (rarely needed on servers)
- X11/GUI packages on servers
- Development tools on production servers

```bash
# Example removals for server
apt-get purge telnet rsh-client ftp avahi-daemon cups
```

---

## Disable Unnecessary Services

### List Running Services

```bash
# Systemd systems
systemctl list-units --type=service --state=running

# All services (including stopped)
systemctl list-units --type=service
```

### Disable Unnecessary Services

```bash
# Disable service
systemctl disable service-name
systemctl stop service-name

# Check status
systemctl status service-name

# Prevent service from being started (mask)
systemctl mask service-name
```

### Common Services to Review

**Likely unnecessary on most servers:**
- `bluetooth.service` - Bluetooth
- `cups.service` - Printing
- `avahi-daemon.service` - Service discovery
- `ModemManager.service` - Modem management

```bash
# Example: disable Bluetooth
systemctl disable bluetooth.service
systemctl stop bluetooth.service
```

**Be careful with:**
- `sshd.service` - You probably need this
- `cron.service` - Usually needed
- `rsyslog.service` - Logging is important
- `systemd-journald.service` - Core system logging

---

## Keep Systems Updated

### Automated Updates

**Debian/Ubuntu:**
```bash
# Install unattended-upgrades
apt-get install unattended-upgrades apt-listchanges

# Configure
dpkg-reconfigure -plow unattended-upgrades

# Enable for security updates
echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades
```

**RHEL/CentOS:**
```bash
# Install yum-cron
yum install yum-cron

# Enable and start
systemctl enable yum-cron
systemctl start yum-cron

# Configure in /etc/yum/yum-cron.conf
```

### Manual Updates

```bash
# Debian/Ubuntu
apt-get update
apt-get upgrade              # Standard updates
apt-get dist-upgrade         # Also handles dependencies

# RHEL/CentOS
yum check-update
yum update

# Check for security updates only
yum updateinfo list security
yum update --security
```

### Check for Unpatched Vulnerabilities

```bash
# Debian/Ubuntu
apt list --upgradable

# Security updates only
grep security /etc/apt/sources.list
apt-cache policy

# RHEL/CentOS
yum list updates
yum updateinfo list security
```

---

## Secure Boot Process

### GRUB Password Protection

Prevent unauthorized kernel parameter changes or single-user mode access.

```bash
# Generate password hash
grub-mkpasswd-pbkdf2

# Add to /etc/grub.d/40_custom
cat << 'EOF' >> /etc/grub.d/40_custom
set superusers="grubadmin"
password_pbkdf2 grubadmin <hash_generated_above>
EOF

# Update GRUB
update-grub           # Debian/Ubuntu
grub2-mkconfig -o /boot/grub2/grub.cfg    # RHEL/CentOS
```

### Disable Single User Mode Without Password

**Debian/Ubuntu** - Edit `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
```

Add to `/etc/inittab` or systemd configuration to require password for single-user mode.

### Disable Ctrl+Alt+Delete Reboot

```bash
# Systemd
systemctl mask ctrl-alt-del.target

# Verify
systemctl status ctrl-alt-del.target
```

---

## File System Hardening

### Secure Mount Options

**Important mount options:**
- `noexec` - Prevent execution of binaries
- `nodev` - Prevent device files
- `nosuid` - Ignore setuid/setgid bits

**Edit `/etc/fstab`:**
```
/tmp                /tmp        tmpfs   defaults,noexec,nodev,nosuid 0 0
/var/tmp            /var/tmp    tmpfs   defaults,noexec,nodev,nosuid 0 0
/dev/shm            /dev/shm    tmpfs   defaults,noexec,nodev,nosuid 0 0
```

**Remount immediately:**
```bash
mount -o remount /tmp
mount -o remount /var/tmp
mount -o remount /dev/shm
```

### Set Proper Permissions

```bash
# World-writable directories should have sticky bit
chmod 1777 /tmp
chmod 1777 /var/tmp

# Sensitive directories
chmod 700 /root
chmod 600 /boot/grub/grub.cfg
chmod 644 /etc/passwd
chmod 640 /etc/shadow
chmod 640 /etc/gshadow
chmod 644 /etc/group

# Cron directories
chmod 700 /etc/cron.d
chmod 700 /etc/cron.daily
chmod 700 /etc/cron.hourly
chmod 700 /etc/cron.monthly
chmod 700 /etc/cron.weekly
```

### Find and Fix Permission Issues

```bash
# World-writable files (security risk)
find / -xdev -type f -perm -0002 -ls 2>/dev/null

# World-writable directories without sticky bit
find / -xdev -type d -perm -0002 ! -perm -1000 -ls 2>/dev/null

# Files with no owner (orphaned)
find / -xdev -nouser -ls 2>/dev/null
find / -xdev -nogroup -ls 2>/dev/null

# SUID/SGID files (audit regularly)
find / -xdev -type f \( -perm -4000 -o -perm -2000 \) -ls 2>/dev/null
```

---

## Network Hardening

### Disable IPv6 (if not used)

**Temporarily:**
```bash
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

**Permanently** - Add to `/etc/sysctl.conf`:
```
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```

Apply:
```bash
sysctl -p
```

### Disable IP Forwarding (if not router)

```bash
# Check current value
sysctl net.ipv4.ip_forward

# Disable
sysctl -w net.ipv4.ip_forward=0

# Permanent in /etc/sysctl.conf
net.ipv4.ip_forward = 0
```

### Enable SYN Cookies (DDoS protection)

```bash
# Add to /etc/sysctl.conf
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096

# Apply
sysctl -p
```

### Disable Source Routing

```bash
# Add to /etc/sysctl.conf
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
```

### Ignore ICMP Redirects

```bash
# Add to /etc/sysctl.conf
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
```

### Enable Reverse Path Filtering

```bash
# Add to /etc/sysctl.conf
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
```

### Disable ICMP Echo (optional, may break monitoring)

```bash
# Add to /etc/sysctl.conf
net.ipv4.icmp_echo_ignore_all = 1
```

**Note:** This breaks ping, which may affect monitoring.

---

## Password Policies

### Password Complexity Requirements

**Install PAM cracklib:**
```bash
# Debian/Ubuntu
apt-get install libpam-cracklib

# RHEL/CentOS
yum install libpwquality
```

**Configure** in `/etc/pam.d/common-password` (Debian) or `/etc/pam.d/system-auth` (RHEL):
```
password requisite pam_pwquality.so retry=3 minlen=12 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1
```

**Parameters:**
- `minlen=12` - Minimum 12 characters
- `difok=3` - At least 3 different from old password
- `ucredit=-1` - At least 1 uppercase
- `lcredit=-1` - At least 1 lowercase
- `dcredit=-1` - At least 1 digit
- `ocredit=-1` - At least 1 special character

### Password Aging

**Edit `/etc/login.defs`:**
```
PASS_MAX_DAYS   90      # Maximum password age
PASS_MIN_DAYS   1       # Minimum days between changes
PASS_MIN_LEN    12      # Minimum length
PASS_WARN_AGE   14      # Warning days before expiration
```

**Apply to existing user:**
```bash
chage -M 90 -m 1 -W 14 username

# View settings
chage -l username
```

### Account Lockout

**Configure** in `/etc/pam.d/common-auth` (Debian) or `/etc/pam.d/system-auth` (RHEL):
```
auth required pam_tally2.so onerr=fail audit silent deny=5 unlock_time=900
```

**Parameters:**
- `deny=5` - Lock after 5 failed attempts
- `unlock_time=900` - Unlock after 15 minutes

**View locked accounts:**
```bash
pam_tally2 --user=username

# Reset
pam_tally2 --user=username --reset
```

---

## SSH Hardening

See dedicated SSH guide for full details. Key points:

```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers alice bob
Protocol 2
```

Change default port (security through obscurity):
```
Port 2222
```

---

## Audit System Configuration

### Check for Weak Permissions

```bash
# Script to check common issues
#!/bin/bash

echo "=== World-writable files ==="
find / -xdev -type f -perm -0002 2>/dev/null | head -20

echo -e "\n=== SUID/SGID files ==="
find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null

echo -e "\n=== Orphaned files ==="
find / -xdev -nouser -o -nogroup 2>/dev/null | head -20

echo -e "\n=== Password file permissions ==="
ls -l /etc/passwd /etc/shadow /etc/group /etc/gshadow

echo -e "\n=== Users with UID 0 ==="
awk -F: '$3 == 0 {print $1}' /etc/passwd

echo -e "\n=== Users with empty passwords ==="
awk -F: '$2 == "" {print $1}' /etc/shadow

echo -e "\n=== SSH configuration ==="
grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config
```

### Check for Listening Services

```bash
# What's listening on network?
ss -tulpn
netstat -tulpn

# Filter unexpected services
ss -tulpn | grep -v -E ':(22|80|443)'
```

### Review Cron Jobs

```bash
# System cron jobs
ls -la /etc/cron.*

# User cron jobs
for user in $(cut -f1 -d: /etc/passwd); do 
    echo "=== $user ==="
    crontab -u $user -l 2>/dev/null
done
```

---

## Automated Hardening Tools

### Lynis - Security Auditing

```bash
# Install
git clone https://github.com/CISOfy/lynis
cd lynis

# Run audit
./lynis audit system

# Review report
cat /var/log/lynis.log
```

### OpenSCAP - Security Compliance

```bash
# Install
apt-get install libopenscap8 openscap-scanner

# Run scan
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_common \
  --results results.xml /usr/share/xml/scap/ssg/content/ssg-ubuntu2004-ds.xml

# Generate report
oscap xccdf generate report results.xml > report.html
```

### CIS Benchmark Scripts

Available from Center for Internet Security:
- https://www.cisecurity.org/cis-benchmarks/

Provides automated scripts to apply CIS hardening standards.

---

## Compliance and Standards

### Common Frameworks

- **CIS Benchmarks** - Industry consensus configurations
- **NIST** - National Institute of Standards and Technology
- **PCI-DSS** - Payment Card Industry Data Security Standard
- **HIPAA** - Health Insurance Portability and Accountability Act
- **GDPR** - General Data Protection Regulation

### Key Areas for Compliance

1. **Access Control**
   - User authentication
   - Authorization policies
   - Audit logging

2. **Data Protection**
   - Encryption at rest
   - Encryption in transit
   - Secure deletion

3. **Monitoring**
   - Log collection
   - Intrusion detection
   - Incident response

4. **Patch Management**
   - Regular updates
   - Vulnerability scanning
   - Change control

---

## Regular Hardening Tasks

### Daily
- Review authentication logs
- Check for failed login attempts
- Monitor critical services

### Weekly
- Review system logs
- Check for available updates
- Review user accounts and privileges

### Monthly
- Update all packages
- Review firewall rules
- Audit file permissions
- Check for orphaned files
- Review cron jobs

### Quarterly
- Full security audit (Lynis/OpenSCAP)
- Review and rotate credentials
- Update disaster recovery procedures
- Security awareness training

---

## Quick Reference

**Remove unnecessary software:**
```bash
apt-get purge telnet ftp rsh-client
apt-get autoremove
```

**Disable unnecessary services:**
```bash
systemctl disable bluetooth.service
systemctl disable cups.service
```

**Secure filesystem:**
```bash
# /etc/fstab mount options
/tmp    tmpfs   defaults,noexec,nodev,nosuid 0 0
```

**Network hardening:**
```bash
# /etc/sysctl.conf
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
```

**Find security issues:**
```bash
find / -xdev -type f -perm -0002        # World-writable
find / -xdev -type f -perm -4000        # SUID files
awk -F: '$3 == 0' /etc/passwd           # UID 0 users
```

---

## Further Reading

- CIS Benchmarks: https://www.cisecurity.org/cis-benchmarks/
- NSA Security Configuration Guides
- NIST Cybersecurity Framework
- `man pam` - Pluggable Authentication Modules
- `man sysctl` - Configure kernel parameters at runtime
