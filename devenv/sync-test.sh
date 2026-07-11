#!/usr/bin/env bash
#
# Test suite for sync.sh.
#
# Creates all fixtures in a temporary sandbox (with an isolated $HOME so the
# real ~/.sync-dirs is never touched), runs every scenario, and deletes
# everything when done — pass or fail.

set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/sync.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
CONFIG="$HOME/.sync-dirs"
SRC="$SANDBOX/src"
DEST="$SANDBOX/dest"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

check()      { if eval "$2"; then pass "$1"; else fail "$1"; fi; }
check_file() { if [[ -e "$2" ]]; then pass "$1 exists"; else fail "$1 exists"; fi; }
check_gone() { if [[ ! -e "$2" ]]; then pass "$1 absent"; else fail "$1 absent"; fi; }
# Assert on $out without eval (safe for quotes/apostrophes in output).
check_out()  { if grep -qE -e "$2" <<< "$out"; then pass "$1"; else fail "$1"; fi; }

# Run the script interactively by piping answers; capture combined output.
run_sync() { printf '%s\n' "$@" | "$SCRIPT" 2>&1; }

# ---------------------------------------------------------------------------
# Fixture setup: a source tree exercising every exclusion scenario.
# ---------------------------------------------------------------------------
setup_fixtures() {
    rm -rf "$HOME" "$SRC" "$DEST"
    mkdir -p "$HOME"

    mkdir -p "$SRC"/{.git,node_modules,build,docs,app/vendor,app/deep}

    # Plain files that must always sync.
    echo root      > "$SRC/main.txt"
    echo docs      > "$SRC/docs/readme.md"
    echo app       > "$SRC/app/code.js"
    echo deep      > "$SRC/app/deep/deep.txt"

    # Global excludes: .git, node_modules, *.swp, *~ must never sync.
    echo head      > "$SRC/.git/HEAD"
    echo dep       > "$SRC/node_modules/dep.js"
    echo swap      > "$SRC/main.txt.swp"
    echo backup    > "$SRC/backup~"

    # Root .gitignore: excludes *.log everywhere and build/ at any level.
    printf '*.log\nbuild/\n' > "$SRC/.gitignore"
    echo log       > "$SRC/root.log"
    echo log       > "$SRC/docs/docs.log"
    echo built     > "$SRC/build/out.bin"

    # --- Exclusion pattern robustness fixtures (see matching test section) ---
    # Leading slash: anchored to the .gitignore's dir only, not deeper.
    printf '/anchored.txt\n' >> "$SRC/.gitignore"
    echo a > "$SRC/anchored.txt"        # excluded (at root)
    echo a > "$SRC/docs/anchored.txt"   # syncs (leading / doesn't reach here)
    # Middle slash: git would anchor 'tools/gen.txt' to the root, but
    # rsync's dir-merge anchors only on a LEADING slash, so it floats and
    # matches deeper paths too. Known deviation, documented in sync.sh.
    printf 'tools/gen.txt\n' >> "$SRC/.gitignore"
    mkdir -p "$SRC/tools" "$SRC/docs/tools"
    echo g > "$SRC/tools/gen.txt"        # excluded (matches at root)
    echo g > "$SRC/docs/tools/gen.txt"   # ALSO excluded (rsync deviation)
    # Wildcard prefix pattern, unanchored: applies at every depth.
    printf 'temp-*\n' >> "$SRC/.gitignore"
    echo t > "$SRC/temp-1.txt"
    echo t > "$SRC/docs/temp-2.txt"
    # Trailing slash means directory-only: a plain FILE named 'build' syncs.
    echo notadir > "$SRC/docs/build"
    # Comments and blank lines in .gitignore are inert, not patterns.
    printf '\n# notacomment.txt\n' >> "$SRC/.gitignore"
    echo n > "$SRC/notacomment.txt"     # must sync despite the comment line
    # Global excludes (layer 1) beat gitignore negations (layer 2).
    printf '!important.swp\n!node_modules\n' >> "$SRC/.gitignore"
    echo swap > "$SRC/docs/important.swp"
    # Global excludes apply in nested dirs too, not just at the root.
    echo swap > "$SRC/app/deep/editor.swp"
    mkdir -p "$SRC/docs/node_modules"
    echo dep > "$SRC/docs/node_modules/dep.js"

    # Nested .gitignore in app/: excludes vendor/ and *.cache — these
    # patterns must apply ONLY inside app/, not elsewhere.
    printf 'vendor/\n*.cache\n' > "$SRC/app/.gitignore"
    echo vendored  > "$SRC/app/vendor/lib.js"
    echo cache     > "$SRC/app/x.cache"
    # Same names OUTSIDE app/ — must still sync (nested patterns are scoped).
    mkdir -p "$SRC/docs/vendor"
    echo notvendor > "$SRC/docs/vendor/kept.js"
    echo notcache  > "$SRC/docs/y.cache"

    # Parent/child .gitignore chain: app/.gitignore AND app/deep/.gitignore
    # must both apply, each to its own scope.
    # Child adds its own pattern (secret.txt) that must not leak upward.
    printf 'secret.txt\n' > "$SRC/app/deep/.gitignore"
    echo secret    > "$SRC/app/deep/secret.txt"
    echo public    > "$SRC/secret.txt"   # outside app/deep/ — must sync
    # Parent pattern (*.cache from app/.gitignore) must also apply INSIDE
    # the child dir, alongside the child's own rules.
    echo cache     > "$SRC/app/deep/z.cache"
    # Child negation must override the parent's exclude (git: deeper
    # .gitignore wins), but only within the child's scope.
    printf '!keep.cache\n' >> "$SRC/app/deep/.gitignore"
    echo keep      > "$SRC/app/deep/keep.cache"
    echo notkept   > "$SRC/app/keep.cache"   # parent scope: stays excluded

    # Negation: rsync's ':- .gitignore' filter can't handle '!' lines, so
    # sync.sh translates them into explicit include rules scoped to the
    # .gitignore's directory: important.tmp must sync despite '*.tmp'.
    printf '*.tmp\n!important.tmp\n' > "$SRC/docs/.gitignore"
    echo tmp       > "$SRC/docs/junk.tmp"
    echo important > "$SRC/docs/important.tmp"
    # Scoping: the negation lives in docs/, so a same-named file excluded
    # by app/'s own rules must NOT be rescued by it.
    printf 'important.tmp\n' >> "$SRC/app/.gitignore"
    echo appimportant > "$SRC/app/important.tmp"
    # Anchored negation (contains a slash): re-include one file inside an
    # otherwise-ignored subdirectory pattern.
    printf 'assets/*\n!assets/logo.png\n' >> "$SRC/docs/.gitignore"
    mkdir -p "$SRC/docs/assets"
    echo logo  > "$SRC/docs/assets/logo.png"
    echo other > "$SRC/docs/assets/other.png"
}

echo "Testing $SCRIPT in sandbox $SANDBOX"
setup_fixtures

# ---------------------------------------------------------------------------
echo "== Help and argument handling =="
# ---------------------------------------------------------------------------
out="$("$SCRIPT" --help 2>&1)"; rc=$?
check "--help exits 0"              "(( rc == 0 ))"
check_out "--help shows usage"      'Usage:'

"$SCRIPT" --bogus >/dev/null 2>&1
check "unknown option exits non-zero" "(( $? != 0 ))"

"$SCRIPT" --init only-one-arg >/dev/null 2>&1
check "--init with 1 arg exits non-zero" "(( $? != 0 ))"

"$SCRIPT" --init "$SANDBOX/no-such-dir" "$DEST" >/dev/null 2>&1
check "--init with missing source exits non-zero" "(( $? != 0 ))"
check_gone "config after failed --init" "$CONFIG"

"$SCRIPT" >/dev/null 2>&1
check "normal run with no config exits non-zero" "(( $? != 0 ))"

# ---------------------------------------------------------------------------
echo "== --init =="
# ---------------------------------------------------------------------------
"$SCRIPT" --init "$SRC" "$DEST" >/dev/null 2>&1
check "--init exits 0"              "(( $? == 0 ))"
check_file "config file"            "$CONFIG"
check "config has hand-edit header" "grep -q 'safe to edit by hand' '$CONFIG'"
check "config entry appended"       "grep -qF '$SRC|$DEST|' '$CONFIG'"
check "entry stores both ownerships" \
    "grep -qE '\|[0-9]+:[0-9]+\|[0-9]+:[0-9]+$' '$CONFIG'"
check_gone "--init does not sync"   "$DEST"

lines_before=$(wc -l < "$CONFIG")
mkdir -p "$SANDBOX/src2"
"$SCRIPT" --init "$SANDBOX/src2" "$SANDBOX/dest2" >/dev/null 2>&1
check "second --init only appends one line" \
    "(( $(wc -l < "$CONFIG") == lines_before + 1 ))"

# ---------------------------------------------------------------------------
echo "== Listing and selection =="
# ---------------------------------------------------------------------------
out="$(run_sync '')"
check_out "lists normal entry as option 1"   '^ 1\) .*src \['
check_out "lists reversed entry as option 2" '^   2\) .*dest \['
check_out "reversed option is indented 2 extra spaces" '^   2\)'
check_out "reversed entry swaps direction"   "2\) $SANDBOX/dest .*-> $SANDBOX/src "

# Two config entries must yield exactly 4 options: 4 accepted, 5 rejected.
# (Prompt text itself isn't asserted: read -p prints no prompt on piped stdin.)
out="$(run_sync 4 n)"
check "option 4 (reversed 2nd entry) is accepted" \
    "! grep -q 'Invalid selection' <<< \"\$out\""
out="$(run_sync 5)"
check_out "option 5 rejected (2 entries = 4 options)" 'Invalid selection'

run_sync '99' >/dev/null 2>&1
check "out-of-range selection exits non-zero" "(( $? != 0 ))"
run_sync 'abc' >/dev/null 2>&1
check "non-numeric selection exits non-zero"  "(( $? != 0 ))"

# Comment/blank lines in config must not become entries: still only 4 options.
printf '\n# a manual comment\n' >> "$CONFIG"
out="$(run_sync 5)"
check_out "comments in config don't add options" 'Invalid selection'
out="$(run_sync '')"
check "comments not listed as entries" "! grep -qF 'a manual comment' <<< \"\$out\""

# ---------------------------------------------------------------------------
echo "== Confirmation flow =="
# ---------------------------------------------------------------------------
out="$(run_sync 1 n)"
check_out "shows full command before confirm" 'rsync +-avh +--delete +--chown='
check_out "command applies dest ownership"    '--chown=[0-9]+:[0-9]+'
check_out "command has global excludes"       '--exclude=.git'
check_out "command has gitignore filter"      'filter=:-'
check_out "declining confirm aborts"          'Aborted'
check_gone "no sync after abort"              "$DEST/main.txt"

out="$(run_sync 1 y y n)"
check_out "dry-run runs"                'Dry-run complete'
check_gone "dry-run copies nothing"     "$DEST/main.txt"
check "command re-shown after dry-run (for the real-sync confirm)" \
    "(( $(grep -c 'Command to run:' <<< \"$out\") == 2 ))"
check_out "declining after dry-run aborts" 'Aborted'

out="$(run_sync 1 y y y)"
check_out "confirming after dry-run syncs" 'Sync complete'
check_file "synced file after dry-run+confirm" "$DEST/main.txt"

# ---------------------------------------------------------------------------
echo "== Sync content: includes, global excludes, gitignore scoping =="
# ---------------------------------------------------------------------------
rm -rf "$DEST"
out="$(run_sync 1 y n)"
check "direct sync (no dry-run) completes" "grep -q 'Sync complete' <<< '$out'"
check "dest directory created"             "[[ -d '$DEST' ]]"

check_file "root file"                "$DEST/main.txt"
check_file "docs file"                "$DEST/docs/readme.md"
check_file "app file"                 "$DEST/app/code.js"
check_file "deep file"                "$DEST/app/deep/deep.txt"
check_file ".gitignore itself synced" "$DEST/.gitignore"

check_gone "global exclude .git"         "$DEST/.git"
check_gone "global exclude node_modules" "$DEST/node_modules"
check_gone "global exclude *.swp"        "$DEST/main.txt.swp"
check_gone "global exclude *~"           "$DEST/backup~"

check_gone "root .gitignore *.log (root)"   "$DEST/root.log"
check_gone "root .gitignore *.log (nested)" "$DEST/docs/docs.log"
check_gone "root .gitignore build/"         "$DEST/build"

check_gone "nested app/.gitignore vendor/"  "$DEST/app/vendor"
check_gone "nested app/.gitignore *.cache"  "$DEST/app/x.cache"
check_file "vendor/ outside app/ still syncs" "$DEST/docs/vendor/kept.js"
check_file "*.cache outside app/ still syncs" "$DEST/docs/y.cache"

check_gone "child app/deep/.gitignore secret.txt"     "$DEST/app/deep/secret.txt"
check_file "secret.txt outside app/deep/ still syncs" "$DEST/secret.txt"
check_gone "parent app/.gitignore *.cache applies inside child dir" \
    "$DEST/app/deep/z.cache"
check_file "child negation !keep.cache overrides parent *.cache" \
    "$DEST/app/deep/keep.cache"
check_gone "child negation scoped: app/keep.cache stays excluded" \
    "$DEST/app/keep.cache"

# ---------------------------------------------------------------------------
echo "== Exclusion pattern robustness =="
# ---------------------------------------------------------------------------
check_gone "leading-slash /anchored.txt at anchor"      "$DEST/anchored.txt"
check_file "leading-slash pattern doesn't reach deeper" "$DEST/docs/anchored.txt"

check_gone "middle-slash tools/gen.txt at anchor"       "$DEST/tools/gen.txt"
# Known deviation from git: rsync floats middle-slash patterns to any
# depth (git would anchor them). If this check ever flips, rsync/sync.sh
# semantics changed — update the docs in sync.sh accordingly.
check_gone "middle-slash pattern floats deeper (rsync deviation)" \
    "$DEST/docs/tools/gen.txt"

check_gone "wildcard temp-* at root"        "$DEST/temp-1.txt"
check_gone "wildcard temp-* at any depth"   "$DEST/docs/temp-2.txt"

check_gone "trailing-slash build/ excludes the directory" "$DEST/build"
check_file "trailing-slash build/ spares a FILE named build" "$DEST/docs/build"

check_file "comment lines in .gitignore are inert" "$DEST/notacomment.txt"

check_gone "global exclude beats negation (!important.swp)" \
    "$DEST/docs/important.swp"
check_gone "global exclude beats negation (!node_modules)" \
    "$DEST/docs/node_modules"
check_gone "global exclude *.swp applies in nested dirs" \
    "$DEST/app/deep/editor.swp"

check_file "nested .gitignore files themselves sync" "$DEST/app/.gitignore"

check_gone "docs/.gitignore *.tmp"          "$DEST/docs/junk.tmp"
check_file "negated !important.tmp syncs"   "$DEST/docs/important.tmp"
check_gone "negation scoped to docs/ (app/important.tmp still excluded)" \
    "$DEST/app/important.tmp"
check_file "anchored negation !assets/logo.png syncs" "$DEST/docs/assets/logo.png"
check_gone "non-negated sibling assets/other.png"     "$DEST/docs/assets/other.png"

# ---------------------------------------------------------------------------
echo "== --delete mirrors removals =="
# ---------------------------------------------------------------------------
echo stray > "$DEST/stray.txt"
rm "$SRC/docs/readme.md"
run_sync 1 y n >/dev/null 2>&1
check_gone "file absent from source removed" "$DEST/docs/readme.md"
check_gone "stray dest file removed"         "$DEST/stray.txt"
echo docs > "$SRC/docs/readme.md"   # restore for later tests

# ---------------------------------------------------------------------------
echo "== Reverse sync (option 2) =="
# ---------------------------------------------------------------------------
run_sync 1 y n >/dev/null 2>&1                # make dest current again
echo edited > "$DEST/main.txt"
echo newfile > "$DEST/docs/added.md"
out="$(run_sync 2 y n)"
check "reverse sync completes"          "grep -q 'Sync complete' <<< '$out'"
check "reverse command swaps direction" "grep -qE 'dest/ +$SANDBOX/src/' <<< '$out'"
check "dest edit synced back to source" "[[ \$(cat '$SRC/main.txt') == edited ]]"
check_file "new dest file synced back"  "$SRC/docs/added.md"

# Reversed entry whose sync source (the dest dir) doesn't exist must error.
out="$(run_sync 4 2>&1)"; rc=$?
check "reverse with missing dir exits non-zero" "(( rc != 0 ))"
check "reverse with missing dir explains error" "grep -q 'does not exist' <<< '$out'"

# ---------------------------------------------------------------------------
echo
echo "Results: $PASS passed, $FAIL failed"
rm -rf "$SANDBOX"   # trap also covers this; explicit per requirements
trap - EXIT
(( FAIL == 0 ))
