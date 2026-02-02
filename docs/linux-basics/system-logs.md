# System Logs

Where to look when things go wrong.

---

## Why This Matters

Logs are your primary diagnostic tool.

When something fails:
- Service won't start
- Application crashes
- Login issues
- Security incident

**Check the logs first.**

---

## Where Logs Live

### Traditional Logging: `/var/log/`

Most logs are in `/var/log/`. This is the first place to look.

```bash
/var/log/
├── syslog              # General system messages (Debian/Ubuntu)
├── messages            # General system messages (RHEL/CentOS)
├── auth.log            # Authentication and authorization (Debian/Ubuntu)
├── secure              # Authentication and authorization (RHEL/CentOS)
├── kern.log            # Kernel messages
├── dmesg               # Kernel ring buffer (boot messages)
├── boot.log            # Boot process
├── cron.log            # Cron job execution
├── mail.log            # Mail server logs
├── apache2/            # Apache web server
│   ├── access.log
│   └── error.log
├── nginx/              # Nginx web server
│   ├── access.log
│   └── error.log
└── mysql/              # MySQL database
    └── error.log
```

### Systemd Journal: `journalctl`

On systemd systems, many logs go to the journal instead of files.

```bash
journalctl                     # All logs
journalctl -u nginx            # Logs for nginx service
journalctl -f                  # Follow (like tail -f)
journalctl -b                  # Current boot only
journalctl --since "1 hour ago"
journalctl --since "2025-01-01" --until "2025-01-02"
```

**Journal vs traditional logs:**
- Journal is binary, requires `journalctl` to read
- Traditional logs are text files
- Many systems have both
- Journal can forward to syslog

---

## Essential Log Files

### System Messages
**Debian/Ubuntu:** `/var/log/syslog`  
**RHEL/CentOS:** `/var/log/messages`

General system activity:
- Service starts/stops
- Kernel messages
- Hardware events
- System daemons

**When to check:**
- General troubleshooting
- Service issues
- Hardware problems

```bash
tail -f /var/log/syslog
grep -i error /var/log/syslog
```

### Authentication Logs
**Debian/Ubuntu:** `/var/log/auth.log`  
**RHEL/CentOS:** `/var/log/secure`

Records:
- SSH logins (successful and failed)
- sudo usage
- User authentication
- PAM events

**When to check:**
- Login problems
- Security audits
- Tracking sudo usage
- Failed login attempts

```bash
# Failed SSH attempts
grep "Failed password" /var/log/auth.log

# Successful SSH logins
grep "Accepted password" /var/log/auth.log

# sudo usage
grep sudo /var/log/auth.log

# User added to group
grep usermod /var/log/auth.log
```

### Kernel Messages
**File:** `/var/log/kern.log` (may not exist on all systems)  
**Command:** `dmesg`

Records:
- Hardware detection
- Driver loading
- Kernel errors
- Hardware failures

**When to check:**
- Boot problems
- Hardware issues
- Driver problems
- Disk errors

```bash
dmesg | less
dmesg -T                       # Human-readable timestamps
dmesg | grep -i error
dmesg | grep -i fail
journalctl -k                  # Kernel messages via journal
```

### Boot Logs
**File:** `/var/log/boot.log`  
**Command:** `journalctl -b`

Records:
- Service startup during boot
- Boot failures
- Systemd target status

**When to check:**
- System won't boot properly
- Services fail to start at boot
- Boot performance issues

```bash
journalctl -b                  # Current boot
journalctl -b -1               # Previous boot
journalctl --list-boots        # Available boot logs
```

---

## Application Logs

### Web Servers

**Apache:**
```bash
/var/log/apache2/access.log    # HTTP requests
/var/log/apache2/error.log     # Errors and warnings
```

**Nginx:**
```bash
/var/log/nginx/access.log      # HTTP requests
/var/log/nginx/error.log       # Errors and warnings
```

**Common patterns:**
```bash
# 404 errors
grep " 404 " /var/log/nginx/access.log

# 500 errors (server errors)
grep " 5[0-9][0-9] " /var/log/nginx/access.log

# Requests from specific IP
grep "192.168.1.100" /var/log/nginx/access.log

# Top requested URLs
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -n | tail
```

### Databases

**MySQL/MariaDB:**
```bash
/var/log/mysql/error.log       # Database errors
```

**PostgreSQL:**
```bash
/var/log/postgresql/postgresql-*-main.log
```

### Mail

**Postfix/Sendmail:**
```bash
/var/log/mail.log              # All mail activity
/var/log/mail.err              # Mail errors
```

---

## Viewing and Searching Logs

### Basic Viewing
```bash
# View entire log
cat /var/log/syslog

# View with paging
less /var/log/syslog

# Last 20 lines
tail -20 /var/log/syslog

# Follow in real-time
tail -f /var/log/syslog

# Follow multiple logs
tail -f /var/log/syslog /var/log/auth.log
```

### Searching Logs
```bash
# Basic search
grep "error" /var/log/syslog

# Case-insensitive
grep -i "error" /var/log/syslog

# With context (5 lines before/after)
grep -C 5 "error" /var/log/syslog

# Multiple patterns
grep -E "error|warning|fail" /var/log/syslog

# Invert match (exclude)
grep -v "CRON" /var/log/syslog

# Count occurrences
grep -c "error" /var/log/syslog

# Show filename with matches
grep -H "error" /var/log/*.log
```

### Time-Based Filtering
```bash
# Today's entries
grep "$(date +%b\ %d)" /var/log/syslog

# Specific date
grep "Jan 15" /var/log/syslog

# Between times (if timestamps present)
awk '/09:00/,/10:00/' /var/log/syslog

# Last hour with journalctl
journalctl --since "1 hour ago"
```

### Advanced Searching
```bash
# Find IP addresses
grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' /var/log/auth.log

# Failed SSH attempts with IPs
grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -n

# Extract specific field (e.g., 5th column)
awk '{print $5}' /var/log/syslog

# Complex pattern matching
awk '/pattern/ {print $0}' /var/log/syslog
```

---

## Journalctl Deep Dive

### Basic Usage
```bash
journalctl                     # All logs (paged)
journalctl -n 50               # Last 50 entries
journalctl -f                  # Follow (tail -f equivalent)
journalctl -r                  # Reverse order (newest first)
```

### Filtering by Service
```bash
journalctl -u nginx            # Nginx service
journalctl -u ssh.service      # SSH service
journalctl -u systemd-logind   # Login service
```

### Filtering by Time
```bash
journalctl --since "2025-01-15 10:00:00"
journalctl --since "1 hour ago"
journalctl --since "today"
journalctl --since "yesterday"
journalctl --until "2025-01-15 12:00:00"
journalctl --since "10:00" --until "11:00"
```

### Filtering by Boot
```bash
journalctl -b                  # Current boot
journalctl -b -1               # Previous boot
journalctl -b -2               # Two boots ago
journalctl --list-boots        # List all boots
```

### Filtering by Priority
```bash
journalctl -p err              # Errors only
journalctl -p warning          # Warnings and above
journalctl -p crit             # Critical and above
```

Priorities: `emerg`, `alert`, `crit`, `err`, `warning`, `notice`, `info`, `debug`

### Filtering by Executable
```bash
journalctl /usr/bin/nginx
journalctl /usr/sbin/sshd
```

### Filtering by PID
```bash
journalctl _PID=1234
```

### Output Formats
```bash
journalctl -o short            # Default
journalctl -o verbose          # All fields
journalctl -o json             # JSON format
journalctl -o json-pretty      # Pretty JSON
journalctl -o cat              # Just messages, no metadata
```

### Disk Usage
```bash
journalctl --disk-usage        # Journal size
journalctl --vacuum-size=1G    # Trim to 1GB
journalctl --vacuum-time=30d   # Keep 30 days
```

---

## Log Rotation

Logs grow over time. Log rotation prevents disk space issues.

### Logrotate Configuration
**Main config:** `/etc/logrotate.conf`  
**Service configs:** `/etc/logrotate.d/`

Example: `/etc/logrotate.d/nginx`
```
/var/log/nginx/*.log {
    daily                    # Rotate daily
    missingok               # Don't error if log is missing
    rotate 14               # Keep 14 old logs
    compress                # Compress old logs
    delaycompress           # Don't compress most recent
    notifempty              # Don't rotate if empty
    create 0640 www-data adm  # New file permissions/owner
    sharedscripts           # Run scripts once for all logs
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

### Manual Rotation
```bash
# Test configuration
logrotate -d /etc/logrotate.conf

# Force rotation
logrotate -f /etc/logrotate.conf
```

### Journal Retention
Configure in `/etc/systemd/journald.conf`:
```
[Journal]
SystemMaxUse=500M       # Max disk space
SystemKeepFree=1G       # Always keep this free
MaxRetentionSec=30d     # Max age
```

Apply changes:
```bash
systemctl restart systemd-journald
```

---

## Common Log Analysis Tasks

### Finding Errors
```bash
# All errors in syslog
grep -i error /var/log/syslog

# Errors from specific service
journalctl -u nginx -p err

# Kernel errors
dmesg | grep -i error

# Errors in last hour
journalctl --since "1 hour ago" -p err
```

### Failed Login Attempts
```bash
# Failed SSH
grep "Failed password" /var/log/auth.log

# Count by IP
grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -n

# Using journalctl
journalctl -u ssh --since today | grep -i failed
```

### Service Crashes
```bash
# Service failures
journalctl -u nginx | grep -i fail

# Segfaults
grep -i segfault /var/log/syslog
dmesg | grep -i segfault

# Core dumps
coredumpctl list
coredumpctl info <PID>
```

### Disk Issues
```bash
# I/O errors
dmesg | grep -i "i/o error"

# Filesystem errors
dmesg | grep -i "ext4\|xfs\|btrfs"

# SMART errors
grep -i smart /var/log/syslog
```

### Network Issues
```bash
# Network interface changes
journalctl | grep -i "link up\|link down"

# DHCP issues
grep -i dhcp /var/log/syslog

# DNS issues
journalctl -u systemd-resolved
```

---

## Remote Logging

### Sending Logs to Remote Server

**Using rsyslog** (in `/etc/rsyslog.conf`):
```
*.* @remote-server:514          # UDP
*.* @@remote-server:514         # TCP
```

**Using journald** (in `/etc/systemd/journald.conf`):
```
[Journal]
ForwardToSyslog=yes
```

Then configure rsyslog to forward.

### Receiving Logs

**In rsyslog** (`/etc/rsyslog.conf`):
```
# Provide UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# Provide TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")
```

---

## Troubleshooting Log Issues

### Logs Not Updating
```bash
# Check if service is running
systemctl status rsyslog
systemctl status systemd-journald

# Check disk space
df -h /var/log

# Check permissions
ls -ld /var/log
ls -l /var/log/*.log
```

### Logs Too Large
```bash
# Find largest logs
du -sh /var/log/* | sort -h

# Immediate cleanup
> /var/log/large-file.log      # Truncate
rm /var/log/old-file.log       # Delete

# Force rotation
logrotate -f /etc/logrotate.conf
```

### Missing Logs
```bash
# Check if logging is configured
grep "^[^#]" /etc/rsyslog.conf

# Check if journal is working
journalctl -xe

# Check if service logs to file or journal
systemctl status <service>
```

---

## Quick Reference

**Essential commands:**
```bash
# Real-time system log
tail -f /var/log/syslog

# Real-time journal
journalctl -f

# Failed logins
grep "Failed" /var/log/auth.log

# Service logs
journalctl -u <service> -f

# Errors in last hour
journalctl --since "1 hour ago" -p err

# Kernel messages
dmesg -T

# Disk space usage by logs
du -sh /var/log/*
```

**Quick diagnostics:**
```bash
# What went wrong recently?
journalctl -p err --since "1 hour ago"

# Why won't service start?
journalctl -u <service> -n 50

# Boot problems?
journalctl -b -p err

# Disk errors?
dmesg | grep -i "error\|fail"
```

---

## Further Reading

- `man syslog` - System logging facility
- `man journalctl` - Query systemd journal
- `man logrotate` - Rotate log files
- `man rsyslog` - Reliable and extended syslog
