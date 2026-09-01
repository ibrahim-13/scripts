#!/usr/bin/env bash
#
# audio-extract-wiz-test.sh - tests for audio-extract-wiz.sh.
#
# Fully hermetic by default: HOME / XDG_CONFIG_HOME are pointed at a temp dir,
# yt-dlp / ffmpeg / node are stubs on a private PATH, prompts are stdin-driven;
# no network access is performed.
# NOT covered hermetically: the real download, real ffmpeg encoding and the
# dependency install path. Run with --live to add one real end-to-end download
# + conversion; it prompts for a URL (nothing is stored in this file).
#
# Usage: ./audio-extract-wiz-test.sh [--live]   (exit 0 = all tests passed)

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$SCRIPT_DIR/audio-extract-wiz.sh"
LIVE_MODE="false"
[ "${1:-}" = "--live" ] && LIVE_MODE="true"

PASS=0; FAIL=0; SKIP=0
OUT=""; RC=0

function t_pass { PASS=$((PASS + 1)); echo "  ok   - $1"; }
function t_fail { FAIL=$((FAIL + 1)); echo "  FAIL - $1"; }
function t_skip { SKIP=$((SKIP + 1)); echo "  skip - $1"; }
function t_case { echo; echo "# $1"; }

function assert_rc {
    [ "$RC" = "$1" ] && t_pass "exit code is $1" || t_fail "exit code is $RC, expected $1 (output: $(echo "$OUT" | tail -n 3 | tr '\n' ' '))"
}

function assert_out_contains {
    if echo "$OUT" | grep -qF -- "$1"; then t_pass "output contains: $1"
    else t_fail "output missing: $1 (output: $(echo "$OUT" | tail -n 5 | tr '\n' ' '))"; fi
}

function assert_out_lacks {
    if echo "$OUT" | grep -qF -- "$1"; then t_fail "output must not contain: $1"
    else t_pass "output lacks: $1"; fi
}

function assert_file {
    [ -f "$1" ] && t_pass "file exists: $(basename "$1")" || t_fail "file missing: $1"
}

function assert_no_file {
    [ -e "$1" ] && t_fail "must not exist: $1" || t_pass "absent: $(basename "$1")"
}

# ---------------------------------------------------------------------------
# sandbox
# ---------------------------------------------------------------------------

SANDBOXES=""
trap 'rm -rf $SANDBOXES' EXIT
SANDBOX=""

function new_sandbox {
    SANDBOX="$(mktemp -d)"
    SANDBOXES="$SANDBOXES $SANDBOX"
    mkdir -p "$SANDBOX/home" "$SANDBOX/config" "$SANDBOX/bin" "$SANDBOX/out"

    # yt-dlp stub: echoes its args, then fakes a download into the directory
    # of the FIRST --output template (the second one is the chapter template)
    cat > "$SANDBOX/bin/yt-dlp" <<'EOS'
#!/bin/sh
echo "FAKE-yt-dlp ARGS: $*"
out=""
prev=""
for a in "$@"; do
    if [ "$prev" = "--output" ] && [ -z "$out" ]; then out="$a"; fi
    prev="$a"
done
dir=$(dirname "$out")
mkdir -p "$dir"
: > "$dir/Fake Title.webm"
case " $* " in
    *" --write-thumbnail "*) : > "$dir/Fake Title.jpg" ;;
esac
exit 0
EOS

    # ffmpeg stub: echoes its args and creates its output file (the last arg)
    cat > "$SANDBOX/bin/ffmpeg" <<'EOS'
#!/bin/sh
echo "FAKE-ffmpeg ARGS: $*"
last=""
for a in "$@"; do last="$a"; done
: > "$last"
exit 0
EOS

    printf '#!/bin/sh\nexit 0\n' > "$SANDBOX/bin/node"
    chmod +x "$SANDBOX/bin/yt-dlp" "$SANDBOX/bin/ffmpeg" "$SANDBOX/bin/node"
}

function run_target { # args... ; stdin closed
    OUT="$(cd "$SANDBOX" && \
        HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/config" \
        PATH="$SANDBOX/bin:$PATH" \
        bash "$TARGET" "$@" < /dev/null 2>&1)"
    RC=$?
}

function run_target_stdin { # $1 = input, rest = args
    local input="$1"; shift
    OUT="$(cd "$SANDBOX" && printf '%s' "$input" | \
        HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/config" \
        PATH="$SANDBOX/bin:$PATH" \
        bash "$TARGET" "$@" 2>&1)"
    RC=$?
}

FAKE_URL="https://example.com/watch?v=abc123"
FAKE_PLAYLIST_URL="https://example.com/watch?v=abc123&list=PL456"
STATE_REL="config/audio-extract-wiz/state"

# ---------------------------------------------------------------------------
# hermetic tests
# ---------------------------------------------------------------------------

t_case "syntax check"
if bash -n "$TARGET" 2>&1; then t_pass "bash -n"; else t_fail "bash -n"; fi

t_case "--help exits 0 and lists flags"
new_sandbox
run_target --help
assert_rc 0
assert_out_contains "Usage:"
assert_out_contains "--print-only"
assert_out_contains "--sponsorblock"

t_case "unknown argument"
run_target --bogus-flag
assert_rc 1
assert_out_contains "unknown argument: --bogus-flag"

t_case "-y without --url"
run_target -y
assert_rc 1
assert_out_contains "-u/--url is required with -y"

t_case "flag validation"
run_target -y -u "$FAKE_URL" -f mp9
assert_rc 1
assert_out_contains "-f/--format must be one of"
run_target -y -u "$FAKE_URL" -s "1:2:3"
assert_rc 1
assert_out_contains "HH:MM:SS"
run_target -y -u "$FAKE_URL" --limit-rate fast
assert_rc 1
assert_out_contains "--limit-rate"
run_target -y -u "not-a-url"
assert_rc 1
assert_out_contains "must start with http"

t_case "slicing conflicts"
run_target -y -u "$FAKE_URL" --convert no -s 00:00:01
assert_rc 1
assert_out_contains "require conversion"
run_target -y -u "$FAKE_URL" -o "$SANDBOX/out" -s 00:00:01 --split-chapters yes
assert_rc 1
assert_out_contains "cannot be combined with --split-chapters"

t_case "--print-only prints commands without executing or saving state"
new_sandbox
run_target -y -u "$FAKE_URL" -o "$SANDBOX/out" -c -f mp3 --print-only
assert_rc 0
assert_out_contains "print-only: nothing was executed"
assert_out_contains "yt-dlp"
assert_out_contains "conversion command (template)"
assert_out_lacks "FAKE-yt-dlp ARGS:"
assert_out_lacks "FAKE-ffmpeg ARGS:"
assert_no_file "$SANDBOX/$STATE_REL"

t_case "plan declined -> nothing changed"
new_sandbox
# stdin: empty line = no rate limit, then "n" declines the plan
run_target_stdin "
n
" -u "$FAKE_URL" -o "$SANDBOX/out" --convert no --embed no --sponsorblock no --split-chapters no
assert_rc 1
assert_out_contains "aborted; nothing was changed"
assert_out_lacks "FAKE-yt-dlp ARGS:"

t_case "-y run without conversion moves the download to the output dir"
new_sandbox
run_target -y -u "$FAKE_URL" -o "$SANDBOX/out" --convert no
assert_rc 0
assert_out_contains "FAKE-yt-dlp ARGS:"
assert_file "$SANDBOX/out/Fake Title.webm"
# embed defaults to yes; without conversion yt-dlp embeds the thumbnail itself
assert_out_contains "--embed-thumbnail"
assert_out_contains "--embed-metadata"
assert_out_contains "--no-playlist"

t_case "-y run with mp3 conversion (preserve meta) converts and cleans up"
new_sandbox
run_target -y -u "$FAKE_URL" -o "$SANDBOX/out" -c -f mp3 -q best
assert_rc 0
assert_out_contains "FAKE-ffmpeg ARGS:"
assert_file "$SANDBOX/out/Fake Title.mp3"
assert_no_file "$SANDBOX/out/Fake Title.webm"
# preserve-meta default yes: cover written by yt-dlp, attached by ffmpeg
assert_out_contains "--write-thumbnail"
assert_out_lacks "--embed-thumbnail"
assert_out_contains "Fake Title.jpg"
assert_out_contains "map_metadata"
if ls "$SANDBOX/out"/.audio-extract-wiz-* >/dev/null 2>&1; then
    t_fail "workdir left behind in output dir"
else
    t_pass "workdir cleaned up"
fi

t_case "keep-original keeps the source next to the converted file"
new_sandbox
run_target -y -u "$FAKE_URL" -o "$SANDBOX/out" -c -f mp3 -k
assert_rc 0
assert_file "$SANDBOX/out/Fake Title.mp3"
assert_file "$SANDBOX/out/Fake Title.webm"

t_case "opus quality preset lands in the ffmpeg command"
new_sandbox
run_target -y -u "$FAKE_URL" -o "$SANDBOX/out" -c -f opus -q medium --preserve-meta no --embed no
assert_rc 0
assert_out_contains "libopus"
assert_out_contains "96k"
assert_file "$SANDBOX/out/Fake Title.opus"

t_case "wav target warns that tags cannot survive"
new_sandbox
run_target -y -u "$FAKE_URL" -o "$SANDBOX/out" -c -f wav --embed yes
assert_rc 0
assert_out_contains "cannot hold tags"
assert_file "$SANDBOX/out/Fake Title.wav"

t_case "sponsorblock, playlist and split-chapters flags reach yt-dlp"
new_sandbox
run_target -y -u "$FAKE_PLAYLIST_URL" -o "$SANDBOX/out" --convert no --playlist all \
    --sponsorblock yes --sb-categories sponsor,selfpromo --split-chapters yes --limit-rate 2M
assert_rc 0
assert_out_contains "--yes-playlist"
assert_out_contains "--sponsorblock-remove sponsor,selfpromo"
assert_out_contains "--split-chapters"
assert_out_contains "--limit-rate 2M"

t_case "state persistence: second run reuses remembered answers"
new_sandbox
run_target -y -u "$FAKE_URL" -o "$SANDBOX/out" -c -f mp3 -q high
assert_rc 0
assert_file "$SANDBOX/$STATE_REL"
if grep -q '^FORMAT=mp3$' "$SANDBOX/$STATE_REL" && grep -q '^QUALITY=high$' "$SANDBOX/$STATE_REL"; then
    t_pass "state file remembers format/quality"
else
    t_fail "state file lacks FORMAT/QUALITY ($(cat "$SANDBOX/$STATE_REL" 2>/dev/null | tr '\n' ' '))"
fi
rm -f "$SANDBOX/out/Fake Title.mp3"
# no -o / -c / -f: everything comes from remembered defaults under -y
run_target -y -u "$FAKE_URL"
assert_rc 0
assert_out_contains "FAKE-ffmpeg ARGS:"
assert_file "$SANDBOX/out/Fake Title.mp3"

t_case "interactive wizard run driven via stdin"
new_sandbox
run_target_stdin "$FAKE_URL
$SANDBOX/out
y
1




y
"
assert_rc 0
assert_out_contains "target audio format"
assert_out_contains "FAKE-ffmpeg ARGS:"
assert_file "$SANDBOX/out/Fake Title.mp3"

t_case "stale workdir from a dead run is detected and removed with -y"
new_sandbox
mkdir -p "$SANDBOX/out/.audio-extract-wiz-99999999"
run_target -y -u "$FAKE_URL" -o "$SANDBOX/out" --convert no
assert_rc 0
assert_out_contains "stale workdir"
assert_no_file "$SANDBOX/out/.audio-extract-wiz-99999999"

t_case "missing dependency with --install-deps no dies"
new_sandbox
rm -f "$SANDBOX/bin/yt-dlp"
# restrict PATH to the sandbox plus a whitelist of core tools, so a real
# yt-dlp installed on the host cannot leak into the dependency check
mkdir -p "$SANDBOX/corebin"
for t in uname grep sed tail cat basename dirname mktemp touch mv rm mkdir id ls; do
    p="$(command -v "$t" 2>/dev/null)" && [ -n "$p" ] && ln -s "$p" "$SANDBOX/corebin/$t"
done
BASH_BIN="$(command -v bash)"
OUT="$(cd "$SANDBOX" && \
    HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/config" \
    PATH="$SANDBOX/bin:$SANDBOX/corebin" \
    "$BASH_BIN" "$TARGET" -y -u "$FAKE_URL" -o "$SANDBOX/out" --convert no --install-deps no < /dev/null 2>&1)"
RC=$?
assert_rc 1
assert_out_contains "missing dependencies"
assert_out_lacks "FAKE-yt-dlp ARGS:"

# ---------------------------------------------------------------------------
# live verification (opt-in; real network, real yt-dlp/ffmpeg)
# ---------------------------------------------------------------------------

if [ "$LIVE_MODE" = "true" ]; then
    echo
    echo "== LIVE TEST: real download + mp3 conversion (needs internet, yt-dlp, ffmpeg) =="
    printf 'enter a video URL to test against (empty = skip): '
    read -r LIVE_URL || LIVE_URL=""
    if [ -z "$LIVE_URL" ]; then
        t_skip "live test skipped (no URL given)"
    elif ! command -v yt-dlp >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1; then
        t_skip "live test skipped (yt-dlp/ffmpeg not installed)"
    else
        LIVE_DIR="$(mktemp -d)"
        SANDBOXES="$SANDBOXES $LIVE_DIR"
        t_case "live: slice 6s and convert to mp3 (medium), preserving metadata"
        OUT="$(HOME="$LIVE_DIR/home" XDG_CONFIG_HOME="$LIVE_DIR/config" \
            bash "$TARGET" -y -u "$LIVE_URL" -o "$LIVE_DIR/out" --create-dir yes \
            -c -f mp3 -q medium -s 00:00:02 -t 00:00:06 \
            --embed yes --preserve-meta yes --sponsorblock no --install-deps no 2>&1)"
        RC=$?
        assert_rc 0
        LIVE_MP3=""
        for f in "$LIVE_DIR/out"/*.mp3; do [ -f "$f" ] && LIVE_MP3="$f"; done
        if [ -n "$LIVE_MP3" ] && [ -s "$LIVE_MP3" ]; then
            t_pass "produced non-empty mp3: $(basename "$LIVE_MP3")"
        else
            t_fail "no mp3 produced (output: $(echo "$OUT" | tail -n 5 | tr '\n' ' '))"
        fi
        if [ -n "$LIVE_MP3" ] && command -v ffprobe >/dev/null 2>&1; then
            DUR="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$LIVE_MP3" 2>/dev/null | cut -d. -f1)"
            if [ -n "$DUR" ] && [ "$DUR" -ge 5 ] && [ "$DUR" -le 8 ]; then
                t_pass "sliced duration is ~6s (${DUR}s)"
            else
                t_fail "unexpected duration: ${DUR:-unknown}s (expected ~6s)"
            fi
        else
            t_skip "duration check (no ffprobe or no file)"
        fi
    fi
else
    echo
    echo "note: run with --live for a real end-to-end download test (prompts for a URL)"
fi

echo
echo "== RESULT: $PASS passed, $FAIL failed, $SKIP skipped =="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
