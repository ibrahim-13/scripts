#!/usr/bin/env bash
#
# Interactive directory sync tool driven by a config file.
#
# Syncs one configured directory into another with rsync, honoring the
# .gitignore files it finds along the way. File modes and ownership are
# deliberately not managed, and the same file runs on Linux and macOS.
#
# NO PERMISSION HANDLING
# ======================
# Nothing here reads, records, or applies file modes or ownership:
#   - the config file stores only <source>|<dest>
#   - there is no --chown, and no 'stat'/'id' call left to feed one
#   - rsync runs with '-rltv', deliberately NOT '-a': -a implies -p -o -g
#     (permissions, owner, group), so avoiding it leaves modes and ownership
#     entirely to the destination filesystem and the caller's umask
#
# Dropping -p says less than it might seem to, so concretely:
#   - a NEW file is created with the source's mode masked by the receiving
#     umask. Under the usual umask 022 an executable therefore stays
#     executable (755 -> 755) while group/other write bits are dropped
#     (664 -> 644); a restrictive umask tightens it further (755 -> 700
#     under umask 077).
#   - an EXISTING destination file keeps the mode it already has, even when
#     its contents are re-transferred, so later source mode changes never
#     propagate. With -p (which -a implies) they would.
# Add -E (--executability) to RSYNC_OPTS below if you want the execute bit
# alone to keep tracking the source on files that already exist; it is the
# only permission-adjacent flag omitted here by choice rather than necessity.
#
# PORTABILITY
# ===========
# Targets bash 3.2, the version macOS ships: no associative arrays, no
# 'mapfile', no globstar, no '${var^^}'. At runtime the only external program
# is rsync — the .gitignore scan is a recursive shell-builtin walk instead of
# 'find -print0', and nothing calls 'stat -c' or 'id', both of which differ
# between GNU and BSD userlands. rsync's own
# flags are probed rather than assumed, because macOS has shipped more than
# one implementation (see the preflight section).
#
# CONFIG FILE
# ===========
# ~/.sync2-dirs, one entry per line:
#   <source>|<dest>
# Any further '|'-separated fields on a line are read and ignored, so a
# config that carries extra trailing columns (uid:gid ownership, say) can be
# used unchanged.
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

CONFIG_FILE="$HOME/.sync2-dirs"

# LAYER 1 — Global exclude patterns applied to every sync (see header).
# Edit this array to change them; --help prints the current list.
GLOBAL_EXCLUDES=(".git" ".hg" ".svn" "node_modules" "*.swp" "*~")

usage() {
    cat <<EOF
Usage:
  $0 --init <source-dir> <dest-dir>
      Append a source/dest pair to $CONFIG_FILE. Does nothing else.
      Creates the config file on first use.

  $0
      Interactive mode: list configured entries, pick one, confirm the
      exact rsync command, choose dry-run or real sync, then run it.

Options:
  -h, --help    Show this help and exit.

Config file: $CONFIG_FILE
  One entry per line:  <source>|<dest>
  Lines starting with '#' and blank lines are ignored, so it is safe to
  edit by hand. Extra '|'-separated fields are ignored.

File modes and ownership are not managed: rsync runs with -rltv, not -a.
Owner and group are never set, new files take the source mode masked by
your umask, and existing destination files keep the mode they have.

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
# Sync entries for sync2.sh — safe to edit by hand.
#
# One entry per line, two '|'-separated fields:
#   <source>|<dest>
#
# Example:
#   /home/me/dir1|/home/me/dir2
#
# - Use absolute paths without a trailing slash.
# - File modes and ownership are not managed; they are left to the
#   destination filesystem and your umask.
# - Any further '|'-separated fields are ignored, so entries carrying extra
#   trailing columns (uid:gid ownership, say) still work here.
# - To remove or change an entry, delete or edit its line.
# - Lines starting with '#' and blank lines are ignored.
EOF
    fi

    printf '%s|%s\n' "$src" "$dest" >> "$CONFIG_FILE"
    echo "Added: $src -> $dest"
    exit 0
fi

if [[ ${#ARGS[@]} -gt 0 ]]; then
    echo "Unexpected argument: ${ARGS[0]}" >&2
    usage >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Portability preflight
#
# rsync is the only external program this script needs, and it must
# understand filter rules. That is worth checking rather than assuming:
# macOS has shipped rsync 2.6.9 (filter rules present since 2.6.0) and, more
# recently, openrsync, whose option set is narrower. Probe the help text so
# an unsupported rsync fails here with an explanation instead of failing
# mid-sync with an option error.
# ---------------------------------------------------------------------------
if ! command -v rsync >/dev/null 2>&1; then
    echo "Error: rsync was not found in PATH." >&2
    exit 1
fi

RSYNC_HELP="$(rsync --help 2>&1 || true)"

if [[ "$RSYNC_HELP" != *--filter* ]]; then
    echo "Error: this rsync does not support --filter rules, which this" >&2
    echo "script needs to apply .gitignore patterns per directory." >&2
    echo "  rsync in use: $(command -v rsync)" >&2
    echo "On macOS, install a full rsync (e.g. 'brew install rsync')." >&2
    exit 1
fi

# -r -l -t: recurse, recreate symlinks as symlinks, preserve mtimes (which
# is what keeps repeat syncs incremental). Not -a: see the header.
RSYNC_OPTS=(-r -l -t -v --delete)
# -h is human-readable in GNU rsync but has meant --help elsewhere; only
# pass it when this rsync advertises the long form.
if [[ "$RSYNC_HELP" == *human-readable* ]]; then
    RSYNC_OPTS+=(-h)
fi

# ---------------------------------------------------------------------------
# Normal run: interactive sync
# ---------------------------------------------------------------------------
if [[ ! -s "$CONFIG_FILE" ]]; then
    echo "No entries in $CONFIG_FILE. Add one with: $0 --init <source> <dest>" >&2
    exit 1
fi

# Load entries, skipping comments and blank lines. 'rest' absorbs any extra
# '|' fields so they are ignored rather than folded into the destination
# path. The '|| [[ -n ... ]]' guard reads a final line that has no trailing
# newline.
SRCS=() DESTS=()
while IFS='|' read -r src dest rest || [[ -n "$src" ]]; do
    [[ -z "$src" || "$src" == \#* ]] && continue
    SRCS+=("$src"); DESTS+=("$dest")
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
    printf '%2d) %s -> %s\n'   "$((i * 2 + 1))" "$src_lead"  "$dest_disp"
    printf '  %2d) %s -> %s\n' "$((i * 2 + 2))" "$dest_lead" "$src_disp"
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
else
    # Reversed direction: sync destination back to source.
    SRC="${DESTS[$idx]}"
    DEST="${SRCS[$idx]}"
fi

if [[ ! -d "$SRC" ]]; then
    echo "Error: sync source '$SRC' does not exist." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Collect every .gitignore under the sync source, for layer 2 below.
#
# Done with shell builtins rather than 'find -print0' to keep the script
# free of userland differences. Two deliberate restrictions:
#   - symlinked directories are not descended into, matching rsync's -l
#     (which copies them as links), and incidentally ruling out link loops
#   - directories matching a global exclude are pruned: layer 1 outranks
#     anything they could contribute, so their negations could never
#     re-include a file anyway
# ---------------------------------------------------------------------------
is_globally_excluded() {
    local name="$1" pattern
    for pattern in "${GLOBAL_EXCLUDES[@]}"; do
        # Unquoted $pattern on purpose: it is a glob, e.g. '*.swp'.
        if [[ "$name" == $pattern ]]; then return 0; fi
    done
    return 1
}

GITIGNORES=()
collect_gitignores() {
    local dir="$1" entry name
    if [[ -f "$dir/.gitignore" ]]; then
        GITIGNORES+=("$dir/.gitignore")
    fi
    # The three globs together cover every entry except '.' and '..'.
    # A glob that matches nothing expands to itself; the -d test drops it.
    for entry in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
        [[ -d "$entry" && ! -L "$entry" ]] || continue
        name="${entry##*/}"
        if is_globally_excluded "$name"; then continue; fi
        collect_gitignores "$entry"
    done
    return 0
}

collect_gitignores "$SRC"

# Build the rsync command. Exclusion layers 1-3 (see file header) are added
# in precedence order — rsync applies the first rule that matches a file.
CMD=(rsync "${RSYNC_OPTS[@]}")

# LAYER 1: global excludes — first in the command, so nothing below
# (including negations) can re-include them.
for pattern in "${GLOBAL_EXCLUDES[@]}"; do
    CMD+=(--exclude="$pattern")
done

# LAYER 2: gitignore negations. The dir-merge in layer 3 misreads '!' as
# its list-clearing token, so read every .gitignore in the sync source and
# translate each '!pattern' line into explicit include rules scoped to that
# .gitignore's own directory. Placed after layer 1 and before layer 3:
# negations override gitignore excludes, global excludes still win.
if (( ${#GITIGNORES[@]} > 0 )); then
    for gi in "${GITIGNORES[@]}"; do
        dir="${gi#"$SRC"}"           # /docs/.gitignore -> /docs, /.gitignore -> ""
        dir="${dir%/.gitignore}"
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" == \!* ]] || continue     # only negation lines
            pat="${line#!}"
            # Trim trailing whitespace, which also drops a CR from a
            # .gitignore saved with Windows line endings.
            pat="${pat%"${pat##*[![:space:]]}"}"
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
    done
fi

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
