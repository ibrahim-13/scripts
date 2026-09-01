#!/usr/bin/env bash
#
# audio-extract-wiz.sh - interactive wizard to download audio from a video
# URL and optionally convert it to another format with ffmpeg.
#
# Wizard flow: URL -> playlist scope -> output dir -> convert? (format,
# quality) -> chapter split -> time slice -> thumbnail/metadata embedding ->
# SponsorBlock removal -> rate limit -> plan summary -> confirm -> download
# (yt-dlp) -> convert (ffmpeg). Downloads land in a private workdir inside the
# output directory, so playlist and chapter-split runs are handled uniformly
# by converting/moving whatever audio files appear there; the workdir is
# removed on exit and stale workdirs from crashed runs are detected on start.
# Every prompt has a CLI flag equivalent; -y accepts defaults for confirmations.
# Compatible with bash 3.2 (macOS default shell) - no associative arrays.

set -eu

# ---------------------------------------------------------------------------
# constants / state
# ---------------------------------------------------------------------------

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/audio-extract-wiz"
STATE_FILE="$STATE_DIR/state"

WORKDIR=""
PRODUCED=""

# ---------------------------------------------------------------------------
# output helpers
# ---------------------------------------------------------------------------

function print_info  { echo "[ info   ] $1"; }
function print_warn  { echo "[ warn   ] $1"; }
function print_error { echo "[ error  ] $1" >&2; }
function print_step  { echo; echo "==> $1"; }
function die { print_error "$1"; exit 1; }

# ---------------------------------------------------------------------------
# prompt helpers
# ---------------------------------------------------------------------------

ARG_YES="false"

# prompt_confirm "question" "default(y|n)" -> return 0 for yes
function prompt_confirm {
    local q="$1" def="${2:-n}" hint ans
    if [ "$ARG_YES" = "true" ]; then
        [ "$def" = "y" ] && return 0 || return 1
    fi
    if [ "$def" = "y" ]; then hint="(Y/n)"; else hint="(y/N)"; fi
    read -r -p "[ prompt ] $q $hint " ans || ans=""
    [ -z "$ans" ] && ans="$def"
    case "$ans" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# prompt_value "question" "default" -> echoes answer (default when empty / -y)
function prompt_value {
    local q="$1" def="${2:-}" ans
    if [ "$ARG_YES" = "true" ]; then echo "$def"; return; fi
    read -r -p "[ prompt ] $q [$def] " ans || ans=""
    [ -z "$ans" ] && ans="$def"
    echo "$ans"
}

# prompt_choice "question" "default-key" "key1:desc1" "key2:desc2" ...
# echoes the chosen key
function prompt_choice {
    local q="$1" def="$2" i n opt key ans
    shift 2
    if [ "$ARG_YES" = "true" ]; then echo "$def"; return; fi
    echo "[ prompt ] $q" >&2
    i=0
    for opt in "$@"; do
        i=$((i + 1))
        key="${opt%%:*}"
        echo "    $i) $key - ${opt#*:}$( [ "$key" = "$def" ] && echo '  (default)' )" >&2
    done
    n=$i
    while true; do
        read -r -p "[ prompt ] choose 1-$n or name [$def] " ans || ans=""
        [ -z "$ans" ] && { echo "$def"; return; }
        if echo "$ans" | grep -qE '^[0-9]+$' && [ "$ans" -ge 1 ] && [ "$ans" -le "$n" ]; then
            i=0
            for opt in "$@"; do
                i=$((i + 1))
                [ "$i" = "$ans" ] && { echo "${opt%%:*}"; return; }
            done
        fi
        for opt in "$@"; do
            key="${opt%%:*}"
            [ "$ans" = "$key" ] && { echo "$key"; return; }
        done
        echo "[ error  ] invalid selection: $ans" >&2
    done
}

# ---------------------------------------------------------------------------
# state helpers
# ---------------------------------------------------------------------------

function state_get {
    [ -f "$STATE_FILE" ] || { echo ""; return; }
    sed -n "s/^$1=//p" "$STATE_FILE" | tail -n 1
}

function state_set {
    mkdir -p "$STATE_DIR"
    touch "$STATE_FILE"
    local tmp
    tmp="$(mktemp "$STATE_DIR/.state.XXXXXX")"
    grep -v "^$1=" "$STATE_FILE" > "$tmp" || true
    echo "$1=$2" >> "$tmp"
    mv "$tmp" "$STATE_FILE"
}

# ---------------------------------------------------------------------------
# platform detection
# ---------------------------------------------------------------------------

OS=""; ARCH=""; DISTRO=""; PKG_MGR=""; IS_WSL="false"

function detect_platform {
    local m a
    m="$(uname -s)"; a="$(uname -m)"
    case "$m" in
        Linux*)  OS="linux" ;;
        Darwin*) OS="macos" ;;
        MINGW*|MSYS*|CYGWIN*)
            die "you appear to be on native Windows ($m); run this under WSL instead" ;;
        *) die "unsupported operating system: $m" ;;
    esac
    case "$a" in
        x86_64|amd64)  ARCH="x64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) ARCH="$a" ;;
    esac
    if [ "$OS" = "linux" ]; then
        if [ -f /etc/os-release ]; then
            DISTRO="$(. /etc/os-release && echo "${ID:-unknown}")"
        else
            DISTRO="unknown"
        fi
        grep -qi microsoft /proc/version 2>/dev/null && IS_WSL="true"
        if   command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt"
        elif command -v dnf     >/dev/null 2>&1; then PKG_MGR="dnf"
        elif command -v pacman  >/dev/null 2>&1; then PKG_MGR="pacman"
        elif command -v zypper  >/dev/null 2>&1; then PKG_MGR="zypper"
        else PKG_MGR="none"; fi
    else
        DISTRO="macos"
        if command -v brew >/dev/null 2>&1; then PKG_MGR="brew"; else PKG_MGR="none"; fi
    fi
    print_info "platform: os=$OS arch=$ARCH distro=$DISTRO pkg-mgr=$PKG_MGR wsl=$IS_WSL"
}

# ---------------------------------------------------------------------------
# dependency handling
# ---------------------------------------------------------------------------

function command_exists { command -v "$1" >/dev/null 2>&1; }

JS_RUNTIME=""

# yt-dlp needs a JS runtime (node or bun) to solve some sites' player challenges
function detect_js_runtime {
    if command_exists node; then JS_RUNTIME="node"
    elif command_exists bun; then JS_RUNTIME="bun"
    fi
}

function pkg_name_for {
    case "$1" in
        node) [ "$PKG_MGR" = "brew" ] && echo "node" || echo "nodejs" ;;
        *)    echo "$1" ;;
    esac
}

function ensure_deps {
    local missing="" pkgs="" t cmd sudo_cmd=""
    for t in yt-dlp ffmpeg; do
        command_exists "$t" || missing="$missing $t"
    done
    detect_js_runtime
    [ -z "$JS_RUNTIME" ] && missing="$missing node"
    if [ -z "$missing" ]; then
        print_info "dependencies ok: yt-dlp, ffmpeg, js runtime ($JS_RUNTIME)"
        return 0
    fi
    print_warn "missing dependencies:$missing"
    [ "$ARG_INSTALL_DEPS" = "no" ] && die "missing dependencies (--install-deps no):$missing"
    [ "$PKG_MGR" = "none" ] && die "no supported package manager found; install manually:$missing"
    for t in $missing; do
        pkgs="$pkgs $(pkg_name_for "$t")"
    done
    [ "$(id -u)" != "0" ] && [ "$PKG_MGR" != "brew" ] && sudo_cmd="sudo "
    case "$PKG_MGR" in
        apt)    cmd="${sudo_cmd}apt-get install -y$pkgs" ;;
        dnf)    cmd="${sudo_cmd}dnf install -y$pkgs" ;;
        pacman) cmd="${sudo_cmd}pacman -S --noconfirm$pkgs" ;;
        zypper) cmd="${sudo_cmd}zypper install -y$pkgs" ;;
        brew)   cmd="brew install$pkgs" ;;
    esac
    print_info "install command: $cmd"
    if [ "$ARG_INSTALL_DEPS" = "ask" ]; then
        prompt_confirm "run the install command now?" "y" || die "dependencies missing:$missing"
    fi
    $cmd
    for t in yt-dlp ffmpeg; do
        command_exists "$t" || die "still missing after install: $t"
    done
    detect_js_runtime
    [ -z "$JS_RUNTIME" ] && die "still missing a js runtime (node or bun) after install"
    print_info "dependencies installed"
}

# ---------------------------------------------------------------------------
# usage / argument parsing
# ---------------------------------------------------------------------------

function usage {
    [ -n "${1:-}" ] && echo -e "[ error  ] $1\n" >&2
    cat <<EOF
audio-extract-wiz.sh - wizard to download audio from a video URL and optionally convert it with ffmpeg

Usage: $(basename "$0") [options]

  -y                        accept defaults for all prompts and confirmations
  -u, --url URL             video URL to download audio from
  --playlist MODE           single|all when the URL is a playlist       (default: single)
  -o, --output DIR          output directory                            (default: remembered, else CWD)
  --create-dir yes|no       create the output directory if missing      (default: ask)
  -c                        same as --convert yes
  --convert yes|no          convert the downloaded audio with ffmpeg    (default: remembered, else no)
  -f, --format FMT          target format: mp3 m4a aac opus vorbis flac wav alac  (default: mp3)
  -q, --quality Q           best|high|medium, lossy formats only        (default: best)
  --split-chapters yes|no   one file per video chapter                  (default: no)
  -s, --start HH:MM:SS      slice start time (requires conversion)
  -t, --duration HH:MM:SS   slice duration (requires conversion)
  --embed yes|no            embed thumbnail + metadata                  (default: yes)
  --preserve-meta yes|no    keep tags/cover art through conversion      (default: yes)
  --sponsorblock yes|no     remove SponsorBlock segments                (default: no)
  --sb-categories CATS      SponsorBlock categories, comma separated    (default: sponsor)
                            (e.g. sponsor,selfpromo,intro,outro,music_offtopic)
  --limit-rate RATE         download rate limit, e.g. 500K or 2M        (default: unlimited)
  -k                        same as --keep-original yes
  --keep-original yes|no    keep the downloaded source after conversion (default: no)
  --install-deps MODE       yes|no|ask - install missing dependencies   (default: ask)
  --print-only              print the assembled commands and exit without running anything
  -h, --help                show this help

Remembered defaults are stored in $STATE_FILE
EOF
    [ -n "${1:-}" ] && exit 1
    exit 0
}

ARG_URL=""
ARG_PLAYLIST=""
ARG_OUTPUT=""
ARG_CREATE_DIR=""
ARG_CONVERT=""
ARG_FORMAT=""
ARG_QUALITY=""
ARG_SPLIT=""
ARG_START=""
ARG_DURATION=""
ARG_EMBED=""
ARG_PRESERVE=""
ARG_SPONSORBLOCK=""
ARG_SB_CATS=""
ARG_LIMIT_RATE=""
ARG_KEEP=""
ARG_INSTALL_DEPS="ask"
ARG_PRINT_ONLY="false"

while [ $# -gt 0 ]; do
    case "$1" in
        -y)               ARG_YES="true"; shift ;;
        -u|--url)         ARG_URL="$2"; shift 2 ;;
        --playlist)       ARG_PLAYLIST="$2"; shift 2 ;;
        -o|--output)      ARG_OUTPUT="$2"; shift 2 ;;
        --create-dir)     ARG_CREATE_DIR="$2"; shift 2 ;;
        -c)               ARG_CONVERT="yes"; shift ;;
        --convert)        ARG_CONVERT="$2"; shift 2 ;;
        -f|--format)      ARG_FORMAT="$2"; shift 2 ;;
        -q|--quality)     ARG_QUALITY="$2"; shift 2 ;;
        --split-chapters) ARG_SPLIT="$2"; shift 2 ;;
        -s|--start)       ARG_START="$2"; shift 2 ;;
        -t|--duration)    ARG_DURATION="$2"; shift 2 ;;
        --embed)          ARG_EMBED="$2"; shift 2 ;;
        --preserve-meta)  ARG_PRESERVE="$2"; shift 2 ;;
        --sponsorblock)   ARG_SPONSORBLOCK="$2"; shift 2 ;;
        --sb-categories)  ARG_SB_CATS="$2"; shift 2 ;;
        --limit-rate)     ARG_LIMIT_RATE="$2"; shift 2 ;;
        -k)               ARG_KEEP="yes"; shift ;;
        --keep-original)  ARG_KEEP="$2"; shift 2 ;;
        --install-deps)   ARG_INSTALL_DEPS="$2"; shift 2 ;;
        --print-only)     ARG_PRINT_ONLY="true"; shift ;;
        -h|--help)        usage ;;
        *)                usage "unknown argument: $1" ;;
    esac
done

# ---------------------------------------------------------------------------
# validation helpers / flag validation
# ---------------------------------------------------------------------------

function validate_url  { echo "$1" | grep -qE '^https?://[^[:space:]]+'; }
function validate_time { echo "$1" | grep -qE '^[0-9]{2}:[0-9]{2}:[0-9]{2}$'; }
function validate_rate { echo "$1" | grep -qE '^[0-9]+(\.[0-9]+)?[KMGkmg]?$'; }

function check_yesno {
    if [ -n "$2" ]; then
        case "$2" in yes|no) ;; *) usage "$1 must be yes or no (got: $2)" ;; esac
    fi
}

ALL_FORMATS="mp3 m4a aac opus vorbis flac wav alac"

function is_lossy {
    case "$1" in mp3|m4a|aac|opus|vorbis) return 0 ;; *) return 1 ;; esac
}

check_yesno "--create-dir"     "$ARG_CREATE_DIR"
check_yesno "--convert"        "$ARG_CONVERT"
check_yesno "--split-chapters" "$ARG_SPLIT"
check_yesno "--embed"          "$ARG_EMBED"
check_yesno "--preserve-meta"  "$ARG_PRESERVE"
check_yesno "--sponsorblock"   "$ARG_SPONSORBLOCK"
check_yesno "--keep-original"  "$ARG_KEEP"

if [ -n "$ARG_PLAYLIST" ]; then
    case "$ARG_PLAYLIST" in single|all) ;; *) usage "--playlist must be single or all (got: $ARG_PLAYLIST)" ;; esac
fi
if [ -n "$ARG_FORMAT" ]; then
    echo " $ALL_FORMATS " | grep -qF " $ARG_FORMAT " || usage "-f/--format must be one of: $ALL_FORMATS (got: $ARG_FORMAT)"
fi
if [ -n "$ARG_QUALITY" ]; then
    case "$ARG_QUALITY" in best|high|medium) ;; *) usage "-q/--quality must be best, high or medium (got: $ARG_QUALITY)" ;; esac
fi
if [ -n "$ARG_START" ]; then
    validate_time "$ARG_START" || usage "-s/--start must be in HH:MM:SS format (got: $ARG_START)"
fi
if [ -n "$ARG_DURATION" ]; then
    validate_time "$ARG_DURATION" || usage "-t/--duration must be in HH:MM:SS format (got: $ARG_DURATION)"
fi
if [ -n "$ARG_LIMIT_RATE" ]; then
    validate_rate "$ARG_LIMIT_RATE" || usage "--limit-rate must look like 4200, 500K or 2M (got: $ARG_LIMIT_RATE)"
fi
if [ -n "$ARG_URL" ]; then
    validate_url "$ARG_URL" || usage "invalid URL: must start with http:// or https://"
fi
case "$ARG_INSTALL_DEPS" in yes|no|ask) ;; *) usage "--install-deps must be yes, no or ask" ;; esac

# conversion-only flags imply --convert yes unless it was set explicitly
for _implied in "$ARG_FORMAT" "$ARG_QUALITY" "$ARG_START" "$ARG_DURATION"; do
    if [ -n "$_implied" ]; then
        [ "$ARG_CONVERT" = "no" ] && usage "-f/-q/-s/-t require conversion but --convert no was given"
        ARG_CONVERT="yes"
    fi
done
if [ "$ARG_PRESERVE" = "yes" ] && [ -z "$ARG_EMBED" ]; then ARG_EMBED="yes"; fi
if [ -n "$ARG_SB_CATS" ] && [ -z "$ARG_SPONSORBLOCK" ]; then ARG_SPONSORBLOCK="yes"; fi

if [ "$ARG_YES" = "true" ] && [ -z "$ARG_URL" ]; then
    usage "-u/--url is required with -y"
fi

# ---------------------------------------------------------------------------
# domain-specific helpers
# ---------------------------------------------------------------------------

# resolve_yesno <flag-value> <question> <default yes|no> -> echoes yes|no
function resolve_yesno {
    local flagval="$1" q="$2" def="$3" hint
    if [ -n "$flagval" ]; then echo "$flagval"; return; fi
    [ "$def" = "yes" ] && hint="y" || hint="n"
    if prompt_confirm "$q" "$hint"; then echo "yes"; else echo "no"; fi
}

# ask_time <question> -> echoes a valid HH:MM:SS or empty
function ask_time {
    local q="$1" ans
    while true; do
        ans="$(prompt_value "$q" "")"
        if [ -z "$ans" ] || validate_time "$ans"; then echo "$ans"; return; fi
        echo "[ warn   ] time must be in HH:MM:SS format" >&2
    done
}

# find_cover <audio-stem> -> echoes the matching jpg written by yt-dlp, or ""
# chapter-split files are named "<title> - NNN <chapter>", so fall back to a
# jpg whose stem is a prefix of the audio stem
function find_cover {
    local stem="$1" j js
    if [ -f "$WORKDIR/$stem.jpg" ]; then echo "$WORKDIR/$stem.jpg"; return; fi
    for j in "$WORKDIR"/*.jpg; do
        [ -f "$j" ] || continue
        js="$(basename "$j")"; js="${js%.jpg}"
        case "$stem" in "$js"*) echo "$j"; return ;; esac
    done
    echo ""
}

TARGET_EXT=""
CODEC_ARGS=()

function set_codec_args {
    case "$FORMAT" in
        mp3)
            TARGET_EXT="mp3"
            case "$QUALITY" in
                best)   CODEC_ARGS=(-c:a libmp3lame -q:a 0) ;;
                high)   CODEC_ARGS=(-c:a libmp3lame -q:a 2) ;;
                medium) CODEC_ARGS=(-c:a libmp3lame -q:a 5) ;;
            esac ;;
        m4a|aac)
            [ "$FORMAT" = "m4a" ] && TARGET_EXT="m4a" || TARGET_EXT="aac"
            case "$QUALITY" in
                best)   CODEC_ARGS=(-c:a aac -b:a 256k) ;;
                high)   CODEC_ARGS=(-c:a aac -b:a 192k) ;;
                medium) CODEC_ARGS=(-c:a aac -b:a 128k) ;;
            esac ;;
        opus)
            TARGET_EXT="opus"
            case "$QUALITY" in
                best)   CODEC_ARGS=(-c:a libopus -b:a 192k) ;;
                high)   CODEC_ARGS=(-c:a libopus -b:a 128k) ;;
                medium) CODEC_ARGS=(-c:a libopus -b:a 96k) ;;
            esac ;;
        vorbis)
            TARGET_EXT="ogg"
            case "$QUALITY" in
                best)   CODEC_ARGS=(-c:a libvorbis -q:a 8) ;;
                high)   CODEC_ARGS=(-c:a libvorbis -q:a 6) ;;
                medium) CODEC_ARGS=(-c:a libvorbis -q:a 4) ;;
            esac ;;
        flac) TARGET_EXT="flac"; CODEC_ARGS=(-c:a flac) ;;
        wav)  TARGET_EXT="wav";  CODEC_ARGS=(-c:a pcm_s16le) ;;
        alac) TARGET_EXT="m4a";  CODEC_ARGS=(-c:a alac) ;;
    esac
}

function convert_file {
    local src="$1" base stem out cover args
    base="$(basename "$src")"
    stem="${base%.*}"
    out="$OUTPUT_DIR/$stem.$TARGET_EXT"
    cover=""
    if [ "$PRESERVE" = "yes" ]; then
        # only these containers take an attached picture through ffmpeg
        case "$FORMAT" in mp3|flac|m4a|alac) cover="$(find_cover "$stem")" ;; esac
    fi

    args=(-hide_banner -y)
    # input-side seek: sample-accurate enough for audio, and it keeps the
    # attached-picture stream (an output-side -ss drops its one frame at t=0)
    [ -n "$SLICE_START" ] && args+=(-ss "$SLICE_START")
    [ -n "$SLICE_DURATION" ] && args+=(-t "$SLICE_DURATION")
    args+=(-i "$src")
    [ -n "$cover" ] && args+=(-i "$cover")
    args+=(-map 0:a)
    if [ -n "$cover" ]; then
        args+=(-map 1:0 -c:v copy)
        case "$FORMAT" in
            mp3) args+=(-id3v2_version 3 -metadata:s:v title="Album cover") ;;
            *)   args+=(-disposition:v:0 attached_pic) ;;
        esac
    fi
    [ "$PRESERVE" = "yes" ] && args+=(-map_metadata 0)
    args+=("${CODEC_ARGS[@]}")

    print_info "converting: $base -> $(basename "$out")"
    print_info "running: $(printf '%q ' ffmpeg "${args[@]}" "$out")"
    ffmpeg "${args[@]}" "$out" </dev/null
    PRODUCED="$PRODUCED
$out"
}

function scan_stale_workdirs {
    local d pid
    for d in "$OUTPUT_DIR"/.audio-extract-wiz-*; do
        [ -d "$d" ] || continue
        pid="${d##*-}"
        if echo "$pid" | grep -qE '^[0-9]+$' && kill -0 "$pid" 2>/dev/null; then
            print_warn "workdir belongs to a running session, leaving it alone: $d (pid $pid)"
            continue
        fi
        print_warn "stale workdir from a crashed/killed run: $d"
        if prompt_confirm "remove stale workdir?" "y"; then
            rm -rf "$d"
            print_info "removed: $d"
        fi
    done
}

CLEANUP_DONE="false"
function cleanup {
    [ "$CLEANUP_DONE" = "true" ] && return 0
    CLEANUP_DONE="true"
    if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
        rm -rf "$WORKDIR"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

########
# MAIN #
########

detect_platform

# --- wizard ---------------------------------------------------------------

print_step "Video URL"
if [ -n "$ARG_URL" ]; then
    URL="$ARG_URL"
    print_info "url: $URL"
else
    while true; do
        URL="$(prompt_value "video URL to download audio from" "")"
        if [ -z "$URL" ]; then print_warn "a URL is required"; continue; fi
        if validate_url "$URL"; then break; fi
        print_warn "invalid URL: must start with http:// or https://"
    done
fi

PLAYLIST="single"
case "$URL" in
    *list=*)
        print_step "Playlist scope"
        if [ -n "$ARG_PLAYLIST" ]; then
            PLAYLIST="$ARG_PLAYLIST"
        else
            PLAYLIST="$(prompt_choice "the URL points at a playlist - what should be downloaded?" "single" \
                "single:only the video the URL points at" \
                "all:every entry in the playlist")"
        fi ;;
    *)
        [ -n "$ARG_PLAYLIST" ] && PLAYLIST="$ARG_PLAYLIST" ;;
esac

print_step "Output directory"
DEF_OUTPUT="$(state_get OUTPUT_DIR)"
[ -z "$DEF_OUTPUT" ] && DEF_OUTPUT="$PWD"
OUTPUT_DIR="${ARG_OUTPUT:-$(prompt_value "output directory" "$DEF_OUTPUT")}"
case "$OUTPUT_DIR" in "~/"*) OUTPUT_DIR="$HOME/${OUTPUT_DIR#~/}" ;; "~") OUTPUT_DIR="$HOME" ;; esac
[ -z "$OUTPUT_DIR" ] && usage "-o/--output requires a directory"
OUTPUT_DIR="${OUTPUT_DIR%/}"
[ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="/"
NEED_CREATE_DIR="no"
if [ ! -d "$OUTPUT_DIR" ]; then
    NEED_CREATE_DIR="$(resolve_yesno "$ARG_CREATE_DIR" "output directory $OUTPUT_DIR does not exist - create it?" "yes")"
    [ "$NEED_CREATE_DIR" = "yes" ] || die "output directory does not exist: $OUTPUT_DIR"
fi
print_info "output dir: $OUTPUT_DIR"

print_step "Conversion"
DEF_CONVERT="$(state_get CONVERT)"
[ -z "$DEF_CONVERT" ] && DEF_CONVERT="no"
CONVERT="$(resolve_yesno "$ARG_CONVERT" "convert the downloaded audio to another format with ffmpeg?" "$DEF_CONVERT")"
FORMAT=""; QUALITY=""
if [ "$CONVERT" = "yes" ]; then
    DEF_FORMAT="$(state_get FORMAT)"
    [ -z "$DEF_FORMAT" ] && DEF_FORMAT="mp3"
    FORMAT="${ARG_FORMAT:-$(prompt_choice "target audio format" "$DEF_FORMAT" \
        "mp3:MPEG layer 3 (libmp3lame)" \
        "m4a:AAC in an MP4 container" \
        "aac:raw AAC (ADTS stream; holds no tags)" \
        "opus:Opus (.opus)" \
        "vorbis:Vorbis (.ogg)" \
        "flac:FLAC, lossless" \
        "wav:PCM, lossless (holds no tags)" \
        "alac:Apple Lossless in an MP4 container (.m4a)")}"
    if is_lossy "$FORMAT"; then
        DEF_QUALITY="$(state_get QUALITY)"
        [ -z "$DEF_QUALITY" ] && DEF_QUALITY="best"
        QUALITY="${ARG_QUALITY:-$(prompt_choice "encoding quality" "$DEF_QUALITY" \
            "best:highest quality the codec offers" \
            "high:transparent for most listening" \
            "medium:smaller files, casual listening")}"
    else
        QUALITY="lossless"
        [ -n "$ARG_QUALITY" ] && print_warn "-q/--quality is ignored for lossless format $FORMAT"
    fi
fi

print_step "Chapter split"
DEF_SPLIT="$(state_get SPLIT)"
[ -z "$DEF_SPLIT" ] && DEF_SPLIT="no"
SPLIT="$(resolve_yesno "$ARG_SPLIT" "split the audio into one file per video chapter?" "$DEF_SPLIT")"

SLICE_START=""; SLICE_DURATION=""
if [ "$CONVERT" = "yes" ] && [ "$SPLIT" = "no" ]; then
    print_step "Time slice"
    SLICE_START="${ARG_START:-$(ask_time "slice start time HH:MM:SS (empty = from the beginning)")}"
    SLICE_DURATION="${ARG_DURATION:-$(ask_time "slice duration HH:MM:SS (empty = to the end)")}"
else
    if [ -n "$ARG_START" ] || [ -n "$ARG_DURATION" ]; then
        [ "$SPLIT" = "yes" ] && die "-s/-t (slicing) cannot be combined with --split-chapters yes"
        die "-s/-t (slicing) require conversion (--convert yes)"
    fi
fi

print_step "Thumbnail and metadata"
DEF_EMBED="$(state_get EMBED)"
[ -z "$DEF_EMBED" ] && DEF_EMBED="yes"
EMBED="$(resolve_yesno "$ARG_EMBED" "embed thumbnail (cover art) and metadata into the audio file?" "$DEF_EMBED")"
PRESERVE="no"
if [ "$EMBED" = "yes" ] && [ "$CONVERT" = "yes" ]; then
    case "$FORMAT" in
        wav|aac)
            print_warn "target format $FORMAT cannot hold tags or cover art; metadata will not survive the conversion" ;;
        *)
            DEF_PRESERVE="$(state_get PRESERVE)"
            [ -z "$DEF_PRESERVE" ] && DEF_PRESERVE="yes"
            PRESERVE="$(resolve_yesno "$ARG_PRESERVE" "preserve tags and cover art through the ffmpeg conversion?" "$DEF_PRESERVE")"
            case "$FORMAT" in
                opus|vorbis)
                    [ "$PRESERVE" = "yes" ] && print_warn "ffmpeg cannot attach cover art to $FORMAT; tags are preserved, the cover is not" ;;
            esac ;;
    esac
fi

print_step "SponsorBlock"
DEF_SB="$(state_get SPONSORBLOCK)"
[ -z "$DEF_SB" ] && DEF_SB="no"
SPONSORBLOCK="$(resolve_yesno "$ARG_SPONSORBLOCK" "remove SponsorBlock-marked segments (sponsor spots etc.) from the audio?" "$DEF_SB")"
SB_CATS=""
if [ "$SPONSORBLOCK" = "yes" ]; then
    DEF_SB_CATS="$(state_get SB_CATS)"
    [ -z "$DEF_SB_CATS" ] && DEF_SB_CATS="sponsor"
    SB_CATS="${ARG_SB_CATS:-$(prompt_value "SponsorBlock categories (comma separated: sponsor,selfpromo,intro,outro,music_offtopic,all)" "$DEF_SB_CATS")}"
fi

print_step "Rate limit"
DEF_RATE="$(state_get LIMIT_RATE)"
LIMIT_RATE="${ARG_LIMIT_RATE:-$(prompt_value "download rate limit, e.g. 500K or 2M (empty = unlimited)" "$DEF_RATE")}"
if [ -n "$LIMIT_RATE" ] && ! validate_rate "$LIMIT_RATE"; then
    die "rate limit must look like 4200, 500K or 2M (got: $LIMIT_RATE)"
fi

KEEP_ORIG="no"
if [ "$CONVERT" = "yes" ]; then
    print_step "Source file handling"
    DEF_KEEP="$(state_get KEEP_ORIG)"
    [ -z "$DEF_KEEP" ] && DEF_KEEP="no"
    KEEP_ORIG="$(resolve_yesno "$ARG_KEEP" "keep the original downloaded file next to the converted one?" "$DEF_KEEP")"
fi

# --- plan -------------------------------------------------------------------

echo
echo "==================== PLAN ===================="
echo "  url              : $URL"
echo "  playlist         : $PLAYLIST"
echo "  output dir       : $OUTPUT_DIR$( [ "$NEED_CREATE_DIR" = "yes" ] && echo '  (will be created)' )"
if [ "$CONVERT" = "yes" ]; then
    echo "  convert          : yes -> $FORMAT (quality: $QUALITY)"
else
    echo "  convert          : no (keep the downloaded format)"
fi
echo "  split chapters   : $SPLIT"
if [ "$CONVERT" = "yes" ] && [ "$SPLIT" = "no" ]; then
    echo "  slice            : start=${SLICE_START:-<beginning>} duration=${SLICE_DURATION:-<to the end>}"
fi
echo "  embed thumb/meta : $EMBED$( [ "$PRESERVE" = "yes" ] && echo ' (preserved through conversion)' )"
echo "  sponsorblock     : $SPONSORBLOCK${SB_CATS:+ [$SB_CATS]}"
echo "  rate limit       : ${LIMIT_RATE:-unlimited}"
if [ "$CONVERT" = "yes" ]; then
    echo "  keep original    : $KEEP_ORIG"
fi
echo "=============================================="
echo
prompt_confirm "proceed with this plan?" "y" || die "aborted; nothing was changed"

# --- act ----------------------------------------------------------------

WORKDIR="$OUTPUT_DIR/.audio-extract-wiz-$$"

if [ "$ARG_PRINT_ONLY" = "true" ]; then
    detect_js_runtime
    [ -z "$JS_RUNTIME" ] && JS_RUNTIME="node"
else
    print_step "Dependencies"
    ensure_deps
fi

# thumbnails cannot be embedded into webm audio (many sites' usual bestaudio),
# so when embedding without conversion prefer an m4a stream
FMT_SELECTOR="ba"
if [ "$EMBED" = "yes" ] && [ "$CONVERT" = "no" ]; then
    FMT_SELECTOR="ba[ext=m4a]/ba"
fi

YTDLP_CMD=(yt-dlp "$URL" \
    -f "$FMT_SELECTOR" \
    --ignore-config --no-config-locations \
    --abort-on-error \
    --js-runtimes "$JS_RUNTIME" \
    --output "$WORKDIR/%(title)s.%(ext)s")
case "$PLAYLIST" in
    all) YTDLP_CMD+=(--yes-playlist) ;;
    *)   YTDLP_CMD+=(--no-playlist) ;;
esac
if [ "$SPLIT" = "yes" ]; then
    YTDLP_CMD+=(--split-chapters \
        --output "chapter:$WORKDIR/%(title)s - %(section_number)03d %(section_title)s.%(ext)s")
fi
if [ "$EMBED" = "yes" ]; then
    YTDLP_CMD+=(--embed-metadata)
    # with conversion the cover is attached by our own ffmpeg pass instead
    [ "$CONVERT" = "no" ] && YTDLP_CMD+=(--embed-thumbnail)
fi
[ "$PRESERVE" = "yes" ] && YTDLP_CMD+=(--write-thumbnail --convert-thumbnails jpg)
[ "$SPONSORBLOCK" = "yes" ] && YTDLP_CMD+=(--sponsorblock-remove "$SB_CATS")
[ -n "$LIMIT_RATE" ] && YTDLP_CMD+=(--limit-rate "$LIMIT_RATE")

print_step "Download command"
printf '%q ' "${YTDLP_CMD[@]}"; echo

if [ "$ARG_PRINT_ONLY" = "true" ]; then
    if [ "$CONVERT" = "yes" ]; then
        set_codec_args
        print_info "per-file conversion command (template):"
        echo "ffmpeg -hide_banner -y${SLICE_START:+ -ss $SLICE_START}${SLICE_DURATION:+ -t $SLICE_DURATION} -i '<downloaded-file>'$( [ "$PRESERVE" = "yes" ] && echo " -i '<cover.jpg>'" ) -map 0:a$( [ "$PRESERVE" = "yes" ] && echo " -map_metadata 0" )$(printf ' %q' "${CODEC_ARGS[@]}") '<name>.$TARGET_EXT'"
    fi
    print_info "print-only: nothing was executed"
    exit 0
fi

if [ "$NEED_CREATE_DIR" = "yes" ]; then
    mkdir -p "$OUTPUT_DIR"
    print_info "created output directory: $OUTPUT_DIR"
fi

scan_stale_workdirs

# remember this run's answers as the next run's defaults
state_set OUTPUT_DIR "$OUTPUT_DIR"
state_set CONVERT "$CONVERT"
if [ "$CONVERT" = "yes" ]; then
    state_set FORMAT "$FORMAT"
    is_lossy "$FORMAT" && state_set QUALITY "$QUALITY"
    state_set KEEP_ORIG "$KEEP_ORIG"
fi
state_set SPLIT "$SPLIT"
state_set EMBED "$EMBED"
if [ "$EMBED" = "yes" ] && [ "$CONVERT" = "yes" ]; then state_set PRESERVE "$PRESERVE"; fi
state_set SPONSORBLOCK "$SPONSORBLOCK"
[ -n "$SB_CATS" ] && state_set SB_CATS "$SB_CATS"
state_set LIMIT_RATE "$LIMIT_RATE"

print_step "Downloading"
mkdir -p "$WORKDIR"
"${YTDLP_CMD[@]}" </dev/null

if [ "$CONVERT" = "yes" ]; then
    set_codec_args
    print_step "Converting"
else
    print_step "Collecting files"
fi

FOUND_AUDIO="false"
for f in "$WORKDIR"/*; do
    [ -f "$f" ] || continue
    case "$f" in
        *.jpg|*.jpeg|*.png|*.webp) continue ;;  # thumbnail written for cover art
        *.part|*.ytdl|*.json)      continue ;;  # yt-dlp leftovers
    esac
    FOUND_AUDIO="true"
    if [ "$CONVERT" = "yes" ]; then
        convert_file "$f"
        if [ "$KEEP_ORIG" = "yes" ]; then
            mv -f "$f" "$OUTPUT_DIR/"
            PRODUCED="$PRODUCED
$OUTPUT_DIR/$(basename "$f")"
        fi
    else
        mv -f "$f" "$OUTPUT_DIR/"
        PRODUCED="$PRODUCED
$OUTPUT_DIR/$(basename "$f")"
    fi
done
[ "$FOUND_AUDIO" = "true" ] || die "yt-dlp produced no audio files in $WORKDIR"

print_step "Done"
print_info "produced files:"
echo "$PRODUCED" | sed '/^$/d; s/^/    /'
