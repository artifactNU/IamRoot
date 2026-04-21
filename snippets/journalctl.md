## journalctl Quick Reference for Sysadmins

Useful `journalctl` one-liners for log inspection, login auditing, and troubleshooting on systemd-based systems.

---

### Login & Authentication

```bash
# Show all login/logout events (SSH, sudo, PAM, etc.)
journalctl _SYSTEMD_UNIT=systemd-logind.service

# Show SSH login attempts (success and failure)
journalctl _SYSTEMD_UNIT=sshd.service -n 100

# Failed login attempts only
journalctl _SYSTEMD_UNIT=sshd.service | grep "Failed password"

# Successful SSH logins
journalctl _SYSTEMD_UNIT=sshd.service | grep "Accepted"

# All authentication events (sudo, su, PAM)
journalctl SYSLOG_FACILITY=10

# sudo usage
journalctl _COMM=sudo

# User session opens/closes
journalctl _SYSTEMD_UNIT=systemd-logind.service | grep -E "New session|Removed session"
```

---

### Time-Based Filtering

```bash
# Logs since a specific date/time
journalctl --since "2026-04-20 08:00:00"
journalctl --since "2026-04-20 08:00:00" --until "2026-04-20 18:00:00"

# Logs from the last hour
journalctl --since "1 hour ago"

# Logs from today
journalctl --since today

# Logs from previous boot
journalctl -b -1

# List all available boots
journalctl --list-boots
```

---

### Service & Unit Logs

```bash
# Follow logs for a specific service in real time
journalctl -u nginx.service -f

# Show only errors and above for a service
journalctl -u sshd.service -p err

# Show logs from the current boot for a service
journalctl -u postgresql.service -b

# Logs for multiple units at once
journalctl -u nginx.service -u php-fpm.service
```

---

### Priority / Severity Filtering

```bash
# Only errors (err=3), critical (crit=2), alerts (alert=1), emergencies (emerg=0)
journalctl -p err

# Errors and above, system-wide, current boot
journalctl -p err -b

# Show priority levels:
# 0=emerg 1=alert 2=crit 3=err 4=warning 5=notice 6=info 7=debug
journalctl -p warning --since today
```

---

### Output & Format

```bash
# Show last N lines (like tail)
journalctl -n 50

# Follow live output (like tail -f)
journalctl -f

# Output in JSON (one entry per line, useful for parsing)
journalctl -o json-pretty -n 5

# Show full message without truncation
journalctl --no-pager -n 20

# Kernel messages only (equivalent to dmesg)
journalctl -k
journalctl -k --since "1 hour ago"
```

---

### Disk Usage & Maintenance

```bash
# Check journal disk usage
journalctl --disk-usage

# Vacuum logs older than 30 days
sudo journalctl --vacuum-time=30d

# Vacuum logs to keep under 500MB
sudo journalctl --vacuum-size=500M

# Rotate journal files immediately
sudo journalctl --rotate
```

---

### Practical One-Liners

```bash
# Who logged in today?
journalctl _SYSTEMD_UNIT=sshd.service --since today | grep "Accepted"

# Any brute-force attempts in the last hour?
journalctl _SYSTEMD_UNIT=sshd.service --since "1 hour ago" | grep "Failed password" | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn

# Did any service crash since last reboot?
journalctl -b -p err | grep -i "failed\|crash\|core dump"

# What started/stopped recently?
journalctl -b | grep -E "Started|Stopped|Failed" | tail -30

# Check for OOM kills
journalctl -k | grep -i "oom\|killed process"
```
