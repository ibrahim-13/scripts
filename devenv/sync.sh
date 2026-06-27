#!/usr/bin/env bash
set -eu

# rsync-based bidirectional directory sync script.
# Config file: ~/.sync-dirs  (source/destination pairs, INI format)
# Exclude file: ~/.sync-exclude (fixed patterns to always exclude)
#
# See --help for full usage and file format documentation.
# Use --init to generate template versions of both files.

SCRIPT_SOURCE=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_SOURCE" ]; do
  SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )
  SCRIPT_SOURCE=$(readlink "$SCRIPT_SOURCE")
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE=$SCRIPT_DIR/$SCRIPT_SOURCE
done

DEFAULT_CONFIG_FILE="$HOME/.sync-dirs"
DEFAULT_EXCLUDE_FILE="$HOME/.sync-exclude"

CONFIG_FILE="$DEFAULT_CONFIG_FILE"
EXCLUDE_FILE="$DEFAULT_EXCLUDE_FILE"
EXCLUDE_FILE_EXPLICIT="false"   # set to true when --exclude-config is given

SRC_DIR=""
DST_DIR=""
PAIR_NAME=""
PAIR_OWNER=""   # user:group from the 'owner=' config key; empty = not set

ARG_REVERSE="false"
ARG_DRY_RUN="false"
ARG_PAIR_NAME=""
ARG_INIT="false"

# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------

function print_info  { printf "[ info   ] %s\n" "$1"; }
function print_warn  { printf "[ warn   ] %s\n" "$1"; }
function print_error { printf "[ error  ] %s\n" "$1" >&2; }

# Simple y/N prompt — does NOT exit the script.
# $1: question text.  Returns 0 for yes, 1 for no/anything else.
function ask_yes_no {
  local answer
  printf "%s (y/N) " "$1"
  read -r answer
  case "$answer" in
    [Yy]) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Help / usage
# ---------------------------------------------------------------------------

function show_config_format {
  cat <<EOF

━━━  Config file  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Default location : $DEFAULT_CONFIG_FILE

Format (INI-style, one section per sync pair):

    [pair-name]
    src=/path/to/source/directory
    dst=/path/to/destination/directory
    owner=username:groupname        # optional

Fields:
  src    (required) Source directory path.
  dst    (required) Destination directory path.
  owner  (optional) user:group ownership to apply to all transferred files
         in the destination, passed to rsync as --chown=user:group.
         Formats accepted:
           user:group   set both owner and group
           user:        set owner only  (trailing colon optional: just 'user')
           :group       set group only  (leading colon required)
         If omitted, rsync runs in archive mode (-a) which preserves the
         source ownership; changing ownership to arbitrary users requires
         the receiving rsync to run as root or have appropriate privileges.

Rules:
  • Lines starting with '#' are treated as comments and ignored.
  • Blank lines are ignored.
  • Pair names must be unique within the file (used with -p/--pair).
  • Each section must have exactly one 'src' entry and one 'dst' entry.
  • Only 'src', 'dst', and 'owner' keys are allowed inside a section.
  • The tilde (~) at the start of a path is expanded to \$HOME.
  • Paths may be absolute or start with ~.

Example file:

    # My sync pairs
    [documents-backup]
    src=~/Documents
    dst=/mnt/usb/Documents
    owner=arshad:arshad

    [project-sync]
    src=~/projects/myapp
    dst=/mnt/usb/projects/myapp

How to create/edit manually:
  1. Open a text editor:  nano $DEFAULT_CONFIG_FILE
  2. Add one [section] block per sync pair following the format above.
  3. Save the file and run this script to verify it is parsed correctly.
  Alternatively: run '$(basename "$0") --init' to generate a template.

━━━  Exclude file  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Default location : $DEFAULT_EXCLUDE_FILE

Format (one rsync exclude pattern per line):

    # comment
    pattern-to-exclude

Rules:
  • Lines starting with '#' are treated as comments and ignored.
  • Blank lines are ignored.
  • Patterns follow rsync glob syntax (passed via --exclude-from):
      *      matches any characters within a single path component.
      **     matches anything, including path separators.
      /foo   pattern anchored to the root of the synced directory.
      foo/   matches only directories named foo.
  • The .git directory is always excluded regardless of this file.
  • .gitignore files inside each synced directory are also respected
    automatically via rsync's per-directory dir-merge filter rule.
  • Files already present in the destination are NOT deleted just
    because they match an exclude rule (rsync only skips sending them).

Example file:

    # Version control
    .git
    .svn

    # Node / JavaScript
    node_modules/

    # Python
    __pycache__/
    *.pyc

    # Build artefacts
    build/
    dist/

How to create/edit manually:
  1. Open a text editor:  nano $DEFAULT_EXCLUDE_FILE
  2. Add one rsync pattern per line following the rules above.
  3. Save the file — it is read each time the script runs.
  Alternatively: run '$(basename "$0") --init' to generate a template with
                 common patterns already filled in.

━━━  Sync behaviour  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  • rsync is run with archive mode (-a): permissions, timestamps, symlinks,
    and ownership are preserved.
  • --delete: files in the destination that are absent in the source are
    removed, making the two directories exactly equal.
  • --chown: when 'owner=' is set in the config pair, rsync applies that
    user:group to all transferred files in the destination.
  • Confirmation is always required before data is transferred; it cannot
    be bypassed by any flag.
EOF
}

function usage {
  if [ -n "${1:-}" ]; then
    print_error "$1"
    echo ""
  fi
  cat <<EOF
Sync two directories using rsync (source/destination are interchangeable).

Usage: $(basename "$0") [OPTIONS]

Sync options:
  -p, --pair <name>          Select sync pair by name (skips interactive menu)
  -r, --reverse              Reverse source and destination
  -n, --dry-run              Show what would be synced without making changes

Setup options:
      --init                 Generate template config and exclude files

Global options:
      --config <file>        Config file path  (default: $DEFAULT_CONFIG_FILE)
      --exclude-config <f>   Exclude file path (default: $DEFAULT_EXCLUDE_FILE)
  -h, --help                 Show this help message


EOF
  show_config_format
  exit "${2:-1}"
}

# ---------------------------------------------------------------------------
# Confirmation — always requires explicit typed input; cannot be skipped
# ---------------------------------------------------------------------------

# $1: question to show the user.
# Exits the script if the user does not type exactly 'yes'.
function prompt_confirmation {
  local answer
  echo ""
  printf "[ confirm ] %s\n" "$1"
  printf "[ confirm ] Type 'yes' to proceed (anything else cancels): "
  read -r answer
  if [ "$answer" = "yes" ]; then
    return 0
  fi
  echo "[ confirm ] Sync cancelled."
  exit 1
}

# ---------------------------------------------------------------------------
# Config file parsing
# ---------------------------------------------------------------------------

# Print all section names (pair names) from the config file, one per line.
function get_pair_names {
  [ -f "$CONFIG_FILE" ] || return 0
  while IFS= read -r line; do
    if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
    fi
  done < "$CONFIG_FILE"
}

# Read a key's value from a named section of the INI config file.
# $1: section name   $2: key name
# Outputs the value to stdout; nothing if not found.
function get_config_value {
  local section="$1" key="$2" in_section="false"
  while IFS= read -r raw_line; do
    local line="${raw_line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue

    if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
      if [ "${BASH_REMATCH[1]}" = "$section" ]; then
        in_section="true"
      else
        [ "$in_section" = "true" ] && return 0   # past our section, stop
        in_section="false"
      fi
    elif [ "$in_section" = "true" ] && [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
      if [ "${BASH_REMATCH[1]}" = "$key" ]; then
        printf '%s' "${BASH_REMATCH[2]}"
        return 0
      fi
    fi
  done < "$CONFIG_FILE"
}

# Validate 'owner=' value format.
# $1: the value string.  Returns 0 if valid, 1 if invalid.
# Valid: user:group  user:  :group  user  (no spaces, at most one colon)
function validate_owner_value {
  local val="$1"
  # Must not be empty
  [ -z "$val" ] && return 1
  # Must not contain spaces or tabs
  case "$val" in *' '*|*'	'*) return 1 ;; esac
  # Must have at most one colon
  local no_colons="${val//:/}"
  local colon_count=$(( ${#val} - ${#no_colons} ))
  [ "$colon_count" -gt 1 ] && return 1
  # Must not be a bare colon with nothing else
  [ "$val" = ":" ] && return 1
  return 0
}

# Validate the config file format.  Exits with errors and format hints on failure.
function validate_config {
  if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Config file not found: $CONFIG_FILE"
    printf "\nRun '%s --init' to create a template, or see --help for the format.\n" "$(basename "$0")"
    exit 1
  fi

  local current_section="" has_src="false" has_dst="false"
  local line_num=0 errors=0 has_any_section="false"

  while IFS= read -r raw_line; do
    line_num=$((line_num + 1))
    local line="${raw_line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -z "$line" ] && continue

    if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
      if [ -n "$current_section" ]; then
        if [ "$has_src" = "false" ]; then
          print_error "Section [$current_section]: missing 'src' entry"
          errors=$((errors + 1))
        fi
        if [ "$has_dst" = "false" ]; then
          print_error "Section [$current_section]: missing 'dst' entry"
          errors=$((errors + 1))
        fi
      fi
      current_section="${BASH_REMATCH[1]}"
      has_src="false"
      has_dst="false"
      has_any_section="true"
    elif [[ "$line" =~ ^src=(.+)$ ]]; then
      has_src="true"
    elif [[ "$line" =~ ^dst=(.+)$ ]]; then
      has_dst="true"
    elif [[ "$line" =~ ^owner=(.*)$ ]]; then
      local owner_val="${BASH_REMATCH[1]}"
      if ! validate_owner_value "$owner_val"; then
        print_error "Line $line_num: invalid 'owner' value '$owner_val' in [$current_section]"
        printf "           Expected format: user:group  user:  :group  or  user\n" >&2
        errors=$((errors + 1))
      fi
    elif [ -n "$current_section" ]; then
      print_error "Line $line_num: unrecognised entry '$line' in [$current_section]"
      errors=$((errors + 1))
    else
      print_error "Line $line_num: entry '$line' appears outside any section"
      errors=$((errors + 1))
    fi
  done < "$CONFIG_FILE"

  if [ -n "$current_section" ]; then
    if [ "$has_src" = "false" ]; then
      print_error "Section [$current_section]: missing 'src' entry"
      errors=$((errors + 1))
    fi
    if [ "$has_dst" = "false" ]; then
      print_error "Section [$current_section]: missing 'dst' entry"
      errors=$((errors + 1))
    fi
  fi

  if [ "$has_any_section" = "false" ]; then
    print_error "Config file contains no sync pair sections"
    errors=$((errors + 1))
  fi

  if [ "$errors" -gt 0 ]; then
    echo ""
    print_error "Config file has $errors error(s): $CONFIG_FILE"
    printf "See '%s --help' for the correct format.\n" "$(basename "$0")"
    exit 1
  fi
}

# Validate the exclude file.
# If the user explicitly provided --exclude-config, the file must exist.
# If the file exists (default or explicit), it must be readable.
function validate_exclude_file {
  if [ ! -f "$EXCLUDE_FILE" ]; then
    if [ "$EXCLUDE_FILE_EXPLICIT" = "true" ]; then
      print_error "Exclude file not found: $EXCLUDE_FILE"
      printf "See '%s --help' for the correct format, or remove --exclude-config to use the default.\n" "$(basename "$0")"
      exit 1
    fi
    return 0   # default file not existing is fine — no extra excludes
  fi
  if [ ! -r "$EXCLUDE_FILE" ]; then
    print_error "Exclude file is not readable: $EXCLUDE_FILE"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Interactive pair selection
# ---------------------------------------------------------------------------

# Show a numbered menu of available pairs and return the chosen name.
function select_pair {
  local names
  names=$(get_pair_names)

  if [ -z "$names" ]; then
    print_error "No sync pairs found in: $CONFIG_FILE"
    exit 1
  fi

  echo "Available sync pairs:"
  echo ""

  local i=1
  local -a name_array=()
  while IFS= read -r name; do
    local src dst owner_val owner_display
    src=$(get_config_value "$name" "src")
    dst=$(get_config_value "$name" "dst")
    owner_val=$(get_config_value "$name" "owner")
    if [ -n "$owner_val" ]; then
      owner_display="  [owner: $owner_val]"
    else
      owner_display=""
    fi
    printf "  %d) %-20s  %s  ->  %s%s\n" "$i" "$name" "$src" "$dst" "$owner_display"
    name_array+=("$name")
    i=$((i + 1))
  done <<< "$names"

  echo ""
  local max_choice=$(( i - 1 ))
  printf "Select pair number [1-%d]: " "$max_choice"
  local choice
  read -r choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || \
     [ "$choice" -lt 1 ] || \
     [ "$choice" -gt "${#name_array[@]}" ]; then
    print_error "Invalid selection: '$choice'"
    exit 1
  fi

  printf '%s' "${name_array[$((choice - 1))]}"
}

# ---------------------------------------------------------------------------
# Setup command: --init
# ---------------------------------------------------------------------------

# Generate a template config file.
function cmd_init_config {
  if [ -f "$CONFIG_FILE" ]; then
    print_warn "Config file already exists: $CONFIG_FILE"
    if ! ask_yes_no "Overwrite it with a fresh template?"; then
      print_info "Skipping config file — existing file kept."
      return
    fi
  fi
  cat > "$CONFIG_FILE" <<'TEMPLATE'
# sync-dirs — source/destination pairs for sync.sh
#
# Format:
#   [pair-name]
#   src=/path/to/source/directory
#   dst=/path/to/destination/directory
#   owner=user:group                  # optional: ownership for destination files
#
# Fields:
#   src    (required) Source directory path. Tilde (~) expands to $HOME.
#   dst    (required) Destination directory path.
#   owner  (optional) user:group to apply to transferred files via rsync --chown.
#          Formats: user:group  user:  :group  user
#          Setting ownership to arbitrary users requires root or privileges.
#
# Rules:
#   - Pair names must be unique (no spaces allowed in pair names).
#   - Each section needs exactly one 'src' and one 'dst' entry.
#   - Lines starting with '#' are ignored.  Blank lines are ignored.
#
# To edit: open this file in a text editor (e.g. nano ~/.sync-dirs)
# Run 'sync.sh --help' for full format documentation.

# Example pair — edit the paths or remove this block:
[example-pair]
src=~/Documents
dst=/mnt/backup/Documents
# owner=myuser:mygroup
TEMPLATE
  print_info "Created config file: $CONFIG_FILE"
  printf "         Edit it with a text editor: nano %s\n" "$CONFIG_FILE"
}

# Generate a template exclude file.
function cmd_init_exclude {
  if [ -f "$EXCLUDE_FILE" ]; then
    print_warn "Exclude file already exists: $EXCLUDE_FILE"
    if ! ask_yes_no "Overwrite it with a fresh template?"; then
      print_info "Skipping exclude file — existing file kept."
      return
    fi
  fi
  cat > "$EXCLUDE_FILE" <<'TEMPLATE'
# sync-exclude — fixed patterns to always exclude when syncing.
# Used by sync.sh via rsync's --exclude-from option.
#
# Format: one rsync glob pattern per line.
# Lines starting with '#' are ignored.  Blank lines are ignored.
#
# Pattern syntax (rsync glob):
#   *        matches any characters within one path component
#   **       matches anything, including path separators
#   /foo     anchored to the root of the synced directory
#   foo/     matches a directory named foo (trailing slash = dir only)
#
# Note: .git is always excluded by the script regardless of this file.
# Note: .gitignore files in each directory are also honoured automatically.
#
# To edit: open this file in a text editor (e.g. nano ~/.sync-exclude)
# Run 'sync.sh --help' for full format documentation.

# Version control
.git
.svn
.hg

# Node / JavaScript
node_modules/

# Python
__pycache__/
*.pyc
*.pyo
.venv/
venv/

# Build artefacts
build/
dist/
target/
*.o
*.a
*.so

# Editor / OS noise
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.cache/
TEMPLATE
  print_info "Created exclude file: $EXCLUDE_FILE"
  printf "         Edit it with a text editor: nano %s\n" "$EXCLUDE_FILE"
}

# ---------------------------------------------------------------------------
# Build rsync exclude arguments
# ---------------------------------------------------------------------------

# Populate the global EXCLUDE_ARGS array.
# .git is always excluded.  If the exclude file exists it is passed directly
# to rsync via --exclude-from, which handles comments and blank lines natively.
EXCLUDE_ARGS=()
function build_exclude_args {
  EXCLUDE_ARGS=()
  EXCLUDE_ARGS+=("--exclude=.git")
  if [ -f "$EXCLUDE_FILE" ]; then
    EXCLUDE_ARGS+=("--exclude-from=$EXCLUDE_FILE")
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -p|--pair)
      [ -z "${2:-}" ] && usage "--pair requires a name argument"
      ARG_PAIR_NAME="$2"; shift 2 ;;
    -r|--reverse)
      ARG_REVERSE="true"; shift ;;
    -n|--dry-run)
      ARG_DRY_RUN="true"; shift ;;
    --init)
      ARG_INIT="true"; shift ;;
    --config)
      [ -z "${2:-}" ] && usage "--config requires a file path"
      CONFIG_FILE="$2"; shift 2 ;;
    --exclude-config)
      [ -z "${2:-}" ] && usage "--exclude-config requires a file path"
      EXCLUDE_FILE="$2"
      EXCLUDE_FILE_EXPLICIT="true"
      shift 2 ;;
    -h|--help)
      usage "" 0 ;;
    *)
      usage "Unknown option: $1" ;;
  esac
done

# ---------------------------------------------------------------------------
# Setup commands (do not require rsync or an existing config)
# ---------------------------------------------------------------------------

if [ "$ARG_INIT" = "true" ]; then
  cmd_init_config
  cmd_init_exclude
  exit 0
fi

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

if ! command -v rsync &>/dev/null; then
  print_error "rsync is not installed.  Install it first:"
  printf "  sudo dnf install rsync    # Fedora / RHEL\n"
  printf "  sudo apt install rsync    # Debian / Ubuntu\n"
  exit 1
fi

validate_config
validate_exclude_file

# ---------------------------------------------------------------------------
# Resolve the pair
# ---------------------------------------------------------------------------

if [ -n "$ARG_PAIR_NAME" ]; then
  PAIR_NAME="$ARG_PAIR_NAME"
  PAIR_FOUND="false"
  while IFS= read -r _pname; do
    [ "$_pname" = "$PAIR_NAME" ] && { PAIR_FOUND="true"; break; }
  done <<< "$(get_pair_names)"
  if [ "$PAIR_FOUND" = "false" ]; then
    print_error "Sync pair '$PAIR_NAME' not found in: $CONFIG_FILE"
    printf "Available pairs:\n"
    while IFS= read -r _pname; do
      printf "  - %s\n" "$_pname"
    done <<< "$(get_pair_names)"
    exit 1
  fi
else
  PAIR_NAME=$(select_pair)
fi

SRC_DIR=$(get_config_value "$PAIR_NAME" "src")
DST_DIR=$(get_config_value "$PAIR_NAME" "dst")
PAIR_OWNER=$(get_config_value "$PAIR_NAME" "owner")

[ -z "$SRC_DIR" ] && { print_error "Could not read 'src' for pair: $PAIR_NAME"; exit 1; }
[ -z "$DST_DIR" ] && { print_error "Could not read 'dst' for pair: $PAIR_NAME"; exit 1; }

# Expand leading ~ to $HOME
SRC_DIR="${SRC_DIR/#\~/$HOME}"
DST_DIR="${DST_DIR/#\~/$HOME}"

# Reverse if requested
if [ "$ARG_REVERSE" = "true" ]; then
  swap_tmp="$SRC_DIR"
  SRC_DIR="$DST_DIR"
  DST_DIR="$swap_tmp"
fi

# Validate source exists
if [ ! -d "$SRC_DIR" ]; then
  print_error "Source directory does not exist: $SRC_DIR"
  exit 1
fi

# Create destination if needed
if [ ! -d "$DST_DIR" ]; then
  print_warn "Destination directory does not exist, it will be created: $DST_DIR"
  mkdir -p "$DST_DIR"
fi

# ---------------------------------------------------------------------------
# Build rsync options
# ---------------------------------------------------------------------------

build_exclude_args

# -a  : archive mode (recursive + preserve perms, times, symlinks, owner)
# -v  : verbose — show each transferred file
# -h  : human-readable file sizes
# --delete        : remove files in dest absent in src (exact mirror)
# --filter=:- ... : per-directory dir-merge of .gitignore (exclude-only)
# --stats         : print transfer statistics at the end
RSYNC_OPTS=(
  "-a"
  "-v"
  "-h"
  "--delete"
  "--filter=:- .gitignore"
  "--stats"
)

if [ -n "$PAIR_OWNER" ]; then
  # --chown=user:group overrides ownership of all transferred destination files.
  # Internally rsync maps this to --usermap=*:user --groupmap=*:group.
  # Changing to arbitrary owners requires root or appropriate privileges.
  RSYNC_OPTS+=("--chown=$PAIR_OWNER")
fi

if [ "$ARG_DRY_RUN" = "true" ]; then
  RSYNC_OPTS+=("--dry-run")
fi

# ---------------------------------------------------------------------------
# Display summary — shown before the confirmation prompt
# ---------------------------------------------------------------------------

# Human-readable exclude file line for display
if [ -f "$EXCLUDE_FILE" ]; then
  EXCL_FILE_DISPLAY="$EXCLUDE_FILE"
else
  EXCL_FILE_DISPLAY="(none — $EXCLUDE_FILE not found)"
fi

# Human-readable ownership line for display
if [ -n "$PAIR_OWNER" ]; then
  OWNER_DISPLAY="$PAIR_OWNER  (applied to destination files via --chown)"
else
  OWNER_DISPLAY="preserved from source  (-a archive mode)"
fi

echo ""
echo "================================"
echo "  Sync Summary"
echo "================================"
echo ""
printf "  Pair        : %s\n" "$PAIR_NAME"
printf "  Config file : %s\n" "$CONFIG_FILE"
printf "  Exclude file: %s\n" "$EXCL_FILE_DISPLAY"
printf "  Source      : %s\n" "$SRC_DIR"
printf "  Destination : %s\n" "$DST_DIR"
printf "  Ownership   : %s\n" "$OWNER_DISPLAY"
[ "$ARG_REVERSE" = "true" ] && printf "  Direction   : REVERSED (original dst -> original src)\n"
[ "$ARG_DRY_RUN" = "true" ] && printf "  Mode        : DRY RUN (no files will be changed)\n"
echo ""
printf "  Excluded patterns:\n"
printf "    - .git  (always excluded)\n"
if [ -f "$EXCLUDE_FILE" ]; then
  while IFS= read -r raw_line; do
    excl_line="${raw_line%%#*}"
    excl_line="${excl_line#"${excl_line%%[![:space:]]*}"}"
    excl_line="${excl_line%"${excl_line##*[![:space:]]}"}"
    [ -z "$excl_line" ] && continue
    printf "    - %s\n" "$excl_line"
  done < "$EXCLUDE_FILE"
fi
printf "    - (patterns from .gitignore files in each directory)\n"
echo ""
printf "  WARNING: Files in the destination that are absent in the source\n"
printf "           WILL BE PERMANENTLY DELETED (rsync --delete).\n"
echo ""

# ---------------------------------------------------------------------------
# Mandatory confirmation — cannot be bypassed by any option
# ---------------------------------------------------------------------------

prompt_confirmation "Start sync from '$SRC_DIR' to '$DST_DIR'?"

# ---------------------------------------------------------------------------
# Run rsync
# ---------------------------------------------------------------------------

echo ""
print_info "Starting sync..."
echo ""

rsync "${RSYNC_OPTS[@]}" "${EXCLUDE_ARGS[@]}" "$SRC_DIR/" "$DST_DIR/"

echo ""
print_info "Sync complete."
