#!/usr/bin/env bash

# codesearch.sh — Search files in a directory and output results in various formats

set -eu

#---------------------------------------------------------------------------
# Utility & configuration variables
#---------------------------------------------------------------------------

function print_info  { echo "[ info   ] $1"; }
function print_warn  { echo "[ warn   ] $1"; }
function print_error { echo "[ error  ] $1"; }

# Format string for --line-number annotation (printf-style, receives line then col)
LINENUM_FORMAT="L%d:C%d"

# Number of context lines shown before and after each match when --context is set
CONTEXT_LINES=7

# ANSI colors used by --context --color output
COLOR_MATCH=$'\033[1;33m'   # bold yellow — applied to entire match line (manual fallback)
COLOR_RESET=$'\033[0m'

#---------------------------------------------------------------------------
# Usage
#---------------------------------------------------------------------------

function usage {
    if [ -n "${1:-}" ]; then
        print_error "$1"
        echo ""
    fi
    echo "codesearch — search files in a directory and output results in various formats"
    echo ""
    echo "Usage: $(basename "$0") -d <directory> -t <text> [options]"
    echo "       $(basename "$0") --completion"
    echo ""
    echo "Required:"
    echo "  -d, --directory <path>      directory to search recursively"
    echo "  -t, --text <text>           text or pattern to search"
    echo ""
    echo "Search options:"
    echo "  -i, --case-insensitive      case insensitive text matching"
    echo "  -x, --exact                 match whole word only"
    echo "  -r, --regex                 treat text as regex (default: literal)"
    echo "  -p, --file-pattern <pat>    filter files by name (case-insensitive regex)"
    echo "                                examples: '\\.sh\$'  '\\.(sh|md)\$'  'readme'"
    echo ""
    echo "Output options:"
    echo "  -f, --format <format>       path format for results (default: name)"
    echo "                                name  — filenames only"
    echo "                                rel   — relative file paths from CWD"
    echo "                                full  — absolute file paths"
    echo "  -n, --line-number           append line and column to each result"
    echo "                                format: $LINENUM_FORMAT  (e.g. L12:C33)"
    echo "                                outputs one entry per match occurrence"
    echo "  -c, --context               show $CONTEXT_LINES lines before/after each match"
    echo "  -C, --color                 highlight matching lines in context output"
    echo "                                uses grep native color when available, else bold yellow"
    echo "                                only applies with --context; ignored otherwise"
    echo "  -o, --output <file>         write output to file instead of stdout"
    echo ""
    echo "Other:"
    echo "  --completion                generate and source bash completion (exclusive)"
    echo "  -h, --help                  show this help"
    echo ""
    exit 1
}

#---------------------------------------------------------------------------
# Bash completion
#---------------------------------------------------------------------------

function fn_generate_completion {
    local comp_file
    comp_file="$HOME/.local/share/bash-completion/completions/codesearch"
    mkdir -p "$(dirname "$comp_file")"

    cat > "$comp_file" <<'COMP'
_codesearch_completion() {
    local cur prev opts formats
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-d --directory -t --text -i --case-insensitive -x --exact -r --regex -p --file-pattern -f --format -n --line-number -c --context -C --color -o --output --completion -h --help"
    formats="name rel full"

    case "$prev" in
        -d|--directory)
            COMPREPLY=($(compgen -d -- "$cur"))
            return
            ;;
        -o|--output)
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
        -f|--format)
            COMPREPLY=($(compgen -W "$formats" -- "$cur"))
            return
            ;;
        -p|--file-pattern|-t|--text)
            return
            ;;
    esac

    COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}
complete -F _codesearch_completion codesearch.sh
complete -F _codesearch_completion codesearch
COMP

    # shellcheck source=/dev/null
    source "$comp_file"
    print_info "bash completion loaded from: $comp_file"
}

#---------------------------------------------------------------------------
# File enumeration
#---------------------------------------------------------------------------

# Outputs null-delimited paths of all candidate files under ARG_DIR.
# When ARG_FILE_PATTERN is set, only files whose basename matches the
# case-insensitive regex are emitted.
# Globals: ARG_DIR, ARG_FILE_PATTERN
function fn_get_files {
    if [[ -n "$ARG_FILE_PATTERN" ]]; then
        find "$ARG_DIR" -type f -print0 | while IFS= read -r -d $'\0' filepath; do
            local bn
            bn="$(basename "$filepath")"
            if echo "$bn" | grep -qiE -- "$ARG_FILE_PATTERN" 2>/dev/null; then
                printf '%s\0' "$filepath"
            fi
        done
    else
        find "$ARG_DIR" -type f -print0
    fi
}

#---------------------------------------------------------------------------
# grep flag builder
#---------------------------------------------------------------------------

# Prints space-separated grep flags for content search (no -r; file list
# is supplied via fn_get_files | xargs).
# Globals: ARG_REGEX, ARG_CASE_INSENSITIVE, ARG_EXACT
function fn_build_content_grep_flags {
    local -a flags
    flags=("--binary-files=without-match")

    if [[ "$ARG_REGEX" == "1" ]]; then
        flags+=("-E")
    else
        flags+=("-F")
    fi

    if [[ "$ARG_CASE_INSENSITIVE" == "1" ]]; then flags+=("-i"); fi
    if [[ "$ARG_EXACT" == "1" ]]; then flags+=("-w"); fi

    echo "${flags[@]}"
}

# Computes 1-indexed column of the first match of ARG_TEXT in a line string.
# $1: the line content to search within
# Globals: ARG_TEXT, ARG_REGEX, ARG_CASE_INSENSITIVE, ARG_EXACT
function fn_column_in_line {
    local line_content="$1"
    local -a col_flags
    col_flags=("-ob")
    [[ "$ARG_REGEX" == "1" ]] && col_flags+=("-E") || col_flags+=("-F")
    [[ "$ARG_CASE_INSENSITIVE" == "1" ]] && col_flags+=("-i")
    [[ "$ARG_EXACT" == "1" ]] && col_flags+=("-w")

    local byte_offset
    byte_offset=$(echo "$line_content" | grep "${col_flags[@]}" -- "$ARG_TEXT" 2>/dev/null | head -1 | cut -d: -f1)
    echo $(( ${byte_offset:-0} + 1 ))
}

# Returns true if grep on this system supports --color=always.
# Used by fn_format_context to choose between native and manual coloring.
function fn_grep_supports_color {
    local _ec=0
    { printf '' | grep --color=always -F "x" - >/dev/null 2>&1; } || _ec=$?
    [[ "$_ec" -lt 2 ]]
}

#---------------------------------------------------------------------------
# Path display helper
#---------------------------------------------------------------------------

# Returns the display form of a file path according to ARG_FORMAT.
# $1: file path (as returned by grep / find)
# Globals: ARG_FORMAT
function fn_get_display_path {
    local filepath="$1"
    case "$ARG_FORMAT" in
        name) basename "$filepath" ;;
        rel)  realpath --relative-to="$(pwd)" "$(realpath "$filepath")" 2>/dev/null || echo "$filepath" ;;
        full) realpath "$filepath" ;;
    esac
}

#---------------------------------------------------------------------------
# Output functions
#---------------------------------------------------------------------------

# fn_format_files — handles name/rel/full with optional --line-number
# Without --line-number: one line per matching file (filename/path)
# With    --line-number: one line per match occurrence with L<n>:C<col> suffix
# Globals: ARG_LINE_NUMBER, ARG_TEXT, ARG_FORMAT, LINENUM_FORMAT
function fn_format_files {
    local -a flags
    read -ra flags <<< "$(fn_build_content_grep_flags)"

    if [[ "$ARG_LINE_NUMBER" == "1" ]]; then
        # -H ensures filename is always printed even when xargs passes a single file
        fn_get_files | xargs -0 -r grep "${flags[@]}" -H -n -- "$ARG_TEXT" 2>/dev/null | \
            while IFS= read -r match_line; do
                local filepath rest linenum line_content colnum
                filepath="${match_line%%:*}"
                rest="${match_line#*:}"
                linenum="${rest%%:*}"
                line_content="${rest#*:}"
                colnum=$(fn_column_in_line "$line_content")
                printf '%s %s\n' \
                    "$(fn_get_display_path "$filepath")" \
                    "$(printf "$LINENUM_FORMAT" "$linenum" "$colnum")"
            done
    else
        fn_get_files | xargs -0 -r grep "${flags[@]}" -l -- "$ARG_TEXT" 2>/dev/null | \
            while IFS= read -r filepath; do
                fn_get_display_path "$filepath"
            done
    fi
}

# fn_format_context — shows matching files with context blocks
# For each matching file:
#   - prints the filename/path (using ARG_FORMAT)
#   - prints CONTEXT_LINES lines before and after each match
#   - with --color: highlights match lines (grep native color if available, else bold yellow)
#   - multiple match blocks within a file are separated by ---
#   - files are separated by a blank line
# Globals: ARG_TEXT, ARG_FORMAT, ARG_COLOR, CONTEXT_LINES, COLOR_MATCH, COLOR_RESET
function fn_format_context {
    local -a flags
    read -ra flags <<< "$(fn_build_content_grep_flags)"
    local first_file=1

    # Resolve coloring strategy once upfront
    local use_grep_color=0 use_manual_color=0
    if [[ "$ARG_COLOR" == "1" ]]; then
        if fn_grep_supports_color; then
            use_grep_color=1
        else
            use_manual_color=1
        fi
    fi

    while IFS= read -r filepath; do
        [[ "$first_file" == "1" ]] && first_file=0 || echo ""

        fn_get_display_path "$filepath"

        local -a ctx_flags=("${flags[@]}" -n -B"$CONTEXT_LINES" -A"$CONTEXT_LINES" --no-filename)
        [[ "$use_grep_color" == "1" ]] && ctx_flags+=(--color=always)

        # grep -n with -B/-A uses ':' for match lines and '-' for context lines.
        grep "${ctx_flags[@]}" -- "$ARG_TEXT" "$filepath" 2>/dev/null | \
            while IFS= read -r ctx_line; do
                if [[ "$ctx_line" == "--" ]]; then
                    echo "---"
                elif [[ "$use_manual_color" == "1" && "$ctx_line" =~ ^[0-9]+: ]]; then
                    printf "${COLOR_MATCH}%s${COLOR_RESET}\n" "$ctx_line"
                else
                    echo "$ctx_line"
                fi
            done
    done < <(fn_get_files | xargs -0 -r grep "${flags[@]}" -l -- "$ARG_TEXT" 2>/dev/null)
}

#---------------------------------------------------------------------------
# Search dispatcher
#---------------------------------------------------------------------------

function fn_search {
    local output

    if [[ "$ARG_CONTEXT" == "1" ]]; then
        output=$(fn_format_context)
    else
        output=$(fn_format_files)
    fi

    if [[ -z "$output" ]]; then
        return 1
    fi

    if [[ -n "$ARG_OUTPUT" ]]; then
        printf '%s\n' "$output" > "$ARG_OUTPUT"
        print_info "results written to: $ARG_OUTPUT"
    else
        printf '%s\n' "$output"
    fi
    return 0
}

#---------------------------------------------------------------------------
# MAIN
#---------------------------------------------------------------------------

ARG_DIR=""
ARG_TEXT=""
ARG_CASE_INSENSITIVE="0"
ARG_EXACT="0"
ARG_REGEX="0"
ARG_FILE_PATTERN=""
ARG_FORMAT="name"
ARG_FORMAT_EXPLICIT="0"
ARG_LINE_NUMBER="0"
ARG_CONTEXT="0"
ARG_COLOR="0"
ARG_OUTPUT=""
ARG_COMPLETION="0"

if [[ $# -eq 0 ]]; then
    usage "no arguments provided"
fi

while [[ "$#" -gt 0 ]]; do case $1 in
    -d|--directory)         ARG_DIR="$2"; shift; shift;;
    -t|--text)              ARG_TEXT="$2"; shift; shift;;
    -i|--case-insensitive)  ARG_CASE_INSENSITIVE="1"; shift;;
    -x|--exact)             ARG_EXACT="1"; shift;;
    -r|--regex)             ARG_REGEX="1"; shift;;
    -p|--file-pattern)      ARG_FILE_PATTERN="$2"; shift; shift;;
    -f|--format)            ARG_FORMAT="$2"; ARG_FORMAT_EXPLICIT="1"; shift; shift;;
    -n|--line-number)       ARG_LINE_NUMBER="1"; shift;;
    -c|--context)           ARG_CONTEXT="1"; shift;;
    -C|--color)             ARG_COLOR="1"; shift;;
    -o|--output)            ARG_OUTPUT="$2"; shift; shift;;
    --completion)           ARG_COMPLETION="1"; shift;;
    -h|--help)              usage;;
    *) usage "unknown argument: $1";;
esac; done

# --completion is exclusive: no other args allowed
if [[ "$ARG_COMPLETION" == "1" ]]; then
    if [[ -n "$ARG_DIR" || -n "$ARG_TEXT" || "$ARG_CASE_INSENSITIVE" == "1" || \
          "$ARG_EXACT" == "1" || "$ARG_REGEX" == "1" || -n "$ARG_FILE_PATTERN" || \
          "$ARG_FORMAT_EXPLICIT" == "1" || "$ARG_LINE_NUMBER" == "1" || \
          "$ARG_CONTEXT" == "1" || "$ARG_COLOR" == "1" || -n "$ARG_OUTPUT" ]]; then
        usage "--completion cannot be combined with other arguments"
    fi
    fn_generate_completion
    exit 0
fi

# Validate required arguments
if [[ -z "$ARG_DIR" ]];  then usage "directory is required (-d)"; fi
if [[ -z "$ARG_TEXT" ]]; then usage "search text is required (-t)"; fi

# Validate directory exists
if [[ ! -d "$ARG_DIR" ]]; then
    print_error "directory does not exist: $ARG_DIR"
    exit 2
fi

# Validate format (linenum and context are now flags, not formats)
case "$ARG_FORMAT" in
    name|rel|full) ;;
    *) usage "invalid format: $ARG_FORMAT (valid: name, rel, full)";;
esac

# Validate output file path
if [[ -n "$ARG_OUTPUT" ]]; then
    local_output_dir="$(dirname "$ARG_OUTPUT")"
    if [[ ! -d "$local_output_dir" ]]; then
        print_error "output directory does not exist: $local_output_dir"
        exit 2
    fi
fi

# Run
if ! fn_search; then
    exit 1
fi
