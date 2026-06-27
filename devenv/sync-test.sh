#!/usr/bin/env bash
set -eu

SCRIPT_SOURCE=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_SOURCE" ]; do
  SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )
  SCRIPT_SOURCE=$(readlink "$SCRIPT_SOURCE")
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE=$SCRIPT_DIR/$SCRIPT_SOURCE
done
SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )

SYNC_SCRIPT="$SCRIPT_DIR/sync.sh"

# TEST_DIR  — config files, exclude files, and non-rsync test state.
#             Lives inside the project directory (inside the git repo).
TEST_DIR="$SCRIPT_DIR/test-sync"

# RSYNC_DIR — directories that rsync actually reads/writes during sync tests.
#             Must be OUTSIDE the git repository for two reasons:
#             1. Git 2.x sets any .git directory created inside a repo to mode 000
#                (immutable security feature), preventing test setup for the
#                ".git always excluded" test case.
#             2. SELinux on Fedora/RHEL assigns initrc_tmp_t to files created by
#                this process context; the rsync binary (rsync_exec_t) transitions
#                to the restricted rsync_t domain and cannot access initrc_tmp_t.
#                The rsync wrapper below fixes this via runcon.
RSYNC_DIR="/tmp/sync-sh-test"

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------

PASS=0; FAIL=0; SKIP=0

function pass { PASS=$((PASS + 1)); printf "  PASS  %s\n" "$1"; }
function fail { FAIL=$((FAIL + 1)); printf "  FAIL  %s\n" "$1"; }
function skip { SKIP=$((SKIP + 1)); printf "  SKIP  %s\n" "$1"; }

# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

function assert_exit_code {
  if [ "$2" -eq "$3" ]; then pass "$1"; else fail "$1 (exit $2, expected $3)"; fi
}

function assert_contains {
  local _found=false
  case "$2" in *"$3"*) _found=true ;; esac
  if [ "$_found" = "true" ]; then pass "$1"; else
    fail "$1"
    printf "    expected to find: %s\n" "$3"
    printf "    in output:\n%s\n" "$2" | head -20
  fi
}

function assert_not_contains {
  local _found=false
  case "$2" in *"$3"*) _found=true ;; esac
  if [ "$_found" = "false" ]; then pass "$1"; else
    fail "$1 (unexpected string found: $3)"
  fi
}

function assert_file_exists { [ -f "$2" ] && pass "$1" || fail "$1 (missing: $2)"; }
function assert_file_absent { [ ! -f "$2" ] && pass "$1" || fail "$1 (exists: $2)"; }
function assert_dir_absent  { [ ! -d "$2" ] && pass "$1" || fail "$1 (exists: $2)"; }
function assert_file_content {
  local actual; actual=$(cat "$2")
  if [ "$actual" = "$3" ]; then pass "$1"; else
    fail "$1"
    printf "    expected: %s\n" "$3"
    printf "    actual:   %s\n" "$actual"
  fi
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

function setup {
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR"
  rm -rf "$RSYNC_DIR"
  mkdir -p "$RSYNC_DIR"

  # Install an rsync wrapper as the first entry in PATH.
  #
  # Problem: on SELinux-Enforcing systems, executing /usr/bin/rsync (rsync_exec_t)
  # from this process (initrc_t) causes a domain transition into rsync_t, which
  # cannot access files labelled initrc_tmp_t — the type automatically assigned to
  # all files and directories our process creates, including those in /tmp.
  #
  # Fix: when SELinux is enforcing, keep rsync in the calling process's SELinux
  # domain by wrapping it with runcon.  On systems without SELinux (getenforce
  # absent or not returning "Enforcing") the wrapper passes through directly to
  # the real rsync binary — no runcon overhead, no extra dependencies.
  cat > "$TEST_DIR/rsync" <<'WRAPPER'
#!/usr/bin/env bash
selinux_enforcing() {
  command -v getenforce &>/dev/null && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]
}
if selinux_enforcing; then
  ctx=$(cat /proc/self/attr/current 2>/dev/null | tr -d '\0')
  exec runcon "$ctx" /usr/bin/rsync "$@"
else
  exec /usr/bin/rsync "$@"
fi
WRAPPER
  chmod +x "$TEST_DIR/rsync"

  # Prepend TEST_DIR so both the test helpers and sync.sh pick up the wrapper.
  export PATH="$TEST_DIR:$PATH"
}

function teardown {
  rm -rf "$TEST_DIR"
  rm -rf "$RSYNC_DIR"
}

trap teardown EXIT

# ---------------------------------------------------------------------------
# Config factories
# ---------------------------------------------------------------------------

function write_valid_config {
  # $1: config path  $2: src dir  $3: dst dir
  cat > "$1" <<EOF
[pair-a]
src=$2
dst=$3
EOF
}

function write_config_with_owner {
  # $1: config path  $2: src dir  $3: dst dir  $4: owner value
  cat > "$1" <<EOF
[pair-a]
src=$2
dst=$3
owner=$4
EOF
}

function write_config_no_dst {
  cat > "$1" <<EOF
[pair-x]
src=/some/path
EOF
}

function write_config_no_src {
  cat > "$1" <<EOF
[pair-x]
dst=/some/path
EOF
}

function write_config_unknown_key {
  cat > "$1" <<EOF
[pair-x]
src=/some/path
dst=/some/dst
extra=value
EOF
}

function write_config_key_outside_section {
  cat > "$1" <<EOF
src=/some/path
[pair-x]
dst=/some/dst
EOF
}

function write_config_empty { > "$1"; }

# ---------------------------------------------------------------------------
# Test helpers for rsync tests
# ---------------------------------------------------------------------------

# Wipe and re-create the rsync src/dst directories used by pair-a.
function reset_dirs {
  rm -rf "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a"
  mkdir -p "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a"
}

# Run sync.sh with pair-a from the valid config, auto-confirming with 'yes'.
# Forwards any extra arguments to the script.
function run_sync {
  echo "yes" | "$SYNC_SCRIPT" \
    --config "$TEST_DIR/cfg-valid.ini" \
    -p pair-a "$@" 2>&1
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

setup

echo ""
echo "════════════════════════════════════════"
echo "  sync.sh test suite"
echo "════════════════════════════════════════"

# -----------------------------------------------------------------------
echo ""
echo "── Help text ──────────────────────────────────────────────────────"

output=$("$SYNC_SCRIPT" -h 2>&1) && rc=0 || rc=$?
assert_exit_code   "-h exits with code 0"          "$rc" 0
assert_contains    "-h shows usage line"            "$output" "Usage:"
assert_contains    "-h shows --pair"                "$output" "--pair"
assert_contains    "-h shows --reverse"             "$output" "--reverse"
assert_contains    "-h shows --dry-run"             "$output" "--dry-run"
assert_contains    "-h shows --init"                "$output" "--init"
assert_contains    "-h shows --config"              "$output" "--config"
assert_contains    "-h shows --exclude-config"      "$output" "--exclude-config"
assert_contains    "-h shows src= format"           "$output" "src="
assert_contains    "-h shows dst= format"           "$output" "dst="
assert_contains    "-h shows owner= field"          "$output" "owner="
assert_contains    "-h owner formats"               "$output" "user:group"
assert_contains    "-h config file location"        "$output" ".sync-dirs"
assert_contains    "-h exclude file location"       "$output" ".sync-exclude"
assert_contains    "-h manual editing guidance"     "$output" "text editor"
assert_contains    "-h --init generation tip"       "$output" "--init"
assert_contains    "-h rsync --exclude-from info"   "$output" "--exclude-from"
assert_contains    "-h --delete explanation"        "$output" "--delete"
assert_contains    "-h --chown explanation"         "$output" "--chown"
assert_not_contains "-h no --add-pair mention"      "$output" "--add-pair"

output=$("$SYNC_SCRIPT" --help 2>&1) && rc=0 || rc=$?
assert_exit_code   "--help exits with code 0"       "$rc" 0
assert_contains    "--help shows usage line"         "$output" "Usage:"

# -----------------------------------------------------------------------
echo ""
echo "── Config validation ──────────────────────────────────────────────"

CFG="$TEST_DIR/cfg-test.ini"

output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "missing config exits non-zero"    "$rc" 1
assert_contains    "missing config shows --init hint" "$output" "--init"

write_config_empty "$CFG"
output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "empty config exits non-zero"   "$rc" 1
assert_contains    "empty config shows error"      "$output" "error"

write_config_no_dst "$CFG"
output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "no-dst config exits non-zero"  "$rc" 1
assert_contains    "no-dst config shows error"     "$output" "error"
assert_contains    "no-dst mentions 'dst'"         "$output" "dst"

write_config_no_src "$CFG"
output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "no-src config exits non-zero"  "$rc" 1
assert_contains    "no-src mentions 'src'"         "$output" "src"

write_config_unknown_key "$CFG"
output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "unknown-key config exits non-zero" "$rc" 1
assert_contains    "unknown-key shows error"           "$output" "error"

write_config_key_outside_section "$CFG"
output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "key-outside-section exits non-zero" "$rc" 1
assert_contains    "key-outside-section shows error"    "$output" "error"

# -----------------------------------------------------------------------
echo ""
echo "── Owner field validation ─────────────────────────────────────────"

mkdir -p "$TEST_DIR/src-o" "$TEST_DIR/dst-o"

for good_owner in "alice:staff" "alice:" ":staff" "alice" "1000:1000" "bob"; do
  write_config_with_owner "$CFG" "$TEST_DIR/src-o" "$TEST_DIR/dst-o" "$good_owner"
  output=$("$SYNC_SCRIPT" --config "$CFG" -p pair-a 2>&1) && rc=0 || rc=$?
  assert_not_contains "owner='$good_owner' passes validation (no parse error)" \
    "$output" "invalid 'owner'"
done

cat > "$CFG" <<'EOF'
[pair-x]
src=/some/path
dst=/some/dst
owner=
EOF
output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "owner= empty exits non-zero"  "$rc" 1
assert_contains    "owner= empty shows error"     "$output" "invalid 'owner'"

cat > "$CFG" <<'EOF'
[pair-x]
src=/some/path
dst=/some/dst
owner=alice bob
EOF
output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "owner with space exits non-zero" "$rc" 1
assert_contains    "owner with space shows error"    "$output" "invalid 'owner'"

cat > "$CFG" <<'EOF'
[pair-x]
src=/some/path
dst=/some/dst
owner=alice:staff:extra
EOF
output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "owner with two colons exits non-zero" "$rc" 1
assert_contains    "owner with two colons shows error"    "$output" "invalid 'owner'"

cat > "$CFG" <<'EOF'
[pair-x]
src=/some/path
dst=/some/dst
owner=:
EOF
output=$("$SYNC_SCRIPT" --config "$CFG" 2>&1) && rc=0 || rc=$?
assert_exit_code   "owner=: exits non-zero" "$rc" 1
assert_contains    "owner=: shows error"    "$output" "invalid 'owner'"

# -----------------------------------------------------------------------
echo ""
echo "── Exclude file validation ─────────────────────────────────────────"

write_valid_config "$TEST_DIR/cfg-excl.ini" "$RSYNC_DIR/src-e" "$RSYNC_DIR/dst-e"
mkdir -p "$RSYNC_DIR/src-e" "$RSYNC_DIR/dst-e"

MISSING_EXCL="$TEST_DIR/does-not-exist-excl.txt"
output=$(echo "yes" | "$SYNC_SCRIPT" \
  --config "$TEST_DIR/cfg-excl.ini" \
  --exclude-config "$MISSING_EXCL" \
  -p pair-a 2>&1) && rc=0 || rc=$?
assert_exit_code  "missing explicit exclude file exits non-zero" "$rc" 1
assert_contains   "missing exclude file shows error"             "$output" "error"
assert_contains   "missing exclude file mentions path"           "$output" "$MISSING_EXCL"

UNREADABLE_EXCL="$TEST_DIR/unreadable-excl.txt"
echo "node_modules/" > "$UNREADABLE_EXCL"
chmod 000 "$UNREADABLE_EXCL"
output=$(echo "yes" | "$SYNC_SCRIPT" \
  --config "$TEST_DIR/cfg-excl.ini" \
  --exclude-config "$UNREADABLE_EXCL" \
  -p pair-a 2>&1) && rc=0 || rc=$?
assert_exit_code  "unreadable exclude file exits non-zero" "$rc" 1
assert_contains   "unreadable exclude file shows error"    "$output" "error"
chmod 644 "$UNREADABLE_EXCL"

# -----------------------------------------------------------------------
echo ""
echo "── Pair selection ─────────────────────────────────────────────────"

mkdir -p "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a"
write_valid_config "$CFG" "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a"

output=$("$SYNC_SCRIPT" --config "$CFG" -p nonexistent 2>&1) && rc=0 || rc=$?
assert_exit_code  "bad pair name exits non-zero" "$rc" 1
assert_contains   "bad pair shows error"         "$output" "error"

write_valid_config "$TEST_DIR/cfg-nosrc.ini" "$TEST_DIR/no-src-here" "$RSYNC_DIR/dst-a"
output=$("$SYNC_SCRIPT" --config "$TEST_DIR/cfg-nosrc.ini" -p pair-a 2>&1) && rc=0 || rc=$?
assert_exit_code  "missing src exits non-zero" "$rc" 1
assert_contains   "missing src shows error"    "$output" "error"

# -----------------------------------------------------------------------
echo ""
echo "── Unknown / missing CLI options ──────────────────────────────────"

output=$("$SYNC_SCRIPT" --unknown-flag 2>&1) && rc=0 || rc=$?
assert_exit_code  "unknown flag exits non-zero"           "$rc" 1
assert_contains   "unknown flag shows error"              "$output" "Unknown"

output=$("$SYNC_SCRIPT" --add-pair 2>&1) && rc=0 || rc=$?
assert_exit_code  "--add-pair is unknown (removed)"       "$rc" 1

output=$("$SYNC_SCRIPT" --pair 2>&1) && rc=0 || rc=$?
assert_exit_code  "missing --pair value exits non-zero"   "$rc" 1

output=$("$SYNC_SCRIPT" --config 2>&1) && rc=0 || rc=$?
assert_exit_code  "missing --config value exits non-zero" "$rc" 1


# -----------------------------------------------------------------------
echo ""
echo "── --init ─────────────────────────────────────────────────────────"

INIT_CFG="$TEST_DIR/init-test.sync-dirs"
INIT_EXC="$TEST_DIR/init-test.sync-exclude"

output=$("$SYNC_SCRIPT" --init --config "$INIT_CFG" --exclude-config "$INIT_EXC" 2>&1) && rc=0 || rc=$?
assert_exit_code   "--init exits 0"                "$rc" 0
assert_file_exists "--init creates config file"    "$INIT_CFG"
assert_file_exists "--init creates exclude file"   "$INIT_EXC"

cfg_content=$(cat "$INIT_CFG")
assert_contains    "--init config has [example-pair]"  "$cfg_content" "[example-pair]"
assert_contains    "--init config has src="            "$cfg_content" "src="
assert_contains    "--init config has dst="            "$cfg_content" "dst="
assert_contains    "--init config has owner= comment"  "$cfg_content" "owner="
assert_contains    "--init config has help tip"        "$cfg_content" "--help"
assert_contains    "--init config has edit guidance"   "$cfg_content" "text editor"
assert_not_contains "--init config no --add-pair"      "$cfg_content" "--add-pair"

exc_content=$(cat "$INIT_EXC")
assert_contains    "--init exclude has node_modules/"  "$exc_content" "node_modules/"
assert_contains    "--init exclude has __pycache__/"   "$exc_content" "__pycache__/"
assert_contains    "--init exclude has .DS_Store"      "$exc_content" ".DS_Store"
assert_contains    "--init exclude has help tip"       "$exc_content" "--help"
assert_contains    "--init exclude has edit guidance"  "$exc_content" "text editor"

output=$(printf 'n\nn\n' | "$SYNC_SCRIPT" --init --config "$INIT_CFG" --exclude-config "$INIT_EXC" 2>&1) && rc=0 || rc=$?
assert_exit_code   "--init no-overwrite exits 0"         "$rc" 0
assert_contains    "--init no-overwrite shows Skipping"  "$output" "Skipping"

output=$(printf 'y\ny\n' | "$SYNC_SCRIPT" --init --config "$INIT_CFG" --exclude-config "$INIT_EXC" 2>&1) && rc=0 || rc=$?
assert_exit_code    "--init overwrite exits 0"           "$rc" 0
assert_contains     "--init overwrite shows Created"     "$output" "Created"
assert_file_exists  "--init overwrite config exists"     "$INIT_CFG"
assert_file_exists  "--init overwrite exclude exists"    "$INIT_EXC"

# -----------------------------------------------------------------------
echo ""
echo "── Confirmation prompt ─────────────────────────────────────────────"

if ! command -v rsync &>/dev/null; then
  skip "rsync not installed — skipping confirmation tests"
else
  mkdir -p "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a"
  write_valid_config "$TEST_DIR/cfg-valid.ini" "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a"

  output=$(echo "no" | "$SYNC_SCRIPT" --config "$TEST_DIR/cfg-valid.ini" -p pair-a 2>&1) && rc=0 || rc=$?
  assert_exit_code  "conf 'no' cancels (exit 1)"     "$rc" 1
  assert_contains   "conf 'no' shows cancelled msg"  "$output" "cancelled"

  output=$(echo "YES" | "$SYNC_SCRIPT" --config "$TEST_DIR/cfg-valid.ini" -p pair-a 2>&1) && rc=0 || rc=$?
  assert_exit_code  "conf 'YES' (uppercase) cancels" "$rc" 1

  output=$(echo "" | "$SYNC_SCRIPT" --config "$TEST_DIR/cfg-valid.ini" -p pair-a 2>&1) && rc=0 || rc=$?
  assert_exit_code  "conf empty cancels"             "$rc" 1

  output=$(echo "no" | "$SYNC_SCRIPT" --config "$TEST_DIR/cfg-valid.ini" -p pair-a 2>&1) && rc=0 || rc=$?
  assert_contains   "summary shows Source"       "$output" "Source"
  assert_contains   "summary shows Destination"  "$output" "Destination"
  assert_contains   "summary shows Pair"         "$output" "Pair"
  assert_contains   "summary shows Config file"  "$output" "Config file"
  assert_contains   "summary shows Exclude file" "$output" "Exclude file"
  assert_contains   "summary shows Ownership"    "$output" "Ownership"
  assert_contains   "summary: no owner → preserved from source" \
    "$output" "preserved from source"

  OWNER_CFG="$TEST_DIR/cfg-with-owner.ini"
  write_config_with_owner "$OWNER_CFG" "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a" "alice:staff"
  output=$(echo "no" | "$SYNC_SCRIPT" --config "$OWNER_CFG" -p pair-a 2>&1) && rc=0 || rc=$?
  assert_contains   "summary shows owner value"   "$output" "alice:staff"
  assert_contains   "summary shows --chown note"  "$output" "--chown"
fi

# -----------------------------------------------------------------------
echo ""
echo "── Sync (rsync tests) ──────────────────────────────────────────────"

if ! command -v rsync &>/dev/null; then
  skip "rsync not installed — skipping all rsync sync tests"
else
  # cfg-valid.ini points pair-a at RSYNC_DIR; written once here, reset_dirs
  # re-creates just the actual src/dst directories between tests.
  reset_dirs
  write_valid_config "$TEST_DIR/cfg-valid.ini" "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a"

  # ── dry-run
  echo "test-content" > "$RSYNC_DIR/src-a/file.txt"
  output=$(run_sync --dry-run) && rc=0 || rc=$?
  assert_exit_code   "dry-run exits 0"                   "$rc" 0
  assert_contains    "dry-run shows DRY RUN in summary"  "$output" "DRY RUN"
  assert_file_absent "dry-run does not copy file"        "$RSYNC_DIR/dst-a/file.txt"

  # ── basic sync
  reset_dirs
  echo "hello" > "$RSYNC_DIR/src-a/hello.txt"
  output=$(run_sync) && rc=0 || rc=$?
  assert_exit_code    "basic sync exits 0"          "$rc" 0
  assert_file_exists  "basic sync copies file"      "$RSYNC_DIR/dst-a/hello.txt"
  assert_file_content "basic sync correct content"  "$RSYNC_DIR/dst-a/hello.txt" "hello"

  # ── --delete: removes extra file from destination
  reset_dirs
  echo "src-file" > "$RSYNC_DIR/src-a/keep.txt"
  echo "dst-only" > "$RSYNC_DIR/dst-a/extra.txt"
  output=$(run_sync) && rc=0 || rc=$?
  assert_exit_code   "--delete exits 0"                 "$rc" 0
  assert_file_exists "--delete keeps src file in dst"   "$RSYNC_DIR/dst-a/keep.txt"
  assert_file_absent "--delete removes extra dst file"  "$RSYNC_DIR/dst-a/extra.txt"

  # ── --reverse
  reset_dirs
  echo "from-dst" > "$RSYNC_DIR/dst-a/reverse.txt"
  output=$(run_sync --reverse) && rc=0 || rc=$?
  assert_exit_code   "--reverse exits 0"              "$rc" 0
  assert_file_exists "--reverse copies dst -> src"    "$RSYNC_DIR/src-a/reverse.txt"
  assert_contains    "--reverse shows REVERSED"       "$output" "REVERSED"

  # ── .gitignore exclusion
  reset_dirs
  echo "ignored" > "$RSYNC_DIR/src-a/ignored.log"
  echo "*.log"   > "$RSYNC_DIR/src-a/.gitignore"
  echo "kept"    > "$RSYNC_DIR/src-a/kept.txt"
  output=$(run_sync) && rc=0 || rc=$?
  assert_exit_code   ".gitignore: exits 0"                          "$rc" 0
  assert_file_exists ".gitignore: .gitignore itself copied"         "$RSYNC_DIR/dst-a/.gitignore"
  assert_file_exists ".gitignore: kept.txt copied"                  "$RSYNC_DIR/dst-a/kept.txt"
  assert_file_absent ".gitignore: ignored.log excluded"             "$RSYNC_DIR/dst-a/ignored.log"

  # ── .git always excluded  (RSYNC_DIR is outside the git repo so .git gets normal perms)
  reset_dirs
  mkdir -p "$RSYNC_DIR/src-a/.git"
  echo "git-object" > "$RSYNC_DIR/src-a/.git/HEAD"
  echo "normal"     > "$RSYNC_DIR/src-a/normal.txt"
  output=$(run_sync) && rc=0 || rc=$?
  assert_exit_code   ".git excluded: exits 0"            "$rc" 0
  assert_file_exists ".git excluded: normal.txt copied"  "$RSYNC_DIR/dst-a/normal.txt"
  assert_dir_absent  ".git excluded: .git not synced"    "$RSYNC_DIR/dst-a/.git"

  # ── --exclude-config patterns
  reset_dirs
  EXCL_FILE="$TEST_DIR/test.exclude"
  printf 'build/\n*.tmp\n' > "$EXCL_FILE"
  mkdir -p "$RSYNC_DIR/src-a/build"
  echo "artefact" > "$RSYNC_DIR/src-a/build/out.o"
  echo "tmp-data" > "$RSYNC_DIR/src-a/data.tmp"
  echo "kept"     > "$RSYNC_DIR/src-a/main.c"
  output=$(echo "yes" | "$SYNC_SCRIPT" \
    --config "$TEST_DIR/cfg-valid.ini" \
    --exclude-config "$EXCL_FILE" \
    -p pair-a 2>&1) && rc=0 || rc=$?
  assert_exit_code   "--exclude-config: exits 0"            "$rc" 0
  assert_file_exists "--exclude-config: main.c copied"      "$RSYNC_DIR/dst-a/main.c"
  assert_file_absent "--exclude-config: data.tmp excluded"  "$RSYNC_DIR/dst-a/data.tmp"
  assert_dir_absent  "--exclude-config: build/ excluded"    "$RSYNC_DIR/dst-a/build"

  # ── summary shows config and exclude file paths
  reset_dirs
  EXCL_FILE_SUMMARY="$TEST_DIR/summary.exclude"
  printf '*.bak\n' > "$EXCL_FILE_SUMMARY"
  output=$(echo "no" | "$SYNC_SCRIPT" \
    --config "$TEST_DIR/cfg-valid.ini" \
    --exclude-config "$EXCL_FILE_SUMMARY" \
    -p pair-a 2>&1) && rc=0 || rc=$?
  assert_contains "summary shows config file path"  "$output" "$TEST_DIR/cfg-valid.ini"
  assert_contains "summary shows exclude file path" "$output" "$EXCL_FILE_SUMMARY"

  # ── summary shows (none) when no exclude file exists
  reset_dirs
  output=$(echo "no" | "$SYNC_SCRIPT" \
    --config "$TEST_DIR/cfg-valid.ini" \
    -p pair-a 2>&1) && rc=0 || rc=$?
  assert_contains "summary shows (none) when default exclude absent" "$output" "(none"

  # ── owner= in config: summary shows value and --chown note (dry-run)
  reset_dirs
  OWNER_SYNC_CFG="$TEST_DIR/cfg-owner-sync.ini"
  CURRENT_USER=$(id -un)
  CURRENT_GROUP=$(id -gn)
  write_config_with_owner "$OWNER_SYNC_CFG" \
    "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a" \
    "${CURRENT_USER}:${CURRENT_GROUP}"
  echo "owned-file" > "$RSYNC_DIR/src-a/owned.txt"
  output=$(echo "yes" | "$SYNC_SCRIPT" \
    --config "$OWNER_SYNC_CFG" -p pair-a --dry-run 2>&1) && rc=0 || rc=$?
  assert_exit_code  "owner= dry-run exits 0"                 "$rc" 0
  assert_contains   "owner= dry-run shows owner in summary"  "$output" "${CURRENT_USER}:${CURRENT_GROUP}"
  assert_contains   "owner= dry-run shows --chown note"      "$output" "--chown"

  # ── tilde expansion in src/dst
  reset_dirs
  HOME_BACKUP_CFG="$TEST_DIR/tilde-cfg.ini"
  write_valid_config "$HOME_BACKUP_CFG" "$RSYNC_DIR/src-a" "$RSYNC_DIR/dst-a"
  echo "tilde-test" > "$RSYNC_DIR/src-a/tilde.txt"
  output=$(echo "yes" | "$SYNC_SCRIPT" --config "$HOME_BACKUP_CFG" -p pair-a 2>&1) && rc=0 || rc=$?
  assert_exit_code   "tilde cfg: exits 0"      "$rc" 0
  assert_file_exists "tilde cfg: file synced"  "$RSYNC_DIR/dst-a/tilde.txt"
fi

# -----------------------------------------------------------------------
echo ""
echo "════════════════════════════════════════"
TOTAL=$((PASS + FAIL + SKIP))
printf "  Results: %d total  |  %d passed  |  %d failed  |  %d skipped\n" \
  "$TOTAL" "$PASS" "$FAIL" "$SKIP"
echo "════════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ]
