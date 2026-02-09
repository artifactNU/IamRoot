#!/usr/bin/env bash
# cleanup-old-files.sh
# Purpose: Safely find and remove old files with size/age filters
# Usage:   ./cleanup-old-files.sh DIRECTORY [OPTIONS]
# Exit:    0 OK, 1 ERROR

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Default values
DEFAULT_AGE_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# FUNCTIONS
# ============================================================================

print_usage() {
    cat << EOF
Usage: $(basename "$0") DIRECTORY [OPTIONS]

Find and optionally remove old files based on age, size, and pattern filters.

Arguments:
  DIRECTORY         Directory to search for old files

Options:
  -h, --help              Show this help message
  -n, --dry-run           Show files that would be deleted without deleting
  -a, --age DAYS          Files older than DAYS days (default: 30)
  -s, --min-size SIZE     Minimum file size (e.g., 10M, 1G)
  -m, --max-size SIZE     Maximum file size (e.g., 100M, 5G)
  -d, --max-depth N       Maximum directory depth to search
  -p, --pattern PATTERN   Only match files matching pattern (e.g., "*.log")
  -e, --exclude PATTERN   Exclude files matching pattern (can be used multiple times)
  -i, --interactive       Ask for confirmation before each deletion
  -f, --force             Delete without confirmation (use with caution!)
  --empty-dirs            Also remove empty directories after file cleanup

Examples:
  # Find log files older than 30 days (dry run)
  $(basename "$0") /var/log -n -p "*.log"

  # Delete files older than 90 days larger than 100MB
  $(basename "$0") /tmp --age 90 --min-size 100M --force

  # Interactive cleanup with exclusions
  $(basename "$0") /home/user/downloads -a 180 -i -e "*.iso"

  # Clean old logs and empty directories
  $(basename "$0") /var/log/old -a 60 -p "*.gz" --empty-dirs --force

Size formats:
  K = Kilobytes, M = Megabytes, G = Gigabytes
  Examples: 10K, 100M, 1G

Safety features:
  - Dry-run mode by default shows what would be deleted
  - Interactive mode for careful deletion
  - Excludes root-owned files unless run as root
  - Requires explicit --force flag for non-interactive deletion
  - Shows summary before deletion in non-interactive mode

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

log_info() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ${NC} $*"
}

validate_directory() {
    local dir=$1
    
    if [[ ! -d "$dir" ]]; then
        log_error "Directory does not exist: $dir"
        exit 1
    fi
    
    if [[ ! -r "$dir" ]]; then
        log_error "Directory is not readable: $dir"
        exit 1
    fi
}

human_readable_size() {
    local size=$1
    
    if [[ $size -lt 1024 ]]; then
        echo "${size}B"
    elif [[ $size -lt 1048576 ]]; then
        echo "$((size / 1024))K"
    elif [[ $size -lt 1073741824 ]]; then
        echo "$((size / 1048576))M"
    else
        echo "$((size / 1073741824))G"
    fi
}

build_find_command() {
    local search_dir=$1
    local age_days=$2
    local min_size=$3
    local max_size=$4
    local max_depth=$5
    local pattern=$6
    shift 6
    local exclude_patterns=("$@")
    
    local find_cmd="find"
    local find_args=()
    
    # Directory to search
    find_args+=("$search_dir")
    
    # Max depth
    if [[ -n "$max_depth" ]]; then
        find_args+=("-maxdepth" "$max_depth")
    fi
    
    # Type: files only
    find_args+=("-type" "f")
    
    # Age filter
    find_args+=("-mtime" "+$age_days")
    
    # Size filters
    if [[ -n "$min_size" ]]; then
        find_args+=("-size" "+$min_size")
    fi
    
    if [[ -n "$max_size" ]]; then
        find_args+=("-size" "-$max_size")
    fi
    
    # Pattern filter
    if [[ -n "$pattern" ]]; then
        find_args+=("-name" "$pattern")
    fi
    
    # Exclude patterns
    if [[ ${#exclude_patterns[@]} -gt 0 ]]; then
        for exclude in "${exclude_patterns[@]}"; do
            if [[ -n "$exclude" ]]; then
                find_args+=("!" "-name" "$exclude")
            fi
        done
    fi
    
    echo "$find_cmd" "${find_args[@]}"
}

find_old_files() {
    local search_dir=$1
    local age_days=$2
    local min_size=$3
    local max_size=$4
    local max_depth=$5
    local pattern=$6
    shift 6
    local exclude_patterns=("$@")
    
    local find_args=()
    find_args+=("$search_dir")
    
    if [[ -n "$max_depth" ]]; then
        find_args+=("-maxdepth" "$max_depth")
    fi
    
    find_args+=("-type" "f" "-mtime" "+$age_days")
    
    if [[ -n "$min_size" ]]; then
        find_args+=("-size" "+$min_size")
    fi
    
    if [[ -n "$max_size" ]]; then
        find_args+=("-size" "-$max_size")
    fi
    
    if [[ -n "$pattern" ]]; then
        find_args+=("-name" "$pattern")
    fi
    
    for exclude in "${exclude_patterns[@]}"; do
        if [[ -n "$exclude" ]]; then
            find_args+=("!" "-name" "$exclude")
        fi
    done
    
    find "${find_args[@]}" 2>/dev/null || true
}

show_file_summary() {
    local -a files=("$@")
    local total_size=0
    local count=${#files[@]}
    
    if [[ $count -eq 0 ]]; then
        log_info "No files found matching criteria"
        return
    fi
    
    echo ""
    log_info "Found $count file(s) matching criteria:"
    echo ""
    
    printf "%-60s %12s %20s\n" "File" "Size" "Modified"
    printf "%-60s %12s %20s\n" "----" "----" "--------"
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            local size
            size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            local size_human
            size_human=$(human_readable_size "$size")
            local mtime
            mtime=$(stat -c%y "$file" 2>/dev/null | cut -d' ' -f1)
            
            total_size=$((total_size + size))
            
            # Truncate filename if too long
            local display_name="$file"
            if [[ ${#display_name} -gt 57 ]]; then
                display_name="...${display_name: -54}"
            fi
            
            printf "%-60s %12s %20s\n" "$display_name" "$size_human" "$mtime"
        fi
    done
    
    echo ""
    log_info "Total size: $(human_readable_size "$total_size")"
    echo ""
}

delete_files() {
    local interactive=$1
    local force=$2
    shift 2
    local -a files=("$@")
    
    local deleted=0
    local failed=0
    local skipped=0
    
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            continue
        fi
        
        # Safety check: skip root-owned files unless running as root
        if [[ $(stat -c%u "$file") -eq 0 ]] && [[ $EUID -ne 0 ]]; then
            log_warning "Skipping root-owned file: $file"
            ((skipped++))
            continue
        fi
        
        if [[ "$interactive" == "true" ]]; then
            local size
            size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            local size_human
            size_human=$(human_readable_size "$size")
            
            echo -e "${YELLOW}Delete${NC} $file (${size_human})?"
            read -p "  [y/N/q]: " -n 1 -r
            echo
            
            case $REPLY in
                [Yy])
                    if rm -f "$file" 2>/dev/null; then
                        log_success "Deleted: $file"
                        ((deleted++))
                    else
                        log_error "Failed to delete: $file"
                        ((failed++))
                    fi
                    ;;
                [Qq])
                    log "Aborted by user"
                    break
                    ;;
                *)
                    log_info "Skipped: $file"
                    ((skipped++))
                    ;;
            esac
        else
            if rm -f "$file" 2>/dev/null; then
                ((deleted++))
            else
                log_error "Failed to delete: $file"
                ((failed++))
            fi
        fi
    done
    
    echo ""
    log_success "Deleted: $deleted file(s)"
    if [[ $skipped -gt 0 ]]; then
        log_info "Skipped: $skipped file(s)"
    fi
    if [[ $failed -gt 0 ]]; then
        log_error "Failed: $failed file(s)"
    fi
}

remove_empty_dirs() {
    local search_dir=$1
    
    log "Removing empty directories..."
    
    local removed=0
    while IFS= read -r dir; do
        if rmdir "$dir" 2>/dev/null; then
            log_success "Removed empty directory: $dir"
            ((removed++))
        fi
    done < <(find "$search_dir" -type d -empty 2>/dev/null)
    
    if [[ $removed -gt 0 ]]; then
        log_success "Removed $removed empty director(y/ies)"
    else
        log_info "No empty directories found"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Parse arguments
    local search_dir=""
    local dry_run=false
    local age_days=$DEFAULT_AGE_DAYS
    local min_size=""
    local max_size=""
    local max_depth=""
    local pattern=""
    local exclude_patterns=()
    local interactive=false
    local force=false
    local empty_dirs=false
    
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
            -a|--age)
                age_days=$2
                shift 2
                ;;
            -s|--min-size)
                min_size=$2
                shift 2
                ;;
            -m|--max-size)
                max_size=$2
                shift 2
                ;;
            -d|--max-depth)
                max_depth=$2
                shift 2
                ;;
            -p|--pattern)
                pattern=$2
                shift 2
                ;;
            -e|--exclude)
                exclude_patterns+=("$2")
                shift 2
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            --empty-dirs)
                empty_dirs=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                if [[ -z "$search_dir" ]]; then
                    search_dir=$1
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
    if [[ -z "$search_dir" ]]; then
        log_error "Missing required directory argument"
        print_usage
        exit 1
    fi
    
    # Validate directory
    validate_directory "$search_dir"
    
    # Show search parameters
    log "Search parameters:"
    log "  Directory: $search_dir"
    log "  Age: > $age_days days"
    [[ -n "$min_size" ]] && log "  Min size: $min_size"
    [[ -n "$max_size" ]] && log "  Max size: $max_size"
    [[ -n "$max_depth" ]] && log "  Max depth: $max_depth"
    [[ -n "$pattern" ]] && log "  Pattern: $pattern"
    [[ ${#exclude_patterns[@]} -gt 0 ]] && log "  Excludes: ${exclude_patterns[*]}"
    echo ""
    
    # Find files
    log "Searching for files..."
    mapfile -t files < <(find_old_files "$search_dir" "$age_days" "$min_size" "$max_size" "$max_depth" "$pattern" "${exclude_patterns[@]}")
    
    # Show summary
    show_file_summary "${files[@]}"
    
    if [[ ${#files[@]} -eq 0 ]]; then
        exit 0
    fi
    
    # Dry run mode
    if [[ "$dry_run" == "true" ]]; then
        log_warning "DRY RUN MODE - No files were deleted"
        log_info "Remove -n/--dry-run flag to actually delete files"
        exit 0
    fi
    
    # Confirmation for non-interactive deletion
    if [[ "$interactive" == "false" ]] && [[ "$force" == "false" ]]; then
        echo ""
        read -p "$(echo -e "${YELLOW}"Delete ${#files[@]} file\(s\)?"${NC}" [y/N]: )" -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deletion cancelled"
            exit 0
        fi
    fi
    
    # Delete files
    log "Deleting files..."
    delete_files "$interactive" "$force" "${files[@]}"
    
    # Remove empty directories if requested
    if [[ "$empty_dirs" == "true" ]]; then
        echo ""
        remove_empty_dirs "$search_dir"
    fi
    
    log_success "Cleanup complete"
}

# Run main function
main "$@"
