# Bash Cheat Sheet

Practical reference for everyday Bash and Linux command-line usage.
Includes short explanations to reduce mistakes under pressure.

---

## Navigation

- Print current working directory  
  `pwd`

- Change directory  
  `cd <dir>`

- Home directory  
  `cd`

- Root directory  
  `cd /`

- Previous directory  
  `cd -`  
  Quickly toggle between last two directories.

- Parent directory  
  `cd ..`

- Two levels up  
  `cd ../..`

- Absolute path example  
  `cd /home/user/directory`  
  Absolute paths always start with `/` and do not depend on your current location.

---

## Listing & Files

- List directory contents  
  `ls`

- Show hidden files  
  `ls -a`  
  Files starting with `.` are hidden by default.

- Long listing  
  `ls -l`  
  Shows permissions, owner, group, size, and timestamps.

- Human-readable sizes  
  `ls -lh`

- Move or rename  
  `mv <source> <target>`

- Copy file  
  `cp <source> <target>`

- Copy directory recursively  
  `cp -r <source> <target>`

- Remove file  
  `rm <file>`

- Remove directory and contents  
  `rm -r <dir>`  
  ⚠ Destructive. There is no undo.

- Secure overwrite (best-effort)  
  `shred <file>`  
  Not reliable on SSDs or journaling filesystems.

- Create empty file  
  `touch <file>`

- Create directory  
  `mkdir <dir>`

- Create directory tree  
  `mkdir -p a/b/c`

- Show directory tree  
  `tree`

---

## Viewing Files

- Print file to terminal  
  `cat <file>`  
  Avoid for large files.

- Paged viewer (recommended)  
  `less <file>`

  Inside `less`:
  - `/text` search
  - `n` / `N` next / previous
  - `g` / `G` top / bottom
  - `q` quit

- First / last lines  
  `head <file>`  
  `tail <file>`

- Follow log output  
  `tail -f <file>`

---

## Permissions & Ownership

### Permission Basics

Permissions are shown like:

```
-rwxr-xr--
```

Breakdown:
- First character: type (`-` file, `d` directory, `l` symlink)
- Then three groups of three:
  - **User (owner)**
  - **Group**
  - **Others**

Each group:
- `r` = read
- `w` = write
- `x` = execute

---

### Numeric Permissions

Each permission has a value:
- `r = 4`
- `w = 2`
- `x = 1`

Add them together:

| Permissions | Value |
|------------|-------|
| rwx        | 7     |
| rw-        | 6     |
| r-x        | 5     |
| r--        | 4     |

Examples:
- `755` = rwx r-x r-x
- `644` = rw- r-- r--

Usage:
```
chmod 755 script.sh
chmod 644 file.txt
```

Numeric mode is best when setting permissions from scratch.

---

### Symbolic Permissions (letters)

Modify permissions relative to current state.

Targets:
- `u` user (owner)
- `g` group
- `o` others
- `a` all

Operators:
- `+` add
- `-` remove
- `=` set exactly

Examples:
```
chmod u+x script.sh
chmod g-w file.txt
chmod o=r file.txt
chmod a+r file.txt
```

Recursive:
```
chmod -R u+rx directory/
```

Symbolic mode is safer for small changes.

---

### Ownership

- Change owner  
  `chown user file`

- Change owner and group  
  `chown user:group file`

- Recursive ownership  
  `chown -R user:group dir`

---

## umask (Default Permissions)

`umask` controls which permissions are **removed by default** when new files
or directories are created.

- Show current umask  
  `umask`

- Show symbolic umask  
  `umask -S`

Common defaults:
- `022` → files: `644`, directories: `755`
- `077` → files: `600`, directories: `700` (private)

Example:
```
umask 077
```

`umask` affects only new files, not existing ones.

---

## ACL (Advanced Permissions)

- View ACLs  
  `getfacl file`

- Give user read/write  
  `setfacl -m u:alice:rw file`

- Remove all ACLs  
  `setfacl -b file`

---

## Variables & Environment

- Set variable  
  `VAR=value`

- Use variable  
  `echo "$VAR"`

- Export variable  
  `export VAR=value`

- Remove variable  
  `unset VAR`

Important variables:
- `$USER` current user
- `$HOME` home directory
- `$PATH` command search path
- `$SHELL` current shell
- `$TERM` terminal type
- `$EUID` numeric user ID

---

## Quoting & Expansion

- Single quotes (literal)  
  `'Hello $USER'` → `$USER`

- Double quotes (expand variables)  
  `"Hello $USER"` → `Hello simon`

- Arithmetic expansion  
  `$((1 + 2))`

- Command substitution  
  `$(hostname)`

---

## Redirection

- Overwrite file  
  `command > file`

- Append to file  
  `command >> file`

- Redirect stderr  
  `command 2> error.log`

- Redirect stdout and stderr  
  `command > all.log 2>&1`

- Discard output  
  `command > /dev/null`

File descriptors:
- `0` stdin
- `1` stdout
- `2` stderr

---

## Pipes

Send output of one command into another:

```
command1 | command2
```

Example:
```
ps aux | grep root
```

---

## Jobs & Processes

- Run in background  
  `command &`

- List jobs  
  `jobs`

- Bring job to foreground  
  `fg`

- Kill process  
  `kill <pid>`

Signals:
- `15` SIGTERM – polite request
- `9` SIGKILL – force kill (last resort)

---

## Exit Status

- Show last exit code  
  `echo $?`

Common values:
- `0` success
- `1` general error
- `2` incorrect usage

---

## Control Operators

- AND – run only if success  
  `cmd1 && cmd2`

- OR – run if failure  
  `cmd1 || cmd2`

- Always run  
  `cmd1 ; cmd2`

---

## Scripts

- Shebang  
  `#!/usr/bin/env bash`

- Safer defaults  
  `set -euo pipefail`

- Run script  
  `bash script.sh`  
  `./script.sh`

- Make executable  
  `chmod u+x script.sh`

- Shell startup file  
  `~/.bashrc`

---

## Why This Fails (Troubleshooting)

Common reasons commands do not behave as expected:

- **Permission denied**
  - Missing execute bit: `chmod +x`
  - Wrong owner/group: `chown`
  - Blocked by umask or ACL

- **Command not found**
  - Binary not installed
  - `$PATH` missing directory
  - Script not executable or missing shebang

- **Script works manually but not in cron**
  - Cron has minimal `$PATH`
  - Use absolute paths
  - Explicitly set environment variables

- **rm / cp / mv behaves unexpectedly**
  - Wildcards expanded by shell
  - Spaces in filenames (quote paths!)
  - Relative path confusion

- **Pipes produce no output**
  - Upstream command failed
  - `grep` returned no matches
  - Use `set -o pipefail` in scripts

- **Changes don’t persist**
  - Editing wrong file
  - Change overridden by config management
  - `umask` or permissions reset on login

---

## Sysadmin Tips

- Prefer read-only commands first (`ls`, `stat`, `df`)
- Use absolute paths in scripts
- Quote variables unless you want word splitting
- Test dangerous commands with `echo` first
- Avoid wildcards with `sudo`
- Use `set -euo pipefail` in scripts
- Log before you delete
- When unsure, stop and inspect

---

## Danger Zone (Read Before Using)

Commands that can cause **irreversible damage**.

- Remove recursively  
  `rm -rf /path`

- Remove as root  
  `sudo rm -rf`

- Overwrite disks  
  `dd if=... of=...`

- Recursive ownership  
  `chown -R`

- Recursive permissions  
  `chmod -R`

Rules:
- Always double-check paths
- Use `ls` before `rm`
- Prefer absolute paths
- Avoid `*` with `sudo`
- If unsure: stop

---
