# Firewall Basics

Understanding and managing Linux firewalls.

---

## Why This Matters

Firewalls control:
- What traffic can enter your system (INPUT)
- What traffic can leave your system (OUTPUT)
- What traffic can pass through your system (FORWARD)

Most "connection refused" or "timeout" issues involve firewalls.

Understanding firewall rules is essential for both security and troubleshooting.

---

## Linux Firewall Stack

### The Evolution

```
netfilter (kernel)
    ↓
iptables (legacy, still common)
    ↓
nftables (modern replacement)
    ↓
Higher-level tools:
  - firewalld (RHEL/CentOS)
  - ufw (Ubuntu)
```

**All of these** ultimately configure netfilter in the kernel.

### Which Should You Use?

**For direct control:**
- Modern systems: `nftables`
- Legacy/existing systems: `iptables`

**For easier management:**
- RHEL/CentOS/Fedora: `firewalld`
- Ubuntu/Debian: `ufw`

**Most systems** still use iptables, so we'll focus on that.

---

## iptables Fundamentals

### Tables and Chains

**Tables** group rules by function:
- `filter` - Default table, packet filtering
- `nat` - Network Address Translation
- `mangle` - Packet modification
- `raw` - Connection tracking exemptions

**Chains** are lists of rules:
- `INPUT` - Packets destined for this host
- `OUTPUT` - Packets originating from this host
- `FORWARD` - Packets routed through this host
- `PREROUTING` - Alter packets as they arrive
- `POSTROUTING` - Alter packets as they leave

### Packet Flow

```
                         PREROUTING
                              ↓
                         (Routing Decision)
                         ↙           ↘
                    INPUT              FORWARD
                      ↓                   ↓
                (Local Process)      POSTROUTING
                      ↓                   ↓
                   OUTPUT              (exit)
                      ↓
                 POSTROUTING
                      ↓
                   (exit)
```

**For local services:** Packets go through `INPUT` chain  
**For routing/NAT:** Packets go through `FORWARD` chain  
**For outgoing:** Packets go through `OUTPUT` chain

---

## Viewing Current Rules

### Basic Listing

```bash
# View filter table (default)
iptables -L

# Numeric output (faster, no DNS lookups)
iptables -L -n

# With packet/byte counts
iptables -L -n -v

# Line numbers (useful for deletion)
iptables -L -n --line-numbers
```

### View All Tables

```bash
# Filter table
iptables -t filter -L -n -v

# NAT table
iptables -t nat -L -n -v

# Mangle table
iptables -t mangle -L -n -v
```

### Understanding Output

```
Chain INPUT (policy ACCEPT 1234 packets, 567K bytes)
 pkts bytes target  prot opt in  out  source      destination
  100  8000 ACCEPT  tcp  --  *   *    0.0.0.0/0   0.0.0.0/0   tcp dpt:22
   50  4000 DROP    tcp  --  *   *    0.0.0.0/0   0.0.0.0/0   tcp dpt:23
```

- **pkts/bytes**: Packet and byte counters
- **target**: Action (ACCEPT, DROP, REJECT, etc.)
- **prot**: Protocol (tcp, udp, icmp, all)
- **in/out**: Interface
- **source/destination**: IP addresses
- **dpt**: Destination port

---

## Policy (Default Action)

Each chain has a default **policy**: what to do if no rules match.

```bash
# View policies
iptables -L | grep policy

# Set policy
iptables -P INPUT DROP      # Drop by default
iptables -P INPUT ACCEPT    # Accept by default
```

**Common approaches:**

**Permissive (default ACCEPT):**
- Allow everything except explicitly blocked
- Easier for workstations
- Less secure

**Restrictive (default DROP):**
- Block everything except explicitly allowed
- Better for servers
- More secure but requires more rules

---

## Adding Rules

### Basic Syntax

```bash
iptables -A <chain> <match criteria> -j <target>
```

- `-A` = Append to chain
- `-I` = Insert at top
- `-D` = Delete rule
- `-j` = Jump to target (action)

### Allow SSH

```bash
# Allow incoming SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# From specific IP only
iptables -A INPUT -p tcp -s 192.168.1.100 --dport 22 -j ACCEPT
```

### Allow HTTP and HTTPS

```bash
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

### Allow Established Connections

```bash
# Critical rule: allow responses to outgoing connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

**Always include this** if using restrictive policy.

### Allow Loopback

```bash
# Always allow localhost communication
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```

---

## Targets (Actions)

| Target | Effect |
|--------|--------|
| `ACCEPT` | Allow packet |
| `DROP` | Silently discard packet |
| `REJECT` | Discard and send error back |
| `LOG` | Log packet and continue |
| `RETURN` | Return to calling chain |
| `DNAT` | Destination NAT |
| `SNAT` | Source NAT |
| `MASQUERADE` | Dynamic SNAT |

### DROP vs REJECT

**DROP:**
- No response sent
- Connection times out
- Stealthier (attacker doesn't know if host exists)
- Can slow down port scans

**REJECT:**
- Sends "connection refused" back
- Fails immediately
- More polite for legitimate traffic
- Better for debugging

```bash
# Drop silently
iptables -A INPUT -p tcp --dport 23 -j DROP

# Reject with message
iptables -A INPUT -p tcp --dport 23 -j REJECT
```

---

## Match Criteria

### Protocol

```bash
-p tcp           # TCP
-p udp           # UDP
-p icmp          # ICMP
-p all           # Any protocol
```

### Ports

```bash
--dport 22              # Destination port
--sport 1024:65535      # Source port range
--dport 80,443          # Multiple ports (requires multiport module)
```

### IP Addresses

```bash
-s 192.168.1.100        # Source IP
-d 10.0.0.50            # Destination IP
-s 192.168.1.0/24       # Source network
! -s 192.168.1.100      # NOT from this IP
```

### Interfaces

```bash
-i eth0          # Input interface
-o eth1          # Output interface
```

### State/Connection Tracking

```bash
-m conntrack --ctstate NEW              # New connection
-m conntrack --ctstate ESTABLISHED      # Existing connection
-m conntrack --ctstate RELATED          # Related (like FTP data)
-m conntrack --ctstate INVALID          # Malformed packets
```

### Rate Limiting

```bash
# Limit SSH connections (prevent brute force)
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
```

---

## Deleting Rules

### By Line Number

```bash
# Show line numbers
iptables -L INPUT --line-numbers

# Delete rule 3 from INPUT
iptables -D INPUT 3
```

### By Specification

```bash
# Delete exact rule
iptables -D INPUT -p tcp --dport 23 -j DROP
```

### Flush All Rules

```bash
# Clear all rules in all chains
iptables -F

# Clear specific chain
iptables -F INPUT

# Clear specific table
iptables -t nat -F
```

**WARNING:** Flushing with default DROP policy will lock you out.

---

## Saving and Restoring Rules

### Debian/Ubuntu

```bash
# Save rules
iptables-save > /etc/iptables/rules.v4

# Restore rules
iptables-restore < /etc/iptables/rules.v4

# Persist across reboot
apt-get install iptables-persistent
```

### RHEL/CentOS

```bash
# Save rules
service iptables save

# Or manually
iptables-save > /etc/sysconfig/iptables

# Restore on boot (automatic with iptables service)
systemctl enable iptables
```

### Manual Restore

Add to `/etc/rc.local` or create systemd service:

```bash
#!/bin/bash
iptables-restore < /etc/iptables/rules.v4
```

---

## Example Firewall Configurations

### Basic Web Server

```bash
#!/bin/bash

# Flush existing rules
iptables -F

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow ping
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# Log dropped packets
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-dropped: "

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### SSH with Rate Limiting

```bash
# Allow SSH but limit connection attempts
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

### Allow from Specific Network

```bash
# Allow all traffic from internal network
iptables -A INPUT -s 192.168.1.0/24 -j ACCEPT

# Block all other
iptables -A INPUT -j DROP
```

---

## NAT (Network Address Translation)

### Source NAT (Masquerading)

Used for internet sharing.

```bash
# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Masquerade outgoing traffic
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Or with static IP
iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source 203.0.113.5
```

### Destination NAT (Port Forwarding)

Forward external port to internal host.

```bash
# Forward port 80 to internal web server
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.100:80

# Allow forwarded traffic
iptables -A FORWARD -p tcp -d 192.168.1.100 --dport 80 -j ACCEPT
```

### Port Redirection

Redirect one port to another locally.

```bash
# Redirect port 8080 to port 80
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j REDIRECT --to-port 80
```

---

## Logging

### Log Dropped Packets

```bash
# Log before dropping
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-dropped: " --log-level 4
iptables -A INPUT -j DROP
```

**Rate limiting** with `-m limit` prevents log flooding.

### View Logged Packets

```bash
# System logs
grep "iptables-dropped" /var/log/syslog
dmesg | grep "iptables-dropped"

# With journald
journalctl -k | grep "iptables-dropped"
```

---

## UFW (Uncomplicated Firewall)

Ubuntu's simplified firewall interface.

### Basic Usage

```bash
# Enable/disable
ufw enable
ufw disable

# Status
ufw status
ufw status verbose
ufw status numbered

# Default policies
ufw default deny incoming
ufw default allow outgoing
```

### Allow Rules

```bash
# Allow service by name
ufw allow ssh
ufw allow http
ufw allow https

# Allow port
ufw allow 8080/tcp
ufw allow 53/udp

# Allow from IP
ufw allow from 192.168.1.100

# Allow from IP to specific port
ufw allow from 192.168.1.100 to any port 22

# Allow subnet
ufw allow from 192.168.1.0/24
```

### Deny Rules

```bash
# Deny port
ufw deny 23/tcp

# Deny from IP
ufw deny from 203.0.113.50
```

### Delete Rules

```bash
# By number
ufw status numbered
ufw delete 2

# By specification
ufw delete allow 80/tcp
```

### Application Profiles

```bash
# List available profiles
ufw app list

# Info about profile
ufw app info 'Apache Full'

# Allow profile
ufw allow 'Apache Full'
```

---

## Firewalld (RHEL/CentOS)

Zone-based firewall management.

### Basic Usage

```bash
# Status
firewall-cmd --state

# List zones
firewall-cmd --get-zones

# Default zone
firewall-cmd --get-default-zone

# Active zones
firewall-cmd --get-active-zones
```

### Manage Services

```bash
# List allowed services
firewall-cmd --list-all

# Allow service (temporary)
firewall-cmd --add-service=http

# Allow service (permanent)
firewall-cmd --add-service=http --permanent

# Remove service
firewall-cmd --remove-service=http --permanent

# Reload after permanent changes
firewall-cmd --reload
```

### Manage Ports

```bash
# Allow port
firewall-cmd --add-port=8080/tcp --permanent

# Allow port range
firewall-cmd --add-port=4000-4100/tcp --permanent

# Remove port
firewall-cmd --remove-port=8080/tcp --permanent
```

### Rich Rules

```bash
# Allow SSH from specific IP
firewall-cmd --add-rich-rule='rule family="ipv4" source address="192.168.1.100" service name="ssh" accept' --permanent

# Rate limit SSH
firewall-cmd --add-rich-rule='rule service name="ssh" limit value="10/m" accept' --permanent
```

---

## Troubleshooting Firewall Issues

### Is Firewall Blocking?

```bash
# Check if port is filtered
nmap -p 80 <host>

# From remote host
telnet <host> <port>
nc -zv <host> <port>

# Check local rules
iptables -L -n -v | grep <port>
```

### Test Temporarily

```bash
# Temporarily accept all
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F

# Test if service now works
# Then restore firewall rules
```

**Never leave firewall disabled on production.**

### Check Rule Matches

```bash
# View packet counters
iptables -L -n -v

# Zero counters to see what's being hit
iptables -Z
# Generate traffic
# Check again
iptables -L -n -v
```

### Common Mistakes

**1. Forgot to allow established connections:**
```bash
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

**2. Forgot to allow loopback:**
```bash
iptables -A INPUT -i lo -j ACCEPT
```

**3. Wrong chain:**
- Use `INPUT` for traffic TO this host
- Use `OUTPUT` for traffic FROM this host
- Use `FORWARD` for traffic THROUGH this host

**4. Order matters:**
First matching rule wins. Check rule order with:
```bash
iptables -L --line-numbers
```

---

## Security Best Practices

### 1. Default Deny

```bash
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT  # Or DROP if you want strict control
```

### 2. Allow Only What's Needed

Start with nothing allowed, add rules as needed.

### 3. Rate Limit SSH

```bash
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
```

### 4. Drop Invalid Packets

```bash
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
```

### 5. Log Suspicious Activity

```bash
# Log port scans
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "NULL-scan: "
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
```

### 6. Protect Against SYN Floods

```bash
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP
```

---

## Quick Reference

**View rules:**
```bash
iptables -L -n -v                    # All rules
iptables -t nat -L -n -v             # NAT rules
ufw status verbose                   # UFW rules
firewall-cmd --list-all              # Firewalld rules
```

**Allow port:**
```bash
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
ufw allow 80/tcp
firewall-cmd --add-port=80/tcp --permanent && firewall-cmd --reload
```

**Save rules:**
```bash
iptables-save > /etc/iptables/rules.v4
ufw enable                           # Already persistent
firewall-cmd --runtime-to-permanent
```

**Disable temporarily:**
```bash
iptables -F && iptables -P INPUT ACCEPT
ufw disable
systemctl stop firewalld
```

---

## Further Reading

- `man iptables` - Administration tool for IPv4 packet filtering
- `man ufw` - Program for managing netfilter firewall
- `man firewall-cmd` - firewalld command line client
- iptables Tutorial: https://www.frozentux.net/iptables-tutorial/
