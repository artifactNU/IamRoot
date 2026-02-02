# Incident Response

What to do when security incidents occur.

---

## Why This Matters

**Not if, but when.**

Security incidents will happen:
- Compromised accounts
- Malware infections
- Data breaches
- Denial of service attacks
- Insider threats

A prepared response:
- Limits damage
- Preserves evidence
- Speeds recovery
- Meets compliance requirements

**Having a plan is the difference between an incident and a disaster.**

---

## Incident Response Phases

Standard IR framework:

1. **Preparation** - Before incidents occur
2. **Detection** - Identifying incidents
3. **Containment** - Limiting the damage
4. **Eradication** - Removing the threat
5. **Recovery** - Restoring normal operations
6. **Lessons Learned** - Improving defenses

---

## Phase 1: Preparation

### Before an Incident

**Documentation:**
- Incident response plan
- Contact list (IT, security, management, legal)
- System diagrams
- Critical asset inventory
- Backup procedures

**Tools Ready:**
```bash
# Forensic tools
apt-get install sleuthkit autopsy foremost

# Network analysis
apt-get install tcpdump wireshark nmap

# System analysis
apt-get install lsof strace ltrace

# Data collection
apt-get install dc3dd
```

**Baseline Knowledge:**
- Normal network traffic patterns
- Typical CPU/memory usage
- Standard running processes
- Authorized user accounts
- Expected listening ports

**Communication Plan:**
- Who to notify
- Escalation procedures
- External contacts (legal, law enforcement, customers)

---

## Phase 2: Detection

### Indicators of Compromise (IOCs)

**System-level indicators:**
- Unexpected user accounts
- Unusual processes
- Modified system files
- New scheduled tasks
- Unusual network connections

**Network indicators:**
- Connections to suspicious IPs
- Unusual data transfers
- Port scans
- Unexpected protocols

**Application indicators:**
- Authentication failures
- Privilege escalation attempts
- Unusual database queries
- Application errors

### Initial Detection

```bash
# Check for suspicious users
awk -F: '$3 >= 1000 {print $1}' /etc/passwd
grep -v -E '/nologin|/false' /etc/passwd

# Check for suspicious processes
ps aux --sort=-%cpu
ps aux | grep -v -E 'root|www-data|systemd'

# Check network connections
ss -tunap
lsof -i -P

# Recent file modifications
find /bin /sbin /usr/bin /usr/sbin -mtime -7 -ls
find /etc -mtime -1 -ls

# Check cron jobs
ls -la /etc/cron.*
crontab -l
for user in $(cut -f1 -d: /etc/passwd); do echo "=== $user ==="; crontab -u $user -l 2>/dev/null; done
```

---

## Phase 3: Containment

### Immediate Actions

**DO NOT:**
- Panic
- Shut down the system immediately (loses volatile data)
- Delete logs or files
- Notify the attacker (if insider threat)

**DO:**
1. Document everything
2. Notify appropriate personnel
3. Preserve evidence
4. Contain the threat

### Short-term Containment

**Isolate the system:**
```bash
# Disconnect from network (if severe)
ip link set eth0 down

# Or block specific IPs
iptables -A INPUT -s <attacker_ip> -j DROP
iptables -A OUTPUT -d <attacker_ip> -j DROP

# Block all except admin access
iptables -P INPUT DROP
iptables -A INPUT -s <admin_ip> -j ACCEPT
```

**Lock compromised accounts:**
```bash
# Lock user account
usermod -L username
passwd -l username

# Kill user sessions
pkill -u username

# Check where user is logged in
who | grep username
w username
```

**Stop suspicious processes:**
```bash
# Identify PID
ps aux | grep suspicious_process

# Kill process
kill <PID>

# Force kill if needed
kill -9 <PID>

# Check if it respawns (indicates persistence mechanism)
ps aux | grep suspicious_process
```

### Long-term Containment

Apply temporary fixes while preparing full recovery:

```bash
# Disable compromised service
systemctl stop suspicious_service
systemctl disable suspicious_service

# Remove from startup
systemctl mask suspicious_service

# Update firewall rules permanently
iptables-save > /etc/iptables/rules.v4

# Patch vulnerabilities
apt-get update && apt-get upgrade
```

---

## Phase 4: Eradication

### Remove the Threat

**Check for backdoors:**
```bash
# Unusual SUID files
find / -type f -perm -4000 -ls 2>/dev/null

# Hidden files
find / -name ".*" -type f 2>/dev/null

# Files in /tmp and /var/tmp
ls -la /tmp /var/tmp

# Unusual files in system directories
find /bin /sbin /usr/bin /usr/sbin -mtime -7 -ls
```

**Check for rootkits:**
```bash
# Install detection tools
apt-get install rkhunter chkrootkit

# Run scans
rkhunter --check
chkrootkit

# Check kernel modules
lsmod
cat /proc/modules
```

**Check for malicious cron jobs:**
```bash
# System cron
ls -la /etc/cron.*
cat /etc/crontab

# User cron jobs
for user in $(cut -f1 -d: /etc/passwd); do 
    echo "=== $user ==="
    crontab -u $user -l 2>/dev/null
done

# Systemd timers
systemctl list-timers
```

**Check for persistence mechanisms:**
```bash
# Startup scripts
ls -la /etc/init.d/
ls -la /etc/rc*.d/

# Systemd services
systemctl list-unit-files --type=service
ls -la /etc/systemd/system/
ls -la /lib/systemd/system/

# User startup
cat ~/.bashrc ~/.bash_profile ~/.profile
ls -la ~/.config/autostart/
```

**Remove malware:**
```bash
# Delete malicious files
rm /path/to/malicious/file

# Remove malicious cron job
crontab -e
# or
crontab -r

# Remove malicious service
systemctl stop malicious.service
systemctl disable malicious.service
rm /etc/systemd/system/malicious.service
systemctl daemon-reload
```

---

## Phase 5: Recovery

### Restore Normal Operations

**From backups (preferred):**
```bash
# Verify backup integrity
tar -tzf backup.tar.gz

# Restore files
tar -xzf backup.tar.gz -C /

# Verify restored files
diff /etc/original /etc/backup
md5sum /bin/ls
```

**Rebuild from scratch (if severely compromised):**
1. Document current state
2. Reinstall OS
3. Apply hardening
4. Restore data from clean backups
5. Verify integrity

**Verify system integrity:**
```bash
# Check package integrity (Debian/Ubuntu)
debsums -c

# Check package integrity (RHEL/CentOS)
rpm -Va

# Run AIDE
aide --check

# Scan for rootkits again
rkhunter --check
chkrootkit
```

**Reset passwords:**
```bash
# All user passwords
for user in $(cut -f1 -d: /etc/passwd); do
    if id -u $user >/dev/null 2>&1; then
        passwd $user
    fi
done

# Force password change at next login
chage -d 0 username
```

**Regenerate SSH keys:**
```bash
# Remove old host keys
rm /etc/ssh/ssh_host_*

# Generate new keys
ssh-keygen -A

# Restart SSH
systemctl restart sshd

# Notify users to remove old fingerprints
# Users need to: ssh-keygen -R hostname
```

**Monitor for reinfection:**
```bash
# Watch logs
tail -f /var/log/auth.log /var/log/syslog

# Monitor processes
watch -n 5 'ps aux | head -20'

# Monitor network
watch -n 5 'ss -tulpn'

# Check file integrity
aide --check
```

---

## Phase 6: Lessons Learned

### Post-Incident Review

**Within 1-2 weeks of incident, conduct review:**

**What happened?**
- Timeline of events
- Attack vector
- Systems affected
- Data compromised

**How was it detected?**
- What alerted us?
- How long until detection?
- What could improve detection?

**What worked well?**
- Effective procedures
- Helpful tools
- Good decisions

**What didn't work?**
- Gaps in detection
- Missing tools or access
- Communication issues
- Unclear procedures

**Action items:**
- Update IR plan
- Implement new controls
- Additional training
- Tool improvements

---

## Forensic Data Collection

### Volatile Data (Collect First)

**This data is lost on reboot:**

```bash
#!/bin/bash
# Forensic data collection script
OUTDIR="/tmp/forensics-$(date +%Y%m%d-%H%M%S)"
mkdir -p $OUTDIR

# Date and time
date > $OUTDIR/datetime.txt

# Running processes
ps aux > $OUTDIR/processes.txt
ps -eo pid,etime,comm > $OUTDIR/process-times.txt

# Network connections
ss -tunap > $OUTDIR/network-connections.txt
netstat -tunap > $OUTDIR/netstat.txt
lsof -i > $OUTDIR/network-processes.txt

# Logged in users
who > $OUTDIR/logged-in-users.txt
w > $OUTDIR/user-activity.txt

# Open files
lsof > $OUTDIR/open-files.txt

# Loaded kernel modules
lsmod > $OUTDIR/kernel-modules.txt

# Routing table
ip route > $OUTDIR/routing-table.txt
route -n >> $OUTDIR/routing-table.txt

# ARP cache
ip neigh > $OUTDIR/arp-cache.txt
arp -an >> $OUTDIR/arp-cache.txt

# Memory dump (if you have enough space)
dd if=/dev/mem of=$OUTDIR/memory.dump bs=1M
# Or use LiME for better memory acquisition

# Package the data
tar -czf $OUTDIR.tar.gz $OUTDIR/
```

### Non-Volatile Data

**Collect after volatile data:**

```bash
# System information
uname -a > $OUTDIR/system-info.txt
cat /etc/*release >> $OUTDIR/system-info.txt

# User accounts
cp /etc/passwd $OUTDIR/
cp /etc/shadow $OUTDIR/
cp /etc/group $OUTDIR/

# Authentication logs
cp /var/log/auth.log* $OUTDIR/
cp /var/log/secure* $OUTDIR/

# System logs
cp /var/log/syslog* $OUTDIR/
cp /var/log/messages* $OUTDIR/

# Cron jobs
cp -r /etc/cron* $OUTDIR/
crontab -l > $OUTDIR/root-crontab.txt

# Startup scripts
ls -laR /etc/init.d/ > $OUTDIR/init-scripts.txt
systemctl list-unit-files > $OUTDIR/systemd-units.txt

# Recently modified files
find / -mtime -7 -ls > $OUTDIR/recent-modifications.txt 2>/dev/null

# SUID files
find / -type f -perm -4000 -ls > $OUTDIR/suid-files.txt 2>/dev/null

# File hashes of binaries
find /bin /sbin /usr/bin /usr/sbin -type f -exec md5sum {} \; > $OUTDIR/binary-hashes.txt
```

### Disk Imaging

**Create forensic image:**
```bash
# Using dc3dd (better than dd for forensics)
dc3dd if=/dev/sda of=/mnt/external/disk-image.dd hash=md5 hash=sha256 log=/mnt/external/image.log

# Calculate hash of original
md5sum /dev/sda > /mnt/external/disk-hash.txt
sha256sum /dev/sda >> /mnt/external/disk-hash.txt

# Mount read-only for analysis
mount -o ro,loop /mnt/external/disk-image.dd /mnt/analysis
```

---

## Common Incident Types

### Compromised Account

**Steps:**
1. Lock account: `usermod -L username`
2. Kill sessions: `pkill -u username`
3. Check command history: `cat ~username/.bash_history`
4. Check SSH keys: `cat ~username/.ssh/authorized_keys`
5. Check cron jobs: `crontab -u username -l`
6. Review auth logs: `grep username /var/log/auth.log`
7. Force password reset
8. Enable 2FA

### Malware Infection

**Steps:**
1. Isolate system
2. Identify malicious process
3. Collect samples
4. Kill process
5. Remove files
6. Check persistence mechanisms
7. Scan with antivirus (ClamAV)
8. Verify removal
9. Monitor for reinfection

### Unauthorized Access

**Steps:**
1. Review access logs
2. Identify entry point
3. Check for privilege escalation
4. Document accessed data
5. Lock down entry point
6. Rotate credentials
7. Notify affected parties if data breach

### Denial of Service

**Steps:**
1. Identify attack type (SYN flood, HTTP flood, etc.)
2. Identify source IPs
3. Implement rate limiting
4. Block attacking IPs
5. Contact ISP if necessary
6. Consider DDoS mitigation service

---

## Communication During Incidents

### Internal Communication

**Notify:**
- IT team
- Security team
- Management
- Legal (if data breach)
- Compliance (if regulated data)

**Status updates:**
- Regular intervals (every hour during active incident)
- Key milestones
- When contained
- When resolved

### External Communication

**May need to notify:**
- Customers (if their data affected)
- Partners
- Regulators (GDPR, HIPAA, PCI-DSS)
- Law enforcement (if criminal activity)
- Insurance company
- Public (if public-facing service)

**Breach notification requirements:**
- GDPR: 72 hours
- HIPAA: 60 days
- State laws vary

---

## Documentation Template

```
INCIDENT REPORT

Incident ID: INC-2026-001
Date Detected: 2026-02-02 14:30 UTC
Detected By: Alice Smith
Severity: High

SUMMARY:
Brief description of what happened.

TIMELINE:
2026-02-02 14:30 - Suspicious login detected
2026-02-02 14:45 - Account locked, IT notified
2026-02-02 15:00 - Investigation began
...

AFFECTED SYSTEMS:
- web-server-01 (compromised)
- database-server-01 (accessed)

AFFECTED DATA:
- User email addresses (10,000 records)
- No passwords or payment data accessed

ROOT CAUSE:
Phishing attack led to compromised credentials.

ACTIONS TAKEN:
1. Locked compromised account
2. Forced password reset for all users
3. Reviewed access logs
4. Enhanced email filtering

LESSONS LEARNED:
- Need 2FA enforcement
- Better phishing awareness training
- Faster detection needed

FOLLOW-UP ACTIONS:
1. Implement 2FA (Due: 2026-02-15)
2. Security awareness training (Due: 2026-03-01)
3. Deploy SIEM (Due: 2026-04-01)
```

---

## Quick Reference

**Contain:**
```bash
ip link set eth0 down                    # Disconnect network
usermod -L username                      # Lock account
pkill -u username                        # Kill user sessions
systemctl stop service                   # Stop service
```

**Investigate:**
```bash
grep username /var/log/auth.log          # User activity
ps aux | grep suspicious                 # Find process
ss -tulpn                                # Network connections
find / -mtime -1 -ls                     # Recent changes
```

**Collect evidence:**
```bash
ps aux > /tmp/processes.txt              # Running processes
ss -tunap > /tmp/connections.txt         # Network connections
cp /var/log/auth.log /tmp/               # Authentication logs
tar -czf evidence.tar.gz /tmp/*.txt      # Package evidence
```

---

## Further Reading

- NIST SP 800-61 - Computer Security Incident Handling Guide
- SANS Incident Handler's Handbook
- RFC 2350 - Expectations for Computer Security Incident Response
- `man forensics-all` - Forensic tools suite
