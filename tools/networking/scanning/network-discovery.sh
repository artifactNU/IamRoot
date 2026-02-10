#!/usr/bin/env bash
#
# network-discovery.sh
# 
# Discover live hosts and common open ports on a network segment.
# Useful for network inventory, troubleshooting connectivity, and security audits.
#
# SAFETY: Always obtain authorization before scanning networks you don't own.
#         Port scanning may trigger security alerts or be illegal without permission.
#
# Requirements: nmap (optional but recommended), or falls back to basic tools
#
# Usage:
#   ./network-discovery.sh <network>          # e.g., 192.168.1.0/24
#   ./network-discovery.sh <network> <ports>  # e.g., 192.168.1.0/24 "22,80,443"
#   ./network-discovery.sh --help

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default ports to scan (common services)
DEFAULT_PORTS="22,80,443,3306,5432,6379,8080,8443,27017"

# Functions
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <network>

Discover live hosts and scan for open ports on a network segment.

Arguments:
  network           Network in CIDR notation (e.g., 192.168.1.0/24)

Options:
  -p, --ports       Comma-separated list of ports to scan (default: $DEFAULT_PORTS)
  -q, --quick       Quick scan (ping sweep only, no port scanning)
  -f, --full        Full port scan (1-1024)
  -t, --timeout     Timeout in seconds for host detection (default: 1)
  -o, --output      Save results to file
  -n, --no-ping     Skip ping sweep, scan specified hosts directly
  -h, --help        Show this help message

Examples:
  $(basename "$0") 192.168.1.0/24
  $(basename "$0") -p "22,80,443" 10.0.0.0/24
  $(basename "$0") --quick 172.16.0.0/16
  $(basename "$0") -o scan.txt 192.168.1.0/24

Safety Reminder:
  Always obtain proper authorization before scanning networks.
  Unauthorized scanning may be illegal and/or trigger security alerts.

EOF
    exit 0
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

check_dependencies() {
    local missing=0
    
    if ! command -v nmap &>/dev/null; then
        log_warning "nmap not found. Will use fallback methods (slower and less accurate)"
        USE_NMAP=false
    else
        USE_NMAP=true
        log_info "Using nmap for scanning"
    fi
    
    # Check for basic tools
    for tool in ping nc; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "Required tool '$tool' not found"
            ((missing++))
        fi
    done
    
    return $missing
}

validate_network() {
    local network="$1"
    
    # Basic CIDR validation
    if ! [[ "$network" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        log_error "Invalid network format. Expected CIDR notation (e.g., 192.168.1.0/24)"
        return 1
    fi
    
    return 0
}

# Host discovery using nmap
discover_hosts_nmap() {
    local network="$1"
    local timeout="$2"
    
    log_info "Scanning network $network for live hosts..."
    
    # Use nmap for host discovery
    nmap -sn -T4 --host-timeout "${timeout}s" "$network" 2>/dev/null | \
        grep "Nmap scan report for" | \
        awk '{print $5}' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}

# Host discovery using ping (fallback)
discover_hosts_ping() {
    local network="$1"
    local timeout="$2"
    
    log_info "Scanning network $network for live hosts (using ping)..."
    
    # Extract base IP and netmask
    local base_ip="${network%/*}"
    local netmask="${network#*/}"
    
    # For simplicity, only handle /24 networks in fallback mode
    if [[ "$netmask" != "24" ]]; then
        log_warning "Fallback mode only supports /24 networks efficiently"
        log_warning "Install nmap for better subnet support"
        return 1
    fi
    
    local base="${base_ip%.*}"
    local temp_file
    temp_file=$(mktemp)
    
    # Parallel ping sweep
    for i in {1..254}; do
        (
            if ping -c 1 -W "$timeout" "${base}.${i}" &>/dev/null; then
                echo "${base}.${i}"
            fi
        ) &
    done | tee "$temp_file"
    
    wait
    cat "$temp_file"
    rm -f "$temp_file"
}

# Port scanning using nmap
scan_ports_nmap() {
    local host="$1"
    local ports="$2"
    
    if [[ "$ports" == "full" ]]; then
        nmap -p 1-1024 --open -T4 "$host" 2>/dev/null
    else
        nmap -p "$ports" --open -T4 "$host" 2>/dev/null
    fi
}

# Port scanning using nc (fallback)
scan_ports_nc() {
    local host="$1"
    local ports="$2"
    
    local open_ports=()
    
    # Convert comma-separated to array
    IFS=',' read -ra port_array <<< "$ports"
    
    for port in "${port_array[@]}"; do
        if timeout 2 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            open_ports+=("$port")
        fi
    done
    
    if [[ ${#open_ports[@]} -gt 0 ]]; then
        echo "Host: $host"
        echo "Open ports: ${open_ports[*]}"
    fi
}

# Main scanning function
perform_scan() {
    local network="$1"
    local ports="$2"
    local quick="$3"
    local timeout="$4"
    
    local live_hosts=()
    
    # Discover live hosts
    if [[ "$USE_NMAP" == true ]]; then
        mapfile -t live_hosts < <(discover_hosts_nmap "$network" "$timeout")
    else
        mapfile -t live_hosts < <(discover_hosts_ping "$network" "$timeout")
    fi
    
    local host_count=${#live_hosts[@]}
    
    if [[ $host_count -eq 0 ]]; then
        log_warning "No live hosts found on $network"
        return 1
    fi
    
    log_success "Found $host_count live host(s)"
    echo
    
    # Quick mode: just list hosts
    if [[ "$quick" == true ]]; then
        echo "Live Hosts:"
        echo "==========="
        printf '%s\n' "${live_hosts[@]}"
        return 0
    fi
    
    # Port scanning
    log_info "Scanning ports on discovered hosts..."
    echo
    
    for host in "${live_hosts[@]}"; do
        echo -e "${GREEN}■${NC} Scanning $host"
        
        if [[ "$USE_NMAP" == true ]]; then
            scan_ports_nmap "$host" "$ports"
        else
            scan_ports_nc "$host" "$ports"
        fi
        
        echo
    done
}

# Main script
main() {
    local network=""
    local ports="$DEFAULT_PORTS"
    local quick=false
    local timeout=1
    local output_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -p|--ports)
                ports="$2"
                shift 2
                ;;
            -q|--quick)
                quick=true
                shift
                ;;
            -f|--full)
                ports="full"
                shift
                ;;
            -t|--timeout)
                timeout="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -n|--no-ping)
                log_warning "--no-ping not yet implemented"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                network="$1"
                shift
                ;;
        esac
    done
    
    # Validate inputs
    if [[ -z "$network" ]]; then
        log_error "Network argument required"
        echo "Use --help for usage information"
        exit 1
    fi
    
    if ! validate_network "$network"; then
        exit 1
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        log_error "Missing required dependencies"
        exit 1
    fi
    
    # Display scan information
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Network Discovery & Port Scanner${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
    echo "Target Network: $network"
    [[ "$quick" == false ]] && echo "Ports: $ports"
    echo "Timeout: ${timeout}s"
    echo
    log_warning "Ensure you have authorization to scan this network"
    echo
    
    # Perform the scan
    if [[ -n "$output_file" ]]; then
        perform_scan "$network" "$ports" "$quick" "$timeout" | tee "$output_file"
        log_success "Results saved to $output_file"
    else
        perform_scan "$network" "$ports" "$quick" "$timeout"
    fi
}

# Run main function
main "$@"
