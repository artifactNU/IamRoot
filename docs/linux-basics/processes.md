# Process Management

Understanding how programs run and how to manage them.

---

## Why This Matters

As a sysadmin, you need to:
- Identify what is consuming resources
- Stop misbehaving processes
- Understand parent-child relationships
- Diagnose why services won't start or stop

Most performance issues and many outages come down to process management.

---

## What is a Process?

A **process** is a running instance of a program.

Key properties:
- **PID** (Process ID) - Unique identifier
- **PPID** (Parent Process ID) - What spawned this process
- **UID/GID** - User and group it runs as
- **State** - Running, sleeping, zombie, etc.
- **Resources** - Memory, CPU time, open files

View with: `ps`, `top`, `htop`, or `/proc/<PID>/`

---

## Process Lifecycle

```
fork() → exec() → running → exit() → zombie → reaped
```

1. **Fork**: Parent creates child (copy of itself)
2. **Exec**: Child replaces itself with new program
3. **Running**: Process executes
4. **Exit**: Process terminates
5. **Zombie**: Process finished but parent hasn't acknowledged
6. **Reaped**: Parent collects exit status, process removed

---

## Process States

| State | Symbol | Meaning |
|-------|--------|---------|
| Running | `R` | Executing or runnable (on run queue) |
| Sleeping | `S` | Waiting for event (interruptible) |
| Disk sleep | `D` | Waiting for I/O (uninterruptible) |
| Stopped | `T` | Stopped (Ctrl+Z or debugger) |
| Zombie | `Z` | Terminated but not reaped by parent |
| Dead | `X` | Being destroyed |

**D state processes** cannot be killed - they're waiting on kernel/hardware. Usually I/O related.

---

## Viewing Processes

### Basic Process Listing
```bash
ps aux                 # All processes, BSD style
ps -ef                 # All processes, Unix style
ps -eLf                # Include threads
ps -u username         # Processes for specific user
ps -C nginx            # Processes by command name
```

### Process Tree
```bash
pstree                 # Tree of all processes
pstree -p              # Include PIDs
pstree -u              # Show user changes
ps auxf                # Tree format with ps
```

### Real-Time Monitoring
```bash
top                    # Interactive process viewer
htop                   # Better top (if installed)
atop                   # Advanced system monitor
```

**Top keys:**
- `M` - Sort by memory
- `P` - Sort by CPU
- `k` - Kill process
- `r` - Renice process
- `f` - Choose fields to display

### Process Details
```bash
# Everything about a process
ls -l /proc/<PID>/

# Command line arguments
cat /proc/<PID>/cmdline | tr '\0' ' '

# Environment variables
cat /proc/<PID>/environ | tr '\0' '\n'

# Open files
lsof -p <PID>

# Current directory
ls -l /proc/<PID>/cwd

# Memory maps
cat /proc/<PID>/maps

# Status summary
cat /proc/<PID>/status
```

---

## Signals

Signals are messages sent to processes.

### Common Signals

| Signal | Number | Meaning | Can Block? |
|--------|--------|---------|------------|
| `SIGTERM` | 15 | Terminate gracefully | Yes |
| `SIGKILL` | 9 | Kill immediately | No |
| `SIGHUP` | 1 | Hang up (often: reload config) | Yes |
| `SIGINT` | 2 | Interrupt (Ctrl+C) | Yes |
| `SIGQUIT` | 3 | Quit with core dump | Yes |
| `SIGSTOP` | 19 | Pause process | No |
| `SIGCONT` | 18 | Resume process | No |
| `SIGUSR1` | 10 | User-defined signal 1 | Yes |
| `SIGUSR2` | 12 | User-defined signal 2 | Yes |

### Sending Signals
```bash
kill <PID>              # Send SIGTERM (15)
kill -9 <PID>           # Send SIGKILL (9)
kill -HUP <PID>         # Send SIGHUP (1)
kill -l                 # List all signals

killall nginx           # Kill all processes named nginx
pkill -f "python.*manage.py"  # Kill by pattern
```

### Signal Behavior

**SIGTERM vs SIGKILL:**
- `SIGTERM` (15): Asks nicely. Process can clean up, close files, save state.
- `SIGKILL` (9): Immediate termination. No cleanup. Use as last resort.

**Always try SIGTERM first.**

**SIGHUP common use:**
Many daemons reload configuration on SIGHUP:
```bash
kill -HUP $(cat /var/run/nginx.pid)
systemctl reload nginx
```

---

## Process Priority and Nice Values

Linux uses **nice values** to determine process priority.

- Range: `-20` (highest priority) to `19` (lowest priority)
- Default: `0`
- Lower nice = higher priority

### View Priority
```bash
ps -el                  # PRI and NI columns
top                     # PR and NI columns
```

### Change Priority
```bash
nice -n 10 command      # Start with nice value 10
renice -n 5 -p <PID>    # Change running process
renice -n 5 -u username # Change all user's processes
```

**Who can do what:**
- Any user can increase their nice value (lower priority)
- Only root can decrease nice value (increase priority)
- Only root can use negative nice values

---

## Background and Foreground Jobs

### Job Control
```bash
command &               # Run in background
Ctrl+Z                  # Suspend current job
bg                      # Resume last job in background
fg                      # Bring last job to foreground
jobs                    # List jobs
fg %1                   # Foreground job 1
kill %2                 # Kill job 2
```

### Detaching from Terminal
```bash
nohup command &         # Ignore SIGHUP
disown -h %1            # Detach job from shell

# Better: use screen or tmux
screen -S session_name
tmux new -s session_name
```

---

## Resource Limits

### View Limits
```bash
ulimit -a               # All limits for current shell
cat /proc/<PID>/limits  # Limits for specific process
```

### Set Limits
```bash
ulimit -n 4096          # Set max open files
ulimit -u 500           # Set max user processes
ulimit -m 1000000       # Set max memory (KB)
```

**Permanent limits:** Edit `/etc/security/limits.conf`

```
username  soft  nofile  4096
username  hard  nofile  8192
@groupname soft nproc   500
```

---

## Common Process Problems

### High CPU Usage
```bash
# Find top CPU consumers
top
ps aux --sort=-%cpu | head

# See what a process is doing
strace -p <PID>

# Profile CPU usage
perf top
```

### High Memory Usage
```bash
# Find top memory consumers
ps aux --sort=-%mem | head

# Detailed memory breakdown
pmap -x <PID>
cat /proc/<PID>/smaps
```

### Too Many Processes
```bash
# Count processes by user
ps aux | awk '{print $1}' | sort | uniq -c | sort -n

# Find fork bomb or runaway script
pstree -p | grep <process_name>

# Check ulimit
ulimit -u
```

### Zombie Processes
Zombies (`Z` state) have finished but parent hasn't reaped them.

```bash
# Find zombies
ps aux | grep 'Z'

# Find parent
ps -o ppid= <zombie_PID>

# Usually need to restart or signal parent
kill -TERM <parent_PID>
```

**If parent is PID 1:** You have a problem. Likely need to reboot or investigate init/systemd.

### Unkillable Processes (D state)
Process stuck in uninterruptible sleep (usually I/O).

```bash
# Cannot kill these
ps aux | grep ' D '

# Find what they're waiting for
cat /proc/<PID>/stack

# Common causes:
# - Hung NFS mount
# - Failing disk
# - Kernel bug
```

**Solution:** Fix underlying issue (remount, hardware fix) or reboot.

---

## Process Monitoring Tools

### Essential Tools
```bash
ps              # Process snapshot
top / htop      # Interactive monitor
pgrep           # Find processes by name
pkill           # Kill processes by name
pstree          # Process tree
lsof            # List open files
```

### Advanced Tools
```bash
strace          # Trace system calls
ltrace          # Trace library calls
perf            # Performance analysis
systemd-cgtop   # Cgroup resource usage (systemd systems)
iotop           # I/O usage by process
pidstat         # Process statistics over time
```

### Finding Processes
```bash
# By name
pgrep nginx
pidof nginx

# By port
lsof -i :80
ss -tulpn | grep :80

# By user
pgrep -u apache

# By full command line
pgrep -f "python manage.py"
```

---

## Process Ownership and Permissions

Processes run as a specific user and group.

### View Process User
```bash
ps -u               # Shows USER column
ps -o user,pid,cmd
```

### Why It Matters
- File access determined by process user
- Security boundaries
- Resource accounting

### Service User Accounts
Web servers, databases, etc. should **not** run as root.

Common patterns:
```bash
# nginx
ps aux | grep nginx
# root owns master process
# www-data owns worker processes

# systemd starts as root, drops privileges
```

---

## Systemd and Process Management

On systemd systems, most services are managed via systemd.

```bash
systemctl status nginx          # Service status
systemctl start nginx           # Start service
systemctl stop nginx            # Stop service
systemctl restart nginx         # Restart service
systemctl reload nginx          # Reload config (SIGHUP)

# See actual process
systemctl show -p MainPID nginx
ps -p $(systemctl show -p MainPID nginx | cut -d= -f2)
```

**Advantages:**
- Automatic restart on failure
- Resource limits (cgroups)
- Logging integration
- Dependency management

---

## Quick Reference

**Find problematic processes:**
```bash
# High CPU
ps aux --sort=-%cpu | head -10

# High memory
ps aux --sort=-%mem | head -10

# Zombie processes
ps aux | awk '$8 == "Z"'

# Processes in D state (unkillable)
ps aux | awk '$8 == "D"'

# Processes by user
ps -u username

# Process tree
pstree -ap

# What's using port 80?
lsof -i :80
```

**Kill processes:**
```bash
kill <PID>                      # SIGTERM
kill -9 <PID>                   # SIGKILL
killall process_name            # All by name
pkill -f pattern                # By pattern
pkill -u username               # All by user
```

---

## Further Reading

- `man ps` - Process status
- `man kill` - Send signal to process
- `man top` - Display process information
- `man proc` - Process information pseudo-filesystem
- `man systemd` - systemd system and service manager
