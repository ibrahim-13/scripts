#!/usr/bin/env bash

# codesearch-test.sh — Test suite for codesearch.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/search.sh"
TEST_DIR="$SCRIPT_DIR/test"
PASS=0
FAIL=0

# ANSI color codes for test output
_CGRN=$'\033[32m'   # Green
_CRED=$'\033[31m'   # Red
_CYEL=$'\033[33m'   # Yellow
_CBLU=$'\033[34m'   # Blue
_CBLD=$'\033[1m'    # Bold
_CRST=$'\033[0m'    # Reset

#---------------------------------------------------------------------------
# Test framework
#---------------------------------------------------------------------------

function print_pass { printf "  ${_CGRN}[PASS]${_CRST} %s\n" "$1"; PASS=$((PASS+1)); }
function print_fail { printf "  ${_CRED}[FAIL]${_CRST} %s\n" "$1"; printf "         %s\n" "$2"; FAIL=$((FAIL+1)); }

function assert_exit_code {
    local expected="$1" actual="$2" desc="$3"
    if [[ "$actual" == "$expected" ]]; then
        print_pass "$desc (exit=$actual)"
    else
        print_fail "$desc" "expected exit=$expected, got exit=$actual"
    fi
}

function assert_contains {
    local needle="$1" haystack="$2" desc="$3"
    if echo "$haystack" | grep -qF -- "$needle"; then
        print_pass "$desc"
    else
        print_fail "$desc" "expected to find '$needle' in output"
        echo "         --- output ---"
        echo "$haystack" | sed 's/^/         /'
        echo "         --- end ---"
    fi
}

function assert_not_contains {
    local needle="$1" haystack="$2" desc="$3"
    if ! echo "$haystack" | grep -qF -- "$needle"; then
        print_pass "$desc"
    else
        print_fail "$desc" "expected NOT to find '$needle' in output"
    fi
}

function assert_empty {
    local value="$1" desc="$2"
    if [[ -z "$value" ]]; then
        print_pass "$desc"
    else
        print_fail "$desc" "expected empty output, got: '$value'"
    fi
}

function assert_not_empty {
    local value="$1" desc="$2"
    if [[ -n "$value" ]]; then
        print_pass "$desc"
    else
        print_fail "$desc" "expected non-empty output, got empty"
    fi
}

function assert_matches_pattern {
    local pattern="$1" value="$2" desc="$3"
    if echo "$value" | grep -qE "$pattern"; then
        print_pass "$desc"
    else
        print_fail "$desc" "expected pattern '$pattern' to match output: $value"
    fi
}

# run: captures stdout+stderr, sets RUN_OUTPUT and RUN_EXIT
function run {
    RUN_OUTPUT=""
    RUN_EXIT=0
    RUN_OUTPUT=$(bash "$SCRIPT" "$@" 2>&1) || RUN_EXIT=$?
}

# run_stdout_only: captures stdout only
function run_stdout_only {
    RUN_OUTPUT=""
    RUN_EXIT=0
    RUN_OUTPUT=$(bash "$SCRIPT" "$@" 2>/dev/null) || RUN_EXIT=$?
}

#---------------------------------------------------------------------------
# Test setup
#---------------------------------------------------------------------------

function setup_tests {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/docs"
    mkdir -p "$TEST_DIR/src/deep"
    mkdir -p "$TEST_DIR/binary"
    mkdir -p "$TEST_DIR/spaces"

    # docs/readme.txt — "hello" on lines 1,2,3,6; col 1 for lowercase
    cat > "$TEST_DIR/docs/readme.txt" <<'EOF'
Hello World
hello world
HELLO WORLD
This is a readme file.
The quick brown fox jumps over the lazy dog.
hellofoo is not hello
EOF

    # docs/notes.md
    cat > "$TEST_DIR/docs/notes.md" <<'EOF'
The quick brown fox
Hello there, this is a note.
Some other content here.
Another line with hello in it.
Nothing special on this line.
Just text below:
hello=world assignment
The end.
EOF

    # docs/empty.txt
    touch "$TEST_DIR/docs/empty.txt"

    # src/main.sh
    cat > "$TEST_DIR/src/main.sh" <<'EOF'
#!/usr/bin/env bash
function hello_world {
    echo hello
    echo "Hello from main"
}
hello_world
EOF

    # src/util.sh
    cat > "$TEST_DIR/src/util.sh" <<'EOF'
#!/usr/bin/env bash
# util functions
hello=world
HELLO_CONST="constant"
function greet { echo "hello"; }
EOF

    # src/deep/nested.sh
    cat > "$TEST_DIR/src/deep/nested.sh" <<'EOF'
#!/usr/bin/env bash
# nested hello content
echo "deeply nested hello"
EOF

    # binary/sample.bin — binary (null bytes)
    printf '\x00\x01\x02hello\x00\x03' > "$TEST_DIR/binary/sample.bin"

    # spaces/file with spaces.txt
    cat > "$TEST_DIR/spaces/file with spaces.txt" <<'EOF'
hello spaces file
This file has spaces in its name.
another hello in spaces file
EOF

    # docs/special.txt — for literal special-char tests
    cat > "$TEST_DIR/docs/special.txt" <<'EOF'
price is $10.00
cost (USD): $10.00
pattern: hello.world
regex: hello+world
EOF

    # docs/sparse.txt — matches far apart (triggers --- separator in --context output)
    {
        echo "hello at the top"
        for i in $(seq 1 20); do echo "filler line $i no match here"; done
        echo "hello at the bottom"
    } > "$TEST_DIR/docs/sparse.txt"
}

function cleanup_tests {
    rm -rf "$TEST_DIR"
}

#---------------------------------------------------------------------------
# Phase 2 — Argument validation
#---------------------------------------------------------------------------

function test_phase2 {
    printf "\n${_CBLD}${_CBLU}=== Phase 2: Argument Validation ===${_CRST}\n"

    run
    assert_exit_code 1 "$RUN_EXIT" "T01: no args → exit 1"
    assert_contains "no arguments provided" "$RUN_OUTPUT" "T01: no args → usage message"

    run -t "hello"
    assert_exit_code 1 "$RUN_EXIT" "T02: missing -d → exit 1"
    assert_contains "directory is required" "$RUN_OUTPUT" "T02: missing -d → error message"

    run -d "$TEST_DIR"
    assert_exit_code 1 "$RUN_EXIT" "T03: missing -t → exit 1"
    assert_contains "search text is required" "$RUN_OUTPUT" "T03: missing -t → error message"

    run -d "/nonexistent_path_xyz" -t "hello"
    assert_exit_code 2 "$RUN_EXIT" "T04: non-existent dir → exit 2"
    assert_contains "does not exist" "$RUN_OUTPUT" "T04: non-existent dir → error message"

    run --completion -d "$TEST_DIR"
    assert_exit_code 1 "$RUN_EXIT" "T21: --completion + other args → exit 1"
    assert_contains "cannot be combined" "$RUN_OUTPUT" "T21: --completion + other args → error message"

    # linenum and context are now flags, not formats → invalid format
    run -d "$TEST_DIR" -t "hello" -f "linenum"
    assert_exit_code 1 "$RUN_EXIT" "T_FMT1: -f linenum now invalid format → exit 1"
    assert_contains "invalid format" "$RUN_OUTPUT" "T_FMT1: -f linenum → error message"

    run -d "$TEST_DIR" -t "hello" -f "context"
    assert_exit_code 1 "$RUN_EXIT" "T_FMT2: -f context now invalid format → exit 1"
    assert_contains "invalid format" "$RUN_OUTPUT" "T_FMT2: -f context → error message"

    run -d "$TEST_DIR" -t "hello" -f "badformat"
    assert_exit_code 1 "$RUN_EXIT" "T_FMT3: unknown format → exit 1"
    assert_contains "invalid format" "$RUN_OUTPUT" "T_FMT3: unknown format → error message"

    run --help
    assert_exit_code 1 "$RUN_EXIT" "T_HELP: --help → exit 1"
    assert_contains "Usage:" "$RUN_OUTPUT" "T_HELP: --help → shows usage"

    # --completion exclusivity with new flags
    run --completion --line-number
    assert_exit_code 1 "$RUN_EXIT" "T_COMP1: --completion + --line-number → exit 1"
    assert_contains "cannot be combined" "$RUN_OUTPUT" "T_COMP1: --completion + --line-number → error"

    run --completion --context
    assert_exit_code 1 "$RUN_EXIT" "T_COMP2: --completion + --context → exit 1"
    assert_contains "cannot be combined" "$RUN_OUTPUT" "T_COMP2: --completion + --context → error"
}

#---------------------------------------------------------------------------
# Phase 3 — Core search, name format
#---------------------------------------------------------------------------

function test_phase3 {
    printf "\n${_CBLD}${_CBLU}=== Phase 3: Core search (name format) ===${_CRST}\n"

    run_stdout_only -d "$TEST_DIR" -t "hello"
    assert_exit_code 0 "$RUN_EXIT" "T05: basic search → exit 0"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T05: basic search → finds readme.txt"
    assert_contains "notes.md"   "$RUN_OUTPUT" "T05: basic search → finds notes.md"
    assert_contains "main.sh"    "$RUN_OUTPUT" "T05: basic search → finds main.sh"
    assert_not_contains "empty.txt" "$RUN_OUTPUT" "T05: basic search → skips empty.txt"

    run_stdout_only -d "$TEST_DIR" -t "xyzzy_no_match_xyz"
    assert_exit_code 1 "$RUN_EXIT" "T06: no matches → exit 1"
    assert_empty "$RUN_OUTPUT"   "T06: no matches → empty output"

    run_stdout_only -d "$TEST_DIR/binary" -t "hello"
    assert_not_contains "sample.bin" "$RUN_OUTPUT" "T18: binary file → skipped"

    run_stdout_only -d "$TEST_DIR/spaces" -t "hello"
    assert_exit_code 0 "$RUN_EXIT" "T19: spaces in filename → exit 0"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "T19: spaces in filename → found"

    run_stdout_only -d "$TEST_DIR/docs" -t '$10.00'
    assert_exit_code 0 "$RUN_EXIT" "T22: literal special chars → exit 0"
    assert_contains "special.txt" "$RUN_OUTPUT" "T22: literal special chars → found in special.txt"
}

#---------------------------------------------------------------------------
# Phase 4 — Search options
#---------------------------------------------------------------------------

function test_phase4 {
    printf "\n${_CBLD}${_CBLU}=== Phase 4: Search options ===${_CRST}\n"

    run_stdout_only -d "$TEST_DIR/docs" -t "hello world" -i
    assert_exit_code 0 "$RUN_EXIT" "T07: -i case insensitive → exit 0"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T07: -i finds 'hello world' case-insensitively"

    run_stdout_only -d "$TEST_DIR/docs" -t "HELLO WORLD"
    assert_exit_code 0 "$RUN_EXIT" "T07b: case sensitive caps → exit 0"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T07b: case sensitive caps → found"

    run_stdout_only -d "$TEST_DIR/docs" -t "Hello World"
    assert_exit_code 0 "$RUN_EXIT" "T07c: case sensitive mixed → exit 0"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T07c: case sensitive → found"

    run_stdout_only -d "$TEST_DIR/docs" -t "hello" -x
    assert_exit_code 0 "$RUN_EXIT" "T08: --exact whole word → exit 0"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T08: --exact still finds standalone hello"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    echo "hellofoo" > "$tmp_dir/partial.txt"
    run_stdout_only -d "$tmp_dir" -t "hello" -x
    assert_exit_code 1 "$RUN_EXIT" "T08b: --exact prevents partial match → exit 1"
    assert_empty "$RUN_OUTPUT" "T08b: --exact prevents 'hello' matching 'hellofoo'"
    rm -rf "$tmp_dir"

    run_stdout_only -d "$TEST_DIR/docs" -t "hel+o" -r
    assert_exit_code 0 "$RUN_EXIT" "T09: --regex → exit 0"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T09: --regex matches 'hel+o' pattern"

    run_stdout_only -d "$TEST_DIR/docs" -t "hel+o"
    assert_exit_code 1 "$RUN_EXIT" "T09b: literal 'hel+o' not in files → exit 1"
    assert_empty "$RUN_OUTPUT" "T09b: literal 'hel+o' → empty"

    run_stdout_only -d "$TEST_DIR/docs" -t "HEL+O" -r -i
    assert_exit_code 0 "$RUN_EXIT" "T10: --regex -i → exit 0"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T10: --regex -i matches 'HEL+O' case-insensitively"

    run_stdout_only -d "$TEST_DIR/docs" -t "hel+o" -r -x
    assert_exit_code 0 "$RUN_EXIT" "T11: --regex --exact → exit 0"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T11: --regex --exact matches whole-word regex"

    local tmp_dir2
    tmp_dir2=$(mktemp -d)
    echo "hellofoo" > "$tmp_dir2/partial.txt"
    run_stdout_only -d "$tmp_dir2" -t "hel+o" -r -x
    assert_exit_code 1 "$RUN_EXIT" "T11b: --regex --exact prevents partial regex match"
    rm -rf "$tmp_dir2"
}

#---------------------------------------------------------------------------
# Phase 5 — Output formats (name/rel/full) and --line-number / --context flags
#---------------------------------------------------------------------------

function test_phase5 {
    printf "\n${_CBLD}${_CBLU}=== Phase 5: Output formats and --line-number / --context ===${_CRST}\n"

    # --- format: rel ---
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" -f rel
    assert_exit_code 0 "$RUN_EXIT" "T12: format=rel → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T12: rel format → non-empty output"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T12: rel format contains readme.txt"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_fail "T12: rel format → path is relative" "output starts with /"
    else
        print_pass "T12: rel format → path is relative"
    fi
    if echo "$RUN_OUTPUT" | grep -q "/"; then
        print_pass "T12: rel format contains path separator"
    else
        print_fail "T12: rel format contains path separator" "no '/' in: $RUN_OUTPUT"
    fi

    # --- format: full ---
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" -f full
    assert_exit_code 0 "$RUN_EXIT" "T13: format=full → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T13: full format → non-empty output"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_pass "T13: full format starts with /"
    else
        print_fail "T13: full format starts with /" "output: $RUN_OUTPUT"
    fi
    assert_contains "readme.txt" "$RUN_OUTPUT" "T13: full format contains readme.txt"

    # --- --line-number flag (name format) ---
    # readme.txt: "hello world" is on line 2, col 1
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --line-number
    assert_exit_code 0 "$RUN_EXIT" "T14: --line-number → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T14: --line-number → non-empty output"
    # Each line must match: <name> L<n>:C<col>
    assert_matches_pattern '^[^ ]+ L[0-9]+:C[0-9]+$' "$RUN_OUTPUT" \
        "T14: --line-number output matches '<name> L<n>:C<col>' pattern"
    assert_contains "readme.txt L" "$RUN_OUTPUT" "T14: --line-number shows readme.txt with annotation"
    # One entry per match occurrence (readme.txt has multiple 'hello' lines → multiple entries)
    local count
    count=$(echo "$RUN_OUTPUT" | grep -c "readme.txt" || true)
    if [[ "$count" -gt 1 ]]; then
        print_pass "T14: --line-number outputs one entry per match (multiple for readme.txt)"
    else
        print_fail "T14: --line-number outputs one entry per match" "only $count entry for readme.txt"
    fi
    # Verify specific format: L<n>:C<n>
    assert_matches_pattern 'L[0-9]+:C[0-9]+' "$RUN_OUTPUT" "T14: LINENUM_FORMAT uses L<n>:C<n>"

    # --line-number with rel format
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --line-number -f rel
    assert_exit_code 0 "$RUN_EXIT" "T14b: --line-number -f rel → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T14b: --line-number rel → non-empty"
    assert_matches_pattern 'L[0-9]+:C[0-9]+' "$RUN_OUTPUT" "T14b: --line-number rel → has annotation"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_fail "T14b: --line-number rel → path is relative" "starts with /"
    else
        print_pass "T14b: --line-number rel → path is relative"
    fi

    # --line-number with full format
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --line-number -f full
    assert_exit_code 0 "$RUN_EXIT" "T14c: --line-number -f full → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T14c: --line-number full → non-empty"
    assert_matches_pattern 'L[0-9]+:C[0-9]+' "$RUN_OUTPUT" "T14c: --line-number full → has annotation"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_pass "T14c: --line-number full → path is absolute"
    else
        print_fail "T14c: --line-number full → path is absolute" "doesn't start with /"
    fi

    # --line-number no matches → exit 1
    run_stdout_only -d "$TEST_DIR" -t "xyzzy_no_match" --line-number
    assert_exit_code 1 "$RUN_EXIT" "T14d: --line-number no matches → exit 1"
    assert_empty "$RUN_OUTPUT" "T14d: --line-number no matches → empty output"

    # --- --context flag (name format) ---
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --context
    assert_exit_code 0 "$RUN_EXIT" "T15: --context → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T15: --context → non-empty output"
    # Each file should have its name as a header line
    assert_contains "readme.txt" "$RUN_OUTPUT" "T15: --context shows readme.txt header"
    assert_contains "notes.md"   "$RUN_OUTPUT" "T15: --context shows notes.md header"
    # Context separator between match blocks: use sparse.txt which has matches 20+ lines apart
    local sparse_output
    sparse_output=$(bash "$SCRIPT" -d "$TEST_DIR/docs" -t "hello" --context -p "sparse" 2>/dev/null)
    assert_contains "---" "$sparse_output" "T15: --context shows --- separator between blocks"
    # Without --color, no ANSI codes expected
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_fail "T15: --context alone → no ANSI color codes" "ESC codes found without --color"
    else
        print_pass "T15: --context alone → no ANSI color codes"
    fi
    # Context content: verify lines AROUND match appear
    assert_contains "The quick brown fox" "$RUN_OUTPUT" "T15: --context shows context lines around match"

    # --context with rel format → filename header is relative path
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --context -f rel
    assert_exit_code 0 "$RUN_EXIT" "T15b: --context -f rel → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T15b: --context rel → non-empty"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T15b: --context rel → readme.txt in header"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_fail "T15b: --context rel → file header is relative" "starts with /"
    else
        print_pass "T15b: --context rel → file header is relative"
    fi

    # --context with full format → filename header is absolute path
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --context -f full
    assert_exit_code 0 "$RUN_EXIT" "T15c: --context -f full → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T15c: --context full → non-empty"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_pass "T15c: --context full → file header is absolute"
    else
        print_fail "T15c: --context full → file header is absolute" "doesn't start with /"
    fi
    assert_contains "readme.txt" "$RUN_OUTPUT" "T15c: --context full → readme.txt in header"

    # --context no matches → exit 1
    run_stdout_only -d "$TEST_DIR" -t "xyzzy_no_match" --context
    assert_exit_code 1 "$RUN_EXIT" "T15d: --context no matches → exit 1"
    assert_empty "$RUN_OUTPUT" "T15d: --context no matches → empty output"

    # --context + --line-number together (context takes display; both flags accepted)
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --context --line-number
    assert_exit_code 0 "$RUN_EXIT" "T15e: --context + --line-number → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T15e: --context + --line-number → non-empty"
    assert_contains "readme.txt" "$RUN_OUTPUT" "T15e: --context + --line-number → readme.txt present"
    # No color without --color flag
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_fail "T15e: --context + --line-number → no color without --color" "ESC codes found"
    else
        print_pass "T15e: --context + --line-number → no color without --color"
    fi

    # short flags -n and -c
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" -n
    assert_exit_code 0 "$RUN_EXIT" "T_SHORT1: -n short flag → exit 0"
    assert_matches_pattern 'L[0-9]+:C[0-9]+' "$RUN_OUTPUT" "T_SHORT1: -n short flag produces L<n>:C<n>"

    run_stdout_only -d "$TEST_DIR/docs" -t "hello" -c
    assert_exit_code 0 "$RUN_EXIT" "T_SHORT2: -c short flag → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T_SHORT2: -c short flag → non-empty"
    # No color without -C
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_fail "T_SHORT2: -c alone → no color without -C" "ESC codes found"
    else
        print_pass "T_SHORT2: -c alone → no color without -C"
    fi

    # -c -C short flag combo → colored output
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" -c -C
    assert_exit_code 0 "$RUN_EXIT" "T_SHORT3: -c -C short flags → exit 0"
    assert_not_empty "$RUN_OUTPUT" "T_SHORT3: -c -C → non-empty"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_pass "T_SHORT3: -c -C → colored output"
    else
        print_fail "T_SHORT3: -c -C → colored output" "no ESC codes"
    fi
}

#---------------------------------------------------------------------------
# Phase 6 — Output to file
#---------------------------------------------------------------------------

function test_phase6 {
    printf "\n${_CBLD}${_CBLU}=== Phase 6: Output to file ===${_CRST}\n"
    local out_file="$TEST_DIR/output.txt"

    rm -f "$out_file"
    run -d "$TEST_DIR/docs" -t "hello" -o "$out_file"
    assert_exit_code 0 "$RUN_EXIT" "T16: -o file → exit 0"
    if [[ -f "$out_file" ]]; then
        print_pass "T16: output file created"
        local file_content
        file_content="$(cat "$out_file")"
        assert_contains "readme.txt" "$file_content" "T16: output file contains readme.txt"
    else
        print_fail "T16: output file created" "file not found: $out_file"
    fi

    # --line-number output to file
    rm -f "$out_file"
    run -d "$TEST_DIR/docs" -t "hello" --line-number -o "$out_file"
    assert_exit_code 0 "$RUN_EXIT" "T16b: --line-number -o file → exit 0"
    if [[ -f "$out_file" ]]; then
        local fc
        fc="$(cat "$out_file")"
        assert_matches_pattern 'L[0-9]+:C[0-9]+' "$fc" "T16b: --line-number file has L<n>:C<n>"
    else
        print_fail "T16b: --line-number -o file" "file not found: $out_file"
    fi

    # --context --color output to file (ANSI codes in file)
    rm -f "$out_file"
    run -d "$TEST_DIR/docs" -t "hello" --context --color -o "$out_file"
    assert_exit_code 0 "$RUN_EXIT" "T16c: --context --color -o file → exit 0"
    if [[ -f "$out_file" ]]; then
        local fc2
        fc2="$(cat "$out_file")"
        assert_contains "readme.txt" "$fc2" "T16c: --context --color file has readme.txt"
        if printf '%s' "$fc2" | grep -qF $'\033['; then
            print_pass "T16c: --context --color file has ANSI color codes"
        else
            print_fail "T16c: --context --color file has ANSI color codes" "no ESC codes"
        fi
    else
        print_fail "T16c: --context --color -o file" "file not found: $out_file"
    fi

    run -d "$TEST_DIR/docs" -t "hello" -o "/nonexistent_dir/output.txt"
    assert_exit_code 2 "$RUN_EXIT" "T17: -o bad path → exit 2"
    assert_contains "does not exist" "$RUN_OUTPUT" "T17: -o bad path → error message"
}

#---------------------------------------------------------------------------
# Phase 7 — Bash completion
#---------------------------------------------------------------------------

function test_phase7 {
    printf "\n${_CBLD}${_CBLU}=== Phase 7: Bash completion ===${_CRST}\n"
    local comp_file="$HOME/.local/share/bash-completion/completions/codesearch"

    run --completion
    assert_exit_code 0 "$RUN_EXIT" "T20: --completion → exit 0"
    if [[ -f "$comp_file" ]]; then
        print_pass "T20: completion file created at $comp_file"
    else
        print_fail "T20: completion file created" "file not found: $comp_file"
    fi
    assert_contains "loaded" "$RUN_OUTPUT" "T20: completion reports success"

    if grep -q "_codesearch_completion" "$comp_file" 2>/dev/null; then
        print_pass "T20: completion file has _codesearch_completion function"
    else
        print_fail "T20: completion file has _codesearch_completion function" "function not found"
    fi

    # Verify new flags are in completion
    if grep -q "\-\-line-number" "$comp_file" 2>/dev/null; then
        print_pass "T20: completion includes --line-number"
    else
        print_fail "T20: completion includes --line-number" "not found in $comp_file"
    fi
    if grep -q "\-\-context" "$comp_file" 2>/dev/null; then
        print_pass "T20: completion includes --context"
    else
        print_fail "T20: completion includes --context" "not found in $comp_file"
    fi
    if grep -q "\-\-color" "$comp_file" 2>/dev/null; then
        print_pass "T20: completion includes --color"
    else
        print_fail "T20: completion includes --color" "not found in $comp_file"
    fi

    # Verify removed formats are gone from completion
    if ! grep -q "linenum" "$comp_file" 2>/dev/null; then
        print_pass "T20: completion does not list linenum as format"
    else
        print_fail "T20: completion does not list linenum as format" "found 'linenum' in completion"
    fi

    run --completion -d "$TEST_DIR"
    assert_exit_code 1 "$RUN_EXIT" "T21: --completion + other args → exit 1"
    assert_contains "cannot be combined" "$RUN_OUTPUT" "T21: error message"
}

#---------------------------------------------------------------------------
# Phase 8 — File pattern filter (-p / --file-pattern)
#---------------------------------------------------------------------------

function test_phase8 {
    printf "\n${_CBLD}${_CBLU}=== Phase 8: File pattern filter (-p / --file-pattern) ===${_CRST}\n"

    # FP01: no -p → all file types searched
    run_stdout_only -d "$TEST_DIR" -t "hello"
    assert_exit_code 0 "$RUN_EXIT" "FP01: no -p → all files searched (exit 0)"
    assert_contains "readme.txt" "$RUN_OUTPUT" "FP01: finds readme.txt"
    assert_contains "notes.md"   "$RUN_OUTPUT" "FP01: finds notes.md"
    assert_contains "main.sh"    "$RUN_OUTPUT" "FP01: finds main.sh"

    # FP02: -p '\.sh$'
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.sh$'
    assert_exit_code 0 "$RUN_EXIT" "FP02: -p '\\.sh\$' → exit 0"
    assert_contains     "main.sh"    "$RUN_OUTPUT" "FP02: finds main.sh"
    assert_contains     "util.sh"    "$RUN_OUTPUT" "FP02: finds util.sh"
    assert_contains     "nested.sh"  "$RUN_OUTPUT" "FP02: finds nested.sh"
    assert_not_contains "readme.txt" "$RUN_OUTPUT" "FP02: excludes readme.txt"
    assert_not_contains "notes.md"   "$RUN_OUTPUT" "FP02: excludes notes.md"

    # FP03: -p '\.md$'
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.md$'
    assert_exit_code 0 "$RUN_EXIT" "FP03: -p '\\.md\$' → exit 0"
    assert_contains     "notes.md"   "$RUN_OUTPUT" "FP03: finds notes.md"
    assert_not_contains "readme.txt" "$RUN_OUTPUT" "FP03: excludes readme.txt"
    assert_not_contains "main.sh"    "$RUN_OUTPUT" "FP03: excludes main.sh"

    # FP04: case insensitive pattern
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.SH$'
    assert_exit_code 0 "$RUN_EXIT" "FP04: -p '\\.SH\$' uppercase → exit 0"
    assert_contains     "main.sh"    "$RUN_OUTPUT" "FP04: uppercase pattern matches .sh"
    assert_not_contains "readme.txt" "$RUN_OUTPUT" "FP04: excludes non-.sh"

    # FP05: regex alternation
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.(sh|md)$'
    assert_exit_code 0 "$RUN_EXIT" "FP05: alternation → exit 0"
    assert_contains     "main.sh"    "$RUN_OUTPUT" "FP05: alternation matches .sh"
    assert_contains     "notes.md"   "$RUN_OUTPUT" "FP05: alternation matches .md"
    assert_not_contains "readme.txt" "$RUN_OUTPUT" "FP05: alternation excludes .txt"

    # FP06: partial filename match
    run_stdout_only -d "$TEST_DIR" -t "hello" -p 'readme'
    assert_exit_code 0 "$RUN_EXIT" "FP06: partial match → exit 0"
    assert_contains     "readme.txt" "$RUN_OUTPUT" "FP06: partial match finds readme.txt"
    assert_not_contains "notes.md"   "$RUN_OUTPUT" "FP06: partial match excludes notes.md"

    # FP07: pattern with no matching files → exit 1
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.xyz$'
    assert_exit_code 1 "$RUN_EXIT" "FP07: no matching files → exit 1"
    assert_empty "$RUN_OUTPUT" "FP07: no matching files → empty output"

    # FP08: files match pattern but contain no text match
    run_stdout_only -d "$TEST_DIR" -t "hello" -p 'empty'
    assert_exit_code 1 "$RUN_EXIT" "FP08: file match, no text match → exit 1"
    assert_empty "$RUN_OUTPUT" "FP08: → empty output"

    # FP09: -i + -p combined
    run_stdout_only -d "$TEST_DIR" -t "HELLO WORLD" -i -p '\.txt$'
    assert_exit_code 0 "$RUN_EXIT" "FP09: -i + -p → exit 0"
    assert_contains     "readme.txt" "$RUN_OUTPUT" "FP09: -i + -p finds readme.txt"
    assert_not_contains "main.sh"    "$RUN_OUTPUT" "FP09: -i + -p excludes .sh"

    # FP10: -r + -p combined
    run_stdout_only -d "$TEST_DIR" -t "hel+o" -r -p '\.sh$'
    assert_exit_code 0 "$RUN_EXIT" "FP10: -r + -p → exit 0"
    assert_contains     "main.sh"    "$RUN_OUTPUT" "FP10: -r + -p finds main.sh"
    assert_not_contains "readme.txt" "$RUN_OUTPUT" "FP10: -r + -p excludes .txt"

    # FP11: -x + -p combined
    run_stdout_only -d "$TEST_DIR" -t "hello" -x -p '\.sh$'
    assert_exit_code 0 "$RUN_EXIT" "FP11: -x + -p → exit 0"
    assert_contains "main.sh" "$RUN_OUTPUT" "FP11: -x + -p finds whole-word hello in .sh"

    # FP12: -p + format=rel
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.sh$' -f rel
    assert_exit_code 0 "$RUN_EXIT" "FP12: -p + format=rel → exit 0"
    assert_contains "main.sh" "$RUN_OUTPUT" "FP12: rel format with -p works"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_fail "FP12: rel + -p → relative path" "starts with /"
    else
        print_pass "FP12: rel + -p → relative path"
    fi

    # FP13: -p + format=full
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.sh$' -f full
    assert_exit_code 0 "$RUN_EXIT" "FP13: -p + format=full → exit 0"
    assert_contains "main.sh" "$RUN_OUTPUT" "FP13: full format with -p works"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_pass "FP13: full + -p → absolute path"
    else
        print_fail "FP13: full + -p → absolute path" "doesn't start with /"
    fi

    # FP14: -p + --line-number (replaces old linenum format + -p test)
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.sh$' --line-number
    assert_exit_code 0 "$RUN_EXIT" "FP14: -p + --line-number → exit 0"
    assert_not_empty "$RUN_OUTPUT" "FP14: -p + --line-number → non-empty"
    assert_matches_pattern 'L[0-9]+:C[0-9]+' "$RUN_OUTPUT" "FP14: -p + --line-number has annotation"
    assert_not_contains "readme.txt" "$RUN_OUTPUT" "FP14: -p + --line-number excludes .txt"

    # FP15: -p + --context (no color without --color flag)
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.sh$' --context
    assert_exit_code 0 "$RUN_EXIT" "FP15: -p + --context → exit 0"
    assert_not_empty "$RUN_OUTPUT" "FP15: -p + --context → non-empty"
    assert_contains "main.sh"    "$RUN_OUTPUT" "FP15: -p + --context shows main.sh"
    assert_not_contains "readme.txt" "$RUN_OUTPUT" "FP15: -p + --context excludes readme.txt"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_fail "FP15: -p + --context alone → no ANSI codes" "ESC codes found without --color"
    else
        print_pass "FP15: -p + --context alone → no ANSI codes"
    fi

    # FP15b: -p + --context --color → colored output
    run_stdout_only -d "$TEST_DIR" -t "hello" -p '\.sh$' --context --color
    assert_exit_code 0 "$RUN_EXIT" "FP15b: -p + --context --color → exit 0"
    assert_not_empty "$RUN_OUTPUT" "FP15b: -p + --context --color → non-empty"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_pass "FP15b: -p + --context --color → colored output"
    else
        print_fail "FP15b: -p + --context --color → colored output" "no ESC codes"
    fi

    # FP16: -p + -o (output to file)
    local out_file="$TEST_DIR/fp_output.txt"
    rm -f "$out_file"
    run -d "$TEST_DIR" -t "hello" -p '\.sh$' -o "$out_file"
    assert_exit_code 0 "$RUN_EXIT" "FP16: -p + -o → exit 0"
    if [[ -f "$out_file" ]]; then
        local fc
        fc="$(cat "$out_file")"
        assert_contains     "main.sh"    "$fc" "FP16: file contains main.sh"
        assert_not_contains "readme.txt" "$fc" "FP16: file excludes readme.txt"
    else
        print_fail "FP16: output file created" "not found: $out_file"
    fi

    # FP17: --file-pattern long form
    run_stdout_only -d "$TEST_DIR" -t "hello" --file-pattern '\.sh$'
    assert_exit_code 0 "$RUN_EXIT" "FP17: --file-pattern long form → exit 0"
    assert_contains     "main.sh"    "$RUN_OUTPUT" "FP17: --file-pattern finds .sh"
    assert_not_contains "readme.txt" "$RUN_OUTPUT" "FP17: --file-pattern excludes .txt"

    # FP18: -p with spaces in filename
    run_stdout_only -d "$TEST_DIR/spaces" -t "hello" -p '\.txt$'
    assert_exit_code 0 "$RUN_EXIT" "FP18: -p spaces-in-filename → exit 0"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "FP18: -p works with space-in-filename"

    # FP19: --completion + -p → error
    run --completion -p '\.sh$'
    assert_exit_code 1 "$RUN_EXIT" "FP19: --completion + -p → exit 1"
    assert_contains "cannot be combined" "$RUN_OUTPUT" "FP19: error message"

    # FP20: mixed-case pattern
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" -p 'README'
    assert_exit_code 0 "$RUN_EXIT" "FP20: mixed-case pattern → exit 0"
    assert_contains     "readme.txt" "$RUN_OUTPUT" "FP20: 'README' matches readme.txt"
    assert_not_contains "notes.md"   "$RUN_OUTPUT" "FP20: 'README' excludes notes.md"
}

#---------------------------------------------------------------------------
# Summary
#---------------------------------------------------------------------------

function print_summary {
    printf "\n${_CBLD}=================================================${_CRST}\n"
    printf "${_CBLD}  Test Results${_CRST}\n"
    printf "${_CBLD}=================================================${_CRST}\n"
    printf "  ${_CGRN}Passed: %d${_CRST}\n" "$PASS"
    if [[ "$FAIL" -gt 0 ]]; then
        printf "  ${_CRED}Failed: %d${_CRST}\n" "$FAIL"
    else
        printf "  Failed: %d\n" "$FAIL"
    fi
    printf "  Total:  %d\n" "$((PASS+FAIL))"
    printf "${_CBLD}=================================================${_CRST}\n"
    if [[ "$FAIL" -gt 0 ]]; then
        printf "  ${_CRED}${_CBLD}RESULT: FAIL${_CRST}\n"
        exit 1
    else
        printf "  ${_CGRN}${_CBLD}RESULT: PASS${_CRST}\n"
        exit 0
    fi
}

#---------------------------------------------------------------------------
# Phase 10 — --color flag (-C)
#---------------------------------------------------------------------------

function test_phase10 {
    printf "\n${_CBLD}${_CBLU}=== Phase 10: --color flag (-C / --color) ===${_CRST}\n"

    # TC01: --context --color → has ANSI color codes
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --context --color
    assert_exit_code 0 "$RUN_EXIT" "TC01: --context --color → exit 0"
    assert_not_empty "$RUN_OUTPUT" "TC01: --context --color → non-empty"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_pass "TC01: --context --color → ANSI color codes present"
    else
        print_fail "TC01: --context --color → ANSI color codes present" "no ESC codes found"
    fi

    # TC02: --color without --context → accepted, no color applied to file names
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --color
    assert_exit_code 0 "$RUN_EXIT" "TC02: --color without --context → exit 0"
    assert_not_empty "$RUN_OUTPUT" "TC02: --color without --context → non-empty output"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_fail "TC02: --color without --context → no ANSI in filename output" "ESC codes found"
    else
        print_pass "TC02: --color without --context → no ANSI in filename output"
    fi

    # TC03: --context without --color → no ANSI codes
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --context
    assert_exit_code 0 "$RUN_EXIT" "TC03: --context without --color → exit 0"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_fail "TC03: --context without --color → no ANSI codes" "ESC codes found"
    else
        print_pass "TC03: --context without --color → no ANSI codes"
    fi

    # TC04: --context --color -f rel → color present, header is relative
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --context --color -f rel
    assert_exit_code 0 "$RUN_EXIT" "TC04: --context --color rel → exit 0"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_pass "TC04: --context --color rel → ANSI codes present"
    else
        print_fail "TC04: --context --color rel → ANSI codes present" "no ESC codes"
    fi
    if echo "$RUN_OUTPUT" | grep -qE '^/'; then
        print_fail "TC04: --context --color rel → header is relative" "starts with /"
    else
        print_pass "TC04: --context --color rel → header is relative"
    fi

    # TC05: --context --color -f full → color present, header is absolute
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --context --color -f full
    assert_exit_code 0 "$RUN_EXIT" "TC05: --context --color full → exit 0"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_pass "TC05: --context --color full → ANSI codes present"
    else
        print_fail "TC05: --context --color full → ANSI codes present" "no ESC codes"
    fi

    # TC06: --context --color -p pattern → filters files and colors
    run_stdout_only -d "$TEST_DIR" -t "hello" --context --color -p '\.sh$'
    assert_exit_code 0 "$RUN_EXIT" "TC06: --context --color -p → exit 0"
    assert_contains "main.sh" "$RUN_OUTPUT" "TC06: --context --color -p → shows main.sh"
    assert_not_contains "readme.txt" "$RUN_OUTPUT" "TC06: --context --color -p → excludes readme.txt"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_pass "TC06: --context --color -p → ANSI codes present"
    else
        print_fail "TC06: --context --color -p → ANSI codes present" "no ESC codes"
    fi

    # TC07: --context --color no matches → exit 1, empty
    run_stdout_only -d "$TEST_DIR" -t "xyzzy_no_match" --context --color
    assert_exit_code 1 "$RUN_EXIT" "TC07: --context --color no match → exit 1"
    assert_empty "$RUN_OUTPUT" "TC07: --context --color no match → empty output"

    # TC08: --context --color -o file → ANSI codes in file
    local out_file="$TEST_DIR/color_output.txt"
    rm -f "$out_file"
    run -d "$TEST_DIR/docs" -t "hello" --context --color -o "$out_file"
    assert_exit_code 0 "$RUN_EXIT" "TC08: --context --color -o → exit 0"
    if [[ -f "$out_file" ]]; then
        local fc
        fc="$(cat "$out_file")"
        assert_contains "readme.txt" "$fc" "TC08: --context --color file has readme.txt"
        if printf '%s' "$fc" | grep -qF $'\033['; then
            print_pass "TC08: --context --color file has ANSI color codes"
        else
            print_fail "TC08: --context --color file has ANSI color codes" "no ESC codes"
        fi
    else
        print_fail "TC08: --context --color -o file" "file not found: $out_file"
    fi

    # TC09: --completion + --color → exit 1
    run --completion --color
    assert_exit_code 1 "$RUN_EXIT" "TC09: --completion + --color → exit 1"
    assert_contains "cannot be combined" "$RUN_OUTPUT" "TC09: --completion + --color → error message"

    # TC10: -C short flag with -c → same as --color with --context
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" -c -C
    assert_exit_code 0 "$RUN_EXIT" "TC10: -c -C short flags → exit 0"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_pass "TC10: -c -C short flags → ANSI codes present"
    else
        print_fail "TC10: -c -C short flags → ANSI codes present" "no ESC codes"
    fi

    # TC11: --color with --line-number (no --context) → no color in output
    run_stdout_only -d "$TEST_DIR/docs" -t "hello" --line-number --color
    assert_exit_code 0 "$RUN_EXIT" "TC11: --line-number --color → exit 0"
    assert_matches_pattern 'L[0-9]+:C[0-9]+' "$RUN_OUTPUT" "TC11: --line-number --color → has annotation"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_fail "TC11: --line-number --color → no ANSI in non-context output" "ESC codes found"
    else
        print_pass "TC11: --line-number --color → no ANSI in non-context output"
    fi
}

#---------------------------------------------------------------------------
# Phase 9 — Files with spaces in their names
#---------------------------------------------------------------------------

function test_phase9_spaces {
    printf "\n${_CBLD}${_CBLU}=== Phase 9: Files with spaces in name ===${_CRST}\n"

    local SPACES_DIR="$TEST_DIR/spaces"

    # SP01: basic name format — already covered by T19, verified here too
    run_stdout_only -d "$SPACES_DIR" -t "hello"
    assert_exit_code 0 "$RUN_EXIT" "SP01: basic search (name) → exit 0"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "SP01: basic search finds 'file with spaces.txt'"

    # SP02: format=rel
    run_stdout_only -d "$SPACES_DIR" -t "hello" -f rel
    assert_exit_code 0 "$RUN_EXIT" "SP02: format=rel with spaces → exit 0"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "SP02: rel format finds 'file with spaces.txt'"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_fail "SP02: rel format → relative path" "starts with /"
    else
        print_pass "SP02: rel format → relative path"
    fi

    # SP03: format=full
    run_stdout_only -d "$SPACES_DIR" -t "hello" -f full
    assert_exit_code 0 "$RUN_EXIT" "SP03: format=full with spaces → exit 0"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "SP03: full format finds 'file with spaces.txt'"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_pass "SP03: full format → absolute path"
    else
        print_fail "SP03: full format → absolute path" "doesn't start with /"
    fi

    # SP04: --line-number (name format) — one entry per match, annotation present
    run_stdout_only -d "$SPACES_DIR" -t "hello" --line-number
    assert_exit_code 0 "$RUN_EXIT" "SP04: --line-number with spaces → exit 0"
    assert_contains "file with spaces.txt L" "$RUN_OUTPUT" "SP04: --line-number shows 'file with spaces.txt' with annotation"
    assert_matches_pattern 'L[0-9]+:C[0-9]+' "$RUN_OUTPUT" "SP04: --line-number has L<n>:C<n>"
    # file has two matches → two entries
    local sp04_count
    sp04_count=$(echo "$RUN_OUTPUT" | grep -c "file with spaces.txt" || true)
    if [[ "$sp04_count" -gt 1 ]]; then
        print_pass "SP04: --line-number produces one entry per match occurrence"
    else
        print_fail "SP04: --line-number produces one entry per match occurrence" "only $sp04_count entry"
    fi

    # SP05: --line-number with correct column for first match on line 1 (col 1)
    assert_contains "file with spaces.txt L1:C1" "$RUN_OUTPUT" "SP05: --line-number col=1 for line starting with 'hello'"

    # SP06: --line-number with rel format
    run_stdout_only -d "$SPACES_DIR" -t "hello" --line-number -f rel
    assert_exit_code 0 "$RUN_EXIT" "SP06: --line-number -f rel with spaces → exit 0"
    assert_contains "file with spaces.txt L" "$RUN_OUTPUT" "SP06: --line-number rel → annotation present"
    assert_matches_pattern 'L[0-9]+:C[0-9]+' "$RUN_OUTPUT" "SP06: --line-number rel → L<n>:C<n>"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_fail "SP06: --line-number rel → relative path" "starts with /"
    else
        print_pass "SP06: --line-number rel → relative path"
    fi

    # SP07: --line-number with full format
    run_stdout_only -d "$SPACES_DIR" -t "hello" --line-number -f full
    assert_exit_code 0 "$RUN_EXIT" "SP07: --line-number -f full with spaces → exit 0"
    assert_contains "file with spaces.txt L" "$RUN_OUTPUT" "SP07: --line-number full → annotation present"
    assert_matches_pattern 'L[0-9]+:C[0-9]+' "$RUN_OUTPUT" "SP07: --line-number full → L<n>:C<n>"
    if echo "$RUN_OUTPUT" | grep -q "^/"; then
        print_pass "SP07: --line-number full → absolute path"
    else
        print_fail "SP07: --line-number full → absolute path" "doesn't start with /"
    fi

    # SP08: --context (name format)
    run_stdout_only -d "$SPACES_DIR" -t "hello" --context
    assert_exit_code 0 "$RUN_EXIT" "SP08: --context with spaces → exit 0"
    assert_not_empty "$RUN_OUTPUT" "SP08: --context → non-empty"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "SP08: --context header shows 'file with spaces.txt'"
    assert_contains "hello spaces file" "$RUN_OUTPUT" "SP08: --context shows matching line content"
    assert_contains "spaces in its name" "$RUN_OUTPUT" "SP08: --context shows context lines"

    # SP09: --context with rel format
    run_stdout_only -d "$SPACES_DIR" -t "hello" --context -f rel
    assert_exit_code 0 "$RUN_EXIT" "SP09: --context -f rel with spaces → exit 0"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "SP09: --context rel header has filename"
    if echo "$RUN_OUTPUT" | head -1 | grep -q "^/"; then
        print_fail "SP09: --context rel → header is relative" "starts with /"
    else
        print_pass "SP09: --context rel → header is relative"
    fi

    # SP10: --context with full format
    run_stdout_only -d "$SPACES_DIR" -t "hello" --context -f full
    assert_exit_code 0 "$RUN_EXIT" "SP10: --context -f full with spaces → exit 0"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "SP10: --context full header has filename"
    if echo "$RUN_OUTPUT" | head -1 | grep -q "^/"; then
        print_pass "SP10: --context full → header is absolute"
    else
        print_fail "SP10: --context full → header is absolute" "doesn't start with /"
    fi

    # SP11: --context --color with spaces in filename
    run_stdout_only -d "$SPACES_DIR" -t "hello" --context --color
    assert_exit_code 0 "$RUN_EXIT" "SP11: --context --color with spaces → exit 0"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "SP11: --context --color shows filename"
    if printf '%s' "$RUN_OUTPUT" | grep -qF $'\033['; then
        print_pass "SP11: --context --color → ANSI color codes present"
    else
        print_fail "SP11: --context --color → ANSI color codes present" "no ESC codes found"
    fi

    # SP12: -p filter + spaces in filename (long form text search)
    run_stdout_only -d "$SPACES_DIR" -t "spaces in its name" -p '\.txt$'
    assert_exit_code 0 "$RUN_EXIT" "SP12: search text with spaces + -p → exit 0"
    assert_contains "file with spaces.txt" "$RUN_OUTPUT" "SP12: finds file when search text has spaces"

    # SP13: -o output to file, spaces in source filename
    local sp_out="$TEST_DIR/spaces_output.txt"
    rm -f "$sp_out"
    run -d "$SPACES_DIR" -t "hello" -o "$sp_out"
    assert_exit_code 0 "$RUN_EXIT" "SP13: -o with spaces-in-filename → exit 0"
    if [[ -f "$sp_out" ]]; then
        local sp_fc
        sp_fc="$(cat "$sp_out")"
        assert_contains "file with spaces.txt" "$sp_fc" "SP13: output file contains 'file with spaces.txt'"
    else
        print_fail "SP13: output file created" "file not found: $sp_out"
    fi
}

#---------------------------------------------------------------------------
# Run all tests
#---------------------------------------------------------------------------

echo "Setting up test files..."
setup_tests
echo "Test files created in: $TEST_DIR"

chmod +x "$SCRIPT"

test_phase2
test_phase3
test_phase4
test_phase5
test_phase6
test_phase7
test_phase8
test_phase9_spaces
test_phase10

cleanup_tests
print_summary
