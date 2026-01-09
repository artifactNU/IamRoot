#!/bin/bash
# Script: audit-sudo-usage.sh
# Purpose: Reviews recent sudo command history from system logs
# Usage: sudo ./audit-sudo-usage.sh [OPTIONS]

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Default values
DAYS=7
SHOW_COMMANDS=true
SHOW_FAILED=true
USER_FILTER=""
VERBOSE=false


# Functions


print_header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}   Sudo Usage Audit Report${NC}"
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

Reviews sudo command history from system authentication logs.

OPTIONS:
    -d, --days DAYS          Number of days to look back (default: 7)
    -u, --user USERNAME      Filter by specific user
    -f, --failures-only      Show only failed sudo attempts
    -s, --successes-only     Show only successful sudo commands
    -c, --command PATTERN    Filter by command pattern (grep style)
    -v, --verbose            Show detailed output
    -h, --help               Display this help message

EXAMPLES:
    sudo ./audit-sudo-usage.sh
    sudo ./audit-sudo-usage.sh -d 30
    sudo ./audit-sudo-usage.sh -u john -d 14
    sudo ./audit-sudo-usage.sh --failures-only

NOTES:
    - Requires root/sudo privileges to read auth logs
    - Searches in /var/log/auth.log* (Debian/Ubuntu) or /var/log/secure* (RHEL/CentOS)

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
    
    echo "${log_files[@]}"
}

read_logs() {
    local file="$1"
    if [[ $file == *.gz ]]; then
        zcat "$file" 2>/dev/null || true
    else
        cat "$file" 2>/dev/null || true
    fi
}

parse_sudo_logs() {
    local log_file="$1"
    local days="$2"
    local cutoff_date
    
    cutoff_date=$(date -d "$days days ago" '+%Y-%m-%d' 2>/dev/null || date -v-"${days}d" '+%Y-%m-%d' 2>/dev/null)
    
    if [[ -z "$cutoff_date" ]]; then
        print_warning "Could not calculate cutoff date, showing all available logs"
    fi
    
    local log_files
    log_files=($(get_log_files "$log_file" "$days"))
    
    for log in "${log_files[@]}"; do
        read_logs "$log"
    done | grep "sudo:" | grep -v "pam_unix(sudo:session)"
}

analyze_successful_commands() {
    local data="$1"
    
    echo -e "\n${GREEN}=== Successful Sudo Commands ===${NC}\n"
    
    local success_data
    success_data=$(echo "$data" | grep "COMMAND=" | grep -v "authentication failure" | grep -v "incorrect password")
    
    if [[ -z "$success_data" ]]; then
        print_info "No successful sudo commands found in the specified time period."
        return
    fi
    
    # Count by user
    echo -e "${CYAN}Commands by User:${NC}"
    echo "$success_data" | grep -oP '(?<=: ).*?(?= :)' | sort | uniq -c | sort -rn | while read -r count user; do
        printf "  %-20s %5d commands\n" "$user" "$count"
    done
    
    # Show recent commands
    if [[ "$VERBOSE" == true ]]; then
        echo -e "\n${CYAN}Recent Commands (last 20):${NC}"
        echo "$success_data" | tail -20 | while IFS= read -r line; do
            local timestamp=$(echo "$line" | grep -oP '^\w+\s+\d+\s+\d+:\d+:\d+')
            local user=$(echo "$line" | grep -oP '(?<=: ).*?(?= :)' | head -1)
            local command=$(echo "$line" | grep -oP '(?<=COMMAND=).*')
            printf "  ${BLUE}%s${NC} | ${YELLOW}%-12s${NC} | %s\n" "$timestamp" "$user" "$command"
        done
    fi
    
    # Top 10 most used commands
    echo -e "\n${CYAN}Most Frequently Used Commands:${NC}"
    echo "$success_data" | grep -oP '(?<=COMMAND=).*' | sort | uniq -c | sort -rn | head -10 | while read -r count cmd; do
        printf "  %5d × %s\n" "$count" "$cmd"
    done
}

analyze_failed_attempts() {
    local data="$1"
    
    echo -e "\n${RED}=== Failed Sudo Attempts ===${NC}\n"
    
    local failed_data
    failed_data=$(echo "$data" | grep -E "(authentication failure|incorrect password|NOT in sudoers)")
    
    if [[ -z "$failed_data" ]]; then
        print_success "No failed sudo attempts found - good security posture!"
        return
    fi
    
    # Count failures by user
    echo -e "${CYAN}Failed Attempts by User:${NC}"
    echo "$failed_data" | grep -oP '(?<=user=)[^ ]+' | sort | uniq -c | sort -rn | while read -r count user; do
        printf "  ${RED}%-20s %5d failures${NC}\n" "$user" "$count"
    done
    
    # Show details if verbose
    if [[ "$VERBOSE" == true ]]; then
        echo -e "\n${CYAN}Recent Failed Attempts (last 15):${NC}"
        echo "$failed_data" | tail -15 | while IFS= read -r line; do
            local timestamp=$(echo "$line" | grep -oP '^\w+\s+\d+\s+\d+:\d+:\d+')
            local user=$(echo "$line" | grep -oP '(?<=user=)[^ ]+' || echo "unknown")
            printf "  ${RED}%s${NC} | ${YELLOW}%-12s${NC} | %s\n" "$timestamp" "$user" "FAILED AUTHENTICATION"
        done
    fi
    
    # Count by source IP if available
    local ips
    ips=$(echo "$failed_data" | grep -oP '(?<=rhost=)[^ ]+' | grep -v "^$" | sort | uniq -c | sort -rn)
    if [[ -n "$ips" ]]; then
        echo -e "\n${CYAN}Failed Attempts by Source:${NC}"
        echo "$ips" | while read -r count ip; do
            printf "  ${RED}%-20s %5d attempts${NC}\n" "$ip" "$count"
        done
    fi
}

show_summary() {
    local data="$1"
    
    echo -e "\n${CYAN}=== Summary ===${NC}\n"
    
    local total_commands=$(echo "$data" | grep -c "COMMAND=" || echo "0")
    local failed_attempts=$(echo "$data" | grep -cE "(authentication failure|incorrect password)" || echo "0")
    local unique_users=$(echo "$data" | grep -oP '(?<=: ).*?(?= :)' | sort -u | wc -l)
    
    printf "  Total sudo commands:    %5d\n" "$total_commands"
    printf "  Failed attempts:        %5d\n" "$failed_attempts"
    printf "  Unique users:           %5d\n" "$unique_users"
    
    if [[ $failed_attempts -gt 0 ]]; then
        local failure_rate=$(awk "BEGIN {printf \"%.1f\", ($failed_attempts/($total_commands+$failed_attempts))*100}")
        printf "  Failure rate:           %5s%%\n" "$failure_rate"
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
            -u|--user)
                USER_FILTER="$2"
                shift 2
                ;;
            -f|--failures-only)
                SHOW_COMMANDS=false
                shift
                ;;
            -s|--successes-only)
                SHOW_FAILED=false
                shift
                ;;
            -c|--command)
                COMMAND_FILTER="$2"
                shift 2
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
    print_info "Analyzing sudo usage for the last $DAYS days..."
    echo
    
    # Detect log file location
    local log_file
    log_file=$(detect_log_file)
    
    if [[ "$VERBOSE" == true ]]; then
        print_info "Using log file: $log_file"
        echo
    fi
    
    # Parse logs
    local sudo_data
    sudo_data=$(parse_sudo_logs "$log_file" "$DAYS")
    
    if [[ -z "$sudo_data" ]]; then
        print_warning "No sudo activity found in the last $DAYS days"
        exit 0
    fi
    
    # Apply user filter if specified
    if [[ -n "$USER_FILTER" ]]; then
        sudo_data=$(echo "$sudo_data" | grep ": $USER_FILTER :")
        print_info "Filtered to user: $USER_FILTER"
    fi
    
    # Apply command filter if specified
    if [[ -n "${COMMAND_FILTER:-}" ]]; then
        sudo_data=$(echo "$sudo_data" | grep "$COMMAND_FILTER")
        print_info "Filtered to commands matching: $COMMAND_FILTER"
    fi
    
    # Show analysis
    if [[ "$SHOW_COMMANDS" == true ]]; then
        analyze_successful_commands "$sudo_data"
    fi
    
    if [[ "$SHOW_FAILED" == true ]]; then
        analyze_failed_attempts "$sudo_data"
    fi
    
    show_summary "$sudo_data"
    
    echo
    print_success "Audit complete!"
    echo
}

# Run main function
main "$@"
