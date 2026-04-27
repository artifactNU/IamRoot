#!/usr/bin/env bash
#
# packet-capture.sh
# 
# Capture and analyze network packets for troubleshooting and monitoring.
# Provides a user-friendly wrapper around tcpdump with common use cases.
#
# SAFETY: Always obtain authorization before capturing network traffic.
#         Packet capture may expose sensitive data and require elevated privileges.
#         Use only on networks you own or have explicit permission to monitor.
#
# Requirements: tcpdump
#
# Usage:
#   sudo ./packet-capture.sh -i eth0              # Capture on eth0
#   sudo ./packet-capture.sh -i any -p 80,443     # HTTP/HTTPS traffic
#   sudo ./packet-capture.sh --help

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_INTERFACE="any"
DEFAULT_COUNT="100"
DEFAULT_SNAPLEN="262144"  # 256KB - captures full packets

# Functions
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Capture and analyze network packets on specified interfaces.

Options:
  -i, --interface   Interface to capture on (default: $DEFAULT_INTERFACE)
  -p, --port        Port(s) to filter (comma-separated, e.g., "80,443")
  -H, --host        Host/IP to filter traffic
  -P, --protocol    Protocol to filter (tcp, udp, icmp, arp)
  -c, --count       Number of packets to capture (default: $DEFAULT_COUNT, 0=unlimited)
  -w, --write       Write packets to pcap file
  -r, --read        Read and analyze existing pcap file
  -f, --filter      Custom tcpdump filter expression
  -v, --verbose     Verbose output (detailed packet info)
  -s, --snaplen     Snapshot length in bytes (default: $DEFAULT_SNAPLEN)
  -n, --no-dns      Don't resolve hostnames (faster)
  -l, --list        List available network interfaces
  -h, --help        Show this help message

Examples:
  # List interfaces
  $(basename "$0") --list

  # Capture 50 packets on eth0
  sudo $(basename "$0") -i eth0 -c 50

  # Capture HTTP/HTTPS traffic
  sudo $(basename "$0") -i any -p 80,443

  # Capture traffic to/from specific host
  sudo $(basename "$0") -H 192.168.1.100

  # Save capture to file
  sudo $(basename "$0") -i eth0 -w capture.pcap

  # Read and analyze saved capture
  $(basename "$0") -r capture.pcap

  # Capture DNS queries
  sudo $(basename "$0") -p 53 -P udp

  # Custom filter (SYN packets)
  sudo $(basename "$0") -f "tcp[tcpflags] & tcp-syn != 0"

Common Port References:
  HTTP: 80          HTTPS: 443       SSH: 22
  DNS: 53           FTP: 21          SMTP: 25
  MySQL: 3306       PostgreSQL: 5432 Redis: 6379

Safety Reminder:
  Always obtain proper authorization before capturing network traffic.
  Packet capture may expose sensitive information and is often regulated.

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

check_root() {
    if [[ $EUID -ne 0 ]] && [[ "$READ_MODE" != true ]]; then
        log_error "This script requires root privileges for packet capture"
        log_info "Please run with sudo: sudo $0 $*"
        exit 1
    fi
}

check_dependencies() {
    local missing=0
    
    if ! command -v tcpdump &>/dev/null; then
        log_error "tcpdump not found. Please install it:"
        echo "  Ubuntu/Debian: sudo apt-get install tcpdump"
        echo "  RHEL/CentOS:   sudo yum install tcpdump"
        echo "  macOS:         brew install tcpdump"
        ((missing++))
    fi
    
    return $missing
}

list_interfaces() {
    log_info "Available network interfaces:"
    echo
    
    if command -v ip &>/dev/null; then
        ip -br addr show | while read -r iface state addr; do
            if [[ "$state" == "UP" ]]; then
                echo -e "  ${GREEN}●${NC} $iface ${CYAN}($state)${NC} - $addr"
            else
                echo -e "  ${YELLOW}○${NC} $iface ${CYAN}($state)${NC} - $addr"
            fi
        done
    elif command -v ifconfig &>/dev/null; then
        ifconfig -a | grep -E '^[a-z]' | awk '{print "  " $1}' | sed 's/:$//'
    else
        log_error "Cannot list interfaces (ip and ifconfig not found)"
        return 1
    fi
    
    echo
    log_info "Use 'any' to capture on all interfaces"
}

build_filter() {
    local filter=""
    local parts=()
    
    # Port filter
    if [[ -n "$PORTS" ]]; then
        local port_filter=""
        IFS=',' read -ra port_array <<< "$PORTS"
        
        for port in "${port_array[@]}"; do
            if [[ -z "$port_filter" ]]; then
                port_filter="port $port"
            else
                port_filter="$port_filter or port $port"
            fi
        done
        
        parts+=("($port_filter)")
    fi
    
    # Host filter
    if [[ -n "$HOST" ]]; then
        parts+=("host $HOST")
    fi
    
    # Protocol filter
    if [[ -n "$PROTOCOL" ]]; then
        parts+=("$PROTOCOL")
    fi
    
    # Custom filter (takes precedence)
    if [[ -n "$CUSTOM_FILTER" ]]; then
        echo "$CUSTOM_FILTER"
        return
    fi
    
    # Combine all parts with 'and'
    for ((i=0; i<${#parts[@]}; i++)); do
        if [[ $i -eq 0 ]]; then
            filter="${parts[$i]}"
        else
            filter="$filter and ${parts[$i]}"
        fi
    done
    
    echo "$filter"
}

capture_packets() {
    local interface="$1"
    local count="$2"
    local output_file="$3"
    local filter="$4"
    local verbose="$5"
    local no_dns="$6"
    local snaplen="$7"
    
    local tcpdump_opts=("-i" "$interface" "-s" "$snaplen")
    
    # Add count limit
    if [[ "$count" != "0" ]]; then
        tcpdump_opts+=("-c" "$count")
    fi
    
    # Add verbosity
    if [[ "$verbose" == true ]]; then
        tcpdump_opts+=("-v")
    fi
    
    # DNS resolution
    if [[ "$no_dns" == true ]]; then
        tcpdump_opts+=("-n")
    fi
    
    # Output file
    if [[ -n "$output_file" ]]; then
        tcpdump_opts+=("-w" "$output_file")
        log_info "Writing packets to: $output_file"
    else
        # Make output more readable when not writing to file
        tcpdump_opts+=("-l")
    fi
    
    # Add filter if specified
    if [[ -n "$filter" ]]; then
        log_info "Filter: $filter"
    fi
    
    log_info "Starting packet capture on $interface..."
    
    if [[ "$count" == "0" ]]; then
        log_warning "Capturing unlimited packets. Press Ctrl+C to stop."
    else
        log_info "Capturing $count packet(s)..."
    fi
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo
    
    # Execute tcpdump
    if [[ -n "$filter" ]]; then
        tcpdump "${tcpdump_opts[@]}" "$filter" 2>&1
    else
        tcpdump "${tcpdump_opts[@]}" 2>&1
    fi
    
    local exit_code=$?
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Capture completed"
        if [[ -n "$output_file" ]] && [[ -f "$output_file" ]]; then
            local file_size
            file_size=$(du -h "$output_file" | cut -f1)
            log_info "Capture file: $output_file ($file_size)"
        fi
    else
        log_error "Capture failed with exit code $exit_code"
        return $exit_code
    fi
}

read_pcap() {
    local pcap_file="$1"
    local filter="$2"
    local verbose="$3"
    
    if [[ ! -f "$pcap_file" ]]; then
        log_error "File not found: $pcap_file"
        return 1
    fi
    
    log_info "Reading pcap file: $pcap_file"
    
    local file_size
    file_size=$(du -h "$pcap_file" | cut -f1)
    log_info "File size: $file_size"
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo
    
    local tcpdump_opts=("-r" "$pcap_file")
    
    if [[ "$verbose" == true ]]; then
        tcpdump_opts+=("-v")
    fi
    
    # Add filter if specified
    if [[ -n "$filter" ]]; then
        log_info "Filter: $filter"
        tcpdump "${tcpdump_opts[@]}" "$filter"
    else
        tcpdump "${tcpdump_opts[@]}"
    fi
    
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo
    
    # Show statistics if available
    log_info "Capture statistics:"
    tcpdump -r "$pcap_file" 2>&1 | tail -3 || true
}

show_capture_info() {
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Network Packet Capture${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
    
    [[ -n "$INTERFACE" ]] && echo "Interface: $INTERFACE"
    [[ -n "$PORTS" ]] && echo "Port(s): $PORTS"
    [[ -n "$HOST" ]] && echo "Host: $HOST"
    [[ -n "$PROTOCOL" ]] && echo "Protocol: $PROTOCOL"
    [[ "$COUNT" != "0" ]] && echo "Packet limit: $COUNT"
    [[ -n "$OUTPUT_FILE" ]] && echo "Output file: $OUTPUT_FILE"
    
    echo
    log_warning "Ensure you have authorization to capture traffic on this network"
    log_warning "Packet capture may expose sensitive information"
    echo
}

# Main script
main() {
    local INTERFACE="$DEFAULT_INTERFACE"
    local PORTS=""
    local HOST=""
    local PROTOCOL=""
    local COUNT="$DEFAULT_COUNT"
    local OUTPUT_FILE=""
    local READ_FILE=""
    local CUSTOM_FILTER=""
    local VERBOSE=false
    local SNAPLEN="$DEFAULT_SNAPLEN"
    local NO_DNS=false
    local LIST_IFACES=false
    local READ_MODE=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -i|--interface)
                INTERFACE="$2"
                shift 2
                ;;
            -p|--port)
                PORTS="$2"
                shift 2
                ;;
            -H|--host)
                HOST="$2"
                shift 2
                ;;
            -P|--protocol)
                PROTOCOL="$2"
                shift 2
                ;;
            -c|--count)
                COUNT="$2"
                shift 2
                ;;
            -w|--write)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -r|--read)
                READ_FILE="$2"
                READ_MODE=true
                shift 2
                ;;
            -f|--filter)
                CUSTOM_FILTER="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -s|--snaplen)
                SNAPLEN="$2"
                shift 2
                ;;
            -n|--no-dns)
                NO_DNS=true
                shift
                ;;
            -l|--list)
                LIST_IFACES=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Check dependencies first
    if ! check_dependencies; then
        exit 1
    fi
    
    # Handle list interfaces
    if [[ "$LIST_IFACES" == true ]]; then
        list_interfaces
        exit 0
    fi
    
    # Handle read mode
    if [[ "$READ_MODE" == true ]]; then
        local filter
        filter=$(build_filter)
        read_pcap "$READ_FILE" "$filter" "$VERBOSE"
        exit 0
    fi
    
    # Check for root privileges
    check_root "$@"
    
    # Build filter expression
    local filter
    filter=$(build_filter)
    
    # Display capture information
    show_capture_info
    
    # Start capture
    capture_packets "$INTERFACE" "$COUNT" "$OUTPUT_FILE" "$filter" "$VERBOSE" "$NO_DNS" "$SNAPLEN"
}

# Handle cleanup on Ctrl+C
trap 'echo; log_info "Capture interrupted by user"; exit 130' INT TERM

# Run main function
main "$@"
