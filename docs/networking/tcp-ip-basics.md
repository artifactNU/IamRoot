# TCP/IP Basics

Understanding how network communication works on Linux.

---

## Why This Matters

When troubleshooting network issues, you need to understand:
- How packets travel from source to destination
- What layers handle what responsibilities
- Where failures can occur
- How to diagnose each layer

Most network problems are easier to solve when you understand the stack.

---

## The Network Stack (Simplified)

```
Application Layer    [HTTP, SSH, DNS, etc.]
    ↕
Transport Layer      [TCP, UDP]
    ↕
Network Layer        [IP, ICMP]
    ↕
Link Layer           [Ethernet, WiFi]
    ↕
Physical Layer       [Cables, signals]
```

**Each layer has its own job.**

Troubleshooting means identifying which layer is failing.

---

## IP Addresses and Networks

### IPv4 Addresses

Format: `192.168.1.100`

- 4 octets, each 0-255
- 32 bits total
- Written in dotted-decimal notation

### Network Masks

Subnet mask defines network and host portions.

Examples:
```
255.255.255.0    = /24  (254 usable hosts)
255.255.0.0      = /16  (65,534 usable hosts)
255.255.255.252  = /30  (2 usable hosts, common for point-to-point)
```

**CIDR notation:** `192.168.1.0/24` means:
- Network: `192.168.1.0`
- Mask: `255.255.255.0`
- Usable IPs: `192.168.1.1` through `192.168.1.254`
- Broadcast: `192.168.1.255`

### Special Addresses

| Address | Purpose |
|---------|---------|
| `127.0.0.1` | Loopback (localhost) |
| `0.0.0.0` | Any address / unspecified |
| `255.255.255.255` | Broadcast to all |
| `10.0.0.0/8` | Private network (RFC 1918) |
| `172.16.0.0/12` | Private network (RFC 1918) |
| `192.168.0.0/16` | Private network (RFC 1918) |
| `169.254.0.0/16` | Link-local (APIPA - no DHCP) |

---

## Ports and Sockets

### Port Numbers

- 16-bit number (0-65535)
- Combined with IP address to identify connection endpoint

**Port ranges:**
- `0-1023` - Well-known ports (require root to bind)
- `1024-49151` - Registered ports
- `49152-65535` - Ephemeral/dynamic ports (used by clients)

### Common Ports

| Port | Service | Protocol |
|------|---------|----------|
| 20/21 | FTP | TCP |
| 22 | SSH | TCP |
| 23 | Telnet | TCP |
| 25 | SMTP | TCP |
| 53 | DNS | TCP/UDP |
| 80 | HTTP | TCP |
| 110 | POP3 | TCP |
| 143 | IMAP | TCP |
| 443 | HTTPS | TCP |
| 3306 | MySQL | TCP |
| 5432 | PostgreSQL | TCP |
| 6379 | Redis | TCP |
| 27017 | MongoDB | TCP |

**View well-known ports:**
```bash
cat /etc/services | less
```

### Socket

A **socket** is an endpoint: IP address + port number

Example: `192.168.1.100:22` (SSH server)

Connection = pair of sockets:
- Local: `192.168.1.100:22` (server)
- Remote: `192.168.1.50:54321` (client)

---

## TCP vs UDP

### TCP (Transmission Control Protocol)

**Characteristics:**
- Connection-oriented
- Reliable delivery (packets acknowledged)
- Ordered delivery (packets arrive in sequence)
- Error checking
- Flow control

**Use cases:**
- HTTP/HTTPS
- SSH
- Email (SMTP, IMAP, POP3)
- File transfers
- Database connections

**Overhead:**
- Three-way handshake to establish connection
- ACK for each packet
- Slower than UDP but reliable

### UDP (User Datagram Protocol)

**Characteristics:**
- Connectionless
- No delivery guarantee
- No ordering guarantee
- No error recovery
- Minimal overhead

**Use cases:**
- DNS queries
- Video streaming
- Voice over IP (VoIP)
- Online gaming
- DHCP
- NTP (time sync)

**When to use UDP:**
- Speed matters more than reliability
- Occasional packet loss is acceptable
- Application handles its own error recovery

---

## TCP Connection States

**View connections:**
```bash
ss -tan               # TCP sockets, all states, numeric
netstat -tan          # Older equivalent
```

### Common States

| State | Meaning |
|-------|---------|
| `LISTEN` | Server waiting for connections |
| `ESTABLISHED` | Connection is active and working |
| `TIME_WAIT` | Connection closed, waiting for late packets |
| `CLOSE_WAIT` | Remote end closed, local waiting for close |
| `FIN_WAIT1` | Connection closing |
| `FIN_WAIT2` | Connection closing, waiting for remote close |
| `SYN_SENT` | Attempting to establish connection |
| `SYN_RECV` | Connection request received |

### TIME_WAIT Explained

After closing a TCP connection, the socket enters `TIME_WAIT` for ~60 seconds.

**Why?**
- Ensures late packets don't interfere with new connections
- Allows safe reuse of source port

**Problem:**
- Many short-lived connections can exhaust available ports
- Common with high-traffic web servers or load balancers

**Check TIME_WAIT count:**
```bash
ss -tan | grep TIME-WAIT | wc -l
```

**Tuning (if necessary):**
```bash
# Reduce TIME_WAIT duration (use with caution)
sysctl net.ipv4.tcp_fin_timeout=30

# Allow TIME_WAIT reuse
sysctl net.ipv4.tcp_tw_reuse=1
```

---

## ICMP (Internet Control Message Protocol)

ICMP is used for diagnostics and error reporting.

**Common ICMP messages:**
- **Echo Request/Reply** - Used by `ping`
- **Destination Unreachable** - Host/port cannot be reached
- **Time Exceeded** - TTL expired (used by `traceroute`)
- **Redirect** - Routing optimization

**Why it matters:**
- Many firewalls block ICMP
- Blocking all ICMP breaks Path MTU Discovery
- Can cause "black hole" routing issues

**Best practice:**
- Allow ICMP echo (ping) for monitoring
- Allow ICMP unreachable messages
- Block ICMP redirects (security)

---

## Network Address Translation (NAT)

NAT allows multiple private IPs to share one public IP.

### How NAT Works

```
Private Network          NAT Gateway          Public Internet
192.168.1.100:54321  →  203.0.113.5:12345  →  8.8.8.8:53
                         (translates)
```

Gateway remembers the mapping and translates return traffic.

### Types of NAT

**SNAT (Source NAT):**
- Changes source IP of outgoing packets
- Used for internet access from private networks

**DNAT (Destination NAT):**
- Changes destination IP of incoming packets
- Used for port forwarding

**Masquerading:**
- Special SNAT for dynamic public IPs
- Common on home routers

### Implications

**Breaks some protocols:**
- FTP (requires ALG - Application Level Gateway)
- Some VPN protocols
- Peer-to-peer applications

**Connection tracking:**
- Stateful NAT maintains connection table
- Table can fill up on high-traffic routers

**Troubleshooting NAT:**
```bash
# View NAT connection tracking (iptables)
conntrack -L

# View NAT rules
iptables -t nat -L -n -v
```

---

## MTU (Maximum Transmission Unit)

MTU is the largest packet size that can be transmitted.

**Standard MTU:**
- Ethernet: 1500 bytes
- Jumbo frames: 9000 bytes
- PPPoE: 1492 bytes (DSL connections)

### Path MTU Discovery

Mechanism to find smallest MTU along path.

**How it works:**
1. Send packet with "Don't Fragment" bit set
2. If too large, router sends ICMP "Fragmentation Needed"
3. Sender reduces packet size and retries

**Problem:**
If ICMP is blocked, PMTU Discovery fails.

**Symptoms:**
- Connection hangs after initial packets
- SSH connects but hangs during login
- HTTP works but large pages fail

**Diagnosis:**
```bash
# Test with different packet sizes
ping -M do -s 1472 8.8.8.8    # 1472 + 28 header = 1500
ping -M do -s 1400 8.8.8.8    # Should work if PMTU issue

# Check interface MTU
ip link show
```

**Fix:**
```bash
# Reduce MTU on interface
ip link set dev eth0 mtu 1400

# Or configure MSS clamping (firewall)
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

---

## Localhost and Loopback

**Loopback interface:** `lo`
- IP: `127.0.0.1` (and entire `127.0.0.0/8`)
- Never leaves the machine
- Routing handled entirely in kernel
- Always available

**Usage:**
```bash
# Services listening on localhost only
0.0.0.0:22      # SSH accessible from anywhere
127.0.0.1:3306  # MySQL only accessible locally
```

**Special case:**
`0.0.0.0` means "all interfaces" when binding, "unspecified" when connecting.

**Security:**
- Bind services to `127.0.0.1` if no remote access needed
- Reduces attack surface
- Common for databases, caches, internal APIs

---

## Network Performance Concepts

### Bandwidth
- Maximum data transfer rate
- Measured in bits per second (bps, Mbps, Gbps)
- Physical limitation of the medium

### Latency
- Time for packet to travel from source to destination
- Measured in milliseconds (ms)
- Affected by distance, routing, processing

**Measure latency:**
```bash
ping -c 10 8.8.8.8
```

### Throughput
- Actual data transfer rate achieved
- Always less than bandwidth
- Affected by latency, packet loss, protocol overhead

### Round-Trip Time (RTT)
- Time for packet to go to destination and back
- Important for TCP (each packet must be ACKed)

**High RTT impact:**
- TCP is slower (waiting for ACKs)
- Interactive applications feel sluggish
- VPN connections affected significantly

---

## Common Network Issues

### Cannot Reach Host

**Layer-by-layer diagnosis:**

1. **Physical/Link:** Is interface up?
   ```bash
   ip link show
   ```

2. **Network:** Can you ping gateway?
   ```bash
   ip route show
   ping <gateway>
   ```

3. **Routing:** Can packets reach destination?
   ```bash
   traceroute <destination>
   ```

4. **Transport:** Is port open?
   ```bash
   telnet <host> <port>
   nc -zv <host> <port>
   ```

5. **Application:** Is service responding correctly?
   ```bash
   curl -v http://<host>
   ```

### Connection Refused

**Meaning:** TCP RST received - port is not listening

**Causes:**
- Service not running
- Service listening on wrong interface
- Connecting to wrong port

**Check:**
```bash
ss -tlnp | grep <port>    # Is something listening?
```

### Connection Timeout

**Meaning:** No response received

**Causes:**
- Firewall blocking
- Service overloaded
- Routing problem
- Host down

**Check:**
```bash
telnet <host> <port>      # Times out or connects?
```

### No Route to Host

**Meaning:** System doesn't know how to reach destination

**Causes:**
- No default gateway
- Missing route
- Gateway is down

**Check:**
```bash
ip route show
ping <gateway>
```

---

## Quick Reference

**View network configuration:**
```bash
ip addr show              # IP addresses
ip link show              # Interfaces
ip route show             # Routing table
ss -tulpn                 # Listening sockets
```

**Test connectivity:**
```bash
ping <host>               # ICMP reachability
traceroute <host>         # Path to destination
telnet <host> <port>      # TCP connectivity
nc -zv <host> <port>      # TCP port check
```

**View connections:**
```bash
ss -tan                   # TCP connections
ss -tun                   # UDP sockets
ss -tlnp                  # Listening TCP with process
netstat -tulpn            # Older equivalent
```

**Packet inspection:**
```bash
tcpdump -i eth0           # Capture all traffic
tcpdump -i eth0 port 80   # HTTP traffic only
tcpdump -nn host 8.8.8.8  # Traffic to/from host
```

---

## Further Reading

- `man ip` - Show/manipulate routing, devices, policy routing
- `man ss` - Socket statistics
- `man tcp` - TCP protocol
- TCP/IP Illustrated (book series)
- RFC 791 (IP), RFC 793 (TCP), RFC 768 (UDP)
