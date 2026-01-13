# Bash Cheat Sheet

Practical reference for everyday Bash and Linux command-line usage.
Includes short explanations to reduce mistakes under pressure.

---

## Table of Contents

- [Navigation](#navigation)
- [Listing & Files](#listing--files)
- [Viewing Files](#viewing-files)
- [Searching](#searching)
- [Text Processing](#text-processing)
- [Permissions & Ownership](#permissions--ownership)
- [Variables & Environment](#variables--environment)
- [Quoting & Expansion](#quoting--expansion)
- [Redirection](#redirection)
- [Pipes](#pipes)
- [Jobs & Processes](#jobs--processes)
- [Exit Status](#exit-status)
- [Control Operators](#control-operators)
- [Conditionals & Loops](#conditionals--loops)
- [Functions](#functions)
- [Scripts](#scripts)
- [System Information](#system-information)
- [Networking](#networking)
- [Archives & Compression](#archives--compression)
- [Disk & Storage](#disk--storage)
- [Users & Groups](#users--groups)
- [Package Management](#package-management)
- [History & Command Line](#history--command-line)
- [Troubleshooting](#troubleshooting)
- [Danger Zone](#danger-zone)

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

- Find location of command  
  `which <command>`

- Show all locations of command  
  `whereis <command>`

---

## Searching

### Find Command

- Find by name  
  `find /path -name "pattern"`

- Case-insensitive name search  
  `find /path -iname "*.log"`

- Find files modified in last N days  
  `find /path -mtime -N`

- Find files larger than size  
  `find /path -size +100M`

- Find and execute command  
  `find /path -name "*.txt" -exec cat {} \;`

- Find empty files/directories  
  `find /path -empty`

- Find by type  
  `find /path -type f`  (f=file, d=directory, l=symlink)

### Grep (Text Search)

- Search in file  
  `grep "pattern" file`

- Recursive search  
  `grep -r "pattern" /path`

- Case-insensitive  
  `grep -i "pattern" file`

- Show line numbers  
  `grep -n "pattern" file`

- Invert match (lines NOT matching)  
  `grep -v "pattern" file`

- Count matches  
  `grep -c "pattern" file`

- Show context (lines before/after)  
  `grep -C 3 "pattern" file`

- Multiple patterns  
  `grep -E "pattern1|pattern2" file`

- Search only file names  
  `grep -l "pattern" *.txt`

### Locate (Fast File Search)

- Find by name (fast)  
  `locate filename`

- Update locate database  
  `sudo updatedb`

---

## Text Processing

### Cut, Sort, Uniq

- Extract columns  
  `cut -d':' -f1,3 /etc/passwd`

- Sort lines  
  `sort file.txt`

- Sort numerically  
  `sort -n file.txt`

- Reverse sort  
  `sort -r file.txt`

- Remove duplicates  
  `sort file.txt | uniq`

- Count duplicates  
  `sort file.txt | uniq -c`

### Sed (Stream Editor)

- Replace first occurrence  
  `sed 's/old/new/' file`

- Replace all occurrences  
  `sed 's/old/new/g' file`

- Edit file in-place  
  `sed -i 's/old/new/g' file`

- Delete lines matching pattern  
  `sed '/pattern/d' file`

- Print specific line  
  `sed -n '10p' file`

### Awk (Text Processing)

- Print column  
  `awk '{print $1}' file`

- Print with custom delimiter  
  `awk -F':' '{print $1}' /etc/passwd`

- Sum column  
  `awk '{sum += $1} END {print sum}' file`

- Conditional processing  
  `awk '$3 > 100 {print $1}' file`

### Other Text Tools

- Word/line/byte count  
  `wc file`  
  `wc -l file` (lines only)

- Show differences  
  `diff file1 file2`

- Translate characters  
  `tr 'a-z' 'A-Z' < file`

- Reverse lines  
  `tac file`

---

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

- Follow with retry (useful if file recreated)  
  `tail -F <file>`

- View multiple files  
  `cat file1 file2`

- View with line numbers  
  `cat -n file`

- Compare files side by side  
  `diff -y file1 file2`

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

- Brace expansion  
  `echo {1..5}` → `1 2 3 4 5`  
  `echo {a,b,c}.txt` → `a.txt b.txt c.txt`

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

- Discard errors  
  `command 2> /dev/null`

- Discard everything  
  `command &> /dev/null`

- Redirect to file and stdout  
  `command | tee file.txt`

- Here document  
  ```bash
  cat << EOF > file.txt
  Line 1
  Line 2
  EOF
  ```

- Here string  
  `grep "pattern" <<< "text to search"`

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

Examples:
```bash
ps aux | grep root
cat file.txt | sort | uniq
ls -l | awk '{print $9}'
journalctl -f | grep error
```

Named pipes (FIFO):
```bash
mkfifo mypipe
echo "data" > mypipe &
cat < mypipe
```

---

## Jobs & Processes

### Process Management

- Run in background  
  `command &`

- List jobs  
  `jobs`

- Bring job to foreground  
  `fg`

- Send to background  
  `bg`

- Disown job (detach from shell)  
  `disown %1`

- List all processes  
  `ps aux`

- Process tree  
  `pstree`

- Interactive process viewer  
  `top`  
  `htop` (if installed, more user-friendly)

- Kill process by PID  
  `kill <pid>`

- Kill process by name  
  `killall <name>`  
  `pkill <pattern>`

### Signals

- `15` SIGTERM – polite request (default)
- `9` SIGKILL – force kill (last resort, can't be caught)
- `1` SIGHUP – hangup, reload config
- `2` SIGINT – interrupt (Ctrl+C)

Send specific signal:
```bash
kill -9 <pid>
kill -SIGTERM <pid>
```

### Process Priority

- Run with low priority  
  `nice -n 10 command`

- Change priority of running process  
  `renice -n 5 -p <pid>`

### Nohup (No Hangup)

Run command immune to hangups:
```bash
nohup command &
```

Output goes to `nohup.out` by default.

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

- Chain commands (run regardless)  
  `cmd1 ; cmd2 ; cmd3`

Examples:
```bash
mkdir mydir && cd mydir
test -f file.txt || echo "File not found"
make || exit 1
cd /tmp && rm -f tempfile ; cd -
```

---

## Conditionals & Loops

### If Statements

```bash
if [ condition ]; then
  echo "True"
elif [ other_condition ]; then
  echo "Other condition"
else
  echo "False"
fi
```

### Test Operators

File tests:
- `-f file` file exists and is regular file
- `-d dir` directory exists
- `-e path` path exists
- `-r file` file is readable
- `-w file` file is writable
- `-x file` file is executable
- `-s file` file is not empty
- `-L file` file is symbolic link

String tests:
- `-z "$str"` string is empty
- `-n "$str"` string is not empty
- `"$str1" = "$str2"` strings equal
- `"$str1" != "$str2"` strings not equal

Numeric tests:
- `$a -eq $b` equal
- `$a -ne $b` not equal
- `$a -lt $b` less than
- `$a -le $b` less than or equal
- `$a -gt $b` greater than
- `$a -ge $b` greater than or equal

### Modern Test Syntax

Using `[[ ]]` (preferred in bash):
```bash
if [[ -f "file.txt" && -r "file.txt" ]]; then
  echo "File exists and is readable"
fi

if [[ "$var" =~ ^[0-9]+$ ]]; then
  echo "Variable contains only digits"
fi
```

### For Loops

```bash
# Iterate over list
for item in one two three; do
  echo "$item"
done

# C-style loop
for ((i=1; i<=10; i++)); do
  echo "$i"
done

# Iterate over files
for file in *.txt; do
  echo "Processing $file"
done

# Iterate over command output
for user in $(cut -d: -f1 /etc/passwd); do
  echo "User: $user"
done
```

### While Loops

```bash
# Basic while loop
count=1
while [ $count -le 5 ]; do
  echo "Count: $count"
  ((count++))
done

# Read file line by line
while IFS= read -r line; do
  echo "Line: $line"
done < file.txt

# Infinite loop
while true; do
  echo "Running..."
  sleep 1
done
```

### Case Statements

```bash
case "$variable" in
  pattern1)
    echo "Match 1"
    ;;
  pattern2|pattern3)
    echo "Match 2 or 3"
    ;;
  *)
    echo "Default"
    ;;
esac
```

---

## Functions

### Defining Functions

```bash
# Method 1
function myfunction {
  echo "Hello from function"
}

# Method 2 (POSIX-compatible)
myfunction() {
  echo "Hello from function"
}
```

### Function Parameters

```bash
greet() {
  local name="$1"
  local greeting="${2:-Hello}"
  echo "$greeting, $name!"
}

greet "Alice"           # Hello, Alice!
greet "Bob" "Welcome"   # Welcome, Bob!
```

Function variables:
- `$1, $2, ...` positional parameters
- `$@` all parameters as separate words
- `$*` all parameters as single word
- `$#` number of parameters
- `$?` return value of last command

### Return Values

```bash
check_file() {
  if [[ -f "$1" ]]; then
    return 0  # success
  else
    return 1  # failure
  fi
}

if check_file "myfile.txt"; then
  echo "File exists"
fi
```

---

## Scripts

### Script Basics

- Shebang (always use this as first line)  
  `#!/usr/bin/env bash`

- Safer defaults (highly recommended)  
  `set -euo pipefail`
  - `-e` exit on error
  - `-u` exit on undefined variable
  - `-o pipefail` exit on pipe failure

- Enable debug mode  
  `set -x`

- Make executable  
  `chmod u+x script.sh`

- Run script  
  `bash script.sh`  
  `./script.sh`

### Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Script description
# Usage: ./script.sh [options]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

main() {
  echo "Script started"
  # Your code here
}

main "$@"
```

### Command Line Arguments

```bash
while getopts "hvf:" opt; do
  case "$opt" in
    h) show_help; exit 0 ;;
    v) verbose=true ;;
    f) filename="$OPTARG" ;;
    *) echo "Invalid option"; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
```

### Error Handling

```bash
# Exit with error message
die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Usage
[[ -f "$file" ]] || die "File not found: $file"

# Trap errors
cleanup() {
  echo "Cleaning up..."
  rm -f /tmp/tempfile
}
trap cleanup EXIT
```

### Shell Startup Files

- Login shell: `/etc/profile` → `~/.bash_profile` or `~/.bash_login` or `~/.profile`
- Interactive non-login: `~/.bashrc`
- Non-interactive: `$BASH_ENV`

Common practice:
- Put functions and aliases in `~/.bashrc`
- Source `~/.bashrc` from `~/.bash_profile`

---

## System Information

### System Details

- System information  
  `uname -a`

- OS release information  
  `cat /etc/os-release`

- Kernel version  
  `uname -r`

- CPU information  
  `lscpu`  
  `cat /proc/cpuinfo`

- Memory information  
  `free -h`  
  `cat /proc/meminfo`

- Uptime  
  `uptime`

- Current date/time  
  `date`

- Hardware information  
  `lshw` (requires sudo)

### Who's Logged In

- Current user  
  `whoami`

- User ID  
  `id`

- All logged-in users  
  `who`

- What users are doing  
  `w`

- Login history  
  `last`

- Failed login attempts  
  `lastb` (requires sudo)

---

## Networking

### Network Information

- Show IP addresses  
  `ip addr show`  
  `ip a`

- Show routing table  
  `ip route show`

- Network interfaces (legacy)  
  `ifconfig`

- Show all connections  
  `ss -tulpn`  
  `netstat -tulpn` (legacy)

- Check if port is open  
  `ss -tuln | grep :80`

### DNS & Connectivity

- DNS lookup  
  `nslookup domain.com`  
  `dig domain.com`  
  `host domain.com`

- Test connectivity  
  `ping -c 4 google.com`

- Trace route  
  `traceroute domain.com`  
  `tracepath domain.com`

- Check if port is accessible  
  `nc -zv host port`  
  `telnet host port`

### Download Files

- Download file  
  `wget URL`  
  `curl -O URL`

- Download to specific file  
  `curl -o filename URL`

- Follow redirects  
  `curl -L URL`

- Download with progress bar  
  `wget --progress=bar URL`

### Network Transfer

- Secure copy to remote  
  `scp file.txt user@host:/path`

- Secure copy from remote  
  `scp user@host:/path/file.txt .`

- Copy directory  
  `scp -r dir/ user@host:/path`

- Rsync (efficient sync)  
  `rsync -avz source/ user@host:/dest/`

### SSH

- Connect to remote host  
  `ssh user@host`

- Use specific key  
  `ssh -i keyfile user@host`

- Port forwarding (local)  
  `ssh -L 8080:localhost:80 user@host`

- Execute remote command  
  `ssh user@host 'command'`

- Copy SSH key to remote  
  `ssh-copy-id user@host`

---

## Archives & Compression

### Tar

- Create tar archive  
  `tar -cvf archive.tar files/`

- Create compressed tar.gz  
  `tar -czvf archive.tar.gz files/`

- Create compressed tar.bz2  
  `tar -cjvf archive.tar.bz2 files/`

- Extract tar archive  
  `tar -xvf archive.tar`

- Extract to specific directory  
  `tar -xvf archive.tar -C /path`

- List contents  
  `tar -tvf archive.tar`

### Compression

- Gzip  
  `gzip file` (creates file.gz, removes original)  
  `gzip -k file` (keep original)  
  `gunzip file.gz`

- Bzip2  
  `bzip2 file`  
  `bunzip2 file.bz2`

- Zip  
  `zip archive.zip file1 file2`  
  `zip -r archive.zip directory/`  
  `unzip archive.zip`

---

## Disk & Storage

### Disk Usage

- Show disk space  
  `df -h`

- Show inode usage  
  `df -i`

- Directory size  
  `du -sh /path`

- Sort by size  
  `du -h /path | sort -h`

- Top largest directories  
  `du -h /path | sort -rh | head -10`

### Disk Operations

- List block devices  
  `lsblk`

- Partition information  
  `fdisk -l` (requires sudo)  
  `parted -l` (requires sudo)

- Mount filesystem  
  `mount /dev/sda1 /mnt`

- Unmount  
  `umount /mnt`

- Show mounted filesystems  
  `mount | column -t`

- Check filesystem  
  `fsck /dev/sda1` (requires sudo, unmount first)

---

## Users & Groups

### User Management

- Add user  
  `sudo useradd username`  
  `sudo adduser username` (interactive)

- Set password  
  `sudo passwd username`

- Delete user  
  `sudo userdel username`

- Delete user and home  
  `sudo userdel -r username`

- Modify user  
  `sudo usermod -aG groupname username`

- Switch user  
  `su - username`

- Run as root  
  `sudo command`

- Open root shell  
  `sudo -i`

### Group Management

- List groups  
  `groups`  
  `groups username`

- Create group  
  `sudo groupadd groupname`

- Delete group  
  `sudo groupdel groupname`

- Add user to group  
  `sudo usermod -aG groupname username`

### User Information

- User details  
  `id username`

- All users  
  `cat /etc/passwd`

- All groups  
  `cat /etc/group`

---

## Package Management

### APT (Debian/Ubuntu)

- Update package list  
  `sudo apt update`

- Upgrade packages  
  `sudo apt upgrade`

- Install package  
  `sudo apt install package`

- Remove package  
  `sudo apt remove package`

- Remove with config  
  `sudo apt purge package`

- Search package  
  `apt search keyword`

- Show package info  
  `apt show package`

- Clean cache  
  `sudo apt clean`

- Autoremove unused  
  `sudo apt autoremove`

### YUM/DNF (RHEL/Fedora)

- Update packages  
  `sudo dnf update`

- Install package  
  `sudo dnf install package`

- Remove package  
  `sudo dnf remove package`

- Search package  
  `dnf search keyword`

### Snap

- Install snap  
  `sudo snap install package`

- List installed  
  `snap list`

- Update snaps  
  `sudo snap refresh`

---

## History & Command Line

### History

- Show command history  
  `history`

- Run previous command  
  `!!`

- Run command N from history  
  `!N`

- Run last command starting with text  
  `!text`

- Search history  
  `Ctrl+R`

- Clear history  
  `history -c`

### Command Line Shortcuts

Navigation:
- `Ctrl+A` beginning of line
- `Ctrl+E` end of line
- `Ctrl+B` back one character
- `Ctrl+F` forward one character
- `Alt+B` back one word
- `Alt+F` forward one word

Editing:
- `Ctrl+U` delete to beginning
- `Ctrl+K` delete to end
- `Ctrl+W` delete word before cursor
- `Alt+D` delete word after cursor
- `Ctrl+Y` paste deleted text

Control:
- `Ctrl+C` interrupt/cancel
- `Ctrl+D` exit shell or EOF
- `Ctrl+Z` suspend process
- `Ctrl+L` clear screen

---

## Troubleshooting

### Why This Fails

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

### Debugging Tips

- Check syntax without running  
  `bash -n script.sh`

- Run with debug output  
  `bash -x script.sh`

- Check exit code  
  `echo $?`

- Show line causing error  
  Add `trap 'echo "Error at line $LINENO"' ERR` to script

- Verbose output  
  Add `set -v` to script

- Check if variable is set  
  `[[ -v VARNAME ]] && echo "Set" || echo "Not set"`

- Check if command exists  
  `command -v commandname > /dev/null`

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

## Quick Reference

### Most Common Commands

```bash
# Navigation
cd <dir>              # Change directory
pwd                   # Print working directory
ls -lah               # List files with details

# File operations
cp <src> <dst>        # Copy file
mv <src> <dst>        # Move/rename
rm <file>             # Delete file
mkdir <dir>           # Create directory

# Viewing
cat <file>            # Display file
less <file>           # Paged viewer
head <file>           # First 10 lines
tail -f <file>        # Follow log file

# Searching
grep "text" <file>    # Search in file
find . -name "*.txt"  # Find files
locate <name>         # Fast file search

# Permissions
chmod 755 <file>      # Set permissions
chown user:group      # Change owner

# Processes
ps aux                # List processes
top                   # Process monitor
kill <pid>            # Kill process
killall <name>        # Kill by name

# System info
df -h                 # Disk space
du -sh <dir>          # Directory size
free -h               # Memory usage
uname -a              # System info

# Network
ping <host>           # Test connectivity
curl <url>            # Download/request
ssh user@host         # Remote login
scp file user@host:   # Secure copy

# Archives
tar -czvf arc.tar.gz dir/   # Create compressed archive
tar -xzvf arc.tar.gz        # Extract archive
unzip file.zip              # Extract zip

# Package management (Ubuntu/Debian)
sudo apt update             # Update package list
sudo apt install <pkg>      # Install package
sudo apt remove <pkg>       # Remove package
```

### Command Chaining

```bash
cmd1 && cmd2          # Run cmd2 only if cmd1 succeeds
cmd1 || cmd2          # Run cmd2 only if cmd1 fails
cmd1 ; cmd2           # Run both regardless
cmd1 | cmd2           # Pipe output of cmd1 to cmd2
```

### Keyboard Shortcuts

```bash
Ctrl+C                # Cancel current command
Ctrl+D                # Exit shell / EOF
Ctrl+L                # Clear screen
Ctrl+R                # Search history
Ctrl+A                # Beginning of line
Ctrl+E                # End of line
!!                    # Repeat last command
```

---
