# Permissions and Ownership

Understanding Linux access control.

---

## Why This Matters

Permissions control:
- Who can read, modify, or execute files
- What processes can do when running as a user
- Security boundaries between users and services

Most permission-related problems come from misunderstanding ownership or the setuid/setgid bits.

---

## Basic Permission Model

Every file has:
1. **Owner** (user)
2. **Group** (group)
3. **Permission bits** (rwx for owner, group, others)

View with: `ls -l`

```
-rw-r--r-- 1 alice developers 1234 Jan 15 10:30 file.txt
│││││││││  │ │     │          │    │
│││││││││  │ owner group      size date/time
│││││││││  └─ number of hard links
││││││││└─ other permissions (r--)
│││││││└── group permissions (r--)
││││││└─── owner permissions (rw-)
│││││└──── special bits
││││└───── file type (- = regular file)
```

---

## Permission Bits

| Symbol | Meaning | Octal | Files | Directories |
|--------|---------|-------|-------|-------------|
| `r` | Read | 4 | View contents | List files |
| `w` | Write | 2 | Modify contents | Create/delete files |
| `x` | Execute | 1 | Run as program | Enter directory |

### File Type Indicators
- `-` Regular file
- `d` Directory
- `l` Symbolic link
- `c` Character device
- `b` Block device
- `s` Socket
- `p` Named pipe (FIFO)

---

## Common Permission Patterns

| Octal | Symbolic | Typical Use |
|-------|----------|-------------|
| `644` | `rw-r--r--` | Regular files (user can edit, others read) |
| `755` | `rwxr-xr-x` | Executables, directories (world-accessible) |
| `700` | `rwx------` | Private directories (only owner access) |
| `600` | `rw-------` | Private files (SSH keys, credentials) |
| `775` | `rwxrwxr-x` | Shared group directories |
| `664` | `rw-rw-r--` | Group-editable files |

---

## Special Bits

### Setuid (4000)
When set on executable:
- Process runs with owner's privileges, not caller's
- Example: `/usr/bin/passwd` (runs as root so users can change passwords)

```bash
-rwsr-xr-x 1 root root 63960 passwd
   ^
   setuid bit (s replaces x)
```

**Security implications:**
- Any setuid root binary is a potential privilege escalation vector
- Audit regularly: `find / -perm -4000 -type f 2>/dev/null`

### Setgid (2000)
On executable:
- Process runs with file's group, not caller's

On directory:
- New files inherit directory's group (not creator's primary group)
- Useful for shared directories

```bash
drwxrwsr-x 2 alice developers 4096 shared/
      ^
      setgid bit (s replaces x)
```

### Sticky Bit (1000)
On directory:
- Only file owner can delete their own files
- Example: `/tmp`

```bash
drwxrwxrwt 10 root root 4096 tmp/
         ^
         sticky bit (t replaces x)
```

**Why it matters:**
Without sticky bit on `/tmp`, any user could delete any other user's temp files.

---

## Ownership

Every file has an owner (user) and group.

**Change owner:**
```bash
chown alice file.txt
chown alice:developers file.txt
chown -R alice:developers directory/
```

**Change group only:**
```bash
chgrp developers file.txt
```

**Who can change ownership?**
- Only root can change file owner
- File owner can change group (if they're a member of new group)

---

## Common Scenarios

### Shared Project Directory
Users `alice` and `bob` both need read/write access.

```bash
mkdir /opt/project
chgrp developers /opt/project
chmod 2775 /opt/project  # setgid + group write
```

Now both users can create and edit files, all inheriting the `developers` group.

### Fixing Web Server Permissions
Web server runs as `www-data`. Files owned by `alice`.

```bash
chown -R alice:www-data /var/www/site/
chmod -R 750 /var/www/site/
find /var/www/site/ -type f -exec chmod 640 {} \;
```

- Alice can edit files
- Web server can read but not modify
- Others have no access

### SSH Key Permissions
Too-permissive SSH keys are rejected:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/authorized_keys
```

---

## Default Permissions and umask

New files don't have 777 permissions because of **umask**.

Default umask: `0022`
- Files created as: `666 - 022 = 644`
- Directories created as: `777 - 022 = 755`

**View umask:**
```bash
umask         # Shows octal: 0022
umask -S      # Shows symbolic: u=rwx,g=rx,o=rx
```

**Change umask:**
```bash
umask 0077    # New files: 600, new directories: 700
```

Set permanently in `~/.bashrc` or `/etc/profile`.

---

## Access Control Lists (ACLs)

For more granular control than user/group/other.

**View ACLs:**
```bash
getfacl file.txt
```

**Set ACL:**
```bash
setfacl -m u:bob:rw file.txt    # Give bob read/write
setfacl -m g:admins:rx dir/      # Give admins group rx
setfacl -x u:bob file.txt        # Remove bob's ACL
setfacl -b file.txt              # Remove all ACLs
```

**Identify files with ACLs:**
Look for `+` in `ls -l`:
```
-rw-rw-r--+ 1 alice developers 1234 file.txt
          ^
          has ACL
```

---

## Troubleshooting Permission Issues

### "Permission denied" when reading file
1. Check file permissions: `ls -l file`
2. Check directory permissions: Need `x` on all parent directories
3. Check if SELinux/AppArmor is involved: `getenforce` or `aa-status`

### "Permission denied" when writing file
1. Check write permission on file
2. Check write + execute on parent directory
3. Check filesystem is not read-only: `mount | grep <filesystem>`

### Command works as root but not as user
1. Likely permission issue or missing group membership
2. Check groups: `groups username`
3. Check setuid/setgid: `ls -l $(which command)`

### Cannot delete file in directory you own
- Check parent directory permissions (need `w` and `x`)
- Check if directory has sticky bit and you're not the file owner

---

## Security Best Practices

1. **Principle of least privilege**
   - Grant minimum permissions necessary
   - Avoid world-writable files: `find / -perm -002 -type f 2>/dev/null`

2. **Protect sensitive files**
   - SSH keys: `600` or `400`
   - Config files with passwords: `600`
   - `/etc/shadow`: Should be `640` or `000`

3. **Audit setuid/setgid binaries**
   ```bash
   find / -type f \( -perm -4000 -o -perm -2000 \) -ls 2>/dev/null
   ```

4. **Group membership**
   - Add users to groups rather than using world permissions
   - Avoid adding users to `sudo` group unnecessarily

5. **Service account permissions**
   - Service accounts should not have shell: `/usr/sbin/nologin`
   - Home directories should be restrictive: `700`

---

## Quick Reference

**Check permissions:**
```bash
ls -l file                    # Long listing
stat file                     # Detailed info
namei -l /path/to/file        # Show permissions of entire path
```

**Set permissions:**
```bash
chmod 644 file                # Octal notation
chmod u+x file                # Add execute for user
chmod g-w file                # Remove write for group
chmod o=r file                # Set other to read-only
chmod -R 755 directory/       # Recursive
```

**Find permission problems:**
```bash
# World-writable files (security risk)
find / -perm -002 -type f 2>/dev/null

# Setuid/setgid files
find / -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null

# Files with no owner (orphaned)
find / -nouser -o -nogroup 2>/dev/null
```

---

## Further Reading

- `man chmod` - Change file mode bits
- `man chown` - Change file owner and group
- `man umask` - Set file mode creation mask
- `man acl` - Access Control Lists
