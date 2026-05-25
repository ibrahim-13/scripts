#!/usr/bin/env bash
set -eu

# --- Error Codes ---
ERR_MISSING_DEP=10
ERR_STATE_MISSING=11
ERR_INIT_FAILED=12
ERR_CONFLICT=13
ERR_INVALID_ARG=14
ERR_GENERAL=15

# --- Paths (relative to CWD where the user runs this script) ---
BASE_DIR="$(pwd)"
DIR_PATCHES="$BASE_DIR/patches"
DIR_REPO="$BASE_DIR/repo"
DIR_STATE="$BASE_DIR/state"
FILE_REPO="$DIR_STATE/repo.txt"
FILE_COMMIT="$DIR_STATE/commit.txt"
GITIGNORE="$BASE_DIR/.gitignore"

# --- Global flags ---
ARG_CONFIRM="false"

# --- Utility functions ---

function print_info {
    echo "[ info   ] $1"
}

function print_error {
    echo "[ error  ] $1" >&2
}

function prompt_confirmation {
    local prompt_text="$1"
    if [ "$ARG_CONFIRM" = "true" ]; then
        return 0
    fi
    local answer
    printf "[ prompt ] %s (y/N): " "$prompt_text"
    read -r answer
    case "$answer" in
        [Yy]) return 0 ;;
        *) return 1 ;;
    esac
}

function check_deps {
    local missing=0
    for cmd in git; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            print_error "required command not found: $cmd"
            missing=1
        fi
    done
    if [ "$missing" -ne 0 ]; then
        exit $ERR_MISSING_DEP
    fi
}

function check_state {
    if [ ! -d "$DIR_STATE" ]; then
        print_error "state directory not found; run: $(basename "$0") init"
        exit $ERR_STATE_MISSING
    fi
    if [ ! -s "$FILE_REPO" ]; then
        print_error "state/repo.txt is empty or missing; run: $(basename "$0") init"
        exit $ERR_STATE_MISSING
    fi
    if [ ! -s "$FILE_COMMIT" ]; then
        print_error "state/commit.txt is empty or missing; run: $(basename "$0") init"
        exit $ERR_STATE_MISSING
    fi
}

# Convert a commit subject to a URL-safe slug (without numeric prefix).
# $1: commit subject string
# Outputs the slug to stdout.
function generate_patch_name {
    local subject="$1"
    local slug
    slug=$(printf '%s' "$subject" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -cs 'a-z0-9' '-' \
        | sed 's/^-*//;s/-*$//')
    printf '%s' "$slug"
}

# Parse the commit subject from a .patch file's Subject: header.
# Strips the [PATCH N/M] or [PATCH] prefix that git format-patch adds.
# $1: path to .patch file
# Outputs the commit subject to stdout.
function get_subject_from_patch {
    local patch_file="$1"
    local raw
    raw=$(grep "^Subject: " "$patch_file" | head -1 | sed 's/^Subject: //')
    # Strip [PATCH 1/3] or [PATCH] prefix
    printf '%s' "$raw" | sed 's/^\[PATCH[^]]*\] //'
}

# Rename patch files from git's 4-digit prefix to 3-digit prefix.
# Moves files from $1 (source dir) to $2 (destination dir).
# $1: source directory containing NNNNname.patch files
# $2: destination directory
function _move_and_rename_patches {
    local src_dir="$1"
    local dst_dir="$2"
    for f in "$src_dir"/[0-9]*.patch; do
        [ -f "$f" ] || continue
        local fname
        fname=$(basename "$f")
        local numpart="${fname%%-*}"
        local rest="${fname#*-}"
        local num
        num=$((10#$numpart))
        local newname
        newname=$(printf "%03d-%s" "$num" "$rest")
        mv "$f" "$dst_dir/$newname"
    done
}

# --- Commands ---

function cmd_init {
    # Create directories
    mkdir -p "$DIR_PATCHES" || { print_error "failed to create patches/"; exit $ERR_INIT_FAILED; }
    mkdir -p "$DIR_STATE"   || { print_error "failed to create state/"; rm -rf "$DIR_PATCHES"; exit $ERR_INIT_FAILED; }
    touch "$FILE_REPO" "$FILE_COMMIT"

    # Handle .gitignore: create if absent, add "repo" line if not present
    if [ ! -f "$GITIGNORE" ]; then
        touch "$GITIGNORE"
    fi
    if ! grep -qxF "repo" "$GITIGNORE" && ! grep -qxF "repo/" "$GITIGNORE"; then
        echo "repo" >> "$GITIGNORE"
    fi

    # Prompt for repository URL
    local repo_url
    printf "[ input  ] Enter repository URL: "
    read -r repo_url || true
    if [ -z "$repo_url" ]; then
        print_error "repository URL cannot be empty"
        rm -rf "$DIR_PATCHES" "$DIR_STATE"
        exit $ERR_INIT_FAILED
    fi
    echo "$repo_url" > "$FILE_REPO"

    # Clone repository (git clone creates repo/ itself).
    # Redirect stdin to /dev/null so git clone does not consume the input pipe
    # that is meant for the subsequent read prompts.
    print_info "cloning repository: $repo_url"
    if ! git clone "$repo_url" "$DIR_REPO" < /dev/null; then
        print_error "git clone failed for: $repo_url"
        rm -rf "$DIR_PATCHES" "$DIR_STATE" "$DIR_REPO"
        exit $ERR_INIT_FAILED
    fi

    # Prompt for commit hash (empty = use HEAD)
    local commit_hash
    printf "[ input  ] Enter commit hash (leave empty for latest): "
    read -r commit_hash || true

    if [ -z "$commit_hash" ]; then
        commit_hash=$(git -C "$DIR_REPO" rev-parse HEAD < /dev/null)
        print_info "using latest commit: $commit_hash"
    fi
    echo "$commit_hash" > "$FILE_COMMIT"

    # Checkout to the specified commit
    print_info "checking out commit: $commit_hash"
    if ! git -C "$DIR_REPO" checkout "$commit_hash" < /dev/null; then
        print_error "git checkout failed for commit: $commit_hash"
        rm -rf "$DIR_PATCHES" "$DIR_STATE" "$DIR_REPO"
        exit $ERR_INIT_FAILED
    fi

    print_info "initialization complete"
}

function cmd_create_all_patches {
    check_state
    local base_commit
    base_commit=$(cat "$FILE_COMMIT")

    local commit_count
    commit_count=$(git -C "$DIR_REPO" rev-list --count "${base_commit}..HEAD" < /dev/null)

    if [ "$commit_count" -eq 0 ]; then
        print_info "no commits after base commit, nothing to generate"
        return 0
    fi

    # Delete all existing patch files
    print_info "removing existing patch files"
    rm -f "$DIR_PATCHES"/*.patch 2>/dev/null || true

    # Generate patches to a temp dir, then rename/move to patches/
    local tmp_dir
    tmp_dir=$(mktemp -d)

    print_info "generating $commit_count patch(es) from base commit $base_commit"
    if ! git -C "$DIR_REPO" format-patch --start-number 0 "${base_commit}..HEAD" -o "$tmp_dir" < /dev/null > /dev/null; then
        rm -rf "$tmp_dir"
        print_error "git format-patch failed"
        exit $ERR_GENERAL
    fi

    _move_and_rename_patches "$tmp_dir" "$DIR_PATCHES"
    rm -rf "$tmp_dir"

    print_info "patches written to: $DIR_PATCHES"
}

function cmd_create_patch {
    check_state
    local base_commit
    base_commit=$(cat "$FILE_COMMIT")

    # Collect subjects of existing patch files
    local existing_subjects=()
    if ls "$DIR_PATCHES"/*.patch > /dev/null 2>&1; then
        for patch in $(ls "$DIR_PATCHES"/*.patch | sort); do
            existing_subjects+=("$(get_subject_from_patch "$patch")")
        done
    fi

    # Find the highest existing patch number (start next numbering after it)
    local highest_num=-1
    if ls "$DIR_PATCHES"/*.patch > /dev/null 2>&1; then
        for patch in $(ls "$DIR_PATCHES"/*.patch | sort); do
            local fname
            fname=$(basename "$patch")
            local numpart="${fname%%-*}"
            local num
            num=$((10#$numpart))
            if [ "$num" -gt "$highest_num" ]; then
                highest_num=$num
            fi
        done
    fi

    local next_num=$((highest_num + 1))
    local new_patches=0

    # Iterate commits after base (oldest first), generate patch for each without a match
    while IFS= read -r commit_line; do
        [ -z "$commit_line" ] && continue
        local hash="${commit_line%% *}"
        local subject="${commit_line#* }"

        # Check if this commit subject already has a corresponding patch
        local found=0
        for s in "${existing_subjects[@]+"${existing_subjects[@]}"}"; do
            if [ "$s" = "$subject" ]; then
                found=1
                break
            fi
        done

        if [ "$found" -eq 0 ]; then
            local tmp_dir
            tmp_dir=$(mktemp -d)

            if ! git -C "$DIR_REPO" format-patch -1 "$hash" --start-number "$next_num" -o "$tmp_dir" < /dev/null > /dev/null; then
                rm -rf "$tmp_dir"
                print_error "git format-patch failed for commit: $hash"
                exit $ERR_GENERAL
            fi

            _move_and_rename_patches "$tmp_dir" "$DIR_PATCHES"
            rm -rf "$tmp_dir"

            # Track the new subject so subsequent iterations don't re-generate it
            existing_subjects+=("$subject")
            next_num=$((next_num + 1))
            new_patches=$((new_patches + 1))

            local new_patch_name
            new_patch_name=$(printf "%03d-%s.patch" "$((next_num - 1))" "$(generate_patch_name "$subject")")
            print_info "created patch: $new_patch_name"
        fi
    done < <(git -C "$DIR_REPO" log --format="%H %s" --reverse "${base_commit}..HEAD" < /dev/null)

    if [ "$new_patches" -eq 0 ]; then
        print_info "no new patches to create"
    else
        print_info "created $new_patches new patch(es)"
    fi
}

function cmd_apply_patches {
    check_state
    local base_commit
    base_commit=$(cat "$FILE_COMMIT")

    # Subjects of commits already applied after base
    local applied_subjects
    applied_subjects=$(git -C "$DIR_REPO" log --format="%s" "${base_commit}..HEAD" < /dev/null 2>/dev/null || true)

    # Collect patches that are not yet applied, in sorted order
    local patches_to_apply=()
    if ls "$DIR_PATCHES"/*.patch > /dev/null 2>&1; then
        for patch in $(ls "$DIR_PATCHES"/*.patch | sort); do
            local subject
            subject=$(get_subject_from_patch "$patch")
            if ! printf '%s\n' "$applied_subjects" | grep -qxF "$subject"; then
                patches_to_apply+=("$patch")
            fi
        done
    fi

    if [ ${#patches_to_apply[@]} -eq 0 ]; then
        print_info "all patches already applied, nothing to do"
        return 0
    fi

    for patch in "${patches_to_apply[@]}"; do
        print_info "applying: $(basename "$patch")"
        if ! git -C "$DIR_REPO" am -3 --ignore-space-change "$patch" < /dev/null; then
            print_error "conflict while applying: $(basename "$patch")"
            print_error "resolve conflicts in repo/, then run:"
            print_error "  cd repo && git am --continue"
            print_error "then re-run: $(basename "$0") apply patches"
            exit $ERR_CONFLICT
        fi
    done

    print_info "all patches applied successfully"
}

function cmd_reset_patches {
    check_state
    local base_commit
    base_commit=$(cat "$FILE_COMMIT")

    print_info "resetting repo to base commit: $base_commit"
    if ! git -C "$DIR_REPO" reset --hard "$base_commit" < /dev/null; then
        print_error "git reset --hard failed"
        exit $ERR_GENERAL
    fi
    print_info "reset complete; HEAD is now at base commit"
}

function cmd_rebase_to_commit {
    check_state

    local new_commit
    printf "[ input  ] Enter new base commit hash: "
    read -r new_commit || true

    if [ -z "$new_commit" ]; then
        print_error "commit hash cannot be empty"
        exit $ERR_INVALID_ARG
    fi

    # Validate the commit exists in the local repo object store
    if ! git -C "$DIR_REPO" cat-file -e "${new_commit}^{commit}" < /dev/null 2>/dev/null; then
        print_error "commit not found in repo: $new_commit"
        print_error "you may need to fetch first: git -C repo fetch"
        exit $ERR_INVALID_ARG
    fi

    # Step 1: Remove all applied patch commits (move HEAD back to old base)
    cmd_reset_patches

    # Step 2: Move to the new base commit
    print_info "moving repo to new base commit: $new_commit"
    if ! git -C "$DIR_REPO" reset --hard "$new_commit" < /dev/null; then
        print_error "failed to reset to new commit: $new_commit"
        exit $ERR_GENERAL
    fi

    # Step 3: Update state BEFORE re-applying so that if a conflict occurs
    # the user can run 'create all patches' with the correct base after resolving.
    echo "$new_commit" > "$FILE_COMMIT"

    # Step 4: Re-apply all patches in order
    if ls "$DIR_PATCHES"/*.patch > /dev/null 2>&1; then
        print_info "re-applying all patches on new base..."
        for patch in $(ls "$DIR_PATCHES"/*.patch | sort); do
            print_info "applying: $(basename "$patch")"
            if ! git -C "$DIR_REPO" am -3 --ignore-space-change "$patch" < /dev/null; then
                print_error "conflict while applying: $(basename "$patch")"
                print_error "resolve conflicts in repo/, then run:"
                print_error "  cd repo && git am --continue"
                print_error "then re-run: $(basename "$0") create all patches"
                exit $ERR_CONFLICT
            fi
        done
    else
        print_info "no patches to re-apply"
    fi

    # Step 5: Regenerate all patch files (they may have rebased cleanly)
    cmd_create_all_patches

    print_info "rebase to $new_commit complete"
}

function usage {
    if [ -n "${1:-}" ]; then
        print_error "$1"
        echo ""
    fi
    cat << EOF
patcher - manage patches for a git repository

Usage: $(basename "$0") [-y] [-h|--help] <command>

Options:
  -y                   skip all confirmation prompts (treat as yes)
  -h, --help           print this help and exit

Commands:
  init                 initialize patcher: clone repo, set base commit
  create all patches   regenerate ALL patch files from git history (overwrites)
  create patch         create patch files only for new commits not yet patched
  apply patches        apply unapplied patch files to the repository
  reset patches        reset repo HEAD to base commit (removes patch commits)
  rebase to commit     rebase the patch stack onto a new upstream base commit
EOF
    exit 1
}

# --- Main ---

check_deps

# Pre-scan for -y and help flags before processing the command
for arg in "$@"; do
    case "$arg" in
        -y) ARG_CONFIRM="true" ;;
        -h|--help) usage ;;
    esac
done

# Build positional args list (without flags)
ARGS=()
for arg in "$@"; do
    case "$arg" in
        -y|-h|--help) ;;
        *) ARGS+=("$arg") ;;
    esac
done

if [ ${#ARGS[@]} -eq 0 ]; then
    usage
fi

CMD="${ARGS[0]}"

case "$CMD" in
    init)
        cmd_init
        ;;
    create)
        if [ ${#ARGS[@]} -ge 3 ] && [ "${ARGS[1]}" = "all" ] && [ "${ARGS[2]}" = "patches" ]; then
            cmd_create_all_patches
        elif [ ${#ARGS[@]} -ge 2 ] && [ "${ARGS[1]}" = "patch" ]; then
            cmd_create_patch
        else
            usage "unknown 'create' subcommand: ${ARGS[*]:1}"
        fi
        ;;
    apply)
        if [ ${#ARGS[@]} -ge 2 ] && [ "${ARGS[1]}" = "patches" ]; then
            cmd_apply_patches
        else
            usage "unknown 'apply' subcommand: ${ARGS[*]:1}"
        fi
        ;;
    reset)
        if [ ${#ARGS[@]} -ge 2 ] && [ "${ARGS[1]}" = "patches" ]; then
            cmd_reset_patches
        else
            usage "unknown 'reset' subcommand: ${ARGS[*]:1}"
        fi
        ;;
    rebase)
        if [ ${#ARGS[@]} -ge 3 ] && [ "${ARGS[1]}" = "to" ] && [ "${ARGS[2]}" = "commit" ]; then
            cmd_rebase_to_commit
        else
            usage "unknown 'rebase' subcommand: ${ARGS[*]:1}"
        fi
        ;;
    *)
        usage "unknown command: $CMD"
        ;;
esac
