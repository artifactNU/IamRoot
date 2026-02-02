# Disk Space Problems

Diagnosing and resolving disk space issues.

---

## Why This Matters

Running out of disk space causes:
- Application failures
- Database corruption
- Log file loss
- System instability
- Boot failures

Early detection and cleanup prevent outages.

---

## Check Disk Space

### Basic Disk Usage

```bash
# Filesystem usage
df -h

# Human-readable with filesystem type
df -hT

# Inodes usage (can run out even with space available)
df -i

# Specific filesystem
df -h /var
```

### What the Output Means

```bash
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G   40G   10G  80% /
/dev/sda2       100G   95G    5G  95% /var
```

**Red flags:**
- **95%+ used** - Immediate action needed
- **90%+ used** - Plan cleanup soon
- **Inodes 90%+** - Too many small files

---

## Find What's Using Space

### By Directory

```bash
# Size of directories in current location
du -sh *

# Sort by size
du -sh * | sort -h

# Or
du -h --max-depth=1 | sort -h

# Check specific directory
du -sh /var/*

# Top 10 largest directories
du -h /var | sort -h | tail -20

# Interactive disk usage browser (best tool)
ncdu /var
```

### By File

```bash
# Largest files in directory
find /var -type f -exec du -h {} + | sort -h | tail -20

# Files larger than 100MB
find /var -type f -size +100M -exec ls -lh {} \;

# Files larger than 1GB
find /var -type f -size +1G -exec ls -lh {} \;

# Largest files system-wide
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null

# Top 20 largest files
find / -type f -exec du -h {} + 2>/dev/null | sort -h | tail -20
```

---

## Common Space Hogs

### Log Files

**Location:** `/var/log/`

```bash
# Log file sizes
du -sh /var/log/*

# Largest log files
find /var/log -type f -exec ls -lh {} \; | sort -k5 -h | tail

# Truncate large log (don't delete while service is using it)
> /var/log/large-file.log
# or
truncate -s 0 /var/log/large-file.log

# Compress old logs
gzip /var/log/*.log.1

# Delete old compressed logs
find /var/log -name "*.gz" -mtime +30 -delete
```

### Journal Logs

```bash
# Check journal size
journalctl --disk-usage

# Clean up old journal entries
journalctl --vacuum-time=30d    # Keep 30 days
journalctl --vacuum-size=1G     # Keep 1GB max

# Configure retention in /etc/systemd/journald.conf
SystemMaxUse=500M
SystemKeepFree=1G
MaxRetentionSec=30d
```

### Package Manager Cache

**Debian/Ubuntu:**
```bash
# Check APT cache size
du -sh /var/cache/apt/archives

# Clean package cache
apt-get clean
apt-get autoclean

# Remove old kernels
apt-get autoremove --purge
```

**RHEL/CentOS:**
```bash
# Check YUM cache size
du -sh /var/cache/yum

# Clean cache
yum clean all
```

### Temporary Files

```bash
# /tmp size
du -sh /tmp

# Clean old temp files (be careful)
find /tmp -type f -atime +7 -delete
find /tmp -type d -empty -delete

# /var/tmp size
du -sh /var/tmp

# Clean old files
find /var/tmp -type f -atime +10 -delete
```

### Core Dumps

```bash
# Find core dumps
find / -name "core.*" -o -name "core" 2>/dev/null

# Size of core dumps
find / -name "core.*" -exec ls -lh {} \; 2>/dev/null

# Delete core dumps (if you don't need them)
find / -name "core.*" -delete 2>/dev/null

# Disable core dumps permanently
echo "* hard core 0" >> /etc/security/limits.conf
echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
sysctl -p
```

### Docker/Container Images

```bash
# Docker disk usage
docker system df

# Remove unused images
docker image prune -a

# Remove unused containers
docker container prune

# Remove unused volumes
docker volume prune

# Remove everything unused
docker system prune -a --volumes
```

### Database Files

```bash
# MySQL data directory
du -sh /var/lib/mysql/*

# PostgreSQL data directory
du -sh /var/lib/postgresql/*

# Check for large tables
# MySQL:
mysql -e "SELECT table_schema, table_name, ROUND(data_length/1024/1024,2) AS size_mb FROM information_schema.tables ORDER BY data_length DESC LIMIT 20;"

# PostgreSQL:
psql -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 20;"
```

---

## Special Cases

### Hidden Space - Deleted Files Still Open

**Problem:** File deleted but process still has it open, space not freed.

```bash
# Find deleted files still open
lsof | grep deleted
lsof | grep '(deleted)'

# Or
lsof +L1

# Example output:
# apache2  1234  www-data  5w  /var/log/apache2/access.log (deleted)

# Solution: Restart or HUP the service
systemctl restart apache2

# Or kill and restart the process
kill -HUP <PID>
```

### Inodes Exhausted

**Problem:** Can't create files even though space available.

```bash
# Check inode usage
df -i

# Find directories with many files
find / -xdev -type d -exec sh -c 'echo "$(ls -1 {} | wc -l) {}"' \; 2>/dev/null | sort -n | tail -20

# Common culprit: cache directories, mail spools
du --inodes -d 5 / 2>/dev/null | sort -n | tail -20

# Clean up directories with many small files
find /var/spool/mail -type f -size 0 -delete
find /tmp -type f -delete
```

### Sparse Files

**Problem:** `du` and `df` show different values.

```bash
# du shows logical size, df shows actual space used
# List files with holes (sparse files)
find / -type f -exec sh -c 'test $(stat -c "%b*%B" "$1" | bc) -lt $(stat -c "%s" "$1")' _ {} \; -ls 2>/dev/null

# Check specific file
du -h file.img          # Logical size
ls -lh file.img         # Actual size
du --apparent-size file.img
```

### Quota Issues

```bash
# Check user quotas
quota -v username
repquota -a

# Check group quotas
quota -vg groupname
```

---

## Emergency Space Recovery

### When Disk is 100% Full

**1. Find and delete largest files immediately:**
```bash
# Find largest files quickly
find /var -type f -size +100M 2>/dev/null

# Quick wins - safe to delete:
> /var/log/syslog          # Truncate log
rm /tmp/large-file         # Delete temp files
apt-get clean              # Clear package cache
```

**2. Truncate logs without stopping services:**
```bash
# Don't use rm - service may still be writing
> /var/log/nginx/access.log
truncate -s 0 /var/log/application.log
```

**3. Compress files instead of deleting:**
```bash
gzip /var/log/*.log
tar -czf backup-$(date +%Y%m%d).tar.gz /path/to/data
```

**4. Move to another filesystem:**
```bash
# Move to external storage
mv /var/log/archive /mnt/external/
ln -s /mnt/external/archive /var/log/archive
```

---

## Monitor Disk Space

### Manual Monitoring

```bash
# Watch disk usage
watch -n 60 'df -h'

# Alert when threshold exceeded
df -h | awk '{if (NF > 1 && $5 ~ /[0-9]+%/) print $5 " " $6}' | while read usage mount; do
    percent=$(echo $usage | sed 's/%//')
    if [ $percent -gt 90 ]; then
        echo "WARNING: $mount is at $usage"
    fi
done
```

### Automated Monitoring

**Simple cron job:**
```bash
# /etc/cron.daily/disk-check
#!/bin/bash
THRESHOLD=90
df -h | awk -v thresh=$THRESHOLD '{
    if (NF > 1 && $5 ~ /[0-9]+%/) {
        gsub(/%/, "", $5)
        if ($5 > thresh) print "WARNING: " $6 " is at " $5 "%"
    }
}' | mail -s "Disk Space Alert" admin@example.com
```

**Using monitoring tools:**
- Nagios / Icinga
- Zabbix
- Prometheus + Node Exporter
- Grafana

---

## Prevent Disk Space Issues

### Log Rotation

**Configure logrotate:**
```bash
# /etc/logrotate.d/application
/var/log/application/*.log {
    daily                    # Rotate daily
    rotate 14                # Keep 14 days
    compress                 # Compress old logs
    delaycompress            # Don't compress most recent
    missingok                # Don't error if missing
    notifempty               # Don't rotate if empty
    create 0640 www-data adm # New file permissions
    sharedscripts
    postrotate
        systemctl reload application > /dev/null
    endscript
}
```

**Test logrotate:**
```bash
# Test configuration
logrotate -d /etc/logrotate.conf

# Force rotation
logrotate -f /etc/logrotate.conf
```

### Disk Quotas

**Enable quotas:**
```bash
# /etc/fstab
/dev/sda2  /home  ext4  defaults,usrquota,grpquota  0  2

# Remount
mount -o remount /home

# Create quota files
quotacheck -cum /home

# Enable quotas
quotaon /home

# Set quotas
edquota -u username
```

### Automatic Cleanup

**Clean old files automatically:**
```bash
# /etc/cron.daily/cleanup-temp
#!/bin/bash
find /tmp -type f -atime +7 -delete
find /var/tmp -type f -atime +14 -delete
find /var/log -name "*.log.*" -mtime +30 -delete
find /home/*/Downloads -type f -atime +60 -delete
```

### Application-Level Controls

**Database:**
- Archive old data
- Partition large tables
- Implement data retention policies

**Applications:**
- Rotate application logs
- Clean up old sessions
- Delete expired data

---

## Expand Disk Space

### Extend Filesystem

**LVM (Logical Volume Manager):**
```bash
# Check current size
lvdisplay

# Extend logical volume
lvextend -L +10G /dev/vg0/lv_root

# Resize filesystem
# For ext4:
resize2fs /dev/vg0/lv_root

# For xfs:
xfs_growfs /dev/vg0/lv_root
```

**Non-LVM partition:**
```bash
# More complex - requires:
# 1. Backup data
# 2. Resize partition (gparted or parted)
# 3. Resize filesystem
# 4. Verify

# Safer to use LVM from the start
```

### Add New Disk

```bash
# Partition new disk
fdisk /dev/sdb

# Create filesystem
mkfs.ext4 /dev/sdb1

# Mount temporarily
mkdir /mnt/newdisk
mount /dev/sdb1 /mnt/newdisk

# Move data
rsync -av /var/log/ /mnt/newdisk/

# Mount permanently
echo "/dev/sdb1  /var/log  ext4  defaults  0  2" >> /etc/fstab
mount -a
```

---

## Troubleshooting Tools

```bash
# Interactive disk usage
ncdu /

# Graphical (if GUI available)
baobab
filelight

# Find duplicate files
fdupes -r /home

# Find old files
find / -type f -atime +365 -ls 2>/dev/null

# Disk usage sorted
du -h / 2>/dev/null | sort -h | tail -50
```

---

## Quick Reference

**Check space:**
```bash
df -h                         # Filesystem usage
df -i                         # Inode usage
du -sh /*                     # Directory sizes
ncdu /                        # Interactive browser
```

**Find large files:**
```bash
find /var -type f -size +100M           # Files > 100MB
du -h /var | sort -h | tail -20         # Largest directories
lsof | grep deleted                     # Deleted but open files
```

**Clean up:**
```bash
> /var/log/large.log          # Truncate log
apt-get clean                 # Clear package cache
journalctl --vacuum-size=1G   # Clean journal
docker system prune -a        # Clean Docker
find /tmp -atime +7 -delete   # Old temp files
```

**Monitor:**
```bash
watch -n 60 'df -h'           # Watch disk usage
df -h | grep -E '9[0-9]%'     # Find > 90% full
```

---

## Further Reading

- `man df` - Report filesystem disk space usage
- `man du` - Estimate file space usage
- `man logrotate` - Rotate log files
- `man quotacheck` - Scan filesystem for disk usage
- `man ncdu` - NCurses Disk Usage
