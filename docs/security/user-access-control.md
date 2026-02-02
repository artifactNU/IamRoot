# User and Access Control

Managing users, groups, and access privileges securely.

---

## Why This Matters

Access control determines:
- Who can log in
- What they can access
- What actions they can perform
- How their activities are audited

Poor access control is a common attack vector and compliance issue.

---

## User Account Management

### Create Users Securely

```bash
# Create user with home directory
useradd -m -s /bin/bash username

# Set password
passwd username

# Or create with specific UID/GID
useradd -m -u 1500 -g users -s /bin/bash username
```

### User Account Best Practices

**Naming conventions:**
- Use consistent format (first.last or flast)
- Avoid generic names (admin, user1)
- Document service accounts

**Account attributes:**
```bash
# Set account expiration
usermod -e 2026-12-31 username

# Lock account (disable login)
usermod -L username
passwd -l username

# Unlock account
usermod -U username
passwd -u username

# Delete user
userdel username           # Keep home directory
userdel -r username        # Remove home directory
```

### Service Accounts

**Create non-interactive accounts:**
```bash
# No login shell, no home directory
useradd -r -s /usr/sbin/nologin servicename

# With home but no login
useradd -r -m -s /usr/sbin/nologin servicename
```

**Why `/usr/sbin/nologin`?**
- Prevents direct login
- Allows service to run as user
- Provides meaningful message if login attempted

**Service account checklist:**
- No password set
- Shell set to `/usr/sbin/nologin` or `/bin/false`
- Minimal group membership
- Home directory if needed, otherwise none

---

## Group Management

### Create and Manage Groups

```bash
# Create group
groupadd developers

# Create with specific GID
groupadd -g 2000 developers

# Add user to group
usermod -aG developers alice

# Remove user from group
gpasswd -d alice developers

# View user's groups
groups alice
id alice

# View group members
getent group developers
```

### Group Strategy

**Functional groups:**
```bash
groupadd webadmins
groupadd dbadmins
groupadd developers
```

**Project groups:**
```bash
groupadd project-alpha
groupadd project-beta
```

**Permission groups:**
Grant access via group membership rather than world permissions.

**Example:**
```bash
# Create group for log access
groupadd logviewers

# Add users
usermod -aG logviewers alice
usermod -aG logviewers bob

# Change log directory group
chgrp -R logviewers /var/log/application
chmod -R g+r /var/log/application
```

---

## sudo Configuration

### sudoers File

**Edit safely:**
```bash
# ALWAYS use visudo (validates syntax)
visudo

# Edit specific file in sudoers.d
visudo -f /etc/sudoers.d/custom
```

**Never edit `/etc/sudoers` directly with regular editors.**

### Basic sudo Rules

```bash
# Allow user full sudo access
alice ALL=(ALL:ALL) ALL

# Allow user to run specific command
bob ALL=(ALL) /usr/bin/systemctl restart nginx

# Allow group sudo access
%wheel ALL=(ALL:ALL) ALL
%sudo ALL=(ALL:ALL) ALL

# No password for specific command
alice ALL=(ALL) NOPASSWD: /usr/bin/apt-get update

# Run as specific user
alice ALL=(www-data) /usr/bin/php
```

**Syntax:**
```
user  hosts=(run_as_user:run_as_group) commands
```

### Example sudo Configurations

**Web administrators:**
```bash
# /etc/sudoers.d/webadmins
%webadmins ALL=(ALL) /usr/bin/systemctl restart nginx, \
                     /usr/bin/systemctl reload nginx, \
                     /usr/bin/systemctl status nginx, \
                     /usr/bin/nginx -t
```

**Database administrators:**
```bash
# /etc/sudoers.d/dbadmins
%dbadmins ALL=(postgres) /usr/bin/psql, \
                         /usr/bin/pg_dump
```

**Backup operators:**
```bash
# /etc/sudoers.d/backup
%backup ALL=(ALL) NOPASSWD: /usr/bin/rsync, \
                            /bin/tar
```

### sudo Security

**Dangerous configurations to avoid:**

```bash
# NEVER - allows anything
alice ALL=(ALL) ALL

# DANGEROUS - shell access
bob ALL=(ALL) /bin/bash

# DANGEROUS - can edit sudoers
carol ALL=(ALL) /usr/bin/visudo

# DANGEROUS - text editors can escape to shell
dave ALL=(ALL) /usr/bin/vim, /usr/bin/nano
```

**Safer alternatives:**

```bash
# Specific commands only
alice ALL=(ALL) /usr/bin/systemctl restart nginx

# With command-line restrictions
bob ALL=(ALL) /usr/bin/systemctl restart nginx, \
              !/usr/bin/systemctl * sudo*

# Read-only commands
carol ALL=(ALL) NOPASSWD: /usr/bin/systemctl status *
```

### sudo Logging

**View sudo usage:**
```bash
# Auth log
grep sudo /var/log/auth.log

# Journal
journalctl SYSLOG_IDENTIFIER=sudo

# Last week
journalctl SYSLOG_IDENTIFIER=sudo --since "1 week ago"
```

**Enable detailed logging:**
```bash
# /etc/sudoers
Defaults logfile="/var/log/sudo.log"
Defaults log_input, log_output
Defaults iolog_dir=/var/log/sudo-io/%{user}
```

---

## SSH Key Management

### Centralized Key Management

**Problem:** Users have keys scattered across many servers.

**Solutions:**

1. **LDAP/Active Directory Integration**
2. **Ansible/Configuration Management**
3. **Centralized authorized_keys**

### authorized_keys Best Practices

**Restrict key usage:**
```bash
# ~/.ssh/authorized_keys

# Restrict to specific source IP
from="192.168.1.100" ssh-ed25519 AAAAC3... user@host

# Force specific command
command="/usr/local/bin/backup.sh" ssh-ed25519 AAAAC3... backup@host

# Disable port forwarding
no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAAC3...

# Combined restrictions
from="192.168.1.100",no-port-forwarding,no-agent-forwarding,command="/usr/local/bin/backup.sh" ssh-ed25519 AAAAC3...
```

### Key Rotation

**Regular key rotation schedule:**

1. Generate new keys
2. Deploy new public keys
3. Test access with new keys
4. Remove old keys
5. Document in change log

```bash
# Find old keys (by modification date)
find ~/.ssh/ -name "id_*" -mtime +365 -ls

# Audit authorized_keys
for user in $(cut -d: -f1 /etc/passwd); do
    authkeys="/home/$user/.ssh/authorized_keys"
    if [ -f "$authkeys" ]; then
        echo "=== $user ==="
        cat "$authkeys"
    fi
done
```

---

## Password Management

### Password Quality

**Check password strength:**
```bash
# Use cracklib
echo "password123" | cracklib-check

# Test against dictionary
john --test
```

### Force Password Changes

```bash
# Force change at next login
passwd -e username
chage -d 0 username

# Set expiration date
chage -E 2026-12-31 username

# View password status
passwd -S username
chage -l username
```

### Disable Password Login (SSH keys only)

```bash
# For specific user
passwd -l username

# In /etc/ssh/sshd_config
PasswordAuthentication no
```

### Password Storage

**Never store passwords in:**
- Plain text files
- Shell scripts
- Configuration files
- Version control

**Use instead:**
- Password managers (KeePass, Bitwarden, 1Password)
- Secrets management (HashiCorp Vault, AWS Secrets Manager)
- Environment variables (for automation)
- Encrypted ansible-vault files

---

## Privileged Account Security

### Root Account

**Best practices:**

1. **Never login as root directly**
   ```bash
   # /etc/ssh/sshd_config
   PermitRootLogin no
   ```

2. **Use sudo instead**
   ```bash
   sudo command
   sudo -i                    # Interactive root shell
   ```

3. **Require password for sudo**
   Avoid `NOPASSWD` except for specific automated tasks

4. **Audit root access**
   ```bash
   # Who switched to root
   grep su /var/log/auth.log
   
   # All sudo usage
   grep sudo /var/log/auth.log
   ```

### Shared Accounts (Avoid)

**Problem:** Shared accounts like `admin` or `devops` user:
- No accountability
- Can't revoke individual access
- Password sharing issues

**Solution:**
- Individual user accounts
- Group-based permissions
- sudo for elevation
- Audit logs show who did what

**If shared accounts are unavoidable:**
- Use SSH keys (one per person)
- Add identifiers to key comments
- Log all activity
- Rotate keys when people leave

---

## Account Auditing

### Find Suspicious Accounts

```bash
# Users with UID 0 (root privileges)
awk -F: '$3 == 0 {print $1}' /etc/passwd

# Users with empty passwords
awk -F: '$2 == "" {print $1}' /etc/shadow

# Users with no password set
awk -F: '$2 == "!" || $2 == "*" {print $1}' /etc/shadow

# Users who can login (have real shell)
grep -v -E '/nologin|/false' /etc/passwd

# Accounts created in last 30 days
find /home -maxdepth 1 -type d -mtime -30

# Recently modified passwords
awk -F: '{if($3 != "!!" && $3 != "*") print $1}' /etc/shadow | \
  xargs -I {} chage -l {} | grep "Last password change"
```

### Review User Activity

```bash
# Last login times
lastlog

# Current users
who
w

# Login history
last
last -f /var/log/wtmp

# Failed login attempts
lastb
last -f /var/log/btmp

# User command history
cat /home/username/.bash_history
```

### Orphaned Files

```bash
# Files owned by deleted users
find / -nouser -ls 2>/dev/null

# Files owned by deleted groups
find / -nogroup -ls 2>/dev/null

# Assign to appropriate user/group or delete
chown root:root /path/to/orphaned/file
```

---

## PAM (Pluggable Authentication Modules)

### What is PAM?

PAM provides flexible authentication framework:
- Password policies
- Account restrictions
- Session management
- Authentication methods

### PAM Configuration Files

Location: `/etc/pam.d/`

Common files:
- `common-auth` - Authentication
- `common-account` - Account validation
- `common-password` - Password management
- `common-session` - Session setup
- `sshd` - SSH-specific rules

### PAM Module Examples

**Password history (prevent reuse):**
```bash
# /etc/pam.d/common-password
password required pam_pwhistory.so remember=5
```

**Time-based access:**
```bash
# /etc/security/time.conf
login ; * ; !root ; Al0800-1800

# /etc/pam.d/login
account required pam_time.so
```

**Limit resources per user:**
```bash
# /etc/security/limits.conf
alice hard nproc 100
alice hard nofile 1024
@developers hard nproc 200
```

**Google Authenticator (2FA):**
```bash
# Install
apt-get install libpam-google-authenticator

# /etc/pam.d/sshd
auth required pam_google_authenticator.so
```

---

## LDAP/Active Directory Integration

### Benefits

- Centralized user management
- Single sign-on (SSO)
- Consistent policies across systems
- Easier onboarding/offboarding

### Integration Tools

**SSSD (System Security Services Daemon):**
```bash
# Install
apt-get install sssd sssd-tools

# Configure /etc/sssd/sssd.conf
[sssd]
domains = example.com
services = nss, pam

[domain/example.com]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldap://ldap.example.com
ldap_search_base = dc=example,dc=com
```

**Alternatively - Centrify, Quest, Samba:**
Commercial and open-source AD integration tools.

---

## Security Best Practices

### 1. Principle of Least Privilege

Grant minimum access required:
```bash
# Instead of: usermod -aG sudo alice
# Grant specific sudo access:
echo "alice ALL=(ALL) /usr/bin/systemctl restart nginx" > /etc/sudoers.d/alice
```

### 2. Regular Access Reviews

Monthly review:
- Active accounts
- sudo permissions
- Group memberships
- SSH keys

### 3. Disable Inactive Accounts

```bash
# Find users who haven't logged in
lastlog | awk '$2 == "Never" {print $1}'

# Lock inactive accounts
usermod -L username
```

### 4. Audit Trail

Ensure logging for:
- Login attempts (successful and failed)
- sudo usage
- Account changes (user add/delete/modify)
- Group changes

```bash
# Enable audit for user commands
apt-get install auditd
auditctl -a always,exit -F arch=b64 -S execve
```

### 5. Separate Privileges

Don't mix:
- Development and production access
- Admin and standard user roles
- Service accounts and human accounts

---

## Compliance Requirements

### Common Requirements

**PCI-DSS:**
- Unique ID for each user
- Multi-factor authentication
- Password complexity
- Account lockout
- Regular access reviews

**SOC 2:**
- Access control policies
- User provisioning/deprovisioning
- Privilege separation
- Audit logging

**HIPAA:**
- Unique user identification
- Emergency access procedures
- Automatic logoff
- Encryption

---

## Quick Reference

**User management:**
```bash
useradd -m -s /bin/bash username      # Create user
passwd username                       # Set password
usermod -L username                   # Lock account
userdel -r username                   # Delete user

groupadd groupname                    # Create group
usermod -aG groupname username        # Add to group
```

**sudo:**
```bash
visudo                                # Edit sudoers safely
visudo -c                             # Check syntax
grep sudo /var/log/auth.log           # View sudo usage
```

**Auditing:**
```bash
awk -F: '$3 == 0' /etc/passwd         # UID 0 users
lastlog                               # Last login times
last                                  # Login history
lastb                                 # Failed logins
```

**SSH keys:**
```bash
ssh-keygen -t ed25519                 # Generate key
ssh-copy-id user@host                 # Deploy key
ssh-add -l                            # List loaded keys
```

---

## Further Reading

- `man sudoers` - Sudo configuration
- `man pam` - Pluggable Authentication Modules
- `man sssd` - System Security Services Daemon
- NIST SP 800-53 - Security Controls
- CIS Controls - Critical Security Controls
