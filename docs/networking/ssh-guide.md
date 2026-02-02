# SSH Guide

Secure Shell usage, configuration, and troubleshooting.

---

## Why This Matters

SSH is the primary way to:
- Access remote Linux systems
- Transfer files securely
- Create secure tunnels
- Execute remote commands

Understanding SSH saves time and prevents lockouts.

---

## Basic SSH Usage

### Connect to Remote Host

```bash
# Basic connection
ssh user@hostname

# Specific port
ssh -p 2222 user@hostname

# With verbose output (troubleshooting)
ssh -v user@hostname
ssh -vv user@hostname    # More verbose
ssh -vvv user@hostname   # Maximum verbosity
```

### First Connection

First time connecting to a host:

```
The authenticity of host 'example.com (203.0.113.50)' can't be established.
ECDSA key fingerprint is SHA256:xxxx...
Are you sure you want to continue connecting (yes/no)?
```

**What this means:**
- SSH doesn't recognize this host yet
- Showing the host's fingerprint
- Asking if you trust this host

**Type `yes`** to accept and add to known hosts.

**Verify fingerprint** if security is critical (compare with known-good value).

---

## SSH Keys

### Why Use Keys?

**Better than passwords:**
- More secure (2048+ bits vs ~40 bit password)
- No password transmission
- Can be password-protected (passphrase)
- Can be revoked individually
- Required for automation

### Generate Key Pair

```bash
# Generate RSA key (default)
ssh-keygen

# Generate ED25519 key (recommended, modern)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Generate RSA key with specific size
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

**Process:**
```
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/user/.ssh/id_ed25519): [Enter]
Enter passphrase (empty for no passphrase): [Type passphrase or Enter]
Enter same passphrase again: [Type passphrase again]
```

**Creates two files:**
- `~/.ssh/id_ed25519` - Private key (keep secret!)
- `~/.ssh/id_ed25519.pub` - Public key (can share)

### Copy Public Key to Remote Host

```bash
# Easy way
ssh-copy-id user@hostname

# Specific key
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@hostname

# Specific port
ssh-copy-id -p 2222 user@hostname

# Manual way
cat ~/.ssh/id_ed25519.pub | ssh user@hostname "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### Using SSH Keys

```bash
# SSH will automatically try keys in ~/.ssh/
ssh user@hostname

# Specify specific key
ssh -i ~/.ssh/id_ed25519 user@hostname
```

### SSH Agent

Avoid retyping passphrase by using ssh-agent.

```bash
# Start agent (usually already running)
eval $(ssh-agent)

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# List loaded keys
ssh-add -l

# Remove all keys from agent
ssh-add -D
```

**Add to shell startup** (~/.bashrc):
```bash
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s)
    ssh-add ~/.ssh/id_ed25519
fi
```

---

## SSH Configuration

### Client Configuration

**File:** `~/.ssh/config`

Makes SSH easier and more organized.

```
# Global defaults
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Shortcut for specific host
Host webserver
    HostName web.example.com
    User deploy
    Port 2222
    IdentityFile ~/.ssh/id_ed25519

# Using wildcards
Host *.example.com
    User admin
    ForwardAgent yes

# Jump host (bastion)
Host internal-server
    HostName 10.0.0.50
    ProxyJump bastion.example.com
```

**Now you can:**
```bash
ssh webserver           # Instead of: ssh -p 2222 deploy@web.example.com
```

### Server Configuration

**File:** `/etc/ssh/sshd_config`

**Important settings:**

```
# Port to listen on
Port 22

# Interfaces to listen on
#ListenAddress 0.0.0.0          # All interfaces
ListenAddress 192.168.1.100     # Specific interface

# Disable root login (security)
PermitRootLogin no

# Disable password authentication (keys only)
PasswordAuthentication no
ChallengeResponseAuthentication no

# Allow public key authentication
PubkeyAuthentication yes

# Disable empty passwords
PermitEmptyPasswords no

# Limit users
AllowUsers alice bob
AllowGroups sshusers

# Timeout for idle connections
ClientAliveInterval 300
ClientAliveCountMax 2

# Enable strict mode (check permissions)
StrictModes yes

# Log level
LogLevel VERBOSE
```

**Apply changes:**
```bash
# Test configuration
sshd -t

# Restart SSH service
systemctl restart sshd

# Or on older systems
service ssh restart
```

**WARNING:** Test new configuration in a separate session before closing current one. Can lock yourself out.

---

## SSH Key Permissions

**Critical permissions:**

```bash
# Your .ssh directory
chmod 700 ~/.ssh

# Private keys
chmod 600 ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_rsa

# Public keys
chmod 644 ~/.ssh/id_ed25519.pub

# Authorized keys
chmod 600 ~/.ssh/authorized_keys

# Config file
chmod 600 ~/.ssh/config
```

**Wrong permissions** will cause SSH to refuse key authentication.

**Check:**
```bash
ls -la ~/.ssh/
```

---

## File Transfers with SSH

### SCP (Secure Copy)

```bash
# Copy file to remote
scp file.txt user@host:/path/to/destination/

# Copy file from remote
scp user@host:/path/to/file.txt /local/path/

# Copy directory recursively
scp -r directory/ user@host:/path/

# Specific port
scp -P 2222 file.txt user@host:/path/

# Preserve permissions and timestamps
scp -p file.txt user@host:/path/

# Limit bandwidth (KB/s)
scp -l 1000 largefile.iso user@host:/path/
```

### SFTP (SSH File Transfer Protocol)

Interactive file transfer.

```bash
# Connect
sftp user@hostname

# Common commands:
sftp> ls                   # List remote files
sftp> lls                  # List local files
sftp> pwd                  # Remote working directory
sftp> lpwd                 # Local working directory
sftp> cd /path             # Change remote directory
sftp> lcd /path            # Change local directory
sftp> get file.txt         # Download file
sftp> put file.txt         # Upload file
sftp> get -r directory/    # Download directory
sftp> put -r directory/    # Upload directory
sftp> rm file.txt          # Delete remote file
sftp> mkdir dirname        # Create remote directory
sftp> bye                  # Exit
```

### rsync over SSH

Best for syncing large directories or many files.

```bash
# Sync directory to remote
rsync -avz -e ssh /local/dir/ user@host:/remote/dir/

# Sync from remote
rsync -avz -e ssh user@host:/remote/dir/ /local/dir/

# With progress
rsync -avz --progress -e ssh /local/dir/ user@host:/remote/dir/

# Dry run (see what would be transferred)
rsync -avz --dry-run -e ssh /local/dir/ user@host:/remote/dir/

# Exclude files
rsync -avz --exclude='*.log' -e ssh /local/dir/ user@host:/remote/dir/
```

**Flags:**
- `-a` Archive mode (preserve permissions, timestamps, etc.)
- `-v` Verbose
- `-z` Compress during transfer
- `-e ssh` Use SSH

---

## SSH Tunneling and Port Forwarding

### Local Port Forwarding

Access remote service through SSH tunnel.

```bash
# Forward local port 8080 to remote port 80
ssh -L 8080:localhost:80 user@host

# Now access: http://localhost:8080
```

**Use case:** Access web interface on remote server.

**Through intermediate host:**
```bash
# Forward local 3306 to database.internal:3306 via jump host
ssh -L 3306:database.internal:3306 user@jumphost
```

### Remote Port Forwarding

Expose local service to remote network.

```bash
# Make local port 8000 accessible on remote host's port 8080
ssh -R 8080:localhost:8000 user@host

# Remote users can now access: http://remotehost:8080
```

**Use case:** Demo local development server to remote team.

### Dynamic Port Forwarding (SOCKS Proxy)

Route all traffic through SSH tunnel.

```bash
# Create SOCKS proxy on local port 1080
ssh -D 1080 user@host

# Configure browser to use SOCKS5 proxy: localhost:1080
```

**Use case:** 
- Secure browsing on untrusted networks
- Access region-restricted content
- Bypass firewall restrictions

### Keep Tunnels Open

```bash
# With autossh (more reliable)
autossh -M 0 -L 8080:localhost:80 user@host

# Background SSH tunnel
ssh -f -N -L 8080:localhost:80 user@host
```

**Flags:**
- `-f` Background mode
- `-N` No command execution (tunnel only)
- `-M` Monitoring port (autossh)

---

## SSH Jump Hosts (Bastion)

### Using ProxyJump

Access internal hosts through bastion.

```bash
# Direct command
ssh -J bastion.example.com user@internal.example.com

# Multiple jumps
ssh -J bastion1,bastion2 user@internal.example.com
```

**In ~/.ssh/config:**
```
Host internal
    HostName internal.example.com
    ProxyJump bastion.example.com
    User admin
```

Now: `ssh internal`

### Using ProxyCommand (Legacy)

```bash
# In ~/.ssh/config
Host internal
    HostName internal.example.com
    ProxyCommand ssh bastion.example.com -W %h:%p
```

---

## Troubleshooting SSH Issues

### Connection Refused

**Meaning:** Nothing listening on port.

```bash
# Check if SSH is running on remote
# (from remote host console)
systemctl status sshd
ss -tlnp | grep :22

# Try different port
ssh -p 2222 user@host

# Check firewall
iptables -L -n | grep 22
```

### Connection Timeout

**Meaning:** No response from host.

```bash
# Can you reach host?
ping host

# Is port accessible?
telnet host 22
nc -zv host 22

# Network route okay?
traceroute host
```

### Permission Denied (publickey)

**Meaning:** Key authentication failed.

```bash
# Verbose output to see why
ssh -vvv user@host

# Check key permissions locally
ls -la ~/.ssh/
chmod 600 ~/.ssh/id_ed25519

# Check authorized_keys on remote
# (must be 600 or 644, directory must be 700)
ls -la ~/.ssh/authorized_keys

# Verify correct public key is in authorized_keys
cat ~/.ssh/authorized_keys

# Check SSH server logs
# (on remote host)
tail -f /var/log/auth.log
journalctl -u sshd -f
```

### Host Key Verification Failed

**Message:**
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

**Meaning:** Host key changed (server reinstalled, MITM attack, or IP reused).

**If you trust the new key:**
```bash
# Remove old key
ssh-keygen -R hostname

# Or edit manually
nano ~/.ssh/known_hosts
# Remove the line for that host
```

### Connection Hangs

**After password/key:**

```bash
# Check MTU issues
ssh -o "IPQoS=0" user@host

# Disable GSSAPI authentication (slow DNS)
ssh -o GSSAPIAuthentication=no user@host

# Add to ~/.ssh/config:
Host *
    GSSAPIAuthentication no
```

**During transfer:**
- MTU issue (see TCP/IP docs)
- Network congestion
- Try compression: `ssh -C user@host`

---

## Security Best Practices

### 1. Use SSH Keys

```bash
# Generate strong key
ssh-keygen -t ed25519

# Disable password authentication in /etc/ssh/sshd_config
PasswordAuthentication no
```

### 2. Disable Root Login

```bash
# In /etc/ssh/sshd_config
PermitRootLogin no
```

### 3. Change Default Port

```bash
# In /etc/ssh/sshd_config
Port 2222
```

Reduces automated attacks, but is **security through obscurity**.

### 4. Use Fail2ban

```bash
# Install
apt-get install fail2ban

# Bans IPs after failed login attempts
```

### 5. Limit User Access

```bash
# In /etc/ssh/sshd_config
AllowUsers alice bob
AllowGroups sshusers
```

### 6. Use Two-Factor Authentication

```bash
# Install Google Authenticator
apt-get install libpam-google-authenticator

# Configure PAM
# Edit /etc/pam.d/sshd
```

### 7. Keep SSH Updated

```bash
# Check version
ssh -V

# Update regularly
apt-get update && apt-get upgrade openssh-server
```

### 8. Monitor SSH Logs

```bash
# Failed attempts
grep "Failed password" /var/log/auth.log

# Successful logins
grep "Accepted" /var/log/auth.log

# See who's connected
who
w
```

---

## Quick Reference

**Connect:**
```bash
ssh user@host
ssh -p 2222 user@host
ssh -i ~/.ssh/key user@host
```

**Generate key:**
```bash
ssh-keygen -t ed25519
ssh-copy-id user@host
```

**Transfer files:**
```bash
scp file.txt user@host:/path/
rsync -avz dir/ user@host:/path/
```

**Port forwarding:**
```bash
ssh -L 8080:localhost:80 user@host       # Local
ssh -R 8080:localhost:8000 user@host     # Remote
ssh -D 1080 user@host                    # SOCKS proxy
```

**Troubleshooting:**
```bash
ssh -vvv user@host                       # Verbose
ssh-keygen -R hostname                   # Remove known host
tail -f /var/log/auth.log                # Server logs
```

---

## Further Reading

- `man ssh` - OpenSSH SSH client
- `man sshd_config` - OpenSSH SSH daemon configuration file
- `man ssh_config` - OpenSSH SSH client configuration files
- `man ssh-keygen` - Authentication key generation
- OpenSSH documentation: https://www.openssh.com/manual.html
