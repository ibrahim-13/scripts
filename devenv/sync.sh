#!/usr/bin/env bash
#
# Interactive directory sync tool driven by a config file.
#
# Config file format (~/.sync-dirs), one entry per line:
#   <source>|<dest>|<src_uid>:<src_gid>|<dest_uid>:<dest_gid>
#
# EXCLUSION PATTERN HANDLING
# ==========================
# Three layers decide what is excluded from a sync. rsync evaluates filter
# rules first-match-wins, so the order they are added to the command defines
# their precedence (each layer is marked "LAYER n" where it is built below):
#
#   LAYER 1 — Global excludes (highest precedence)
#     The GLOBAL_EXCLUDES array below, passed as --exclude flags. These
#     match at any depth in every sync and can never be re-included, not
#     even by a gitignore negation.
#
#   LAYER 2 — Gitignore negations ('!pattern')
#     rsync's dir-merge filter cannot parse '!' lines (it misreads '!' as
#     its list-clearing token), so the script scans every .gitignore in the
#     sync source itself and translates each negation into explicit
#     '--filter=+ ...' include rules, anchored to that .gitignore's own
#     directory. Sitting between layers 1 and 3, they re-include files that
#     layer 3 would exclude — matching git, where a deeper negation
#     overrides a parent exclude — but never beat layer 1.
#
#   LAYER 3 — .gitignore excludes (lowest precedence)
#     A single '--filter=:- .gitignore' dir-merge rule. As rsync walks the
#     tree it reads every .gitignore it meets and applies its patterns from
#     that directory downward only (deeper files win over parent ones), so
#     nested .gitignore files like /a/b/.gitignore and /a/b/c/.gitignore
#     each govern exactly their own subtree, like in git.
#
# Known deviations from git:
#   - Pattern order: git resolves patterns in file order (last match wins),
#     so '!keep.tmp' followed by '*.tmp' would exclude keep.tmp; here
#     negations always beat gitignore excludes, so it would be included.
#   - Middle-slash anchoring: git anchors any pattern containing a slash
#     (e.g. 'tools/gen.txt' matches only at the .gitignore's own level),
#     but rsync's dir-merge anchors only on a LEADING slash — a
#     middle-slash pattern floats and also matches deeper paths like
#     'docs/tools/gen.txt'. Write '/tools/gen.txt' to get git's behavior.

set -euo pipefail

CONFIG_FILE="$HOME/.sync-dirs"

# LAYER 1 — Global exclude patterns applied to every sync (see header).
# Edit this array to change them; --help prints the current list.
GLOBAL_EXCLUDES=(".git" ".hg" ".svn" "node_modules" "*.swp" "*~")

usage() {
    cat <<EOF
Usage:
  $0 --init <source-dir> <dest-dir>
      Append a source/dest pair (with their ownership) to $CONFIG_FILE.
      Does nothing else. Creates the config file on first use.

  $0
      Interactive mode: list configured entries, pick one, confirm the
      exact rsync command, choose dry-run or real sync, then run it.
      rsync output is always human-readable (-avh).

Options:
  -h, --help    Show this help and exit.

Config file: $CONFIG_FILE
  One entry per line:  <source>|<dest>|<src_uid>:<src_gid>|<dest_uid>:<dest_gid>
  Lines starting with '#' and blank lines are ignored, so it is safe to
  edit by hand.

Global excludes (edit GLOBAL_EXCLUDES in this script to change):
  ${GLOBAL_EXCLUDES[*]}

Nested .gitignore files are honored per-directory via rsync's
--filter=':- .gitignore'. Negation patterns ('!pattern'), which that
filter cannot handle, are translated into explicit rsync include rules
scoped to each .gitignore's directory. Global excludes always win over
negations.
EOF
}

# ---------------------------------------------------------------------------
# Option parsing
# ---------------------------------------------------------------------------
INIT=0
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --init)    INIT=1 ;;
        --*)       echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)         ARGS+=("$1") ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# --init: append an entry to the config file and exit
# ---------------------------------------------------------------------------
if (( INIT )); then
    if [[ ${#ARGS[@]} -ne 2 ]]; then
        echo "Usage: $0 --init <source-dir> <dest-dir>" >&2
        exit 1
    fi
    src="${ARGS[0]}"
    dest="${ARGS[1]}"

    if [[ ! -d "$src" ]]; then
        echo "Error: source directory '$src' does not exist." >&2
        exit 1
    fi

    # On first use, create the config file with instructions for hand-editing.
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<'EOF'
# Sync entries for sync.sh — safe to edit by hand.
#
# One entry per line, four '|'-separated fields:
#   <source>|<dest>|<src_uid>:<src_gid>|<dest_uid>:<dest_gid>
#
# Example:
#   /mnt/projects/superdoc|/home/me/superdoc|1000:1000|1000:1000
#
# - Use absolute paths without a trailing slash.
# - Ownership is numeric uid:gid; the dest ownership is applied by rsync
#   via --chown (find yours with:  id -u  and  id -g).
# - To remove or change an entry, delete or edit its line.
# - Lines starting with '#' and blank lines are ignored.
EOF
    fi

    src_own="$(stat -c '%u:%g' "$src")"
    if [[ -d "$dest" ]]; then
        dest_own="$(stat -c '%u:%g' "$dest")"
    else
        # Destination doesn't exist yet; default to the current user.
        dest_own="$(id -u):$(id -g)"
    fi

    printf '%s|%s|%s|%s\n' "$src" "$dest" "$src_own" "$dest_own" >> "$CONFIG_FILE"
    echo "Added: $src -> $dest (src $src_own, dest $dest_own)"
    exit 0
fi

if [[ ${#ARGS[@]} -gt 0 ]]; then
    echo "Unexpected argument: ${ARGS[0]}" >&2
    usage >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Normal run: interactive sync
# ---------------------------------------------------------------------------
if [[ ! -s "$CONFIG_FILE" ]]; then
    echo "No entries in $CONFIG_FILE. Add one with: $0 --init <source> <dest>" >&2
    exit 1
fi

# Load entries, skipping comments and blank lines.
SRCS=() DESTS=() SRC_OWNS=() DEST_OWNS=()
while IFS='|' read -r src dest src_own dest_own; do
    [[ -z "$src" || "$src" == \#* ]] && continue
    SRCS+=("$src"); DESTS+=("$dest")
    SRC_OWNS+=("$src_own"); DEST_OWNS+=("$dest_own")
done < "$CONFIG_FILE"

if [[ ${#SRCS[@]} -eq 0 ]]; then
    echo "No entries in $CONFIG_FILE. Add one with: $0 --init <source> <dest>" >&2
    exit 1
fi

# Longest shared leading directory prefix of two paths (display only),
# compared whole component by component, e.g. /a/b/c/d + /a/b/e/f -> /a/b/.
shared_prefix() {
    local a="$1" b="$2" prefix=""
    while [[ "$a" == */* && "$b" == */* ]]; do
        [[ "${a%%/*}" == "${b%%/*}" ]] || break
        prefix+="${a%%/*}/"
        a="${a#*/}"; b="${b#*/}"
    done
    printf '%s' "$prefix"
}

# Each config entry gets two options: the normal direction, and (indented)
# the reversed direction for syncing changes back to the source.
echo "Configured syncs:"
for i in "${!SRCS[@]}"; do
    src="${SRCS[$i]}" dest="${DESTS[$i]}"
    prefix="$(shared_prefix "$src" "$dest")"
    src_disp="${src#"$prefix"}" dest_disp="${dest#"$prefix"}"
    # Only factor the prefix out when it names at least one shared directory
    # and neither path collapses to nothing; otherwise show full paths.
    if [[ "$prefix" == */*/* && -n "$src_disp" && -n "$dest_disp" ]]; then
        src_lead="[$prefix] $src_disp" dest_lead="[$prefix] $dest_disp"
    else
        src_lead="$src" dest_lead="$dest"
        src_disp="$src" dest_disp="$dest"
    fi
    printf '%2d) %s [%s] -> %s [%s]\n' "$((i * 2 + 1))" \
        "$src_lead" "${SRC_OWNS[$i]}" "$dest_disp" "${DEST_OWNS[$i]}"
    printf '  %2d) %s [%s] -> %s [%s]\n' "$((i * 2 + 2))" \
        "$dest_lead" "${DEST_OWNS[$i]}" "$src_disp" "${SRC_OWNS[$i]}"
done

max=$(( ${#SRCS[@]} * 2 ))
read -rp "Select entry [1-$max]: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > max )); then
    echo "Invalid selection." >&2
    exit 1
fi
idx=$(( (choice - 1) / 2 ))

if (( choice % 2 )); then
    SRC="${SRCS[$idx]}"
    DEST="${DESTS[$idx]}"
    DEST_OWN="${DEST_OWNS[$idx]}"
else
    # Reversed direction: sync destination back to source.
    SRC="${DESTS[$idx]}"
    DEST="${SRCS[$idx]}"
    DEST_OWN="${SRC_OWNS[$idx]}"
fi

if [[ ! -d "$SRC" ]]; then
    echo "Error: sync source '$SRC' does not exist." >&2
    exit 1
fi

# Build the rsync command. Exclusion layers 1-3 (see file header) are added
# in precedence order — rsync applies the first rule that matches a file.
#   --chown applies the configured destination ownership while syncing.
CMD=(rsync -avh --delete --chown="$DEST_OWN")

# LAYER 1: global excludes — first in the command, so nothing below
# (including negations) can re-include them.
for pattern in "${GLOBAL_EXCLUDES[@]}"; do
    CMD+=(--exclude="$pattern")
done

# LAYER 2: gitignore negations. The dir-merge in layer 3 misreads '!' as
# its list-clearing token, so scan every .gitignore in the sync source and
# translate each '!pattern' line into explicit include rules scoped to that
# .gitignore's own directory. Placed after layer 1 and before layer 3:
# negations override gitignore excludes, global excludes still win.
while IFS= read -r -d '' gi; do
    dir="${gi#"$SRC"}"           # /docs/.gitignore -> /docs, /.gitignore -> ""
    dir="${dir%/.gitignore}"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == \!* ]] || continue     # only negation lines
        pat="${line#!}"
        pat="${pat%"${pat##*[![:space:]]}"}"   # trim trailing whitespace
        [[ -z "$pat" ]] && continue
        if [[ "${pat%/}" == */* ]]; then
            # Contains a slash: gitignore anchors it to the .gitignore's
            # own directory -> one anchored include rule.
            CMD+=(--filter="+ $dir/${pat#/}")
        else
            # No slash: matches at any depth below the .gitignore's
            # directory -> include it there and in every subdirectory.
            CMD+=(--filter="+ $dir/$pat" --filter="+ $dir/**/$pat")
        fi
    done < "$gi"
done < <(find "$SRC" -name .gitignore -type f -print0)

# LAYER 3: .gitignore excludes. One dir-merge rule; rsync reads each
# .gitignore during the walk and applies its patterns only from that
# directory downward, deeper files overriding parent ones (git semantics).
CMD+=(--filter=':- .gitignore' "$SRC/" "$DEST/")

echo
echo "Command to run:"
printf '  %q' "${CMD[@]}"; echo

read -rp "Proceed? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

mkdir -p "$DEST"

read -rp "Dry-run? [y/N]: " dry
if [[ "$dry" =~ ^[Yy]$ ]]; then
    echo "Running dry-run..."
    "${CMD[@]}" --dry-run
    echo "Dry-run complete (nothing was changed): $SRC -> $DEST"

    echo
    echo "Command to run:"
    printf '  %q' "${CMD[@]}"; echo
    read -rp "Run the real sync now? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "Running sync..."
"${CMD[@]}"
echo "Sync complete: $SRC -> $DEST"
