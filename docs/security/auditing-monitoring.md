# Security Auditing and Monitoring

Detecting and responding to suspicious activity.

---

## Why This Matters

**You can't protect what you can't see.**

Monitoring and auditing help you:
- Detect intrusions early
- Investigate security incidents
- Meet compliance requirements
- Identify policy violations
- Understand normal vs abnormal behavior

Most breaches are discovered months after they occur. Good monitoring reduces this time.

---

## What to Monitor

### Critical Security Events

1. **Authentication**
   - Failed login attempts
   - Successful logins (especially root)
   - SSH key usage
   - sudo execution

2. **File Access**
   - Sensitive file modifications
   - Permission changes
   - Ownership changes
   - SUID/SGID changes

3. **System Changes**
   - User/group creation
   - Package installation
   - Service configuration
   - Firewall rule changes

4. **Network Activity**
   - Unexpected listening ports
   - Unusual outbound connections
   - Port scans
   - Large data transfers

5. **Process Activity**
   - New privileged processes
   - Unusual process execution
   - Cron job execution
   - Scheduled task changes

---

## Log Analysis

### Essential Log Files

```bash
/var/log/auth.log          # Authentication (Debian/Ubuntu)
/var/log/secure            # Authentication (RHEL/CentOS)
/var/log/syslog            # General system messages
/var/log/kern.log          # Kernel messages
/var/log/audit/audit.log   # Audit daemon (if installed)
```

### Failed Login Attempts

```bash
# Failed SSH attempts
grep "Failed password" /var/log/auth.log

# With IP addresses
grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -n

# Recent failed attempts (last hour)
grep "Failed password" /var/log/auth.log | grep "$(date '+%b %e %H')"

# Failed sudo attempts
grep "sudo.*FAILED" /var/log/auth.log

# Using journalctl
journalctl _SYSTEMD_UNIT=sshd.service | grep "Failed password"
```

### Successful Logins

```bash
# All successful SSH logins
grep "Accepted password\|Accepted publickey" /var/log/auth.log

# Root logins (should be none if PermitRootLogin no)
grep "session opened for user root" /var/log/auth.log

# Recent logins
last
lastlog

# Currently logged in
who
w
```

### sudo Usage

```bash
# All sudo commands
grep sudo /var/log/auth.log | grep COMMAND

# Specific user
grep "sudo.*alice.*COMMAND" /var/log/auth.log

# Failed sudo attempts
grep "sudo.*FAILED" /var/log/auth.log

# Root shells opened
grep "sudo.*root.*COMMAND=/bin/bash" /var/log/auth.log
```

### File Modifications

```bash
# Recently modified system files
find /etc -type f -mtime -1 -ls

# Recently modified binaries
find /usr/bin /usr/sbin -type f -mtime -7 -ls

# SUID/SGID changes
find / -type f \( -perm -4000 -o -perm -2000 \) -mtime -7 -ls 2>/dev/null
```

---

## Auditd (Linux Audit Framework)

### Install and Enable

```bash
# Debian/Ubuntu
apt-get install auditd audispd-plugins

# RHEL/CentOS
yum install audit audit-libs

# Enable and start
systemctl enable auditd
systemctl start auditd
```

### Audit Rules

**View current rules:**
```bash
auditctl -l
```

**Add rules temporarily:**
```bash
# Watch file for changes
auditctl -w /etc/passwd -p wa -k passwd_changes

# Watch directory recursively
auditctl -w /etc/ssh/ -p wa -k ssh_config

# Monitor user/group changes
auditctl -w /usr/sbin/useradd -p x -k user_creation
auditctl -w /usr/sbin/userdel -p x -k user_deletion
auditctl -w /usr/sbin/usermod -p x -k user_modification

# Monitor network changes
auditctl -a always,exit -F arch=b64 -S socket -S connect -k network_connections
```

**Permanent rules:** `/etc/audit/rules.d/audit.rules`
```bash
# /etc/audit/rules.d/audit.rules

## Watch authentication files
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes

## Watch SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config

## Monitor user/group tools
-w /usr/sbin/useradd -p x -k user_modification
-w /usr/sbin/userdel -p x -k user_modification
-w /usr/sbin/usermod -p x -k user_modification
-w /usr/sbin/groupadd -p x -k group_modification
-w /usr/sbin/groupdel -p x -k group_modification

## Monitor sudo
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

## Monitor login/logout
-w /var/log/lastlog -p wa -k login_logout
-w /var/run/faillock/ -p wa -k login_logout

## Monitor system calls
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system_locale

## Monitor file deletion
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete

## Capture all commands run by root
-a exit,always -F arch=b64 -F euid=0 -S execve -k root_commands
```

**Apply rules:**
```bash
augenrules --load
service auditd restart
```

### Search Audit Logs

```bash
# Search all audit logs
ausearch -k passwd_changes

# By time range
ausearch -k passwd_changes --start today
ausearch -k passwd_changes --start 08:00 --end 17:00

# By user
ausearch -ua alice

# By process
ausearch -p 1234

# Failed events
ausearch -m USER_LOGIN --success no

# Generate report
aureport
aureport --summary
aureport --auth
aureport --failed
```

---

## File Integrity Monitoring

### AIDE (Advanced Intrusion Detection Environment)

**Install:**
```bash
apt-get install aide
```

**Initialize database:**
```bash
# Create initial database
aideinit

# Or manually
aide --init
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

**Configure** `/etc/aide/aide.conf`:
```bash
# Directories to monitor
/etc p+i+n+u+g+s+m+c+sha256
/usr/bin p+i+n+u+g+s+m+c+sha256
/usr/sbin p+i+n+u+g+s+m+c+sha256

# Exclude
!/var/log
!/tmp
```

**Run checks:**
```bash
# Check for changes
aide --check

# Update database after legitimate changes
aide --update
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

**Automate with cron:**
```bash
# /etc/cron.daily/aide
#!/bin/bash
/usr/bin/aide --check | mail -s "AIDE Report $(hostname)" admin@example.com
```

### Tripwire (Alternative)

Commercial and open-source FIM tool with similar functionality.

---

## Network Monitoring

### Active Connections

```bash
# Current connections
ss -tunap
netstat -tunap

# Listening ports
ss -tlnp
lsof -i -P

# Established connections only
ss -tan state established

# Connections by specific process
ss -tp | grep nginx

# Unusual ports (not 22, 80, 443)
ss -tlnp | grep -v -E ':(22|80|443) '
```

### Monitor Network Traffic

```bash
# Real-time bandwidth by process
nethogs

# Real-time bandwidth by connection
iftop

# Interface statistics
iftop -i eth0

# Track specific port
tcpdump -i eth0 port 22

# Capture suspicious traffic
tcpdump -i eth0 -w capture.pcap 'not port 22 and not port 443'
```

### Detect Port Scans

Port scans show many connection attempts:

```bash
# Watch for SYN packets without established connections
tcpdump -i eth0 'tcp[tcpflags] & (tcp-syn) != 0 and tcp[tcpflags] & (tcp-ack) == 0'

# Count connections per IP
netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n

# See what IPs are connecting
ss -tan | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n
```

---

## Process Monitoring

### Unusual Processes

```bash
# Processes by CPU usage
ps aux --sort=-%cpu | head -20

# Processes by memory
ps aux --sort=-%mem | head -20

# Processes running as root
ps aux | awk '$1 == "root"'

# Processes listening on network
lsof -i -n -P

# Recently started processes
ps -eo pid,etime,comm --sort=etime | head -20

# Hidden processes (discrepancy between /proc and ps)
ls /proc | grep '^[0-9]' | while read pid; do
    ps -p $pid > /dev/null || echo "Hidden: $pid"
done
```

### Process Execution Monitoring

```bash
# Monitor process execution (requires auditd)
auditctl -a always,exit -F arch=b64 -S execve -k process_execution

# Search executed commands
ausearch -k process_execution

# Using systemtap (advanced)
stap -e 'probe kprocess.exec { printf("%s -> %s\n", execname(), cmdline_str()) }'
```

---

## Intrusion Detection

### fail2ban

**Install:**
```bash
apt-get install fail2ban
```

**Configure** `/etc/fail2ban/jail.local`:
```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = admin@example.com
sendername = Fail2Ban

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6
```

**Manage bans:**
```bash
# View banned IPs
fail2ban-client status sshd

# Unban IP
fail2ban-client set sshd unbanip 192.168.1.100

# Ban IP manually
fail2ban-client set sshd banip 192.168.1.100
```

### OSSEC (Host-based IDS)

Open-source HIDS with:
- Log analysis
- File integrity monitoring
- Rootkit detection
- Active response

```bash
# Install
wget https://github.com/ossec/ossec-hids/archive/3.7.0.tar.gz
tar -xzf 3.7.0.tar.gz
cd ossec-hids-3.7.0
./install.sh

# Start
/var/ossec/bin/ossec-control start
```

---

## Automated Monitoring Scripts

### Daily Security Check Script

```bash
#!/bin/bash
# /usr/local/bin/daily-security-check.sh

LOGFILE="/var/log/security-check.log"
EMAIL="admin@example.com"

echo "=== Security Check - $(date) ===" > $LOGFILE

# Failed login attempts
echo -e "\n=== Failed Login Attempts (last 24h) ===" >> $LOGFILE
grep "Failed password" /var/log/auth.log | grep "$(date '+%b %e')" >> $LOGFILE

# Successful root logins
echo -e "\n=== Root Login Sessions ===" >> $LOGFILE
grep "session opened for user root" /var/log/auth.log | tail -20 >> $LOGFILE

# sudo usage
echo -e "\n=== sudo Commands ===" >> $LOGFILE
grep "COMMAND" /var/log/auth.log | grep "$(date '+%b %e')" >> $LOGFILE

# New SUID files
echo -e "\n=== Recent SUID/SGID Files ===" >> $LOGFILE
find / -type f \( -perm -4000 -o -perm -2000 \) -mtime -1 2>/dev/null >> $LOGFILE

# Listening ports
echo -e "\n=== Listening Ports ===" >> $LOGFILE
ss -tlnp >> $LOGFILE

# Large processes
echo -e "\n=== Top CPU Processes ===" >> $LOGFILE
ps aux --sort=-%cpu | head -10 >> $LOGFILE

echo -e "\n=== Top Memory Processes ===" >> $LOGFILE
ps aux --sort=-%mem | head -10 >> $LOGFILE

# Send report
mail -s "Daily Security Report - $(hostname)" $EMAIL < $LOGFILE
```

**Schedule with cron:**
```bash
# /etc/cron.daily/security-check
0 6 * * * /usr/local/bin/daily-security-check.sh
```

---

## Real-time Alerting

### Using swatch (Simple Watcher)

```bash
# Install
apt-get install swatch

# Configure ~/.swatchrc
watchfor /Failed password/
    echo bold
    mail addresses=admin@example.com,subject="Failed SSH Login"

watchfor /session opened for user root/
    echo bold
    mail addresses=admin@example.com,subject="Root Login Detected"

# Run
swatch --tail-file=/var/log/auth.log --daemon
```

### Using systemd journal

```bash
# Watch for specific events
journalctl -f -u sshd | grep --line-buffered "Failed password" | \
while read line; do
    echo "$line" | mail -s "SSH Failed Login" admin@example.com
done
```

---

## Security Information and Event Management (SIEM)

For larger environments, consider:

- **ELK Stack** (Elasticsearch, Logstash, Kibana)
- **Splunk**
- **Graylog**
- **OSSIM** (Open Source Security Information Management)

These provide:
- Centralized log collection
- Real-time analysis
- Alerting and dashboards
- Compliance reporting

---

## Incident Response Checklist

When suspicious activity is detected:

```
☐ 1. Document
   ☐ Time of detection
   ☐ What was observed
   ☐ Screenshot/copy evidence

☐ 2. Contain
   ☐ Isolate affected system (disconnect network if severe)
   ☐ Disable compromised accounts
   ☐ Block malicious IPs

☐ 3. Analyze
   ☐ Review logs
   ☐ Check file modifications
   ☐ Identify scope
   ☐ Determine attack vector

☐ 4. Eradicate
   ☐ Remove malware/backdoors
   ☐ Patch vulnerabilities
   ☐ Update configurations

☐ 5. Recover
   ☐ Restore from clean backups
   ☐ Verify system integrity
   ☐ Monitor for reinfection

☐ 6. Lessons Learned
   ☐ Document incident
   ☐ Update procedures
   ☐ Improve defenses
```

---

## Compliance Monitoring

### PCI-DSS Requirements

- Log all user access
- Log privileged actions
- Daily log review
- Retain logs for 1 year minimum
- Quarterly access reviews

### HIPAA Requirements

- Log access to ePHI
- Audit trail protection
- Regular review of audit logs
- Incident response procedures

### SOC 2 Requirements

- Monitoring and alerting
- Log retention
- Access control logging
- Change management tracking

---

## Quick Reference

**View authentication logs:**
```bash
grep "Failed password" /var/log/auth.log     # Failed logins
grep "Accepted" /var/log/auth.log            # Successful logins
grep "sudo.*COMMAND" /var/log/auth.log       # sudo usage
lastlog                                      # Last login times
```

**Audit file changes:**
```bash
find /etc -type f -mtime -1 -ls              # Modified today
auditctl -w /etc/passwd -p wa                # Watch file
ausearch -k passwd_changes                   # Search audit logs
```

**Monitor network:**
```bash
ss -tlnp                                     # Listening ports
ss -tan state established                    # Active connections
nethogs                                      # Bandwidth by process
```

**Process monitoring:**
```bash
ps aux --sort=-%cpu | head                   # Top CPU
ps aux --sort=-%mem | head                   # Top memory
lsof -i -P                                   # Network processes
```

---

## Further Reading

- `man auditd` - Linux audit daemon
- `man aide` - Advanced Intrusion Detection Environment
- `man fail2ban-client` - Fail2ban management
- NIST SP 800-92 - Guide to Computer Security Log Management
- CIS Benchmarks - Security configuration standards
