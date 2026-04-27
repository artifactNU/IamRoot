#!/bin/bash

################################################################################
# xlsx-to-csv.sh - Extract columns and/or rows from Excel/LibreOffice files
#
# Converts selected rows/columns from Excel or LibreOffice spreadsheets to CSV
#
# Usage:
#   xlsx-to-csv.sh -f <file> [-c <cols>] [-r <rows>] [-o <output>]
#
# Options:
#   -f, --file FILE          Input Excel/ODS file (required)
#   -c, --columns COLS       Column selection (numeric or letter-based)
#   -r, --rows ROWS          Row selection (numeric)
#   -o, --output FILE        Output CSV file (default: stdout)
#   -h, --help               Show this help message
#
# Column/Row Format (supports mixed):
#   Single:      1,2,5          or  A,B,C
#   Ranges:      1-5,8-10       or  A-C,F-H
#   Mixed:       1-3,5,A,C-E    or  1,3-5,2,4
#
# Examples:
#   # Extract columns A, B, D from sheet 1
#   xlsx-to-csv.sh -f data.xlsx -c A,B,D
#
#   # Extract rows 1-10 with columns 1-5
#   xlsx-to-csv.sh -f data.xlsx -c 1-5 -r 1-10 -o output.csv
#
#   # Extract specific columns from file
#   xlsx-to-csv.sh -f data.xlsx -c 1-3,5,7-9
#
#   # Extract rows only
#   xlsx-to-csv.sh -f data.xlsx -r 5-15 -o rows.csv
#
################################################################################

set -euo pipefail

# Global variables
INPUT_FILE=""
COLUMNS=""
ROWS=""
OUTPUT_FILE=""
TEMP_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

print_error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}WARNING: $*${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✓ ${*}${NC}"
}

print_help() {
    sed -n '3,41p' "$0" | sed 's/^# //'
}

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

################################################################################
# Validation Functions
################################################################################

check_dependencies() {
    local missing=()
    
    for cmd in libreoffice soffice awk cut; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
}

validate_input_file() {
    if [[ ! -f "$INPUT_FILE" ]]; then
        print_error "Input file not found: $INPUT_FILE"
        exit 1
    fi
    
    local ext="${INPUT_FILE##*.}"
    ext="${ext,,}"  # Convert to lowercase
    
    if [[ ! "$ext" =~ ^(xlsx|xls|ods|csv|tsv)$ ]]; then
        print_error "Unsupported file format: $ext"
        print_error "Supported formats: xlsx, xls, ods, csv, tsv"
        exit 1
    fi
}

################################################################################
# Conversion Functions
################################################################################

# Convert Excel column letter(s) to number (A=1, B=2, AA=27, etc.)
letter_to_number() {
    local letter="$1"
    letter="${letter^^}"  # Convert to uppercase
    
    # Validate it's only letters
    if [[ ! "$letter" =~ ^[A-Z]+$ ]]; then
        print_error "Invalid column letter: $letter"
        return 1
    fi
    
    local num=0
    for (( i=0; i<${#letter}; i++ )); do
        num=$((num * 26 + $(printf '%d' "'${letter:$i:1}") - 64))
    done
    
    echo "$num"
}

# Convert number to Excel column letter (1=A, 2=B, 27=AA, etc.)
number_to_letter() {
    local num=$1
    local letters="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local letter=""
    
    while (( num > 0 )); do
        (( num-- ))
        letter="${letters:num%26:1}${letter}"
        (( num /= 26 ))
    done
    
    echo "$letter"
}

# Parse column specification and return sorted array of column numbers
parse_columns() {
    local col_spec="$1"
    declare -a cols
    
    # Split by comma
    IFS=',' read -ra items <<< "$col_spec"
    
    for item in "${items[@]}"; do
        item="${item// /}"  # Remove spaces
        
        if [[ "$item" =~ ^[0-9]+-[0-9]+$ ]]; then
            # Numeric range: 1-5
            local start="${item%-*}"
            local end="${item#*-}"
            for (( i=start; i<=end; i++ )); do
                cols+=("$i")
            done
        elif [[ "$item" =~ ^[A-Za-z]+-[A-Za-z]+$ ]]; then
            # Letter range: A-C
            local start="${item%-*}"
            local end="${item#*-}"
            start=$(letter_to_number "$start")
            end=$(letter_to_number "$end")
            for (( i=start; i<=end; i++ )); do
                cols+=("$i")
            done
        elif [[ "$item" =~ ^[0-9]+$ ]]; then
            # Single number
            cols+=("$item")
        elif [[ "$item" =~ ^[A-Za-z]+$ ]]; then
            # Single letter
            cols+=("$(letter_to_number "$item")")
        else
            print_error "Invalid column specification: $item"
            return 1
        fi
    done
    
    # Sort and remove duplicates
    printf '%s\n' "${cols[@]}" | sort -n -u | tr '\n' ','
    echo  # Newline
}

# Parse row specification and return sorted array of row numbers
parse_rows() {
    local row_spec="$1"
    declare -a row_nums
    
    # Split by comma
    IFS=',' read -ra items <<< "$row_spec"
    
    for item in "${items[@]}"; do
        item="${item// /}"  # Remove spaces
        
        if [[ "$item" =~ ^[0-9]+-[0-9]+$ ]]; then
            # Range: 1-10
            local start="${item%-*}"
            local end="${item#*-}"
            for (( i=start; i<=end; i++ )); do
                row_nums+=("$i")
            done
        elif [[ "$item" =~ ^[0-9]+$ ]]; then
            # Single number
            row_nums+=("$item")
        else
            print_error "Invalid row specification: $item"
            return 1
        fi
    done
    
    # Sort and remove duplicates
    printf '%s\n' "${row_nums[@]}" | sort -n -u | tr '\n' ','
    echo  # Newline
}

################################################################################
# File Conversion
################################################################################

convert_to_csv() {
    local input="$1"
    local output="$2"
    
    # LibreOffice batch conversion
    libreoffice --headless --convert-to csv:"Text CSV" \
        --outdir "$(dirname "$output")" \
        "$input" > /dev/null 2>&1 || {
        print_error "Failed to convert file with LibreOffice"
        return 1
    }
    
    # The output filename depends on input, but we need to check what was created
    # For multi-sheet files, we need to extract specific sheet
    local base_name="${input%.*}"
    base_name="${base_name##*/}"
    local converted="${output%/*}/${base_name}.csv"
    
    if [[ ! -f "$converted" ]]; then
        print_error "Conversion produced unexpected output"
        return 1
    fi
    
    mv "$converted" "$output"
}

# Extract selected columns from CSV
extract_columns() {
    local input_csv="$1"
    local columns="$2"
    local output="$3"
    
    # Remove trailing comma and convert to cut-compatible format
    columns="${columns%,}"
    
    # cut uses 1-based indexing and comma-separated list
    cut -d',' -f"$columns" "$input_csv" > "$output"
}

# Extract selected rows from CSV
extract_rows() {
    local input_csv="$1"
    local rows="$2"
    local output="$3"
    
    # Remove trailing comma
    rows="${rows%,}"
    
    local -a row_array
    mapfile -t -d ',' row_array < <(printf '%s' "$rows")
    
    # Use awk to extract specific rows
    local awk_prog="BEGIN { FS=OFS=\",\" }"
    awk_prog+=" { "
    
    for row in "${row_array[@]}"; do
        if [[ "$row" != "${row_array[0]}" ]]; then
            awk_prog+=" || "
        fi
        awk_prog+="NR==$row"
    done
    
    awk_prog+=" { print } }"
    
    awk "$awk_prog" "$input_csv" > "$output"
}

# Extract both rows and columns
extract_rows_and_columns() {
    local input_csv="$1"
    local columns="$2"
    local rows="$3"
    local output="$4"
    
    # Remove trailing commas
    columns="${columns%,}"
    rows="${rows%,}"
    
    local -a row_array col_array
    mapfile -t -d ',' row_array < <(printf '%s' "$rows")
    mapfile -t -d ',' col_array < <(printf '%s' "$columns")
    
    # Build awk program to extract specific rows and columns
    local awk_prog="BEGIN { FS=OFS=\",\" }"
    awk_prog+=" { "
    
    for row in "${row_array[@]}"; do
        if [[ "$row" != "${row_array[0]}" ]]; then
            awk_prog+=" || "
        fi
        awk_prog+="NR==$row"
    done
    
    awk_prog+=" { "
    awk_prog+='output = ""; '
    awk_prog+="for (i=1; i<=NF; i++) { "
    
    local first=1
    for col in "${col_array[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
        else
            awk_prog+="if (i==$col) output = output \",\" \$i; "
        fi
    done
    
    awk_prog+="if (i==${col_array[0]}) output = \$i; "
    awk_prog+="} print output } }"
    
    awk "$awk_prog" "$input_csv" > "$output"
}

################################################################################
# Main Functions
################################################################################

parse_arguments() {
    if [[ $# -eq 0 ]]; then
        print_help
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                INPUT_FILE="$2"
                shift 2
                ;;
            -c|--columns)
                COLUMNS="$2"
                shift 2
                ;;
            -r|--rows)
                ROWS="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    
    if [[ -z "$INPUT_FILE" ]]; then
        print_error "Input file is required (-f/--file)"
        exit 1
    fi
    
    if [[ -z "$COLUMNS" && -z "$ROWS" ]]; then
        print_error "At least one of -c/--columns or -r/--rows must be specified"
        exit 1
    fi
    
    check_dependencies
    validate_input_file
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    
    # Convert input file to CSV
    local temp_csv="$TEMP_DIR/temp.csv"
    print_success "Converting input file to CSV..."
    convert_to_csv "$INPUT_FILE" "$temp_csv"
    
    # Parse column and row specifications
    local parsed_cols=""
    local parsed_rows=""
    
    if [[ -n "$COLUMNS" ]]; then
        parsed_cols=$(parse_columns "$COLUMNS") || exit 1
        print_success "Columns parsed: ${parsed_cols%,}"
    fi
    
    if [[ -n "$ROWS" ]]; then
        parsed_rows=$(parse_rows "$ROWS") || exit 1
        print_success "Rows parsed: ${parsed_rows%,}"
    fi
    
    # Determine output file
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="/dev/stdout"
    fi
    
    # Extract data based on selection
    if [[ -n "$parsed_cols" ]] && [[ -n "$parsed_rows" ]]; then
        print_success "Extracting rows and columns..."
        extract_rows_and_columns "$temp_csv" "$parsed_cols" "$parsed_rows" "$OUTPUT_FILE"
    elif [[ -n "$parsed_cols" ]]; then
        print_success "Extracting columns..."
        extract_columns "$temp_csv" "$parsed_cols" "$OUTPUT_FILE"
    else
        print_success "Extracting rows..."
        extract_rows "$temp_csv" "$parsed_rows" "$OUTPUT_FILE"
    fi
    
    if [[ "$OUTPUT_FILE" != "/dev/stdout" ]]; then
        print_success "Output saved to: $OUTPUT_FILE"
    fi
}

main "$@"
