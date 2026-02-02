# Service Failures

Diagnosing and fixing services that won't start or crash.

---

## Why This Matters

Service failures disrupt operations:
- Web server down = site unavailable
- Database crash = application failure
- SSH failure = can't access system
- Critical services = production outage

Systematic diagnosis gets services running faster.

---

## General Service Troubleshooting

### Check Service Status

```bash
# systemd systems
systemctl status servicename

# Detailed status
systemctl status servicename -l --no-pager

# Is it running?
systemctl is-active servicename

# Is it enabled at boot?
systemctl is-enabled servicename

# View service logs
journalctl -u servicename
journalctl -u servicename -n 50
journalctl -u servicename -f
```

### Common Service States

| State | Meaning | Action |
|-------|---------|--------|
| `active (running)` | Service is working | None needed |
| `inactive (dead)` | Service stopped | Start it |
| `failed` | Service crashed or failed to start | Check logs |
| `activating` | Service is starting | Wait or check if stuck |

---

## Service Won't Start

### Step 1: Check Service Status

```bash
systemctl status servicename
```

Look for:
- Exit code (if crashed)
- Error messages
- Last log entries

### Step 2: Check Service Logs

```bash
# Last 50 lines
journalctl -u servicename -n 50

# Follow logs while starting
journalctl -u servicename -f

# Since last boot
journalctl -u servicename -b

# With timestamps
journalctl -u servicename -o short-precise
```

### Step 3: Try Manual Start

```bash
# Start the service
systemctl start servicename

# Check status immediately
systemctl status servicename

# Watch logs
journalctl -u servicename -f
```

### Step 4: Test Configuration

Many services have config test commands:

```bash
# Nginx
nginx -t

# Apache
apachectl configtest

# SSH
sshd -t

# Postfix
postfix check

# PostgreSQL (as postgres user)
su - postgres -c "/usr/lib/postgresql/*/bin/postgres -C /etc/postgresql/*/main/postgresql.conf"
```

### Step 5: Check Dependencies

```bash
# View service dependencies
systemctl list-dependencies servicename

# Check if dependencies are running
systemctl status dependency-service

# View failed dependencies
systemctl --failed
```

---

## Common Failure Causes

### Configuration Errors

**Symptoms:**
- Service fails immediately on start
- "Configuration error" in logs
- Specific line numbers mentioned

**Fix:**
```bash
# Test configuration
nginx -t
apachectl configtest

# Check for typos
cat /etc/nginx/nginx.conf

# Restore from backup if needed
cp /etc/nginx/nginx.conf.backup /etc/nginx/nginx.conf

# Check syntax highlighting in editor
vim /etc/nginx/nginx.conf
```

### Permission Problems

**Symptoms:**
- "Permission denied" errors
- "Cannot open file" errors
- Service runs as wrong user

**Check and fix:**
```bash
# Check service user
systemctl status servicename | grep "Main PID"
ps aux | grep servicename

# Check file ownership
ls -l /etc/servicename/
ls -l /var/log/servicename/

# Fix ownership
chown -R serviceuser:servicegroup /var/log/servicename/
chown serviceuser:servicegroup /etc/servicename/config.conf

# Fix permissions
chmod 755 /var/log/servicename/
chmod 644 /etc/servicename/config.conf
```

### Port Already in Use

**Symptoms:**
- "Address already in use"
- "Cannot bind to port"
- Service fails to start

**Diagnose:**
```bash
# What's using the port?
ss -tlnp | grep :80
lsof -i :80

# Find the process
ps aux | grep <PID>

# Kill the other process or change port
kill <PID>
# or
systemctl stop other-service
```

### Missing Files or Directories

**Symptoms:**
- "No such file or directory"
- "Cannot open log file"
- "Cannot create PID file"

**Fix:**
```bash
# Create missing directories
mkdir -p /var/log/servicename
mkdir -p /var/run/servicename

# Set ownership
chown serviceuser:servicegroup /var/log/servicename
chown serviceuser:servicegroup /var/run/servicename

# Check systemd service file for required paths
cat /lib/systemd/system/servicename.service
```

### Dependency Failures

**Symptoms:**
- "Failed to start" after boot
- Other services also failed
- Database service not ready

**Fix:**
```bash
# Check what failed
systemctl --failed

# Check dependencies
systemctl list-dependencies servicename

# Start dependencies first
systemctl start dependency-service
systemctl start servicename

# Fix service ordering
systemctl edit servicename
# Add:
[Unit]
After=dependency.service
Requires=dependency.service
```

### Resource Limits

**Symptoms:**
- "Too many open files"
- "Cannot allocate memory"
- Service crashes under load

**Fix:**
```bash
# Check current limits
cat /proc/<PID>/limits

# Increase limits in systemd service
systemctl edit servicename
# Add:
[Service]
LimitNOFILE=65536
LimitNPROC=4096

# Reload and restart
systemctl daemon-reload
systemctl restart servicename
```

---

## Specific Service Problems

### Web Server (Nginx)

**Won't start:**
```bash
# Check configuration
nginx -t

# Check port availability
ss -tlnp | grep :80

# Check error log
tail -f /var/log/nginx/error.log

# Common issues:
# - Syntax error in config
# - Port 80/443 already in use
# - Missing SSL certificate files
# - Wrong file permissions

# Test with minimal config
nginx -t -c /etc/nginx/nginx.conf.default
```

**502 Bad Gateway:**
```bash
# Upstream (PHP-FPM, etc.) not running
systemctl status php7.4-fpm

# Upstream connection refused
# Check socket/port in nginx config
cat /etc/nginx/sites-enabled/default | grep fastcgi_pass

# Check PHP-FPM socket
ls -l /run/php/php7.4-fpm.sock
```

### Web Server (Apache)

**Won't start:**
```bash
# Check configuration
apachectl configtest

# Check error log
tail -f /var/log/apache2/error.log

# Check which port Apache is trying to use
grep "^Listen" /etc/apache2/ports.conf

# Common issues:
# - Module conflict
# - VirtualHost misconfiguration
# - Port conflict

# Disable problematic module
a2dismod module_name
systemctl restart apache2
```

### Database (MySQL/MariaDB)

**Won't start:**
```bash
# Check error log
tail -f /var/log/mysql/error.log

# Check datadir ownership
ls -l /var/lib/mysql/

# Common issues:
# - Insufficient disk space
# - Corrupt tables
# - Wrong permissions on datadir
# - Another instance already running

# Check if already running
ps aux | grep mysqld

# Check socket file
ls -l /var/run/mysqld/mysqld.sock

# Fix permissions
chown -R mysql:mysql /var/lib/mysql
```

**Table corruption:**
```bash
# Check tables
mysqlcheck -A

# Repair tables
mysqlcheck -r --all-databases

# If InnoDB corruption
# Restart with recovery mode
# Add to /etc/mysql/my.cnf:
[mysqld]
innodb_force_recovery = 1

# Restart, export data, reinstall
```

### Database (PostgreSQL)

**Won't start:**
```bash
# Check log
tail -f /var/log/postgresql/postgresql-*-main.log

# Check data directory
ls -l /var/lib/postgresql/*/main/

# Common issues:
# - Port conflict
# - Corrupt data directory
# - Wrong permissions
# - Old postmaster.pid file

# Remove stale PID file
rm /var/lib/postgresql/*/main/postmaster.pid

# Check port
ss -tlnp | grep :5432

# Fix permissions
chown -R postgres:postgres /var/lib/postgresql
```

### SSH Server

**Won't start:**
```bash
# Test configuration
sshd -t

# Check logs
journalctl -u sshd -n 50

# Common issues:
# - Missing host keys
# - Wrong permissions on config files
# - Port conflict
# - Invalid configuration

# Regenerate host keys
rm /etc/ssh/ssh_host_*
ssh-keygen -A

# Fix permissions
chmod 644 /etc/ssh/sshd_config
chmod 600 /etc/ssh/ssh_host_*_key
```

### Docker

**Won't start:**
```bash
# Check Docker status
systemctl status docker

# Check logs
journalctl -u docker -n 50

# Common issues:
# - Disk space full
# - Corrupt Docker files
# - Resource limits

# Clean up Docker
docker system prune -a

# Reset Docker (WARNING: loses all containers/images)
systemctl stop docker
rm -rf /var/lib/docker
systemctl start docker
```

---

## Service Crashes

### Service Starts Then Stops

**Diagnose:**
```bash
# View logs from last crash
journalctl -u servicename -n 100

# Check exit code
systemctl status servicename

# Watch service start
journalctl -u servicename -f &
systemctl start servicename

# Check for core dumps
coredumpctl list
coredumpctl info <PID>
```

### Service Crashes Under Load

**Diagnose:**
```bash
# Monitor resources while under load
htop

# Check memory limits
systemctl show servicename | grep Memory

# Check file descriptor limits
systemctl show servicename | grep LimitNOFILE

# Check for OOM killer
dmesg | grep -i "oom"
grep "oom" /var/log/syslog

# Check application logs for errors
tail -f /var/log/servicename/error.log
```

### Service Memory Leak

**Diagnose:**
```bash
# Monitor memory usage over time
watch -n 10 'ps aux | grep servicename'

# Detailed memory info
pmap -x <PID>

# Track memory over time
while true; do
    ps aux | grep servicename | grep -v grep
    sleep 60
done > memory-track.log
```

---

## Service Hangs

### Service Won't Stop

```bash
# Try graceful stop
systemctl stop servicename

# If hanging, check status
systemctl status servicename

# Force kill
systemctl kill servicename

# If still won't stop, kill process
ps aux | grep servicename
kill -9 <PID>

# Check what it's waiting for
lsof -p <PID>
strace -p <PID>
```

### Service Unresponsive

```bash
# Check if process exists
ps aux | grep servicename

# Check if responding
systemctl status servicename

# Check what it's doing
strace -p <PID>

# Check for deadlock (multiple threads)
pstack <PID>
gdb -p <PID>
(gdb) thread apply all bt
```

---

## Preventing Service Failures

### Automatic Restart

**Configure automatic restart:**
```bash
# Edit service file
systemctl edit servicename

# Add:
[Service]
Restart=on-failure
RestartSec=10s
StartLimitInterval=200s
StartLimitBurst=5

# Reload
systemctl daemon-reload
```

### Health Checks

**Simple monitoring script:**
```bash
#!/bin/bash
# /usr/local/bin/check-service.sh

SERVICE="nginx"

if ! systemctl is-active --quiet $SERVICE; then
    echo "$SERVICE is down, attempting restart"
    systemctl restart $SERVICE
    echo "$SERVICE restart attempted at $(date)" >> /var/log/service-restarts.log
    echo "$SERVICE was down!" | mail -s "Service Alert" admin@example.com
fi
```

**Add to cron:**
```bash
# /etc/cron.d/service-check
*/5 * * * * root /usr/local/bin/check-service.sh
```

### Monitoring

Use monitoring tools:
- systemd service monitoring
- Nagios / Icinga
- Zabbix
- Prometheus + Alertmanager
- Uptime monitors (external)

---

## Quick Reference

**Check service:**
```bash
systemctl status servicename          # Current status
journalctl -u servicename -n 50       # Recent logs
journalctl -u servicename -f          # Follow logs
systemctl is-active servicename       # Running?
systemctl is-enabled servicename      # Auto-start?
```

**Control service:**
```bash
systemctl start servicename           # Start
systemctl stop servicename            # Stop
systemctl restart servicename         # Restart
systemctl reload servicename          # Reload config
systemctl enable servicename          # Auto-start
systemctl disable servicename         # No auto-start
```

**Troubleshoot:**
```bash
nginx -t                              # Test nginx config
apachectl configtest                  # Test Apache config
sshd -t                               # Test SSH config
ss -tlnp | grep :80                   # What's on port 80?
systemctl --failed                    # What failed?
journalctl -u service -n 100          # Last 100 log lines
```

---

## Further Reading

- `man systemctl` - Control the systemd system and service manager
- `man journalctl` - Query the systemd journal
- `man systemd.service` - Service unit configuration
- `man systemd.exec` - Execution environment configuration
