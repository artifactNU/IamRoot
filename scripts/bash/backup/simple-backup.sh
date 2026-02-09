#!/usr/bin/env bash
# simple-backup.sh
# Purpose: Simple directory backup using rsync with verification
# Usage:   ./simple-backup.sh SOURCE_DIR BACKUP_DIR
# Exit:    0 OK, 1 ERROR

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Rsync options
RSYNC_OPTS=(
    --archive           # Preserve permissions, timestamps, etc.
    --verbose           # Show what's being copied
    --human-readable    # Human-readable sizes
    --delete            # Delete files in dest that don't exist in source
    --partial           # Keep partially transferred files
    --progress          # Show progress
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FUNCTIONS
# ============================================================================

print_usage() {
    cat << EOF
Usage: $(basename "$0") SOURCE_DIR BACKUP_DIR [OPTIONS]

Simple incremental backup using rsync.

Arguments:
  SOURCE_DIR    Directory to backup (e.g., /home/user/data)
  BACKUP_DIR    Backup destination (e.g., /backup/data)

Options:
  -h, --help           Show this help message
  -n, --dry-run        Show what would be backed up without doing it
  -e, --exclude PATTERN  Exclude files matching pattern (can be used multiple times)
  --no-delete          Don't delete files in backup that don't exist in source

Examples:
  # Basic backup
  $(basename "$0") /home/user/documents /backup/documents

  # Dry run (test without making changes)
  $(basename "$0") -n /home/user/documents /backup/documents

  # Exclude certain files
  $(basename "$0") -e "*.tmp" -e "cache/" /var/www /backup/www

  # Backup without deleting removed files
  $(basename "$0") --no-delete /home/user/data /backup/data

Notes:
  - Requires rsync to be installed
  - Preserves permissions, timestamps, and symlinks
  - Creates backup directory if it doesn't exist
  - Safe to run multiple times (incremental)
  - Use --dry-run first to preview changes

EOF
}

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $*"
}

check_dependencies() {
    if ! command -v rsync &> /dev/null; then
        log_error "rsync is not installed"
        log_error "Install with: sudo apt-get install rsync"
        exit 1
    fi
}

validate_source() {
    local source=$1
    
    if [[ ! -d "$source" ]]; then
        log_error "Source directory does not exist: $source"
        exit 1
    fi
    
    if [[ ! -r "$source" ]]; then
        log_error "Source directory is not readable: $source"
        exit 1
    fi
}

prepare_backup_dir() {
    local backup_dir=$1
    
    # Create backup directory if it doesn't exist
    if [[ ! -d "$backup_dir" ]]; then
        log "Creating backup directory: $backup_dir"
        mkdir -p "$backup_dir" || {
            log_error "Failed to create backup directory: $backup_dir"
            exit 1
        }
    fi
    
    # Check if writable
    if [[ ! -w "$backup_dir" ]]; then
        log_error "Backup directory is not writable: $backup_dir"
        exit 1
    fi
}

calculate_size() {
    local dir=$1
    du -sh "$dir" 2>/dev/null | cut -f1 || echo "unknown"
}

check_disk_space() {
    local source=$1
    local dest=$2
    
    # Get source size in KB
    local source_size
    source_size=$(du -sk "$source" 2>/dev/null | cut -f1)
    
    # Get available space in destination in KB
    local dest_available
    dest_available=$(df -k "$(dirname "$dest")" | awk 'NR==2 {print $4}')
    
    # Check if we have at least source size + 10% buffer
    local required_space=$((source_size + source_size / 10))
    
    if [[ $dest_available -lt $required_space ]]; then
        log_warning "Low disk space in destination"
        log_warning "Required: ~$((required_space / 1024))MB, Available: $((dest_available / 1024))MB"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Backup cancelled"
            exit 0
        fi
    fi
}

perform_backup() {
    local source=$1
    local backup_dir=$2
    local dry_run=$3
    shift 3
    local rsync_opts=("$@")
    
    log "Starting backup"
    log "Source: $source"
    log "Destination: $backup_dir"
    log "Options: ${rsync_opts[*]}"
    
    if [[ "$dry_run" == "true" ]]; then
        log_warning "DRY RUN MODE - No changes will be made"
        rsync_opts+=(--dry-run)
    fi
    
    # Add trailing slash to source to copy contents
    if [[ "${source}" != */ ]]; then
        source="${source}/"
    fi
    
    local start_time
    start_time=$(date +%s)
    
    # Perform backup
    if rsync "${rsync_opts[@]}" "$source" "$backup_dir"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "Backup completed in ${duration}s"
        
        if [[ "$dry_run" != "true" ]]; then
            local backup_size
            backup_size=$(calculate_size "$backup_dir")
            log_success "Backup size: $backup_size"
        fi
        
        return 0
    else
        log_error "Backup failed"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Parse arguments
    local source=""
    local backup_dir=""
    local dry_run=false
    local exclude_patterns=()
    local no_delete=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -e|--exclude)
                exclude_patterns+=("--exclude=$2")
                shift 2
                ;;
            --no-delete)
                no_delete=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                if [[ -z "$source" ]]; then
                    source=$1
                elif [[ -z "$backup_dir" ]]; then
                    backup_dir=$1
                else
                    log_error "Too many arguments"
                    print_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$source" ]] || [[ -z "$backup_dir" ]]; then
        log_error "Missing required arguments"
        print_usage
        exit 1
    fi
    
    # Remove --delete if no-delete flag is set
    if [[ "$no_delete" == "true" ]]; then
        RSYNC_OPTS=("${RSYNC_OPTS[@]/--delete/}")
    fi
    
    # Add exclude patterns
    if [[ ${#exclude_patterns[@]} -gt 0 ]]; then
        RSYNC_OPTS+=("${exclude_patterns[@]}")
    fi
    
    # Checks
    check_dependencies
    validate_source "$source"
    prepare_backup_dir "$backup_dir"
    
    # Show info
    log "Source size: $(calculate_size "$source")"
    
    if [[ "$dry_run" != "true" ]]; then
        check_disk_space "$source" "$backup_dir"
    fi
    
    # Perform backup
    if perform_backup "$source" "$backup_dir" "$dry_run" "${RSYNC_OPTS[@]}"; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
