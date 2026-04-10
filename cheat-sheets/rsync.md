# rsync Cheat Sheet

Practical reference for local and remote file synchronisation with `rsync`.
Covers flags, filters, SSH transport, common patterns, and troubleshooting.

---

## Table of Contents

- [Key Concepts](#key-concepts)
- [Essential Flags](#essential-flags)
- [Basic Syntax](#basic-syntax)
- [Local Transfers](#local-transfers)
- [Remote Transfers (SSH)](#remote-transfers-ssh)
- [Filters & Exclusions](#filters--exclusions)
- [Dry Runs & Verification](#dry-runs--verification)
- [Bandwidth & Performance](#bandwidth--performance)
- [Checksum & Integrity](#checksum--integrity)
- [Backup Patterns](#backup-patterns)
- [Daemon Mode](#daemon-mode)
- [Useful One-Liners](#useful-one-liners)
- [Troubleshooting](#troubleshooting)

---

## Key Concepts

| Concept | Explanation |
|---------|-------------|
| Trailing slash | `src/` means "contents of src"; `src` means "src itself" |
| Delta transfer | Only changed blocks are sent, not entire files |
| Archive mode | `-a` equals `-rlptgoD` — preserves almost everything |
| Checksum mode | `-c` compares checksums instead of size+mtime (slower, safer) |
| Itemised output | `-i` shows exactly what changed per file |

### Trailing Slash Rules (important)

```bash
rsync -a src/  dest/   # copies contents of src INTO dest
rsync -a src   dest/   # copies src directory itself → dest/src/
```

---

## Essential Flags

| Flag | Long form | Effect |
|------|-----------|--------|
| `-a` | `--archive` | Recursive + preserve symlinks, perms, times, owner, group |
| `-v` | `--verbose` | Show files being transferred |
| `-z` | `--compress` | Compress data during transfer |
| `-P` | `--progress --partial` | Show progress; resume partial transfers |
| `-n` | `--dry-run` | Simulate; make no changes |
| `-c` | `--checksum` | Use checksum instead of size+mtime for comparison |
| `-i` | `--itemize-changes` | Show itemised change log |
| `-u` | `--update` | Skip files newer on destination |
| `-H` | `--hard-links` | Preserve hard links |
| `-S` | `--sparse` | Handle sparse files efficiently |
| `-x` | `--one-file-system` | Do not cross filesystem boundaries |
| `--delete` | | Delete files on dest that are absent from source |
| `--delete-dry-run` | | Show what `--delete` would remove |
| `--backup` | | Rename (not delete) displaced destination files |
| `--backup-dir` | | Directory to store displaced files |
| `-e` | `--rsh=CMD` | Specify remote shell (usually SSH) |
| `-q` | `--quiet` | Suppress non-error output (good for cron) |
| `--stats` | | Print transfer statistics summary |
| `--progress` | | Per-file progress indicator |
| `--info=progress2` | | Overall progress bar (rsync 3.1+) |

---

## Basic Syntax

```
rsync [OPTIONS] SOURCE [SOURCE...] DESTINATION
```

- `SOURCE` and `DESTINATION` can be local paths or `[user@]host:path`
- Multiple sources are supported; all go into the same destination

---

## Local Transfers

```bash
# Copy a directory tree
rsync -av /data/src/ /data/dest/

# Mirror (delete files removed from source)
rsync -av --delete /data/src/ /data/dest/

# Copy but keep dest-only files untouched (no --delete)
rsync -av /data/src/ /data/dest/

# Update only — skip files newer on dest
rsync -avu /data/src/ /data/dest/

# Do not cross filesystem boundaries (skip /proc, /sys, etc.)
rsync -avx / /mnt/backup/
```

---

## Remote Transfers (SSH)

```bash
# Push local to remote
rsync -avz /local/dir/ user@host:/remote/dir/

# Pull remote to local
rsync -avz user@host:/remote/dir/ /local/dir/

# Specify SSH port
rsync -avz -e "ssh -p 2222" /local/ user@host:/remote/

# Use a specific SSH key
rsync -avz -e "ssh -i ~/.ssh/deploy_key" /local/ user@host:/remote/

# Push and delete files removed locally
rsync -avz --delete /local/dir/ user@host:/remote/dir/

# Chain through a jump host
rsync -avz -e "ssh -J jumphost" /local/ user@host:/remote/
```

---

## Filters & Exclusions

### Exclude patterns

```bash
# Exclude a single directory
rsync -av --exclude='node_modules/' src/ dest/

# Exclude multiple patterns
rsync -av --exclude='*.log' --exclude='tmp/' src/ dest/

# Exclude from a file (one pattern per line)
rsync -av --exclude-from='exclude.txt' src/ dest/
```

### Include/exclude ordering (first match wins)

```bash
# Include only .conf files, exclude everything else
rsync -av --include='*.conf' --exclude='*' src/ dest/

# Sync an entire tree but skip cache directories
rsync -av --include='*/' --exclude='*cache*' --include='*' src/ dest/
```

### Filter rules file

```
# exclude.txt
*.tmp
*.swp
.git/
node_modules/
__pycache__/
*.pyc
.DS_Store
```

### rsync filter rule syntax

| Rule | Meaning |
|------|---------|
| `- pattern` | Exclude matching files |
| `+ pattern` | Include matching files (overrides later excludes) |
| `H pattern` | Hide (like exclude but also hides from `--list-only`) |
| `P pattern` | Protect (don't delete even with `--delete`) |
| `R pattern` | Risk (allow deletion despite protection) |

---

## Dry Runs & Verification

```bash
# Simulate without making changes
rsync -avn src/ dest/

# Itemised output — see what would change and why
rsync -avin src/ dest/

# Itemise changes on a real run
rsync -avi src/ dest/

# Show what --delete would remove
rsync -avn --delete src/ dest/

# Force checksum comparison (no mtime shortcut)
rsync -avc src/ dest/
```

### Itemised output format (`-i`)

```
YXcstpoguax  filename
│││││││││││
│││││││││││─ x — extended attributes changed
││││││││││── a — ACL changed
│││││││││─── u — update reason
││││││││──── g — group changed
│││││││───── o — owner changed
││││││────── p — permissions changed
│││││─────── t — timestamp changed
││││──────── s — size changed
│││───────── c — checksum differs (or file created for the first time)
││────────── X — file type (f=file, d=dir, L=symlink, D=device, S=special)
│─────────── Y — operation (> sent, < received, c local change, . unchanged, * deleted)
```

---

## Bandwidth & Performance

```bash
# Limit bandwidth (in KB/s)
rsync -avz --bwlimit=5000 src/ user@host:dest/

# Compress only in transit (good for WAN, bad for LAN)
rsync -av --compress src/ dest/

# Skip compression for already-compressed files
rsync -avz --skip-compress=gz,bz2,xz,zip,jpg,png,mp4 src/ dest/

# Increase throughput with more checksumming threads (rsync 3.2+)
rsync -avz --checksum-choice=xxh128 src/ dest/

# Overall progress bar
rsync -av --info=progress2 src/ dest/

# Use faster cipher for SSH transport
rsync -avz -e "ssh -c aes128-gcm@openssh.com" src/ user@host:dest/
```

---

## Checksum & Integrity

```bash
# Use checksums to decide what to transfer (ignores mtime)
rsync -avc src/ dest/

# Verify an already-synced copy (no transfer)
rsync -avnc src/ dest/

# Use xxHash (faster than MD5 for large files, rsync 3.2+)
rsync -av --checksum-choice=xxh128 src/ dest/
```

---

## Backup Patterns

### Simple full backup

```bash
rsync -avx --delete --stats \
  /home/ /mnt/backup/home/
```

### Incremental backups with hard-links (snapshot style)

```bash
TODAY=$(date +%Y-%m-%d)
YESTERDAY=$(date -d yesterday +%Y-%m-%d)

rsync -avx --delete \
  --link-dest=/mnt/backup/$YESTERDAY/ \
  /home/ /mnt/backup/$TODAY/
```
Each day's snapshot only uses disk space for changed files; unchanged files are hard-linked.

### Append-only remote backup (push to server)

```bash
rsync -avz --delete \
  -e "ssh -i ~/.ssh/backup_key" \
  /data/ backupuser@backuphost:/backups/data/
```

### Backup with displaced-file preservation

```bash
rsync -avx --delete \
  --backup --backup-dir=/mnt/backup/deleted/$(date +%Y-%m-%d) \
  /home/ /mnt/backup/current/
```

---

## Daemon Mode

### Start rsync daemon

```bash
# /etc/rsyncd.conf
[data]
    path = /srv/data
    comment = Data share
    read only = yes
    use chroot = yes
    hosts allow = 192.168.1.0/24
    auth users = backupuser
    secrets file = /etc/rsyncd.secrets

# /etc/rsyncd.secrets (mode 600)
backupuser:s3cr3t

# Start
rsync --daemon
# or via systemd
systemctl enable --now rsync
```

### Transfer via daemon

```bash
# List available modules
rsync rsync://host/

# Pull from daemon
rsync -avz rsync://backupuser@host/data /local/dest/

# With password file
rsync -avz --password-file=/etc/rsync.pass rsync://backupuser@host/data /local/
```

---

## Useful One-Liners

```bash
# Mirror a website over SSH
rsync -avz --delete user@host:/var/www/html/ /local/mirror/

# Copy only files modified in the last 7 days
find /src -mtime -7 -print0 | rsync -av --files-from=- --from0 / dest/

# Sync, then show a summary of what changed
rsync -avi --stats src/ dest/ | tee rsync-$(date +%Y%m%d).log

# Exclude hidden files and directories
rsync -av --exclude='.*' src/ dest/

# Transfer a list of specific files
rsync -av --files-from=filelist.txt / user@host:/dest/

# Preserve extended attributes and ACLs
rsync -avAX src/ dest/

# Resume interrupted large-file transfer
rsync -avP --append-verify src/bigfile.iso user@host:dest/

# Sync only files (no directories — flat copy)
rsync -av --no-r /src/*.conf /dest/
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `Permission denied (publickey)` | SSH key not accepted | Check `-e "ssh -i /path/to/key"` or `ssh-agent` |
| `rsync: [receiver] mkstemp ... failed: Permission denied` | Dest directory not writable | Check ownership/permissions on destination |
| `rsync error: some files could not be transferred (code 23)` | Partial failure (permissions, open files) | Review per-file errors; use `--ignore-errors` cautiously |
| Files always re-transferred despite no change | `mtime` drift (FAT, NFS, VM clock skew) | Use `-c` (checksum) or `--modify-window=1` |
| `rsync: connection unexpectedly closed` | SSH timeout or firewall dropping idle connection | Add `ServerAliveInterval 60` to SSH config |
| `Broken pipe` on large transfers | Network instability or SSH timeout | Use `-P` (partial) and re-run; rsync will resume |
| Destination has extra files after sync | Missing `--delete` | Add `--delete`; test with `--delete-dry-run` first |
| Hard-link snapshot not saving space | `--link-dest` path wrong or different filesystem | Verify previous snapshot exists; hard-links require same filesystem |
| `chown` errors transferring as non-root | `-a` tries to preserve owner | Use `-rlptD` (archive minus owner/group) instead of `-a` |
| Slow transfer on fast LAN | `-z` compression overhead | Remove `-z`; compression helps on WAN, hurts on LAN |
