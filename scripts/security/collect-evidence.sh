#!/usr/bin/env bash
#
# collect-evidence.sh
#
# Collect forensic evidence from a Linux system for incident response and analysis.
# Gathers system state, logs, network info, processes, and file metadata while
# maintaining evidence integrity with timestamps and hashes.
#
# LEGAL WARNING: Only use this tool on systems you own or have explicit written
#                authorization to investigate. Unauthorized access may violate
#                computer fraud and abuse laws.
#
# Usage:
#   sudo ./collect-evidence.sh
#   sudo ./collect-evidence.sh -o /mnt/external/evidence
#   sudo ./collect-evidence.sh --quick

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default values
DEFAULT_OUTPUT_DIR="/tmp/forensics-$(date +%Y%m%d-%H%M%S)"
QUICK_MODE=false
INCLUDE_MEMORY=false
VERBOSE=false

# Functions
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Collect forensic evidence from the system for incident response analysis.

Options:
  -o, --output      Output directory (default: $DEFAULT_OUTPUT_DIR)
  -q, --quick       Quick collection (skip time-consuming operations)
  -m, --memory      Include memory dump (requires significant disk space)
  -v, --verbose     Verbose output
  -h, --help        Show this help message

Collection Categories:
  • System Information    - OS, hardware, uptime, users
  • Network State         - Connections, routing, firewall rules
  • Process Information   - Running processes, open files, loaded modules
  • User Activity         - Login history, command history, cron jobs
  • System Logs           - Auth logs, system logs, application logs
  • File System           - Mounted filesystems, suspicious files
  • Persistence           - Startup services, scheduled tasks
  • Security State        - SELinux/AppArmor, installed packages

Examples:
  # Standard collection
  sudo $(basename "$0")

  # Quick collection to specific directory
  sudo $(basename "$0") -q -o /evidence/case-001

  # Full collection including memory dump
  sudo $(basename "$0") -m -o /mnt/external/evidence

Output:
  All evidence is collected into a timestamped directory with:
  - Individual text files for each data category
  - A comprehensive collection log
  - SHA-256 hashes for evidence integrity
  - A summary report

Legal Notice:
  This tool is for authorized incident response and forensic analysis only.
  Always obtain proper authorization before collecting evidence.

EOF
    exit 0
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_section() {
    echo
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $*${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges for full evidence collection"
        log_info "Please run with sudo: sudo $0 $*"
        exit 1
    fi
}

check_disk_space() {
    local output_dir="$1"
    local parent_dir
    parent_dir=$(dirname "$output_dir")
    
    local available
    available=$(df -BG "$parent_dir" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ $available -lt 1 ]]; then
        log_error "Insufficient disk space. At least 1GB recommended"
        log_info "Available: ${available}GB"
        return 1
    fi
    
    if [[ $available -lt 5 ]]; then
        log_warning "Low disk space: ${available}GB available"
        if [[ "$INCLUDE_MEMORY" == true ]]; then
            log_error "Memory dump requires significant space. Aborting."
            return 1
        fi
    fi
    
    return 0
}

setup_output_dir() {
    local output_dir="$1"
    
    if [[ -d "$output_dir" ]]; then
        log_warning "Output directory exists: $output_dir"
        log_info "Files will be added/overwritten"
    else
        mkdir -p "$output_dir" || {
            log_error "Failed to create output directory: $output_dir"
            exit 1
        }
    fi
    
    # Create subdirectories
    mkdir -p "$output_dir"/{system,network,processes,users,logs,filesystem,persistence,security}
    
    log_success "Output directory: $output_dir"
}

exec_cmd() {
    local description="$1"
    local output_file="$2"
    shift 2
    local cmd=("$@")
    
    if [[ "$VERBOSE" == true ]]; then
        log_info "Collecting: $description"
    fi
    
    {
        echo "# $description"
        echo "# Collected: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo "# Command: ${cmd[*]}"
        echo
        "${cmd[@]}" 2>&1 || echo "[Command failed with exit code $?]"
        echo
    } >> "$output_file"
}

collect_system_info() {
    local output_dir="$1"
    log_section "Collecting System Information"
    
    local outfile="$output_dir/system/system-info.txt"
    
    exec_cmd "Hostname" "$outfile" hostname
    exec_cmd "OS Release" "$outfile" cat /etc/os-release
    exec_cmd "Kernel Version" "$outfile" uname -a
    exec_cmd "System Uptime" "$outfile" uptime
    exec_cmd "Current Date/Time" "$outfile" date
    exec_cmd "Timezone" "$outfile" timedatectl
    
    exec_cmd "CPU Information" "$output_dir/system/cpu-info.txt" cat /proc/cpuinfo
    exec_cmd "Memory Information" "$output_dir/system/memory-info.txt" cat /proc/meminfo
    exec_cmd "Free Memory" "$output_dir/system/memory-info.txt" free -h
    
    exec_cmd "Loaded Kernel Modules" "$output_dir/system/kernel-modules.txt" lsmod
    exec_cmd "Kernel Messages" "$output_dir/system/dmesg.txt" dmesg
    
    exec_cmd "Environment Variables" "$output_dir/system/environment.txt" env
    
    log_success "System information collected"
}

collect_network_info() {
    local output_dir="$1"
    log_section "Collecting Network Information"
    
    exec_cmd "Network Interfaces" "$output_dir/network/interfaces.txt" ip addr show
    exec_cmd "Network Interface Statistics" "$output_dir/network/interfaces.txt" ip -s link
    exec_cmd "Routing Table" "$output_dir/network/routing.txt" ip route show
    exec_cmd "ARP Cache" "$output_dir/network/arp.txt" ip neigh show
    
    exec_cmd "Active Network Connections" "$output_dir/network/connections.txt" ss -tupan
    exec_cmd "Listening Ports" "$output_dir/network/listening-ports.txt" ss -tulpn
    
    exec_cmd "Firewall Rules (iptables)" "$output_dir/network/firewall.txt" iptables -L -n -v
    exec_cmd "NAT Rules" "$output_dir/network/firewall.txt" iptables -t nat -L -n -v
    
    if command -v ufw &>/dev/null; then
        exec_cmd "UFW Status" "$output_dir/network/firewall.txt" ufw status verbose
    fi
    
    if command -v firewall-cmd &>/dev/null; then
        exec_cmd "Firewalld Zones" "$output_dir/network/firewall.txt" firewall-cmd --list-all-zones
    fi
    
    exec_cmd "DNS Configuration" "$output_dir/network/dns.txt" cat /etc/resolv.conf
    exec_cmd "Hosts File" "$output_dir/network/hosts.txt" cat /etc/hosts
    
    log_success "Network information collected"
}

collect_process_info() {
    local output_dir="$1"
    log_section "Collecting Process Information"
    
    exec_cmd "Process List (detailed)" "$output_dir/processes/processes.txt" ps auxf
    exec_cmd "Process Tree" "$output_dir/processes/process-tree.txt" pstree -p
    
    exec_cmd "Open Files" "$output_dir/processes/open-files.txt" lsof -n
    exec_cmd "Open Network Files" "$output_dir/processes/network-files.txt" lsof -i -n
    
    exec_cmd "Running Services (systemd)" "$output_dir/processes/services.txt" systemctl list-units --type=service --all
    
    if [[ "$QUICK_MODE" == false ]]; then
        # Detailed per-process information for suspicious processes
        log_info "Collecting detailed process information..."
        
        {
            echo "# Process Details with Command Lines and Open Files"
            echo "# Collected: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
            echo
            
            for pid in /proc/[0-9]*; do
                if [[ -d "$pid" ]]; then
                    pid_num=$(basename "$pid")
                    echo "=== PID: $pid_num ==="
                    echo "Command: $(cat "$pid/cmdline" 2>/dev/null | tr '\0' ' ')"
                    echo "CWD: $(readlink "$pid/cwd" 2>/dev/null || echo 'N/A')"
                    echo "EXE: $(readlink "$pid/exe" 2>/dev/null || echo 'N/A')"
                    echo
                fi
            done
        } > "$output_dir/processes/process-details.txt"
    fi
    
    log_success "Process information collected"
}

collect_user_activity() {
    local output_dir="$1"
    log_section "Collecting User Activity"
    
    exec_cmd "User Accounts" "$output_dir/users/accounts.txt" cat /etc/passwd
    exec_cmd "Group Information" "$output_dir/users/groups.txt" cat /etc/group
    exec_cmd "Shadow File (hashes)" "$output_dir/users/shadow.txt" cat /etc/shadow
    exec_cmd "Sudoers Configuration" "$output_dir/users/sudoers.txt" cat /etc/sudoers
    
    if [[ -d /etc/sudoers.d ]]; then
        exec_cmd "Sudoers.d Directory" "$output_dir/users/sudoers.txt" find /etc/sudoers.d -type f -exec cat {} \;
    fi
    
    exec_cmd "Currently Logged In Users" "$output_dir/users/current-logins.txt" w
    exec_cmd "Last Logins" "$output_dir/users/login-history.txt" last -F -a
    exec_cmd "Failed Login Attempts" "$output_dir/users/failed-logins.txt" lastb -F -a
    
    # Collect user bash histories
    log_info "Collecting user command histories..."
    {
        echo "# User Command Histories"
        echo "# Collected: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo
        
        for homedir in /home/* /root; do
            if [[ -d "$homedir" ]]; then
                username=$(basename "$homedir")
                echo "=== User: $username ==="
                
                if [[ -f "$homedir/.bash_history" ]]; then
                    echo "--- Bash History ---"
                    cat "$homedir/.bash_history" 2>/dev/null || echo "Cannot read history"
                fi
                
                if [[ -f "$homedir/.zsh_history" ]]; then
                    echo "--- Zsh History ---"
                    cat "$homedir/.zsh_history" 2>/dev/null || echo "Cannot read history"
                fi
                
                echo
            fi
        done
    } > "$output_dir/users/command-history.txt"
    
    # SSH authorized keys
    {
        echo "# SSH Authorized Keys"
        echo "# Collected: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo
        
        for homedir in /home/* /root; do
            if [[ -d "$homedir/.ssh" ]]; then
                username=$(basename "$homedir")
                echo "=== User: $username ==="
                
                if [[ -f "$homedir/.ssh/authorized_keys" ]]; then
                    cat "$homedir/.ssh/authorized_keys"
                fi
                echo
            fi
        done
    } > "$output_dir/users/ssh-authorized-keys.txt"
    
    log_success "User activity collected"
}

collect_system_logs() {
    local output_dir="$1"
    log_section "Collecting System Logs"
    
    # Copy important log files
    log_info "Copying log files..."
    
    local log_files=(
        "/var/log/auth.log"
        "/var/log/secure"
        "/var/log/syslog"
        "/var/log/messages"
        "/var/log/kern.log"
        "/var/log/cron"
        "/var/log/dmesg"
        "/var/log/boot.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            cp "$log_file" "$output_dir/logs/" 2>/dev/null || log_warning "Cannot copy $log_file"
        fi
    done
    
    # Journal logs
    if command -v journalctl &>/dev/null; then
        exec_cmd "System Journal (last 10000 lines)" "$output_dir/logs/journal.txt" journalctl -n 10000 --no-pager
        exec_cmd "Boot Messages" "$output_dir/logs/journal-boot.txt" journalctl -b --no-pager
    fi
    
    log_success "System logs collected"
}

collect_filesystem_info() {
    local output_dir="$1"
    log_section "Collecting Filesystem Information"
    
    exec_cmd "Mounted Filesystems" "$output_dir/filesystem/mounts.txt" mount
    exec_cmd "Disk Usage" "$output_dir/filesystem/disk-usage.txt" df -h
    exec_cmd "Block Devices" "$output_dir/filesystem/block-devices.txt" lsblk -f
    
    exec_cmd "Fstab" "$output_dir/filesystem/fstab.txt" cat /etc/fstab
    
    # Find recently modified files
    if [[ "$QUICK_MODE" == false ]]; then
        log_info "Finding recently modified files (last 7 days)..."
        exec_cmd "Recently Modified Files" "$output_dir/filesystem/recent-files.txt" \
            find / -type f -mtime -7 -ls 2>/dev/null
        
        log_info "Finding SUID/SGID files..."
        exec_cmd "SUID Files" "$output_dir/filesystem/suid-files.txt" \
            find / -perm -4000 -type f -ls 2>/dev/null
        exec_cmd "SGID Files" "$output_dir/filesystem/sgid-files.txt" \
            find / -perm -2000 -type f -ls 2>/dev/null
    fi
    
    log_success "Filesystem information collected"
}

collect_persistence_mechanisms() {
    local output_dir="$1"
    log_section "Collecting Persistence Mechanisms"
    
    exec_cmd "Systemd Services" "$output_dir/persistence/systemd-services.txt" \
        systemctl list-unit-files --type=service
    
    exec_cmd "Cron Jobs (system)" "$output_dir/persistence/cron-system.txt" \
        cat /etc/crontab
    
    if [[ -d /etc/cron.d ]]; then
        exec_cmd "Cron.d Directory" "$output_dir/persistence/cron-crond.txt" \
            find /etc/cron.d -type f -exec cat {} \;
    fi
    
    # User cron jobs
    {
        echo "# User Cron Jobs"
        echo "# Collected: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo
        
        while IFS=: read -r user _; do
            crontab -u "$user" -l 2>/dev/null && echo "=== User: $user ===" || true
        done < /etc/passwd
    } > "$output_dir/persistence/cron-users.txt"
    
    exec_cmd "Init Scripts" "$output_dir/persistence/init-scripts.txt" \
        ls -la /etc/init.d/
    
    exec_cmd "RC Scripts" "$output_dir/persistence/rc-scripts.txt" \
        find /etc/rc*.d/ -type l -ls 2>/dev/null
    
    # Startup files
    {
        echo "# System Startup Files"
        echo "# Collected: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo
        
        for file in /etc/rc.local /etc/profile /etc/bash.bashrc; do
            if [[ -f "$file" ]]; then
                echo "=== $file ==="
                cat "$file"
                echo
            fi
        done
    } > "$output_dir/persistence/startup-files.txt"
    
    log_success "Persistence mechanisms collected"
}

collect_security_state() {
    local output_dir="$1"
    log_section "Collecting Security State"
    
    # SELinux
    if command -v getenforce &>/dev/null; then
        exec_cmd "SELinux Status" "$output_dir/security/selinux.txt" getenforce
        exec_cmd "SELinux Configuration" "$output_dir/security/selinux.txt" cat /etc/selinux/config
    fi
    
    # AppArmor
    if command -v aa-status &>/dev/null; then
        exec_cmd "AppArmor Status" "$output_dir/security/apparmor.txt" aa-status
    fi
    
    # Installed packages
    if command -v dpkg &>/dev/null; then
        exec_cmd "Installed Packages (dpkg)" "$output_dir/security/packages.txt" dpkg -l
    elif command -v rpm &>/dev/null; then
        exec_cmd "Installed Packages (rpm)" "$output_dir/security/packages.txt" rpm -qa
    fi
    
    # Check for suspicious packages or backdoors
    log_info "Checking for suspicious patterns..."
    {
        echo "# Suspicious File Patterns"
        echo "# Collected: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo
        
        echo "=== Hidden Directories in /tmp ==="
        find /tmp -type d -name ".*" 2>/dev/null || echo "None found"
        echo
        
        echo "=== World-Writable Files ==="
        find / -xdev -type f -perm -0002 ! -path "/proc/*" ! -path "/sys/*" 2>/dev/null | head -50 || echo "None found"
        echo
        
    } > "$output_dir/security/suspicious-patterns.txt"
    
    log_success "Security state collected"
}

collect_memory_dump() {
    local output_dir="$1"
    log_section "Collecting Memory Dump"
    
    log_warning "Memory dump collection can take significant time and disk space"
    
    if command -v avml &>/dev/null; then
        log_info "Using AVML for memory acquisition..."
        avml "$output_dir/memory.lime" 2>&1 | tee -a "$output_dir/collection.log"
        log_success "Memory dump created: memory.lime"
    elif [[ -f /proc/kcore ]]; then
        log_info "Copying /proc/kcore (this may take a while)..."
        dd if=/proc/kcore of="$output_dir/memory.raw" bs=1M 2>&1 | tee -a "$output_dir/collection.log" || \
            log_warning "Memory dump via /proc/kcore failed"
    else
        log_warning "No suitable memory acquisition tool found"
        log_info "Consider installing: AVML, LiME, or other memory forensics tools"
    fi
}

generate_hashes() {
    local output_dir="$1"
    log_section "Generating Evidence Hashes"
    
    log_info "Computing SHA-256 hashes for all collected files..."
    
    {
        echo "# Evidence Integrity Hashes (SHA-256)"
        echo "# Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo
        
        find "$output_dir" -type f ! -name "checksums.txt" -exec sha256sum {} \;
    } > "$output_dir/checksums.txt"
    
    log_success "Hash file created: checksums.txt"
}

generate_summary() {
    local output_dir="$1"
    local end_time="$2"
    
    log_section "Generating Collection Summary"
    
    local summary_file="$output_dir/COLLECTION-SUMMARY.txt"
    
    {
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║         FORENSIC EVIDENCE COLLECTION SUMMARY               ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo
        echo "Collection Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo "End Time: $end_time"
        echo "Hostname: $(hostname)"
        echo "Collection Directory: $output_dir"
        echo
        echo "───────────────────────────────────────────────────────────"
        echo "Collected Evidence Categories:"
        echo "───────────────────────────────────────────────────────────"
        echo
        
        [[ -d "$output_dir/system" ]] && echo "  ✓ System Information"
        [[ -d "$output_dir/network" ]] && echo "  ✓ Network State"
        [[ -d "$output_dir/processes" ]] && echo "  ✓ Process Information"
        [[ -d "$output_dir/users" ]] && echo "  ✓ User Activity"
        [[ -d "$output_dir/logs" ]] && echo "  ✓ System Logs"
        [[ -d "$output_dir/filesystem" ]] && echo "  ✓ Filesystem Information"
        [[ -d "$output_dir/persistence" ]] && echo "  ✓ Persistence Mechanisms"
        [[ -d "$output_dir/security" ]] && echo "  ✓ Security State"
        [[ -f "$output_dir/memory.lime" || -f "$output_dir/memory.raw" ]] && echo "  ✓ Memory Dump"
        
        echo
        echo "───────────────────────────────────────────────────────────"
        echo "Collection Statistics:"
        echo "───────────────────────────────────────────────────────────"
        echo
        echo "Total Files: $(find "$output_dir" -type f | wc -l)"
        echo "Total Size: $(du -sh "$output_dir" | cut -f1)"
        echo
        echo "Evidence Integrity:"
        echo "  SHA-256 checksums: checksums.txt"
        echo
        echo "───────────────────────────────────────────────────────────"
        echo "Next Steps:"
        echo "───────────────────────────────────────────────────────────"
        echo
        echo "1. Verify evidence integrity using checksums.txt"
        echo "2. Archive the entire directory for secure storage"
        echo "3. Document chain of custody"
        echo "4. Begin analysis using appropriate forensic tools"
        echo
        echo "Important: Preserve the original evidence and work with copies"
        echo
        
    } > "$summary_file"
    
    cat "$summary_file"
    
    log_success "Collection complete!"
    log_info "Review the summary: $summary_file"
}

# Main script
main() {
    local OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -q|--quick)
                QUICK_MODE=true
                shift
                ;;
            -m|--memory)
                INCLUDE_MEMORY=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
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
    
    # Display banner
    echo
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║      Forensic Evidence Collection Tool                    ║${NC}"
    echo -e "${MAGENTA}║      For Authorized Incident Response Only                ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Check prerequisites
    check_root "$@"
    
    if ! check_disk_space "$OUTPUT_DIR"; then
        exit 1
    fi
    
    # Setup output directory
    setup_output_dir "$OUTPUT_DIR"
    
    # Log all output to collection log
    exec > >(tee -a "$OUTPUT_DIR/collection.log")
    exec 2>&1
    
    local start_time
    start_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    
    log_info "Starting evidence collection at $start_time"
    log_info "Mode: $([ "$QUICK_MODE" == true ] && echo "Quick" || echo "Full")"
    
    # Collect evidence
    collect_system_info "$OUTPUT_DIR"
    collect_network_info "$OUTPUT_DIR"
    collect_process_info "$OUTPUT_DIR"
    collect_user_activity "$OUTPUT_DIR"
    collect_system_logs "$OUTPUT_DIR"
    collect_filesystem_info "$OUTPUT_DIR"
    collect_persistence_mechanisms "$OUTPUT_DIR"
    collect_security_state "$OUTPUT_DIR"
    
    if [[ "$INCLUDE_MEMORY" == true ]]; then
        collect_memory_dump "$OUTPUT_DIR"
    fi
    
    # Generate hashes
    generate_hashes "$OUTPUT_DIR"
    
    local end_time
    end_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    
    # Generate summary
    generate_summary "$OUTPUT_DIR" "$end_time"
}

# Run main function
main "$@"
