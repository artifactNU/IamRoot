# Filesystem Hierarchy Standard

Understanding where things live on a Linux system.

---

## Why This Matters

When troubleshooting, you need to know:
- Where logs are written
- Where configurations live
- What can fill up your disk
- What is safe to clean up

The Filesystem Hierarchy Standard (FHS) provides a predictable layout, but real systems often diverge from it.

---

## Essential Directories

### `/etc` - System Configuration
- Text-based configuration files
- Readable by all users, writable by root
- Changes here affect the entire system
- Examples: `/etc/fstab`, `/etc/hosts`, `/etc/ssh/sshd_config`

**Common operations:**
- Look here first when a service behaves unexpectedly
- Always backup before editing
- Watch for `.d` directories (modular configs)

### `/var` - Variable Data
- Logs, mail spools, caches, databases
- Grows over time
- **This is what fills your disk**

Key subdirectories:
- `/var/log/` - System and application logs
- `/var/spool/` - Mail, print queues, cron jobs
- `/var/cache/` - Application cache (often safe to clean)
- `/var/lib/` - Persistent application state

**Common operations:**
- Monitor disk usage here regularly
- Rotate logs to prevent filling the filesystem
- Check here when "disk full" errors appear

### `/tmp` - Temporary Files
- Cleared on reboot (usually)
- World-writable with sticky bit
- Modern systems may use tmpfs (RAM-backed)

**Common operations:**
- Safe to clean if disk space is critical
- Check here for stale lock files
- Be aware: some distros use `/run` or `/var/tmp` for persistent temp files

### `/home` - User Directories
- User-specific files and configurations
- Quotas often enforced here
- May be on separate filesystem or NFS mount

**Common operations:**
- Check for large files when users report quota issues
- User configs (dotfiles) live here: `.bashrc`, `.ssh/config`
- Avoid system-level automation that touches user homes

### `/opt` - Third-Party Software
- Self-contained application installations
- Not managed by package manager
- Common for commercial or vendor software

**Common operations:**
- Check here for manually-installed applications
- Often requires manual updates
- May have its own directory structure

### `/usr` - User Binaries and Libraries
- System binaries not needed for boot
- `/usr/bin/` - User commands
- `/usr/sbin/` - System administration commands
- `/usr/local/` - Locally-installed software (not from packages)
- `/usr/share/` - Architecture-independent data

**Why it matters:**
- Package manager installs to `/usr`
- Manual installs should go to `/usr/local` to avoid conflicts
- `/usr` may be read-only or on separate filesystem

### `/root` - Root User Home
- Home directory for the root account
- Not `/home/root`
- Only root can read/write

**Common operations:**
- Root's shell history is here (`.bash_history`)
- Root's SSH keys (`.ssh/`)
- Cron scripts sometimes run from here (not ideal)

### `/proc` and `/sys` - Virtual Filesystems
- Not real files on disk
- Kernel and process information
- Used to inspect and configure running system

Examples:
- `/proc/cpuinfo` - CPU details
- `/proc/meminfo` - Memory usage
- `/sys/class/net/` - Network interface info

**Common operations:**
- Read for system state
- Some files are writable for tuning (e.g., `/proc/sys/`)
- Never appears in `df` output

### `/dev` - Device Files
- Block and character devices
- Created by `udev` dynamically
- Examples: `/dev/sda`, `/dev/null`, `/dev/random`

**Common operations:**
- Referenced in `/etc/fstab` for mounting
- Used for disk operations and diagnostics
- `/dev/shm/` - Shared memory (tmpfs)

---

## Common Gotchas

### Separate Filesystems
On many systems, these are separate mountpoints:
- `/boot` - Kernel and bootloader (often small, can fill up)
- `/var` - Variable data (grows over time)
- `/home` - User files (may be NFS)
- `/tmp` - Temporary (may be tmpfs)

**Use `df -h` to see what is separate.**

When "disk full" errors occur, check which filesystem is actually full.

### Hidden Space Usage
Large files in deleted state still consume space if a process has them open.

Check with: `lsof | grep deleted`

### Distribution Differences
- Ubuntu/Debian: Config in `/etc/default/` and `/etc/systemd/`
- RHEL/CentOS: Config in `/etc/sysconfig/`
- systemd: Unit files in `/etc/systemd/system/` (overrides) and `/lib/systemd/system/` (package-provided)

---

## Quick Reference

| Path | Purpose | Grows? | Safe to Clean? |
|------|---------|--------|----------------|
| `/etc` | Configuration | No | No |
| `/var/log` | System logs | Yes | With rotation |
| `/var/cache` | App caches | Yes | Usually |
| `/tmp` | Temp files | Yes | Yes |
| `/home` | User files | Yes | No |
| `/opt` | Third-party apps | Depends | No |
| `/usr` | System binaries | No | No |

---

## Further Reading

- `man hier` - Filesystem hierarchy manual page
- FHS 3.0 specification: https://refspecs.linuxfoundation.org/FHS_3.0/
- `ncdu` - NCurses Disk Usage (great for finding space hogs)
