# Performance Issues

Diagnosing and resolving slow system performance.

---

## Why This Matters

**"The system is slow"** is one of the most common complaints.

Performance problems can be caused by:
- CPU bottlenecks
- Memory exhaustion
- Disk I/O saturation
- Network issues
- Misconfiguration
- Resource leaks

Systematic diagnosis identifies the real bottleneck.

---

## Performance Troubleshooting Approach

1. **Define "slow"** - Be specific about symptoms
2. **Establish baseline** - What is normal for this system?
3. **Identify bottleneck** - CPU, memory, disk, or network?
4. **Find the culprit** - What process/service is responsible?
5. **Determine cause** - Why is it consuming resources?
6. **Apply fix** - Address root cause
7. **Verify improvement** - Measure after changes

**Don't guess.** Use data to identify the actual problem.

---

## Quick Performance Overview

### All-in-One Commands

```bash
# Interactive system monitor (best overall view)
htop

# Classic top
top

# More detailed system monitor
atop

# System activity report
sar -u 1 10        # CPU usage
sar -r 1 10        # Memory usage
sar -d 1 10        # Disk usage
```

### One-Line Health Check

```bash
# Quick system status
uptime && free -h && df -h / && ps aux --sort=-%cpu | head -5
```

---

## CPU Issues

### Symptoms
- High load average
- System feels sluggish
- Commands take long to execute
- Processes waiting for CPU

### Identify CPU Bottleneck

```bash
# Current CPU usage
top
# Press '1' to see per-CPU breakdown
# Press 'Shift+P' to sort by CPU

# Load average
uptime
# Output: load average: 8.5, 7.2, 6.8
# Compare to number of CPUs

# Number of CPUs
nproc
lscpu

# Load average interpretation:
# < number of CPUs = OK
# = number of CPUs = Fully utilized
# > number of CPUs = Overloaded

# CPU usage over time
sar -u 1 10

# Per-process CPU usage
ps aux --sort=-%cpu | head -20
```

### Find CPU-Hungry Processes

```bash
# Top CPU consumers
ps aux --sort=-%cpu | head -10

# With ongoing monitoring
top -b -n 1 | head -20

# CPU usage by command
ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10

# Total CPU usage by user
ps -eo user,pcpu | awk '{cpu[$1]+=$2} END {for (u in cpu) print u, cpu[u]}' | sort -k2 -rn
```

### Common CPU Issues

**High system CPU (not user CPU):**
- Kernel issue
- Excessive context switching
- Hardware interrupts

```bash
# Check context switches
vmstat 1

# cs column = context switches per second
# High cs (> 10000) indicates thrashing

# Check interrupts
cat /proc/interrupts
watch -n 1 'cat /proc/interrupts | head -20'
```

**High I/O wait:**
- CPU waiting for disk
- Not actually CPU problem (see disk section)

```bash
# Look at 'wa' column in top
# or %iowait in sar output
top
# wa > 10% indicates I/O bottleneck
```

### CPU Issue Remedies

**Kill runaway process:**
```bash
kill <PID>
kill -9 <PID>    # Force kill
```

**Renice process (lower priority):**
```bash
renice +10 <PID>          # Make less important
renice -5 <PID>           # Make more important (needs root)
```

**Limit CPU usage (cgroups):**
```bash
# Create cgroup with CPU limit
cgcreate -g cpu:/limited
echo 50000 > /sys/fs/cgroup/cpu/limited/cpu.cfs_quota_us

# Run process in limited cgroup
cgexec -g cpu:/limited command
```

**Optimize application:**
- Check application logs for errors
- Look for infinite loops
- Profile application code
- Scale horizontally if possible

---

## Memory Issues

### Symptoms
- System swapping heavily
- Out of memory (OOM) killer activating
- Applications crashing
- Slow response times

### Identify Memory Bottleneck

```bash
# Memory overview
free -h

# Detailed memory info
cat /proc/meminfo

# Watch memory in real-time
watch -n 1 free -h

# Memory usage by process
ps aux --sort=-%mem | head -20

# Or with better formatting
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -20
```

### Understanding Memory Output

```bash
$ free -h
              total        used        free      shared  buff/cache   available
Mem:           15Gi       8.0Gi       1.0Gi       100Mi       6.0Gi       6.5Gi
Swap:         8.0Gi       2.0Gi       6.0Gi
```

**Key values:**
- **available** - Memory available for applications (most important)
- **buff/cache** - Used for caching (can be freed if needed)
- **Swap used** - Memory pressure indicator

**Red flags:**
- available < 10% of total
- Swap usage increasing over time
- OOM killer messages in logs

### Find Memory Hogs

```bash
# Top memory consumers
ps aux --sort=-%mem | head -10

# Memory by command name
ps -eo comm,rss | awk '{mem[$1]+=$2} END {for (c in mem) print c, mem[c]/1024 "MB"}' | sort -k2 -rn

# Detailed process memory
pmap -x <PID>
cat /proc/<PID>/smaps

# Memory mapped files
lsof -p <PID> | grep REG
```

### Check for Memory Leaks

```bash
# Monitor process memory over time
while true; do
    ps aux | grep process_name
    sleep 60
done

# Or more sophisticated
watch -n 10 'ps aux --sort=-%mem | head -10'

# Graph memory usage
vmstat 1 | awk '{print $4}' > mem.log
# Plot mem.log to see if memory is decreasing over time
```

### OOM Killer

**Check if OOM killer has been active:**
```bash
# Search logs
grep -i "Out of memory" /var/log/syslog
grep -i "oom" /var/log/kern.log
dmesg | grep -i "oom"

# Journalctl
journalctl -k | grep -i "oom"

# Shows what was killed
grep "Killed process" /var/log/kern.log
```

### Memory Issue Remedies

**Free up cache (safe):**
```bash
# Drop caches (doesn't free app memory)
sync
echo 3 > /proc/sys/vm/drop_caches
```

**Kill memory-hungry process:**
```bash
kill <PID>
```

**Adjust OOM killer priority:**
```bash
# Make process less likely to be killed
echo -1000 > /proc/<PID>/oom_score_adj

# Make process more likely to be killed
echo 1000 > /proc/<PID>/oom_score_adj

# View current score
cat /proc/<PID>/oom_score
```

**Disable swap temporarily (testing):**
```bash
swapoff -a    # Disable all swap
swapon -a     # Re-enable all swap
```

**Add more swap:**
```bash
# Create swap file
dd if=/dev/zero of=/swapfile bs=1M count=4096
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

**Tune swappiness:**
```bash
# View current swappiness (0-100)
cat /proc/sys/vm/swappiness

# Lower value = less swapping (better for servers)
sysctl vm.swappiness=10

# Permanent
echo "vm.swappiness=10" >> /etc/sysctl.conf
```

---

## Disk I/O Issues

### Symptoms
- High I/O wait in top
- Slow file operations
- Application timeouts
- Sluggish system even with low CPU

### Identify Disk Bottleneck

```bash
# I/O wait percentage
top
# Look at 'wa' (I/O wait) value
# > 10% indicates I/O bottleneck

# Detailed I/O statistics
iostat -x 1
# Look at %util column
# 100% = fully saturated

# Per-process I/O
iotop
iotop -o    # Only show processes doing I/O

# I/O statistics over time
sar -d 1 10
```

### Find I/O Heavy Processes

```bash
# Processes doing most I/O
iotop -o

# I/O statistics per process
pidstat -d 1

# What files are being accessed
lsof +r 1 -p <PID>

# Strace to see system calls
strace -p <PID> -e trace=read,write,open
```

### Check Disk Performance

```bash
# Simple write test
dd if=/dev/zero of=/tmp/testfile bs=1M count=1024 conv=fdatasync
# Note the speed

# Simple read test
dd if=/tmp/testfile of=/dev/null bs=1M
# Note the speed

# More comprehensive testing
apt-get install fio
fio --name=random-write --ioengine=libaio --iodepth=16 --rw=randwrite --bs=4k --direct=1 --size=1G --numjobs=4 --runtime=60 --group_reporting
```

### Disk I/O Issue Remedies

**Identify problem process:**
```bash
iotop -o
# Kill or tune the offending process
```

**Tune I/O scheduler:**
```bash
# Check current scheduler
cat /sys/block/sda/queue/scheduler

# Change to deadline (good for databases)
echo deadline > /sys/block/sda/queue/scheduler

# Or noop for SSDs
echo noop > /sys/block/sda/queue/scheduler

# Or mq-deadline for newer kernels
echo mq-deadline > /sys/block/sda/queue/scheduler
```

**Increase read-ahead:**
```bash
# Check current read-ahead (in 512-byte sectors)
blockdev --getra /dev/sda

# Increase (good for sequential reads)
blockdev --setra 8192 /dev/sda
```

**Check for failing disk:**
```bash
# SMART status
smartctl -a /dev/sda

# Look for:
# - Reallocated sectors
# - Current pending sectors
# - Uncorrectable errors

# Disk errors in kernel log
dmesg | grep -i "error\|fail"
```

**Mount options:**
```bash
# Use noatime to reduce writes
mount -o remount,noatime,nodiratime /

# Make permanent in /etc/fstab
/dev/sda1  /  ext4  defaults,noatime,nodiratime  0  1
```

---

## Network Issues

### Symptoms
- Slow network transfers
- High latency
- Connection timeouts
- Applications waiting on network

### Identify Network Bottleneck

```bash
# Network interface statistics
ip -s link

# Packet loss and errors
ifconfig eth0    # Look for errors, dropped packets

# Network bandwidth usage
iftop
nethogs          # Per-process
nload           # Real-time graph

# Connection states
ss -s           # Summary
ss -tan         # All TCP connections
```

### Network Performance Testing

```bash
# Test bandwidth to another host
iperf3 -s                    # On server
iperf3 -c <server_ip>        # On client

# Test latency
ping -c 100 <host>

# TCP connection time
time telnet <host> <port>

# DNS resolution time
time nslookup google.com
```

### Network Issue Remedies

**Check for network congestion:**
```bash
# Interface queue length
ip -s link show eth0
# Look for TX/RX dropped packets

# Increase queue length
ifconfig eth0 txqueuelen 10000
```

**TCP tuning:**
```bash
# Check current settings
sysctl net.ipv4.tcp_rmem
sysctl net.ipv4.tcp_wmem

# Increase TCP buffers (in /etc/sysctl.conf)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Apply
sysctl -p
```

---

## Application-Specific Performance

### Web Server Slow

```bash
# Check concurrent connections
ss -tan | grep :80 | wc -l

# Apache - check status
apachectl status

# Nginx - check connections
curl http://localhost/nginx_status

# Check for slow queries (if database-backed)
# See database section
```

### Database Slow

**PostgreSQL:**
```bash
# Slow queries
tail -f /var/log/postgresql/postgresql-*-main.log | grep "duration"

# Active connections
psql -c "SELECT count(*) FROM pg_stat_activity;"

# Long-running queries
psql -c "SELECT pid, age(clock_timestamp(), query_start), query FROM pg_stat_activity WHERE query != '<IDLE>' ORDER BY query_start;"
```

**MySQL:**
```bash
# Slow queries
tail -f /var/log/mysql/mysql-slow.log

# Current processes
mysql -e "SHOW PROCESSLIST;"

# Lock waits
mysql -e "SHOW ENGINE INNODB STATUS\G" | grep -A 10 "TRANSACTIONS"
```

---

## System-Wide Performance Analysis

### Performance Monitoring Tools

```bash
# Overview
htop

# Historic data (requires sysstat package)
sar -u        # CPU
sar -r        # Memory
sar -d        # Disk
sar -n DEV    # Network

# System calls
strace -c command

# Function calls
ltrace -c command

# Advanced profiling
perf top
perf record -a -g
perf report
```

### Benchmark System

```bash
# CPU benchmark
sysbench cpu run

# Memory benchmark
sysbench memory run

# Disk benchmark
sysbench fileio --file-test-mode=seqwr run

# Database benchmark
sysbench oltp_read_write --mysql-user=root --mysql-password=pass prepare
sysbench oltp_read_write --mysql-user=root --mysql-password=pass run
```

---

## Quick Diagnosis Script

```bash
#!/bin/bash
# quick-perf-check.sh

echo "=== System Load ==="
uptime

echo -e "\n=== CPU Usage ==="
top -bn1 | head -15

echo -e "\n=== Memory Usage ==="
free -h

echo -e "\n=== Disk I/O ==="
iostat -x 1 2 | tail -n +4

echo -e "\n=== Top CPU Processes ==="
ps aux --sort=-%cpu | head -10

echo -e "\n=== Top Memory Processes ==="
ps aux --sort=-%mem | head -10

echo -e "\n=== Disk Usage ==="
df -h

echo -e "\n=== Network Connections ==="
ss -s
```

---

## Quick Reference

**System overview:**
```bash
htop                          # Interactive monitor
uptime                        # Load average
free -h                       # Memory usage
df -h                         # Disk usage
```

**Find resource hogs:**
```bash
ps aux --sort=-%cpu | head    # CPU
ps aux --sort=-%mem | head    # Memory
iotop -o                      # Disk I/O
nethogs                       # Network
```

**Detailed analysis:**
```bash
iostat -x 1                   # I/O statistics
vmstat 1                      # Virtual memory
sar -u 1 10                   # CPU over time
top -b -n 1                   # Snapshot
```

**Kill process:**
```bash
kill <PID>                    # Graceful
kill -9 <PID>                 # Force
killall process_name          # All instances
```

---

## Further Reading

- `man top` - Process monitoring
- `man iostat` - I/O statistics
- `man vmstat` - Virtual memory statistics
- `man sar` - System activity report
- Brendan Gregg's Performance Tools: http://www.brendangregg.com/linuxperf.html
