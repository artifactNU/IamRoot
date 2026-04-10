# Networking Cheat Sheet

Reference for network inspection, interface management, and scanning with `ip`, `ss`, and `nmap`.

---

## Table of Contents

- [ip — Interfaces](#ip--interfaces)
- [ip — Addresses](#ip--addresses)
- [ip — Routes](#ip--routes)
- [ip — Neighbours (ARP)](#ip--neighbours-arp)
- [ip — Links & VLANs](#ip--links--vlans)
- [ss — Socket Statistics](#ss--socket-statistics)
- [nmap — Host Discovery](#nmap--host-discovery)
- [nmap — Port Scanning](#nmap--port-scanning)
- [nmap — Service & OS Detection](#nmap--service--os-detection)
- [nmap — Scripts (NSE)](#nmap--scripts-nse)
- [nmap — Output Formats](#nmap--output-formats)
- [nmap — Timing & Performance](#nmap--timing--performance)
- [Useful Combinations](#useful-combinations)
- [Troubleshooting](#troubleshooting)

---

## ip — Interfaces

- Show all interfaces (brief)  
  `ip link show`  
  or  
  `ip -br link`  
  The `-br` flag gives a compact one-line-per-interface view.

- Show detailed stats for one interface  
  `ip -s link show <iface>`  
  Includes RX/TX packet and error counters.

- Bring an interface up / down  
  `ip link set <iface> up`  
  `ip link set <iface> down`

- Rename an interface (must be down first)  
  `ip link set <iface> name <newname>`

- Set MTU  
  `ip link set <iface> mtu 9000`

- Enable/disable promiscuous mode  
  `ip link set <iface> promisc on`  
  `ip link set <iface> promisc off`

---

## ip — Addresses

- Show all addresses (compact)  
  `ip -br addr`

- Show all addresses (verbose)  
  `ip addr show`

- Show addresses for one interface  
  `ip addr show dev <iface>`

- Show only IPv4 / IPv6  
  `ip -4 addr`  
  `ip -6 addr`

- Add an address  
  `ip addr add 192.168.1.10/24 dev <iface>`

- Remove an address  
  `ip addr del 192.168.1.10/24 dev <iface>`

- Flush all addresses on an interface  
  `ip addr flush dev <iface>`  
  Removes all assigned addresses; the interface stays up.

---

## ip — Routes

- Show the routing table  
  `ip route show`  
  or  
  `ip -br route`

- Show route for a specific destination  
  `ip route get 8.8.8.8`  
  Shows which interface and gateway would be used.

- Add a static route  
  `ip route add 10.0.0.0/8 via 192.168.1.1 dev <iface>`

- Add a default gateway  
  `ip route add default via 192.168.1.1`

- Delete a route  
  `ip route del 10.0.0.0/8`

- Replace (add or update) a route  
  `ip route replace 10.0.0.0/8 via 192.168.1.254`

- Flush the routing cache  
  `ip route flush cache`

---

## ip — Neighbours (ARP)

- Show ARP / NDP neighbour table  
  `ip neigh show`

- Show neighbours on one interface  
  `ip neigh show dev <iface>`

- Add a static ARP entry  
  `ip neigh add 192.168.1.50 lladdr aa:bb:cc:dd:ee:ff dev <iface>`

- Delete a neighbour entry  
  `ip neigh del 192.168.1.50 dev <iface>`

- Flush all dynamic neighbour entries  
  `ip neigh flush all`

---

## ip — Links & VLANs

- Add a VLAN sub-interface  
  `ip link add link <iface> name <iface>.10 type vlan id 10`

- Add a bridge  
  `ip link add name br0 type bridge`  
  `ip link set <iface> master br0`

- Add a dummy interface (useful for testing)  
  `ip link add dummy0 type dummy`

- Delete a virtual interface  
  `ip link del <iface>`

- Show bonding/team info  
  `ip -d link show <bond0>`  
  The `-d` flag shows driver-level detail.

---

## ss — Socket Statistics

Drop-in replacement for `netstat`. Much faster on busy systems.

**Common flags**

| Flag | Meaning |
|------|---------|
| `-t` | TCP sockets |
| `-u` | UDP sockets |
| `-l` | Listening sockets only |
| `-a` | All sockets (listening + established) |
| `-n` | Numeric (no DNS/service resolution) |
| `-p` | Show process name and PID |
| `-e` | Extended socket info |
| `-s` | Summary statistics |
| `-4` / `-6` | IPv4 / IPv6 only |

- All listening TCP/UDP ports with process names  
  `ss -tulnp`

- All established TCP connections  
  `ss -tn state established`

- Connections to a specific remote port  
  `ss -tn dst :443`

- Connections from a specific source address  
  `ss -tn src 10.0.0.5`

- Sockets owned by a specific process  
  `ss -tp | grep <process>`

- Unix domain sockets  
  `ss -xl`

- Summary of socket counts by state  
  `ss -s`

- Filter by state  
  `ss -t state time-wait`  
  States: `established`, `syn-sent`, `syn-recv`, `fin-wait-1`, `fin-wait-2`,  
  `time-wait`, `closed`, `close-wait`, `last-ack`, `listening`, `closing`

- Watch connections in real time  
  `watch -n1 ss -tulnp`

---

## nmap — Host Discovery

> **Note:** Only scan networks you own or have explicit permission to scan.

- Ping scan (no port scan) — fast host discovery  
  `nmap -sn 192.168.1.0/24`

- Disable ping, scan all hosts regardless  
  `nmap -Pn 192.168.1.0/24`  
  Useful when ICMP is blocked by firewalls.

- ARP scan (local network only, very fast)  
  `nmap -PR -sn 192.168.1.0/24`

- List scan — just list targets, no packets sent  
  `nmap -sL 192.168.1.0/24`

- Scan from a file of hosts  
  `nmap -iL hosts.txt`

- Exclude hosts  
  `nmap 192.168.1.0/24 --exclude 192.168.1.1`

---

## nmap — Port Scanning

- TCP SYN scan (default, requires root)  
  `nmap -sS <target>`  
  Stealthier than a full connect scan; does not complete the TCP handshake.

- TCP connect scan (no root needed)  
  `nmap -sT <target>`

- UDP scan (slow, requires root)  
  `nmap -sU <target>`

- Scan specific ports  
  `nmap -p 22,80,443 <target>`

- Scan a port range  
  `nmap -p 1-1024 <target>`

- Scan all 65535 ports  
  `nmap -p- <target>`

- Top 100 most common ports  
  `nmap --top-ports 100 <target>`

- Fast scan (top 100 ports, skip DNS)  
  `nmap -F -n <target>`

- TCP + UDP combined  
  `nmap -sS -sU -p T:80,443,U:53,161 <target>`

---

## nmap — Service & OS Detection

- Service/version detection  
  `nmap -sV <target>`  
  Probes open ports to identify the running service and version.

- OS detection (requires root)  
  `nmap -O <target>`

- Aggressive scan (OS + version + scripts + traceroute)  
  `nmap -A <target>`  
  Equivalent to `-O -sV -sC --traceroute`. Noisy — use carefully.

- Limit version intensity (0=light … 9=thorough)  
  `nmap -sV --version-intensity 2 <target>`

---

## nmap — Scripts (NSE)

Scripts live in `/usr/share/nmap/scripts/`.

- Run default safe scripts  
  `nmap -sC <target>`  
  Same as `--script=default`.

- Run a specific script  
  `nmap --script=http-title <target>`

- Run a category of scripts  
  `nmap --script=vuln <target>`  
  Categories: `auth`, `broadcast`, `brute`, `default`, `discovery`,  
  `dos`, `exploit`, `external`, `fuzzer`, `intrusive`, `malware`,  
  `safe`, `version`, `vuln`

- Run multiple scripts  
  `nmap --script=http-headers,http-methods <target>`

- Pass arguments to a script  
  `nmap --script=http-brute --script-args userdb=users.txt,passdb=passwords.txt <target>`

- Search for available scripts  
  `nmap --script-help "*smb*"`  
  `ls /usr/share/nmap/scripts/ | grep <keyword>`

- Update the script database  
  `nmap --script-updatedb`

---

## nmap — Output Formats

- Normal output (terminal)  
  `nmap -oN output.txt <target>`

- Grepable output (one host per line)  
  `nmap -oG output.gnmap <target>`

- XML output  
  `nmap -oX output.xml <target>`

- All formats at once  
  `nmap -oA output <target>`  
  Creates `output.nmap`, `output.gnmap`, and `output.xml`.

- Increase verbosity  
  `nmap -v <target>`  
  Use `-vv` for even more detail.

- Debug output  
  `nmap -d <target>`

---

## nmap — Timing & Performance

Timing templates control speed vs. stealth tradeoff.

| Template | Name | Use case |
|----------|------|----------|
| `-T0` | Paranoid | IDS evasion, very slow |
| `-T1` | Sneaky | IDS evasion, slow |
| `-T2` | Polite | Light on bandwidth |
| `-T3` | Normal | Default |
| `-T4` | Aggressive | Fast, assumes reliable network |
| `-T5` | Insane | Very fast, may miss results |

- Recommended for internal audits  
  `nmap -T4 <target>`

- Limit packets per second  
  `nmap --max-rate 100 <target>`

- Parallelism (number of probes in flight)  
  `nmap --min-parallelism 10 --max-parallelism 50 <target>`

---

## Useful Combinations

- Full audit of a single host  
  `nmap -sS -sU -sV -O -sC -p- -T4 -oA full_scan <target>`

- Quick service sweep of a subnet  
  `nmap -sS -sV -T4 --top-ports 1000 -oA subnet_sweep 192.168.1.0/24`

- Find all open SSH ports on a subnet  
  `nmap -p 22 --open 192.168.1.0/24`

- Who's listening on port 443 right now (local)  
  `ss -tlnp | grep :443`

- What process owns a port  
  `ss -tlnp sport = :8080`

- Show established connections with process info  
  `ss -tnp state established`

- Check if a remote port is open without nmap  
  `ip route get <target> && ss -tn dst <target>:<port>`

- Trace the path to a host and measure RTT  
  `ip route get <target>` followed by `traceroute <target>`

---

## Troubleshooting

- Interface is up but has no address  
  Check `ip addr show dev <iface>`; no `inet` line means DHCP failed or no static config.

- Default route is missing  
  `ip route show` — if there is no `default` entry, add one:  
  `ip route add default via <gateway>`

- Can ping gateway but not internet  
  DNS may be broken. Test with `ping 8.8.8.8` vs `ping google.com`.  
  Check `/etc/resolv.conf` for a valid `nameserver` line.

- ARP not resolving  
  `ip neigh show` — look for `FAILED` or `INCOMPLETE` entries.  
  Flush and retry: `ip neigh flush all`

- nmap reports all ports filtered  
  Host may be blocking probes. Try `-Pn` (skip ping) and `-T2` (slower rate).  
  Confirm reachability first with `ip route get <target>`.

- ss shows TIME_WAIT buildup  
  High connection turnover (e.g., HTTP). Check `net.ipv4.tcp_tw_reuse` sysctl:  
  `sysctl net.ipv4.tcp_tw_reuse`

- Permission denied running nmap SYN scan  
  SYN scan (`-sS`) and OS detection (`-O`) require root. Use `sudo` or switch to connect scan (`-sT`).
