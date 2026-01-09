#!/usr/bin/env bash
# check-failed-logins.sh
# Purpose: Reports on failed SSH and login attempts from system logs
# Usage:   sudo ./check-failed-logins.sh [-d DAYS] [-m MIN] [-t TOP] [--ips-only] [--users-only] [-v]
# Requires: root/sudo privileges to read auth logs
# Exit:    0 OK, 1 ERROR

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

# Default values
DAYS=7
SHOW_IPS=true
SHOW_USERS=true
MIN_ATTEMPTS=3
VERBOSE=false
TOP_COUNT=10

# Functions

print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}  Failed Login Attempts Report${NC}"
    echo -e "${CYAN}================================${NC}"
    echo
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

show_usage() {
    cat << EOF
Usage: sudo $(basename "$0") [OPTIONS]

Reports on failed SSH and login attempts from system authentication logs.

OPTIONS:
    -d, --days DAYS          Number of days to look back (default: 7)
    -m, --min-attempts NUM   Minimum attempts to report (default: 3)
    -t, --top COUNT          Show top N offenders (default: 10)
    -i, --ips-only           Show only IP address statistics
    -u, --users-only         Show only username statistics
    -v, --verbose            Show detailed output with timestamps
    -h, --help               Display this help message

EXAMPLES:
    sudo ./check-failed-logins.sh
    sudo ./check-failed-logins.sh -d 30 -m 5
    sudo ./check-failed-logins.sh --ips-only -t 20
    sudo ./check-failed-logins.sh -v

NOTES:
    - Requires root/sudo privileges to read auth logs
    - Searches in /var/log/auth.log* (Debian/Ubuntu) or /var/log/secure* (RHEL/CentOS)
    - Detects SSH, console, and other authentication failures

EOF
}

detect_log_file() {
    if [[ -f /var/log/auth.log ]]; then
        echo "/var/log/auth.log"
    elif [[ -f /var/log/secure ]]; then
        echo "/var/log/secure"
    else
        print_error "Could not find authentication log file"
        print_info "Tried: /var/log/auth.log, /var/log/secure"
        exit 1
    fi
}

get_log_files() {
    local base_log="$1"
    local days="$2"
    local log_files=("$base_log")
    
    # Add rotated logs based on days requested
    if [[ $days -gt 7 ]]; then
        # Include compressed logs
        for i in {1..10}; do
            if [[ -f "${base_log}.${i}.gz" ]]; then
                log_files+=("${base_log}.${i}.gz")
            elif [[ -f "${base_log}.${i}" ]]; then
                log_files+=("${base_log}.${i}")
            fi
        done
    fi
    
    printf '%s\n' "${log_files[@]}"
}

read_logs() {
    local file="$1"
    if [[ $file == *.gz ]]; then
        zcat "$file" 2>/dev/null || true
    else
        cat "$file" 2>/dev/null || true
    fi
}

parse_failed_logins() {
    local log_file="$1"
    local days="$2"
    local -a log_files
    
    mapfile -t log_files < <(get_log_files "$log_file" "$days")
    
    for log in "${log_files[@]}"; do
        read_logs "$log"
    done | grep -iE "(failed password|authentication failure|invalid user|failed login|connection closed by authenticating user)" | grep -v "pam_unix(sudo:auth)"
}

analyze_by_ip() {
    local data="$1"
    
    echo -e "\n${RED}=== Top Failed Login Attempts by IP Address ===${NC}\n"
    
    # Extract IP addresses from various log formats
    local ip_list
    ip_list=$(echo "$data" | grep -oP '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort | uniq -c | sort -rn)
    
    if [[ -z "$ip_list" ]]; then
        print_info "No IP addresses found in failed login attempts."
        return
    fi
    
    echo -e "${CYAN}Top $TOP_COUNT Offending IP Addresses:${NC}"
    printf "  ${YELLOW}%-18s %10s${NC}\n" "IP ADDRESS" "ATTEMPTS"
    printf "  ${YELLOW}%-18s %10s${NC}\n" "----------" "--------"
    
    echo "$ip_list" | head -n "$TOP_COUNT" | while read -r count ip; do
        if [[ $count -ge $MIN_ATTEMPTS ]]; then
            printf "  ${RED}%-18s %10d${NC}\n" "$ip" "$count"
        fi
    done
    
    # Show geographic distribution hint if verbose
    if [[ "$VERBOSE" == true ]]; then
        echo -e "\n${CYAN}Sample Recent Attempts:${NC}"
        echo "$data" | grep -oP '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort -u | head -5 | while read -r ip; do
            local sample_line
            sample_line=$(echo "$data" | grep "$ip" | head -1)
            local timestamp
            timestamp=$(echo "$sample_line" | grep -oP '^\w+\s+\d+\s+\d+:\d+:\d+' || echo "N/A")
            printf "  ${BLUE}%s${NC} | ${RED}%s${NC}\n" "$timestamp" "$ip"
        done
    fi
}

analyze_by_user() {
    local data="$1"
    
    echo -e "\n${RED}=== Top Failed Login Attempts by Username ===${NC}\n"
    
    # Extract usernames from various patterns
    local user_list
    user_list=$(echo "$data" | grep -oP '(?:user |for |invalid user |for invalid user )\K[^ ]+' | grep -v "^$" | sort | uniq -c | sort -rn)
    
    if [[ -z "$user_list" ]]; then
        print_info "No usernames found in failed login attempts."
        return
    fi
    
    echo -e "${CYAN}Top $TOP_COUNT Targeted Usernames:${NC}"
    printf "  ${YELLOW}%-20s %10s${NC}\n" "USERNAME" "ATTEMPTS"
    printf "  ${YELLOW}%-20s %10s${NC}\n" "--------" "--------"
    
    echo "$user_list" | head -n "$TOP_COUNT" | while read -r count user; do
        if [[ $count -ge $MIN_ATTEMPTS ]]; then
            # Check if user exists on system
            if id "$user" &>/dev/null; then
                printf "  ${MAGENTA}%-20s %10d${NC} ${YELLOW}(EXISTS)${NC}\n" "$user" "$count"
            else
                printf "  ${RED}%-20s %10d${NC}\n" "$user" "$count"
            fi
        fi
    done
    
    if [[ "$VERBOSE" == true ]]; then
        echo -e "\n${CYAN}Sample Attempts by User:${NC}"
        echo "$user_list" | head -5 | while read -r count user; do
            local sample_line
            sample_line=$(echo "$data" | grep -m 1 -E "(user |for |invalid user )${user}( |$)")
            if [[ -n "$sample_line" ]]; then
                local timestamp
                timestamp=$(echo "$sample_line" | grep -oP '^\w+\s+\d+\s+\d+:\d+:\d+' || echo "N/A")
                printf "  ${BLUE}%s${NC} | ${YELLOW}%-15s${NC} | %d attempts\n" "$timestamp" "$user" "$count"
            fi
        done
    fi
}

analyze_patterns() {
    local data="$1"
    
    echo -e "\n${CYAN}=== Attack Pattern Analysis ===${NC}\n"
    
    # SSH failures
    local ssh_count
    ssh_count=$(echo "$data" | grep -c "sshd" || echo "0")
    
    # Invalid user attempts
    local invalid_count
    invalid_count=$(echo "$data" | grep -c "invalid user" || echo "0")
    
    # Failed password with valid users
    local valid_user_count
    valid_user_count=$(echo "$data" | grep "Failed password" | grep -cv "invalid user" || echo "0")
    
    # Root login attempts
    local root_count
    root_count=$(echo "$data" | grep -c "user root" || echo "0")
    
    printf "  ${CYAN}SSH failed attempts:${NC}          %7d\n" "$ssh_count"
    printf "  ${CYAN}Invalid username attempts:${NC}    %7d\n" "$invalid_count"
    printf "  ${CYAN}Valid user wrong password:${NC}    %7d\n" "$valid_user_count"
    printf "  ${RED}Root login attempts:${NC}          %7d\n" "$root_count"
    
    if [[ $root_count -gt 0 ]]; then
        echo
        print_warning "Root login attempts detected! Consider disabling root SSH access."
    fi
    
    # Check for potential brute force (high frequency from single IP)
    local max_from_single_ip
    max_from_single_ip=$(echo "$data" | grep -oP '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
    
    if [[ -n "$max_from_single_ip" ]] && [[ $max_from_single_ip -gt 50 ]]; then
        echo
        print_warning "Potential brute force detected: $max_from_single_ip attempts from single IP"
    fi
}

show_summary() {
    local data="$1"
    
    echo -e "\n${CYAN}=== Summary ===${NC}\n"
    
    local total_failures
    local unique_ips
    local unique_users
    
    total_failures=$(echo "$data" | wc -l)
    unique_ips=$(echo "$data" | grep -oP '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | sort -u | wc -l)
    unique_users=$(echo "$data" | grep -oP '(?:user |for |invalid user )\K[^ ]+' | grep -v "^$" | sort -u | wc -l)
    
    printf "  Total failed attempts:    %7d\n" "$total_failures"
    printf "  Unique IP addresses:      %7d\n" "$unique_ips"
    printf "  Unique usernames:         %7d\n" "$unique_users"
    
    if [[ $total_failures -gt 100 ]]; then
        echo
        print_warning "High number of failed login attempts detected!"
        print_info "Consider implementing fail2ban or similar protection."
    elif [[ $total_failures -eq 0 ]]; then
        echo
        print_success "No failed login attempts found - excellent security posture!"
    else
        echo
        print_success "Moderate number of failed attempts - within normal range."
    fi
}

show_recommendations() {
    local data="$1"
    local total
    
    total=$(echo "$data" | wc -l)
    
    if [[ $total -gt 20 ]]; then
        echo -e "\n${YELLOW}=== Security Recommendations ===${NC}\n"
        
        echo -e "  ${CYAN}•${NC} Consider installing fail2ban to block repeat offenders"
        echo -e "  ${CYAN}•${NC} Use SSH key authentication instead of passwords"
        echo -e "  ${CYAN}•${NC} Change SSH port from default 22"
        echo -e "  ${CYAN}•${NC} Disable root SSH login"
        echo -e "  ${CYAN}•${NC} Enable two-factor authentication"
        echo -e "  ${CYAN}•${NC} Review and restrict allowed users/groups for SSH"
        echo
    fi
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--days)
                DAYS="$2"
                shift 2
                ;;
            -m|--min-attempts)
                MIN_ATTEMPTS="$2"
                shift 2
                ;;
            -t|--top)
                TOP_COUNT="$2"
                shift 2
                ;;
            -i|--ips-only)
                SHOW_USERS=false
                shift
                ;;
            -u|--users-only)
                SHOW_IPS=false
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check for root privileges
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires root privileges to read authentication logs"
        print_info "Please run with: sudo $0"
        exit 1
    fi
    
    print_header
    print_info "Analyzing failed login attempts for the last $DAYS days..."
    echo
    
    # Detect log file location
    local log_file
    log_file=$(detect_log_file)
    
    if [[ "$VERBOSE" == true ]]; then
        print_info "Using log file: $log_file"
        echo
    fi
    
    # Parse logs
    local failed_login_data
    failed_login_data=$(parse_failed_logins "$log_file" "$DAYS")
    
    if [[ -z "$failed_login_data" ]]; then
        print_success "No failed login attempts found in the last $DAYS days!"
        echo
        print_info "Your system appears to be secure with no unauthorized access attempts."
        exit 0
    fi
    
    # Show analysis based on options
    if [[ "$SHOW_IPS" == true ]]; then
        analyze_by_ip "$failed_login_data"
    fi
    
    if [[ "$SHOW_USERS" == true ]]; then
        analyze_by_user "$failed_login_data"
    fi
    
    analyze_patterns "$failed_login_data"
    show_summary "$failed_login_data"
    show_recommendations "$failed_login_data"
    
    echo
    print_success "Analysis complete!"
    echo
}

# Run main function
main "$@"
