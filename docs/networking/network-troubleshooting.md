# Network Troubleshooting

Systematic approach to diagnosing network problems.

---

## Why This Matters

Network issues are common and disruptive:
- Services become unreachable
- Connections time out or hang
- Performance degrades
- Intermittent failures

A methodical approach saves time and prevents guessing.

---

## The Troubleshooting Method

Work from bottom to top of the network stack:

1. **Physical/Link Layer** - Is the interface up?
2. **Network Layer** - Can we route to the destination?
3. **Transport Layer** - Is the port accessible?
4. **Application Layer** - Is the service working correctly?

**Don't skip steps.** Each layer depends on the one below.

---

## Layer 1-2: Physical and Link

### Check Interface Status

```bash
# View interfaces
ip link show
ip addr show

# Is interface up?
ip link show eth0
```

**Look for:**
- `UP` and `LOWER_UP` flags
- Assigned IP address
- Correct subnet mask

### Common Issues

**Interface down:**
```bash
# Bring up interface
ip link set eth0 up
```

**No IP address (DHCP):**
```bash
# Check DHCP client
systemctl status NetworkManager
systemctl status dhclient

# Request new lease
dhclient -r eth0    # Release
dhclient eth0       # Request

# Or with NetworkManager
nmcli connection down eth0
nmcli connection up eth0
```

**Cable/connection problems:**
```bash
# Check ethernet statistics
ethtool eth0

# Look for errors
ip -s link show eth0

# Check dmesg for interface messages
dmesg | grep eth0
```

---

## Layer 3: Network/Routing

### Test Local Network

```bash
# Can we reach the gateway?
ip route show              # Find gateway
ping <gateway_ip>

# Example:
# default via 192.168.1.1 dev eth0
ping 192.168.1.1
```

**If gateway unreachable:**
- Wrong subnet configuration
- Switch/VLAN problem
- ARP issue

### Check ARP Table

ARP maps IP addresses to MAC addresses.

```bash
# View ARP table
ip neigh show
arp -an

# Flush ARP cache if stale
ip neigh flush all
```

### Test Internet Connectivity

```bash
# Can we reach external hosts?
ping 8.8.8.8               # Google DNS (IP)
ping google.com            # Requires DNS too
```

**If 8.8.8.8 works but google.com fails:** DNS problem (see DNS section)

### Routing Issues

```bash
# View routing table
ip route show
route -n

# Trace path to destination
traceroute 8.8.8.8
traceroute -n 8.8.8.8      # Numeric (faster, no DNS)
mtr 8.8.8.8                # Better traceroute (real-time)
```

**Common problems:**
- No default gateway
- Incorrect gateway IP
- Asymmetric routing

**Check default route:**
```bash
ip route show default

# If missing, add it:
ip route add default via 192.168.1.1 dev eth0
```

---

## DNS and Name Resolution

### Test DNS Resolution

```bash
# Basic lookup
nslookup google.com

# More detailed
dig google.com

# Show what system actually uses
getent hosts google.com

# Test specific DNS server
dig @8.8.8.8 google.com
nslookup google.com 8.8.8.8
```

### Check DNS Configuration

```bash
# View DNS settings
cat /etc/resolv.conf

# Should contain:
# nameserver 8.8.8.8
# nameserver 8.8.4.4
```

**On systems with systemd-resolved:**
```bash
systemd-resolve --status
resolvectl status

# Where it's actually configured
cat /etc/systemd/resolved.conf
```

### Common DNS Issues

**No nameservers configured:**
```bash
# Add temporarily
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Permanent (if using resolvconf)
echo "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u
```

**Wrong nameserver:**
```bash
# Test if DNS server is reachable
ping 8.8.8.8

# Test if DNS service is working
dig @8.8.8.8 google.com
```

**DNS works but browser doesn't:**
- Check `/etc/hosts` for overrides
- Clear browser DNS cache
- Check proxy settings

**Slow DNS resolution:**
```bash
# Time DNS lookups
time dig google.com

# Check if IPv6 is causing delays
dig AAAA google.com
```

---

## Layer 4: Transport (TCP/UDP)

### Check if Port is Listening

```bash
# What's listening locally?
ss -tlnp                   # TCP
ss -ulnp                   # UDP
netstat -tulpn             # Older alternative

# Is specific port listening?
ss -tlnp | grep :80
lsof -i :80
```

### Test Remote Port Connectivity

```bash
# TCP connectivity
telnet <host> <port>
nc -zv <host> <port>       # Netcat verbose check
timeout 5 bash -c "</dev/tcp/<host>/<port>" && echo "Open"

# Examples:
telnet google.com 80
nc -zv 192.168.1.100 22
```

**Response meanings:**
- **Connected:** Port is open and accepting connections
- **Connection refused:** Port not listening (but host reachable)
- **Timeout:** Firewall blocking, host down, or routing issue

### Check Active Connections

```bash
# All established connections
ss -tan state established

# Connections to specific port
ss -tan dst :443

# Connections from specific IP
ss -tan dst 192.168.1.100

# Who's connected to my SSH?
ss -tnp | grep :22
```

### Port Already in Use

```bash
# Find what's using port 80
lsof -i :80
ss -tlnp | grep :80

# Kill the process
kill <PID>

# Or force kill
kill -9 <PID>
```

---

## Firewall Issues

### Check Firewall Status

**iptables:**
```bash
# View all rules
iptables -L -n -v
iptables -t nat -L -n -v   # NAT rules

# Check if packet would be accepted
iptables -C INPUT -p tcp --dport 80 -j ACCEPT
```

**nftables:**
```bash
# View rules
nft list ruleset
```

**firewalld (RHEL/CentOS):**
```bash
# Status
firewall-cmd --state

# List allowed services/ports
firewall-cmd --list-all

# Check specific port
firewall-cmd --query-port=80/tcp
```

**ufw (Ubuntu):**
```bash
# Status
ufw status verbose

# Check if enabled
ufw status
```

### Temporarily Disable Firewall (Testing)

**WARNING:** Only do this for testing. Never in production.

```bash
# iptables
iptables -F                # Flush all rules
iptables -P INPUT ACCEPT   # Accept all

# firewalld
systemctl stop firewalld

# ufw
ufw disable
```

**Always re-enable after testing!**

### Allow Port Through Firewall

**iptables:**
```bash
# Allow incoming SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4
```

**firewalld:**
```bash
# Allow port
firewall-cmd --add-port=80/tcp --permanent
firewall-cmd --reload
```

**ufw:**
```bash
# Allow port
ufw allow 80/tcp
```

---

## Common Network Problems

### SSH Connection Issues

**Cannot connect:**
```bash
# 1. Can we reach the host?
ping <host>

# 2. Is SSH port reachable?
telnet <host> 22
nc -zv <host> 22

# 3. Check SSH service
ssh -vvv user@host         # Verbose mode
```

**Connection hangs after password:**
- MTU issue (see TCP/IP docs)
- Slow DNS reverse lookup

**Connection refused:**
- SSH not running: `systemctl status sshd`
- Wrong port: Check `/etc/ssh/sshd_config`
- Firewall blocking

**Permission denied:**
- Wrong username/password
- Key authentication issue
- Check `/var/log/auth.log` on server

### Slow Network Performance

**Test throughput:**
```bash
# Install iperf3 on both hosts
# Server side:
iperf3 -s

# Client side:
iperf3 -c <server_ip>
```

**Check for packet loss:**
```bash
ping -c 100 <host>
# Look for packet loss percentage
```

**Check for high latency:**
```bash
ping <host>
# Look at round-trip times

mtr <host>
# Shows latency at each hop
```

**Check interface errors:**
```bash
ip -s link show eth0
# Look for errors, dropped packets

ethtool -S eth0
# Detailed statistics
```

### Intermittent Connectivity

**Check for routing changes:**
```bash
# Watch routing table
watch -n 1 ip route show
```

**Check for DHCP lease issues:**
```bash
# DHCP logs
journalctl -u NetworkManager
journalctl -u dhclient

# Lease file
cat /var/lib/dhcp/dhclient.leases
```

**Check for IP conflicts:**
```bash
# ARP tool to detect duplicates
arping -D -I eth0 <your_ip>
```

**Monitor connection:**
```bash
# Continuous ping
ping <host> | ts '[%Y-%m-%d %H:%M:%S]'

# Log to file
ping <host> > ping.log 2>&1 &
```

### Service Unreachable from Remote

Works locally but not remotely:

```bash
# 1. Is service listening on all interfaces?
ss -tlnp | grep <port>

# Look for:
# 127.0.0.1:<port>  = localhost only (BAD for remote)
# 0.0.0.0:<port>    = all interfaces (GOOD)

# 2. Can remote host reach us?
# (from remote host)
ping <our_ip>
telnet <our_ip> <port>

# 3. Is firewall blocking?
iptables -L -n -v | grep <port>

# 4. Is routing correct?
# (from remote host)
traceroute <our_ip>
```

---

## Packet Capture and Analysis

### Basic Packet Capture

```bash
# Capture on interface
tcpdump -i eth0

# Save to file
tcpdump -i eth0 -w capture.pcap

# Read from file
tcpdump -r capture.pcap
```

### Useful tcpdump Filters

```bash
# Specific port
tcpdump -i eth0 port 80

# Specific host
tcpdump -i eth0 host 192.168.1.100

# Specific protocol
tcpdump -i eth0 tcp
tcpdump -i eth0 udp
tcpdump -i eth0 icmp

# Exclude SSH (to avoid clutter when connected via SSH)
tcpdump -i eth0 'not port 22'

# HTTP GET requests
tcpdump -i eth0 -A 'tcp port 80 and (tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x47455420)'

# SYN packets (connection attempts)
tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0'
```

### Analyzing Captures

```bash
# Count packets by IP
tcpdump -n -r capture.pcap | awk '{print $3}' | cut -d. -f1-4 | sort | uniq -c | sort -n

# Show HTTP hosts
tcpdump -n -r capture.pcap -A | grep "Host:"

# Extract HTTP URLs
tcpdump -n -r capture.pcap -A | grep -E "GET|POST"
```

**Better analysis with Wireshark:**
```bash
# Capture with tcpdump, analyze with Wireshark GUI
tcpdump -i eth0 -w capture.pcap
# Then open capture.pcap in Wireshark on desktop
```

---

## Network Diagnostic Tools Reference

### Essential Tools

```bash
ping         # ICMP reachability test
traceroute   # Show path to destination
mtr          # Combined ping/traceroute with statistics
dig          # DNS lookup (detailed)
nslookup     # DNS lookup (simple)
host         # DNS lookup (very simple)
```

### Connection Tools

```bash
telnet       # TCP connection test (and interactive)
nc           # Netcat - TCP/UDP connection tool
curl         # HTTP client (testing web services)
wget         # HTTP downloader
```

### Interface and Routing

```bash
ip           # Modern network configuration tool
ifconfig     # Legacy interface configuration
route        # Legacy routing table
ethtool      # Ethernet driver settings and stats
```

### Socket and Connection Info

```bash
ss           # Modern socket statistics
netstat      # Legacy socket statistics
lsof         # List open files (including sockets)
```

### Packet Analysis

```bash
tcpdump      # Packet capture and basic analysis
wireshark    # GUI packet analyzer
tshark       # Wireshark command-line
```

### Performance Testing

```bash
iperf3       # Network throughput testing
ping         # Latency and packet loss
mtr          # Path latency analysis
```

---

## Systematic Troubleshooting Checklist

When service is unreachable:

```
☐ 1. Physical/Link
   ☐ Interface is UP
   ☐ Has IP address
   ☐ Cable connected (if wired)

☐ 2. Network
   ☐ Can ping gateway
   ☐ Default route exists
   ☐ Can ping external host (8.8.8.8)

☐ 3. DNS
   ☐ /etc/resolv.conf has nameservers
   ☐ Can resolve names (dig google.com)
   ☐ DNS servers are reachable

☐ 4. Transport
   ☐ Service is listening (ss -tlnp)
   ☐ Listening on correct interface (not just 127.0.0.1)
   ☐ Can connect locally
   ☐ Can connect remotely (telnet/nc)

☐ 5. Firewall
   ☐ Check local firewall rules
   ☐ Check remote firewall rules
   ☐ No blocking on intermediate firewalls

☐ 6. Application
   ☐ Service is running (systemctl status)
   ☐ No errors in logs
   ☐ Configuration is correct
```

---

## Quick Reference Commands

**Is it up?**
```bash
ping <host>
ip link show
```

**Can I reach it?**
```bash
traceroute <host>
mtr <host>
```

**Is the port open?**
```bash
telnet <host> <port>
nc -zv <host> <port>
```

**What's listening?**
```bash
ss -tlnp
lsof -i :<port>
```

**DNS working?**
```bash
dig <hostname>
nslookup <hostname>
```

**Any firewall rules?**
```bash
iptables -L -n -v
ufw status
firewall-cmd --list-all
```

**What's using bandwidth?**
```bash
iftop
nethogs
iptraf-ng
```

---

## Further Reading

- `man ip` - Network configuration
- `man ss` - Socket statistics
- `man tcpdump` - Packet capture
- `man iptables` - Firewall administration
- Wireshark documentation
- TCP/IP Illustrated (books)
