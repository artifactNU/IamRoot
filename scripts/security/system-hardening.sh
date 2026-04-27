#!/bin/bash

################################################################################
# System Security Hardening Tool
# 
# Description: Audits and applies security hardening measures for Linux systems.
#              WARNING: In --apply mode this tool WILL modify system settings.
#              In --audit mode it only reads system state and does NOT change it.
# Usage: ./system-hardening.sh [--audit|--apply|--help]
#
# What can change in --apply mode:
#   - SSH configuration (/etc/ssh/sshd_config)
#   - Firewall state (ufw/firewalld)
#   - System updates (apt/yum upgrade)
#   - Account locks for empty passwords
#   - File permissions for critical files
#   - Kernel parameters (sysctl and /etc/sysctl.conf)
#   - Service enable/disable (auditd, risky services)
#
# What can break or require follow-up:
#   - SSH access can be disrupted if settings conflict with your access method
#   - Firewall changes can block network traffic
#   - Kernel parameter changes can impact networking or routing
#   - Package updates can require reboots or restart services
#   - Disabling services may impact dependent apps
#
# Modes:
#   --audit : Check security settings without making changes (default)
#   --apply : Apply security hardening measures
#   --help  : Display this help message
#
# Requirements: Root privileges for most checks and all modifications
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
APPLIED_COUNT=0

# Mode selection
MODE="audit"

################################################################################
# Utility Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_check() {
    echo -e "${YELLOW}[CHECK]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS_COUNT++))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL_COUNT++))
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARN_COUNT++))
}

print_applied() {
    echo -e "${GREEN}[APPLIED]${NC} $1"
    ((APPLIED_COUNT++))
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Backed up $file"
    fi
}

################################################################################
# SSH Hardening Checks
################################################################################

check_ssh_hardening() {
    print_header "SSH Security Configuration"
    
    if [[ ! -f /etc/ssh/sshd_config ]]; then
        print_warn "SSH server not installed or config not found"
        return
    fi
    
    # Check PermitRootLogin
    print_check "Checking SSH root login setting..."
    if grep -qE "^PermitRootLogin\s+(no|prohibit-password)" /etc/ssh/sshd_config; then
        print_pass "Root login is disabled or restricted"
    else
        print_fail "Root login should be disabled"
        if [[ "$MODE" == "apply" ]]; then
            backup_file /etc/ssh/sshd_config
            sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
            print_applied "Set PermitRootLogin to prohibit-password"
        fi
    fi
    
    # Check PasswordAuthentication
    print_check "Checking password authentication..."
    if grep -qE "^PasswordAuthentication\s+no" /etc/ssh/sshd_config; then
        print_pass "Password authentication is disabled (key-based only)"
    else
        print_warn "Consider disabling password authentication for key-based auth only"
        if [[ "$MODE" == "apply" ]]; then
            read -p "Disable password authentication? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                backup_file /etc/ssh/sshd_config
                sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
                print_applied "Disabled password authentication"
            fi
        fi
    fi
    
    # Check Protocol 2
    print_check "Checking SSH protocol version..."
    if grep -qE "^Protocol\s+2" /etc/ssh/sshd_config || ! grep -qE "^Protocol" /etc/ssh/sshd_config; then
        print_pass "SSH Protocol 2 is enforced (or default)"
    else
        print_fail "SSH should use Protocol 2 only"
        if [[ "$MODE" == "apply" ]]; then
            backup_file /etc/ssh/sshd_config
            echo "Protocol 2" >> /etc/ssh/sshd_config
            print_applied "Set SSH Protocol to 2"
        fi
    fi
    
    # Check X11Forwarding
    print_check "Checking X11 forwarding..."
    if grep -qE "^X11Forwarding\s+no" /etc/ssh/sshd_config; then
        print_pass "X11 forwarding is disabled"
    else
        print_warn "X11 forwarding should be disabled unless needed"
        if [[ "$MODE" == "apply" ]]; then
            backup_file /etc/ssh/sshd_config
            sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
            print_applied "Disabled X11 forwarding"
        fi
    fi
    
    # Check MaxAuthTries
    print_check "Checking max authentication attempts..."
    if grep -qE "^MaxAuthTries\s+[1-4]" /etc/ssh/sshd_config; then
        print_pass "MaxAuthTries is set to a secure value"
    else
        print_warn "MaxAuthTries should be set to 4 or less"
        if [[ "$MODE" == "apply" ]]; then
            backup_file /etc/ssh/sshd_config
            sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 4/' /etc/ssh/sshd_config
            print_applied "Set MaxAuthTries to 4"
        fi
    fi
}

################################################################################
# Firewall Checks
################################################################################

check_firewall() {
    print_header "Firewall Configuration"
    
    # Check if firewall is active
    print_check "Checking firewall status..."
    
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            print_pass "UFW firewall is active"
        else
            print_fail "UFW is installed but not active"
            if [[ "$MODE" == "apply" ]]; then
                ufw --force enable
                print_applied "Enabled UFW firewall"
            fi
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            print_pass "firewalld is active"
        else
            print_fail "firewalld is installed but not active"
            if [[ "$MODE" == "apply" ]]; then
                systemctl start firewalld
                systemctl enable firewalld
                print_applied "Started and enabled firewalld"
            fi
        fi
    elif command -v iptables &> /dev/null; then
        if iptables -L -n | grep -q "Chain INPUT"; then
            print_warn "iptables is available but status unclear - manual review recommended"
        else
            print_fail "No active firewall detected"
        fi
    else
        print_fail "No firewall detected (ufw, firewalld, or iptables)"
    fi
}

################################################################################
# System Updates Check
################################################################################

check_system_updates() {
    print_header "System Updates"
    
    print_check "Checking for available system updates..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update -qq 2>/dev/null || true
        UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
        if [[ $UPDATES -eq 0 ]] || [[ $UPDATES -eq 1 ]]; then
            print_pass "System is up to date"
        else
            print_warn "$UPDATES package updates available"
            if [[ "$MODE" == "apply" ]]; then
                read -p "Install updates now? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    apt-get upgrade -y
                    print_applied "Installed system updates"
                fi
            fi
        fi
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        UPDATES=$(yum check-update -q | grep -vc "^$")
        if [[ $UPDATES -eq 0 ]]; then
            print_pass "System is up to date"
        else
            print_warn "$UPDATES package updates available"
            if [[ "$MODE" == "apply" ]]; then
                read -p "Install updates now? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    yum update -y
                    print_applied "Installed system updates"
                fi
            fi
        fi
    else
        print_warn "Unknown package manager - cannot check for updates"
    fi
}

################################################################################
# User and Password Policies
################################################################################

check_password_policies() {
    print_header "Password and Account Policies"
    
    # Check password aging
    print_check "Checking password aging policies..."
    if grep -qE "^PASS_MAX_DAYS\s+[0-9]+" /etc/login.defs; then
        MAX_DAYS=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
        if [[ $MAX_DAYS -le 90 ]]; then
            print_pass "Password expiration set to $MAX_DAYS days"
        else
            print_warn "Password expiration should be 90 days or less (currently $MAX_DAYS)"
        fi
    else
        print_warn "Password expiration not configured"
    fi
    
    # Check for accounts with empty passwords
    print_check "Checking for accounts with empty passwords..."
    EMPTY_PASS=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | wc -l)
    if [[ $EMPTY_PASS -eq 0 ]]; then
        print_pass "No accounts with empty passwords found"
    else
        print_fail "$EMPTY_PASS account(s) have empty passwords"
        if [[ "$MODE" == "apply" ]]; then
            print_info "Locking accounts with empty passwords..."
            awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | while read -r user; do
                passwd -l "$user"
                print_applied "Locked account: $user"
            done
        fi
    fi
    
    # Check for UID 0 accounts other than root
    print_check "Checking for non-root UID 0 accounts..."
    UID_ZERO=$(awk -F: '($3 == 0 && $1 != "root") {print $1}' /etc/passwd)
    if [[ -z "$UID_ZERO" ]]; then
        print_pass "Only root has UID 0"
    else
        print_fail "Non-root accounts with UID 0 found: $UID_ZERO"
    fi
}

################################################################################
# File System Permissions
################################################################################

check_file_permissions() {
    print_header "Critical File Permissions"
    
    # Check /etc/passwd permissions
    print_check "Checking /etc/passwd permissions..."
    PERMS=$(stat -c %a /etc/passwd)
    if [[ "$PERMS" == "644" ]]; then
        print_pass "/etc/passwd has correct permissions (644)"
    else
        print_fail "/etc/passwd has incorrect permissions ($PERMS)"
        if [[ "$MODE" == "apply" ]]; then
            chmod 644 /etc/passwd
            print_applied "Set /etc/passwd permissions to 644"
        fi
    fi
    
    # Check /etc/shadow permissions
    print_check "Checking /etc/shadow permissions..."
    if [[ -f /etc/shadow ]]; then
        PERMS=$(stat -c %a /etc/shadow)
        if [[ "$PERMS" == "000" ]] || [[ "$PERMS" == "400" ]] || [[ "$PERMS" == "600" ]]; then
            print_pass "/etc/shadow has correct permissions ($PERMS)"
        else
            print_fail "/etc/shadow has incorrect permissions ($PERMS)"
            if [[ "$MODE" == "apply" ]]; then
                chmod 600 /etc/shadow
                print_applied "Set /etc/shadow permissions to 600"
            fi
        fi
    fi
    
    # Check /etc/group permissions
    print_check "Checking /etc/group permissions..."
    PERMS=$(stat -c %a /etc/group)
    if [[ "$PERMS" == "644" ]]; then
        print_pass "/etc/group has correct permissions (644)"
    else
        print_fail "/etc/group has incorrect permissions ($PERMS)"
        if [[ "$MODE" == "apply" ]]; then
            chmod 644 /etc/group
            print_applied "Set /etc/group permissions to 644"
        fi
    fi
    
    # Check for world-writable files
    print_check "Checking for world-writable files in system directories..."
    print_info "This may take a moment..."
    WORLD_WRITABLE=$(find /etc /usr /bin /sbin -xdev -type f -perm -0002 2>/dev/null | head -10)
    if [[ -z "$WORLD_WRITABLE" ]]; then
        print_pass "No world-writable files found in critical directories"
    else
        print_warn "World-writable files found (showing first 10):"
        echo "$WORLD_WRITABLE"
    fi
}

################################################################################
# Kernel Parameters (sysctl)
################################################################################

check_kernel_parameters() {
    print_header "Kernel Security Parameters"
    
    # IP forwarding
    print_check "Checking IP forwarding..."
    if [[ $(sysctl -n net.ipv4.ip_forward) -eq 0 ]]; then
        print_pass "IP forwarding is disabled"
    else
        print_warn "IP forwarding is enabled (disable unless this is a router)"
        if [[ "$MODE" == "apply" ]]; then
            sysctl -w net.ipv4.ip_forward=0 >/dev/null
            echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf
            print_applied "Disabled IP forwarding"
        fi
    fi
    
    # ICMP redirects
    print_check "Checking ICMP redirect acceptance..."
    if [[ $(sysctl -n net.ipv4.conf.all.accept_redirects) -eq 0 ]]; then
        print_pass "ICMP redirects are disabled"
    else
        print_fail "ICMP redirects should be disabled"
        if [[ "$MODE" == "apply" ]]; then
            sysctl -w net.ipv4.conf.all.accept_redirects=0 >/dev/null
            sysctl -w net.ipv4.conf.default.accept_redirects=0 >/dev/null
            echo "net.ipv4.conf.all.accept_redirects=0" >> /etc/sysctl.conf
            echo "net.ipv4.conf.default.accept_redirects=0" >> /etc/sysctl.conf
            print_applied "Disabled ICMP redirects"
        fi
    fi
    
    # Source packet routing
    print_check "Checking source packet routing..."
    if [[ $(sysctl -n net.ipv4.conf.all.accept_source_route) -eq 0 ]]; then
        print_pass "Source packet routing is disabled"
    else
        print_fail "Source packet routing should be disabled"
        if [[ "$MODE" == "apply" ]]; then
            sysctl -w net.ipv4.conf.all.accept_source_route=0 >/dev/null
            sysctl -w net.ipv4.conf.default.accept_source_route=0 >/dev/null
            echo "net.ipv4.conf.all.accept_source_route=0" >> /etc/sysctl.conf
            echo "net.ipv4.conf.default.accept_source_route=0" >> /etc/sysctl.conf
            print_applied "Disabled source packet routing"
        fi
    fi
    
    # SYN cookies
    print_check "Checking SYN cookies (SYN flood protection)..."
    if [[ $(sysctl -n net.ipv4.tcp_syncookies) -eq 1 ]]; then
        print_pass "SYN cookies are enabled"
    else
        print_fail "SYN cookies should be enabled"
        if [[ "$MODE" == "apply" ]]; then
            sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null
            echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf
            print_applied "Enabled SYN cookies"
        fi
    fi
}

################################################################################
# Services and Processes
################################################################################

check_unnecessary_services() {
    print_header "Unnecessary Services Check"
    
    # List of commonly unnecessary services
    RISKY_SERVICES=("telnet" "rsh" "rlogin" "vsftpd" "ftpd")
    
    print_check "Checking for risky/unnecessary services..."
    FOUND_RISKY=0
    for service in "${RISKY_SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                print_fail "$service is active (should be disabled)"
                FOUND_RISKY=1
                if [[ "$MODE" == "apply" ]]; then
                    systemctl stop "$service"
                    systemctl disable "$service"
                    print_applied "Stopped and disabled $service"
                fi
            fi
        fi
    done
    
    if [[ $FOUND_RISKY -eq 0 ]]; then
        print_pass "No risky services found running"
    fi
}

################################################################################
# Audit Configuration
################################################################################

check_audit_system() {
    print_header "Audit System Configuration"
    
    print_check "Checking if auditd is installed and running..."
    if command -v auditd &> /dev/null || command -v auditctl &> /dev/null; then
        if systemctl is-active --quiet auditd 2>/dev/null; then
            print_pass "auditd is installed and running"
        else
            print_warn "auditd is installed but not running"
            if [[ "$MODE" == "apply" ]]; then
                systemctl start auditd
                systemctl enable auditd
                print_applied "Started and enabled auditd"
            fi
        fi
    else
        print_warn "auditd is not installed (recommended for security auditing)"
        if [[ "$MODE" == "apply" ]]; then
            read -p "Install auditd? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if command -v apt-get &> /dev/null; then
                    apt-get install -y auditd
                elif command -v yum &> /dev/null; then
                    yum install -y audit
                fi
                systemctl start auditd
                systemctl enable auditd
                print_applied "Installed and enabled auditd"
            fi
        fi
    fi
}

################################################################################
# Summary and Report
################################################################################

print_summary() {
    print_header "Security Hardening Summary"
    
    echo -e "${GREEN}Passed checks:${NC} $PASS_COUNT"
    echo -e "${RED}Failed checks:${NC} $FAIL_COUNT"
    echo -e "${YELLOW}Warnings:${NC} $WARN_COUNT"
    
    if [[ "$MODE" == "apply" ]]; then
        echo -e "${GREEN}Changes applied:${NC} $APPLIED_COUNT"
        echo ""
        print_info "Some changes may require a system restart to take full effect"
        print_info "SSH configuration changes require: systemctl restart sshd"
    else
        echo ""
        print_info "Run with --apply to automatically fix issues"
    fi
    
    echo ""
    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo -e "${RED}Security hardening is needed!${NC}"
        exit 1
    elif [[ $WARN_COUNT -gt 0 ]]; then
        echo -e "${YELLOW}Security is good but could be improved${NC}"
        exit 0
    else
        echo -e "${GREEN}System security posture is strong!${NC}"
        exit 0
    fi
}

################################################################################
# Main Execution
################################################################################

show_help() {
    cat << EOF
System Security Hardening Tool

Usage: $0 [OPTIONS]

Options:
    --audit     Audit security settings without making changes (default)
    --apply     Apply security hardening measures
    --help      Display this help message

Description:
    This tool audits and applies security hardening measures for Linux systems.
    In --audit mode it ONLY reads system state and makes NO changes.
    In --apply mode it WILL modify system configuration and services.

    Changes that MAY occur in --apply mode:
      - SSH configuration: /etc/ssh/sshd_config
      - Firewall state: ufw or firewalld
      - System updates: apt/yum upgrade
      - Account locks: empty-password accounts
      - File permissions: /etc/passwd, /etc/shadow, /etc/group
      - Kernel parameters: sysctl runtime + /etc/sysctl.conf
      - Services: start/enable auditd, stop/disable risky services

    What can break or need follow-up:
      - SSH access can be lost if settings conflict with your login method
      - Firewall changes can block required ports/traffic
      - Kernel tuning can affect routing, containers, or networking
      - Updates can require reboot or service restarts
      - Disabling services can impact dependent applications

Examples:
    $0 --audit          # Check security without making changes
    $0 --apply          # Apply hardening measures (requires root)
    sudo $0 --apply     # Apply hardening measures as root

Note:
    Most checks and all modifications require root privileges.

EOF
    exit 0
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --audit)
                MODE="audit"
                shift
                ;;
            --apply)
                MODE="apply"
                require_root
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Print mode
    print_header "System Security Hardening Tool"
    if [[ "$MODE" == "audit" ]]; then
        echo -e "${BLUE}Mode: AUDIT ONLY (no changes will be made)${NC}"
        print_info "Audit mode reads system state only; it does NOT change anything"
    else
        echo -e "${YELLOW}Mode: APPLY (changes WILL be made to the system)${NC}"
        print_warn "Apply mode modifies system configuration, services, and settings"
        print_warn "SSH/firewall updates can block access; review prompts carefully"
    fi
    echo ""
    
    # Warn if not root in audit mode
    if [[ $EUID -ne 0 ]] && [[ "$MODE" == "audit" ]]; then
        print_warn "Not running as root - some checks may be limited"
        echo ""
    fi
    
    # Run all checks
    check_ssh_hardening
    check_firewall
    check_system_updates
    check_password_policies
    check_file_permissions
    check_kernel_parameters
    check_unnecessary_services
    check_audit_system
    
    # Print summary
    print_summary
}

# Run main function
main "$@"
