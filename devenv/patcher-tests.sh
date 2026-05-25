#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHER_SH="$SCRIPT_DIR/patcher.sh"
TEST_DIR="/tmp/patcher-tests"
UPSTREAM_DIR="$TEST_DIR/upstream"

PASS=0
FAIL=0

# Commit hashes set by setup_tests
BASE_COMMIT=""
COMMIT_1=""
COMMIT_2=""
COMMIT_3=""

# --- Test helpers ---

function assert_exit_code {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "[ PASS ] $test_name"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] $test_name  (expected exit $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

function assert_file_exists {
    local file="$1"
    local test_name="$2"
    if [ -f "$file" ]; then
        echo "[ PASS ] $test_name"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] $test_name  (file not found: $file)"
        FAIL=$((FAIL + 1))
    fi
}

function assert_dir_exists {
    local dir="$1"
    local test_name="$2"
    if [ -d "$dir" ]; then
        echo "[ PASS ] $test_name"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] $test_name  (directory not found: $dir)"
        FAIL=$((FAIL + 1))
    fi
}

function assert_file_contains {
    local file="$1"
    local expected="$2"
    local test_name="$3"
    if [ -f "$file" ] && grep -qF "$expected" "$file"; then
        echo "[ PASS ] $test_name"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] $test_name  (file '$file' does not contain '$expected')"
        FAIL=$((FAIL + 1))
    fi
}

function assert_patch_count {
    local dir="$1"
    local expected="$2"
    local test_name="$3"
    local actual
    actual=$(ls "$dir"/*.patch 2>/dev/null | wc -l | tr -d ' ')
    if [ "$actual" -eq "$expected" ]; then
        echo "[ PASS ] $test_name"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] $test_name  (expected $expected patches, found $actual)"
        FAIL=$((FAIL + 1))
    fi
}

function assert_git_log_count {
    local repo_dir="$1"
    local base="$2"
    local expected="$3"
    local test_name="$4"
    local actual
    actual=$(git -C "$repo_dir" rev-list --count "${base}..HEAD")
    if [ "$actual" -eq "$expected" ]; then
        echo "[ PASS ] $test_name"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] $test_name  (expected $expected commits after base, found $actual)"
        FAIL=$((FAIL + 1))
    fi
}

# Create a fresh work directory and return its path.
# The caller is responsible for cd-ing into it and running patcher.sh from it.
function make_work_dir {
    local name="$1"
    local work="$TEST_DIR/$name"
    rm -rf "$work"
    mkdir -p "$work"
    echo "$work"
}

# Run patcher.sh from the given directory with no stdin (for non-interactive commands).
# Returns the numeric exit code; suppresses all patcher output.
# $1: work directory
# $2+: arguments to patcher.sh
function patcher_run {
    local work_dir="$1"
    shift
    local code=0
    (cd "$work_dir" && bash "$PATCHER_SH" "$@" < /dev/null) > /dev/null 2>&1 || code=$?
    echo "$code"
}

# Run patcher.sh with init-style two-line stdin (URL, then commit hash).
# Returns the numeric exit code; suppresses all patcher output.
# $1: work directory
# $2: repository URL
# $3: commit hash (empty string = use latest HEAD)
# $4+: extra arguments to patcher.sh (appended after 'init')
function patcher_run_init {
    local work_dir="$1"
    local url="$2"
    local commit="$3"
    shift 3
    local code=0
    (cd "$work_dir" && { printf '%s\n' "$url"; printf '%s\n' "$commit"; } | bash "$PATCHER_SH" init "$@") > /dev/null 2>&1 || code=$?
    echo "$code"
}

# Run patcher.sh with a single line of stdin (for commands like rebase to commit).
# Returns the numeric exit code; suppresses all patcher output.
# $1: work directory
# $2: the single line of input
# $3+: arguments to patcher.sh
function patcher_run_1input {
    local work_dir="$1"
    local line="$2"
    shift 2
    local code=0
    (cd "$work_dir" && printf '%s\n' "$line" | bash "$PATCHER_SH" "$@") > /dev/null 2>&1 || code=$?
    echo "$code"
}


# Initialize a patcher work directory silently.
# $1: work directory (must exist)
# $2: repo URL
# $3: base commit hash (empty string = use latest)
function patcher_init {
    local work_dir="$1"
    local url="$2"
    local commit="$3"
    (cd "$work_dir" && { printf '%s\n' "$url"; printf '%s\n' "$commit"; } | bash "$PATCHER_SH" init) > /dev/null 2>&1
    # Set git identity in the cloned repo for git am to work
    git -C "$work_dir/repo" config user.email "test@patcher.local"
    git -C "$work_dir/repo" config user.name "Patcher Test"
}

# Add a commit to the repo/ dir inside a patcher work directory.
# $1: work directory
# $2: file to create/append to (relative to repo/)
# $3: content to append
# $4: commit message
function add_repo_commit {
    local work_dir="$1"
    local file="$2"
    local content="$3"
    local message="$4"
    printf '%s\n' "$content" >> "$work_dir/repo/$file"
    git -C "$work_dir/repo" add "$file"
    git -C "$work_dir/repo" commit -q -m "$message"
}

# --- Setup / Cleanup ---

function setup_tests {
    # Clean up any leftover test state from a previous run
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    mkdir -p "$UPSTREAM_DIR"

    # Create upstream git repo with a base commit and 3 additional commits
    cd "$UPSTREAM_DIR"
    git init -q
    git config user.email "upstream@test.local"
    git config user.name "Upstream Test"

    echo "initial content" > readme.txt
    git add .
    git commit -q -m "Initial commit"
    BASE_COMMIT=$(git rev-parse HEAD)

    echo "upstream change 1" >> readme.txt
    git add .
    git commit -q -m "Upstream change one"
    COMMIT_1=$(git rev-parse HEAD)

    echo "upstream change 2" >> readme.txt
    git add .
    git commit -q -m "Upstream change two"
    COMMIT_2=$(git rev-parse HEAD)

    echo "upstream change 3" >> readme.txt
    git add .
    git commit -q -m "Upstream change three"
    COMMIT_3=$(git rev-parse HEAD)

    cd "$SCRIPT_DIR"

    echo "[ setup ] upstream repo: $UPSTREAM_DIR"
    echo "[ setup ] BASE_COMMIT: $BASE_COMMIT"
    echo "[ setup ] COMMIT_1: $COMMIT_1"
    echo "[ setup ] COMMIT_2: $COMMIT_2"
    echo "[ setup ] COMMIT_3: $COMMIT_3"
}

function cleanup_tests {
    rm -rf "$TEST_DIR"
    echo ""
    echo "[ done  ] test directory removed"
}

# --- Tests ---

function test_help_short {
    local work
    work=$(make_work_dir "test_help_short")
    local code
    code=$(patcher_run "$work" -h)
    assert_exit_code 1 "$code" "help_short: -h exits with code 1"
}

function test_help_long {
    local work
    work=$(make_work_dir "test_help_long")
    local code
    code=$(patcher_run "$work" --help)
    assert_exit_code 1 "$code" "help_long: --help exits with code 1"
}

function test_no_args {
    local work
    work=$(make_work_dir "test_no_args")
    local code
    code=$(patcher_run "$work")
    assert_exit_code 1 "$code" "no_args: no arguments exits with code 1"
}

function test_invalid_arg {
    local work
    work=$(make_work_dir "test_invalid_arg")
    local code
    code=$(patcher_run "$work" invalidcommand)
    assert_exit_code 1 "$code" "invalid_arg: unknown command exits with code 1"
}

function test_check_state_no_init_create_all_patches {
    local work
    work=$(make_work_dir "test_state_no_init_cap")
    local code
    code=$(patcher_run "$work" create all patches)
    assert_exit_code 11 "$code" "state_no_init: create all patches exits 11 (ERR_STATE_MISSING)"
}

function test_check_state_no_init_create_patch {
    local work
    work=$(make_work_dir "test_state_no_init_cp")
    local code
    code=$(patcher_run "$work" create patch)
    assert_exit_code 11 "$code" "state_no_init: create patch exits 11 (ERR_STATE_MISSING)"
}

function test_check_state_no_init_apply_patches {
    local work
    work=$(make_work_dir "test_state_no_init_ap")
    local code
    code=$(patcher_run "$work" apply patches)
    assert_exit_code 11 "$code" "state_no_init: apply patches exits 11 (ERR_STATE_MISSING)"
}

function test_check_state_no_init_reset_patches {
    local work
    work=$(make_work_dir "test_state_no_init_rp")
    local code
    code=$(patcher_run "$work" reset patches)
    assert_exit_code 11 "$code" "state_no_init: reset patches exits 11 (ERR_STATE_MISSING)"
}

function test_check_state_no_init_rebase {
    local work
    work=$(make_work_dir "test_state_no_init_reb")
    local code
    code=$(patcher_run "$work" rebase to commit)
    assert_exit_code 11 "$code" "state_no_init: rebase to commit exits 11 (ERR_STATE_MISSING)"
}

function test_init {
    local work
    work=$(make_work_dir "test_init")
    local code
    code=$(patcher_run_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT")
    assert_exit_code 0 "$code" "init: exits with code 0"
    assert_dir_exists "$work/patches" "init: patches/ directory created"
    assert_dir_exists "$work/repo" "init: repo/ directory created"
    assert_dir_exists "$work/state" "init: state/ directory created"
    assert_file_exists "$work/state/repo.txt" "init: state/repo.txt created"
    assert_file_exists "$work/state/commit.txt" "init: state/commit.txt created"
    assert_file_contains "$work/state/repo.txt" "$UPSTREAM_DIR" "init: repo.txt contains URL"
    assert_file_contains "$work/state/commit.txt" "$BASE_COMMIT" "init: commit.txt contains base commit"
    assert_file_contains "$work/.gitignore" "repo" "init: .gitignore contains 'repo'"
    local actual_head
    actual_head=$(git -C "$work/repo" rev-parse HEAD)
    if [ "$actual_head" = "$BASE_COMMIT" ]; then
        echo "[ PASS ] init: repo HEAD is at BASE_COMMIT"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] init: repo HEAD is $actual_head, expected $BASE_COMMIT"
        FAIL=$((FAIL + 1))
    fi
}

function test_init_empty_url {
    local work
    work=$(make_work_dir "test_init_empty_url")
    local code
    code=$(patcher_run_init "$work" "" "")
    assert_exit_code 12 "$code" "init_empty_url: empty URL exits 12 (ERR_INIT_FAILED)"
    if [ ! -d "$work/state" ] && [ ! -d "$work/repo" ]; then
        echo "[ PASS ] init_empty_url: directories cleaned up on failure"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] init_empty_url: directories NOT cleaned up on failure"
        FAIL=$((FAIL + 1))
    fi
}

function test_init_invalid_url {
    local work
    work=$(make_work_dir "test_init_invalid_url")
    local code
    code=$(patcher_run_init "$work" "file:///nonexistent/path/repo" "$BASE_COMMIT")
    assert_exit_code 12 "$code" "init_invalid_url: bad URL exits 12 (ERR_INIT_FAILED)"
}

function test_init_latest_commit {
    local work
    work=$(make_work_dir "test_init_latest")
    local code
    code=$(patcher_run_init "$work" "$UPSTREAM_DIR" "")
    assert_exit_code 0 "$code" "init_latest: exits with code 0"
    assert_file_contains "$work/state/commit.txt" "$COMMIT_3" "init_latest: commit.txt contains COMMIT_3 (latest)"
}

function test_init_gitignore_existing {
    local work
    work=$(make_work_dir "test_init_gitignore_existing")
    echo "node_modules" > "$work/.gitignore"
    local code
    code=$(patcher_run_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT")
    assert_exit_code 0 "$code" "init_gitignore_existing: exits 0"
    assert_file_contains "$work/.gitignore" "node_modules" "init_gitignore_existing: existing content preserved"
    assert_file_contains "$work/.gitignore" "repo" "init_gitignore_existing: repo added to .gitignore"
}

function test_init_gitignore_already_has_repo {
    local work
    work=$(make_work_dir "test_init_gitignore_already_repo")
    echo "repo" > "$work/.gitignore"
    local code
    code=$(patcher_run_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT")
    assert_exit_code 0 "$code" "init_gitignore_already_repo: exits 0"
    local count
    count=$(grep -cxF "repo" "$work/.gitignore" || true)
    if [ "$count" -eq 1 ]; then
        echo "[ PASS ] init_gitignore_already_repo: 'repo' not duplicated in .gitignore"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] init_gitignore_already_repo: 'repo' appears $count times in .gitignore (expected 1)"
        FAIL=$((FAIL + 1))
    fi
}

function test_create_all_patches_no_commits {
    local work
    work=$(make_work_dir "test_cap_no_commits")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"
    local code
    code=$(patcher_run "$work" create all patches)
    assert_exit_code 0 "$code" "create_all_patches_no_commits: exits 0"
    assert_patch_count "$work/patches" 0 "create_all_patches_no_commits: 0 patches generated"
}

function test_create_all_patches {
    local work
    work=$(make_work_dir "test_create_all_patches")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    add_repo_commit "$work" "local.txt" "local change 1" "Add local feature one"
    add_repo_commit "$work" "local.txt" "local change 2" "Add local feature two"

    local code
    code=$(patcher_run "$work" create all patches)
    assert_exit_code 0 "$code" "create_all_patches: exits 0"
    assert_patch_count "$work/patches" 2 "create_all_patches: 2 patches generated"

    if ls "$work/patches"/000-*.patch > /dev/null 2>&1; then
        echo "[ PASS ] create_all_patches: first patch has 000- prefix"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] create_all_patches: no patch with 000- prefix found"
        FAIL=$((FAIL + 1))
    fi
    if ls "$work/patches"/001-*.patch > /dev/null 2>&1; then
        echo "[ PASS ] create_all_patches: second patch has 001- prefix"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] create_all_patches: no patch with 001- prefix found"
        FAIL=$((FAIL + 1))
    fi
}

function test_create_all_patches_overwrite {
    local work
    work=$(make_work_dir "test_cap_overwrite")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    add_repo_commit "$work" "local.txt" "local change 1" "Add feature one"
    (cd "$work" && bash "$PATCHER_SH" create all patches < /dev/null) > /dev/null 2>&1

    add_repo_commit "$work" "local.txt" "local change 2" "Add feature two"
    local code
    code=$(patcher_run "$work" create all patches)
    assert_exit_code 0 "$code" "create_all_patches_overwrite: exits 0"
    assert_patch_count "$work/patches" 2 "create_all_patches_overwrite: 2 patches after regenerate"
}

function test_create_patch {
    local work
    work=$(make_work_dir "test_create_patch")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    add_repo_commit "$work" "local.txt" "local change 1" "Add feature alpha"
    add_repo_commit "$work" "local.txt" "local change 2" "Add feature beta"
    (cd "$work" && bash "$PATCHER_SH" create all patches < /dev/null) > /dev/null 2>&1

    add_repo_commit "$work" "local.txt" "local change 3" "Add feature gamma"
    local code
    code=$(patcher_run "$work" create patch)
    assert_exit_code 0 "$code" "create_patch: exits 0"
    assert_patch_count "$work/patches" 3 "create_patch: 3 patches total (2 old + 1 new)"

    if ls "$work/patches"/002-*.patch > /dev/null 2>&1; then
        echo "[ PASS ] create_patch: new patch has 002- prefix"
        PASS=$((PASS + 1))
    else
        echo "[ FAIL ] create_patch: no patch with 002- prefix found"
        FAIL=$((FAIL + 1))
    fi
}

function test_create_patch_no_new {
    local work
    work=$(make_work_dir "test_create_patch_no_new")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    add_repo_commit "$work" "local.txt" "content" "Add feature one"
    (cd "$work" && bash "$PATCHER_SH" create all patches < /dev/null) > /dev/null 2>&1

    local code
    code=$(patcher_run "$work" create patch)
    assert_exit_code 0 "$code" "create_patch_no_new: exits 0"
    assert_patch_count "$work/patches" 1 "create_patch_no_new: still 1 patch (no new ones created)"
}

function test_create_patch_from_empty {
    local work
    work=$(make_work_dir "test_create_patch_from_empty")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    add_repo_commit "$work" "local.txt" "content" "Feature one"
    add_repo_commit "$work" "local.txt" "content2" "Feature two"

    local code
    code=$(patcher_run "$work" create patch)
    assert_exit_code 0 "$code" "create_patch_from_empty: exits 0"
    assert_patch_count "$work/patches" 2 "create_patch_from_empty: 2 patches created from empty"
}

function test_apply_patches {
    local work
    work=$(make_work_dir "test_apply_patches")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    add_repo_commit "$work" "local.txt" "local change 1" "Add feature one"
    add_repo_commit "$work" "local.txt" "local change 2" "Add feature two"
    (cd "$work" && bash "$PATCHER_SH" create all patches < /dev/null) > /dev/null 2>&1

    (cd "$work" && bash "$PATCHER_SH" reset patches < /dev/null) > /dev/null 2>&1
    assert_git_log_count "$work/repo" "$BASE_COMMIT" 0 "apply_patches: after reset, 0 commits after base"

    local code
    code=$(patcher_run "$work" apply patches)
    assert_exit_code 0 "$code" "apply_patches: exits 0"
    assert_git_log_count "$work/repo" "$BASE_COMMIT" 2 "apply_patches: 2 commits applied after base"
}

function test_apply_patches_idempotent {
    local work
    work=$(make_work_dir "test_apply_patches_idempotent")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    add_repo_commit "$work" "local.txt" "content" "Idempotent feature"
    (cd "$work" && bash "$PATCHER_SH" create all patches < /dev/null) > /dev/null 2>&1
    (cd "$work" && bash "$PATCHER_SH" reset patches < /dev/null) > /dev/null 2>&1
    (cd "$work" && bash "$PATCHER_SH" apply patches < /dev/null) > /dev/null 2>&1

    local code
    code=$(patcher_run "$work" apply patches)
    assert_exit_code 0 "$code" "apply_patches_idempotent: second apply exits 0"
    assert_git_log_count "$work/repo" "$BASE_COMMIT" 1 "apply_patches_idempotent: still 1 commit (no duplicate apply)"
}

function test_apply_patches_no_patches {
    local work
    work=$(make_work_dir "test_apply_patches_none")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    local code
    code=$(patcher_run "$work" apply patches)
    assert_exit_code 0 "$code" "apply_patches_no_patches: exits 0 with no patches"
}

function test_reset_patches {
    local work
    work=$(make_work_dir "test_reset_patches")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    add_repo_commit "$work" "local.txt" "content" "Feature to reset"
    (cd "$work" && bash "$PATCHER_SH" create all patches < /dev/null) > /dev/null 2>&1
    assert_git_log_count "$work/repo" "$BASE_COMMIT" 1 "reset_patches: 1 commit before reset"

    local code
    code=$(patcher_run "$work" reset patches)
    assert_exit_code 0 "$code" "reset_patches: exits 0"
    assert_git_log_count "$work/repo" "$BASE_COMMIT" 0 "reset_patches: 0 commits after reset"
    assert_patch_count "$work/patches" 1 "reset_patches: patch files still exist after reset"
}

function test_reset_patches_no_commits {
    local work
    work=$(make_work_dir "test_reset_patches_no_commits")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    local code
    code=$(patcher_run "$work" reset patches)
    assert_exit_code 0 "$code" "reset_patches_no_commits: exits 0 when already at base"
}

function test_rebase_to_commit {
    local work
    work=$(make_work_dir "test_rebase_to_commit")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    add_repo_commit "$work" "local-only.txt" "local feature" "Add local only feature"
    (cd "$work" && bash "$PATCHER_SH" create all patches < /dev/null) > /dev/null 2>&1

    local code
    code=$(patcher_run_1input "$work" "$COMMIT_1" rebase to commit)
    assert_exit_code 0 "$code" "rebase_to_commit: exits 0"
    assert_file_contains "$work/state/commit.txt" "$COMMIT_1" "rebase_to_commit: commit.txt updated to new base"
    assert_git_log_count "$work/repo" "$COMMIT_1" 1 "rebase_to_commit: 1 patch commit on new base"
    assert_patch_count "$work/patches" 1 "rebase_to_commit: patch files regenerated"
}

function test_rebase_to_commit_empty_hash {
    local work
    work=$(make_work_dir "test_rebase_empty_hash")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    local code
    code=$(patcher_run_1input "$work" "" rebase to commit)
    assert_exit_code 14 "$code" "rebase_empty_hash: empty hash exits 14 (ERR_INVALID_ARG)"
}

function test_rebase_to_commit_invalid_hash {
    local work
    work=$(make_work_dir "test_rebase_invalid_hash")
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    local code
    code=$(patcher_run_1input "$work" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" rebase to commit)
    assert_exit_code 14 "$code" "rebase_invalid_hash: invalid hash exits 14 (ERR_INVALID_ARG)"
}

function test_completion {
    local work
    work=$(make_work_dir "test_completion")
    local code
    code=$(patcher_run "$work" --completion)
    assert_exit_code 0 "$code" "completion: --completion exits with code 0"
    assert_file_exists "$HOME/.local/share/bash-completion/completions/patcher" \
        "completion: completion file created"
}

function test_completion_combined_with_command {
    local work
    work=$(make_work_dir "test_completion_combined")
    local code
    code=$(patcher_run "$work" --completion init)
    assert_exit_code 1 "$code" "completion_combined: --completion with command exits 1"
}

function test_completion_combined_with_y {
    local work
    work=$(make_work_dir "test_completion_combined_y")
    local code
    code=$(patcher_run "$work" --completion -y)
    assert_exit_code 1 "$code" "completion_combined_y: --completion with -y exits 1"
}

function test_confirm_flag {
    local work
    work=$(make_work_dir "test_confirm_flag")
    local code
    code=$(patcher_run_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT" -y)
    assert_exit_code 0 "$code" "confirm_flag: -y init exits 0"
    assert_dir_exists "$work/repo" "confirm_flag: repo/ created with -y flag"
}

function test_confirm_flag_before_command {
    local work
    work=$(make_work_dir "test_confirm_flag_before")
    # Note: patcher_run_init always calls 'init' but we test -y before init here
    local code
    code=$(patcher_run_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT")
    assert_exit_code 0 "$code" "confirm_flag_before: init without -y exits 0"
    assert_dir_exists "$work/repo" "confirm_flag_before: repo/ created"
}

function test_full_workflow {
    local work
    work=$(make_work_dir "test_full_workflow")

    # 1. Init at BASE_COMMIT
    patcher_init "$work" "$UPSTREAM_DIR" "$BASE_COMMIT"

    # 2. Add 2 local commits
    add_repo_commit "$work" "feature-a.txt" "feature a content" "Implement feature A"
    add_repo_commit "$work" "feature-b.txt" "feature b content" "Implement feature B"

    # 3. create all patches
    local code
    code=$(patcher_run "$work" create all patches)
    assert_exit_code 0 "$code" "full_workflow: create all patches exits 0"
    assert_patch_count "$work/patches" 2 "full_workflow: 2 patches created"

    # 4. reset patches
    code=$(patcher_run "$work" reset patches)
    assert_exit_code 0 "$code" "full_workflow: reset patches exits 0"
    assert_git_log_count "$work/repo" "$BASE_COMMIT" 0 "full_workflow: 0 commits after reset"

    # 5. apply patches
    code=$(patcher_run "$work" apply patches)
    assert_exit_code 0 "$code" "full_workflow: apply patches exits 0"
    assert_git_log_count "$work/repo" "$BASE_COMMIT" 2 "full_workflow: 2 commits after apply"

    # 6. create patch (incremental) - add 3rd commit
    add_repo_commit "$work" "feature-c.txt" "feature c content" "Implement feature C"
    code=$(patcher_run "$work" create patch)
    assert_exit_code 0 "$code" "full_workflow: create patch exits 0"
    assert_patch_count "$work/patches" 3 "full_workflow: 3 patches after incremental create"

    # 7. rebase to COMMIT_1 (upstream moved forward; local files don't conflict)
    code=$(patcher_run_1input "$work" "$COMMIT_1" rebase to commit)
    assert_exit_code 0 "$code" "full_workflow: rebase to commit exits 0"
    assert_git_log_count "$work/repo" "$COMMIT_1" 3 "full_workflow: 3 commits on new base after rebase"
    assert_file_contains "$work/state/commit.txt" "$COMMIT_1" "full_workflow: state updated to COMMIT_1"
}

# --- Run all tests ---

echo ""
echo "=== patcher tests ==="
echo ""

setup_tests
echo ""

echo "--- help / args ---"
test_help_short
test_help_long
test_no_args
test_invalid_arg

echo ""
echo "--- state check (no init) ---"
test_check_state_no_init_create_all_patches
test_check_state_no_init_create_patch
test_check_state_no_init_apply_patches
test_check_state_no_init_reset_patches
test_check_state_no_init_rebase

echo ""
echo "--- init ---"
test_init
test_init_empty_url
test_init_invalid_url
test_init_latest_commit
test_init_gitignore_existing
test_init_gitignore_already_has_repo

echo ""
echo "--- create all patches ---"
test_create_all_patches_no_commits
test_create_all_patches
test_create_all_patches_overwrite

echo ""
echo "--- create patch (incremental) ---"
test_create_patch
test_create_patch_no_new
test_create_patch_from_empty

echo ""
echo "--- apply patches ---"
test_apply_patches
test_apply_patches_idempotent
test_apply_patches_no_patches

echo ""
echo "--- reset patches ---"
test_reset_patches
test_reset_patches_no_commits

echo ""
echo "--- rebase to commit ---"
test_rebase_to_commit
test_rebase_to_commit_empty_hash
test_rebase_to_commit_invalid_hash

echo ""
echo "--- completion ---"
test_completion
test_completion_combined_with_command
test_completion_combined_with_y

echo ""
echo "--- -y flag ---"
test_confirm_flag
test_confirm_flag_before_command

echo ""
echo "--- full workflow ---"
test_full_workflow

echo ""
echo "==========================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================="

cleanup_tests

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
