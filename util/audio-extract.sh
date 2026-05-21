#!/usr/bin/env bash

# -e exit on error
# -u error on using unset variable
set -eu

function print_info {
  echo "[ info   ] $1"
}

function print_warn {
  echo "[ warn   ] $1"
}

function print_err {
  echo "[ error  ] $1"
}

########
# MAIN #
########

function usage() {
    if [ -n "${1:-}" ]; then
        echo -e "[ error ] ${1}\n"
    fi
    echo "download audio from YouTube and optionally convert to MP3"
    echo ""
    echo "Usage: $(basename "$0") -u <url> -o <dir> [-c] [-s HH:MM:SS] [-t HH:MM:SS] [-h|--help]"
    echo ""
    echo "  -u <url>        YouTube URL to download audio from (required)"
    echo "  -o <dir>        output directory path, must already exist (required)"
    echo "  -c              convert downloaded audio to MP3"
    echo "  -s <HH:MM:SS>   start time for audio slice (only applies with -c)"
    echo "  -t <HH:MM:SS>   total duration to extract (only applies with -c)"
    echo "  -h|--help       show help"
    echo ""
    exit 1
}

ARG_URL=""
ARG_OUTPUT=""
ARG_CONVERT="false"
ARG_START=""
ARG_TOTAL=""

# parse params
while [[ "$#" > 0 ]]; do case $1 in
    -u) ARG_URL="$2"; shift; shift;;
    -o) ARG_OUTPUT="$2"; shift; shift;;
    -c) ARG_CONVERT="true"; shift;;
    -s) ARG_START="$2"; shift; shift;;
    -t) ARG_TOTAL="$2"; shift; shift;;
    -h|--help) usage;;
    *) usage "invalid argument: $1";;
esac; done

# validate required args
if [ -z "$ARG_URL" ]; then usage "-u (URL) is required"; fi
if [ -z "$ARG_OUTPUT" ]; then usage "-o (output directory) is required"; fi

# validate URL format using grep regex
if ! echo "$ARG_URL" | grep -qE '^https?://[^[:space:]]+'; then
    usage "invalid URL: must start with http:// or https://"
fi

# validate output directory exists
if [ ! -d "$ARG_OUTPUT" ]; then
    print_err "output directory does not exist or is not a directory: $ARG_OUTPUT"
    exit 1
fi

# validate HH:MM:SS time format using grep regex
if [ -n "$ARG_START" ]; then
    if ! echo "$ARG_START" | grep -qE '^[0-9]{2}:[0-9]{2}:[0-9]{2}$'; then
        usage "-s start time must be in HH:MM:SS format"
    fi
fi
if [ -n "$ARG_TOTAL" ]; then
    if ! echo "$ARG_TOTAL" | grep -qE '^[0-9]{2}:[0-9]{2}:[0-9]{2}$'; then
        usage "-t total duration must be in HH:MM:SS format"
    fi
fi

# warn if time flags are set without -c
if [ -n "$ARG_START" ] && [ "$ARG_CONVERT" == "false" ]; then
    print_warn "-s (start time) has no effect without -c (convert)"
fi
if [ -n "$ARG_TOTAL" ] && [ "$ARG_CONVERT" == "false" ]; then
    print_warn "-t (total duration) has no effect without -c (convert)"
fi

# check required binaries
for BIN in yt-dlp ffmpeg; do
    if ! command -v "$BIN" &>/dev/null; then
        print_err "required binary not found on PATH: $BIN"
        exit 1
    fi
done

# check js runtime
if command -v node &>/dev/null; then
    JS_RUNTIME=node
elif command -v bun &>/dev/null; then
    JS_RUNTIME=bun
else
    print_err "js runtime not found"
    exit 1
fi

# download audio with yt-dlp
print_info "downloading audio from: $ARG_URL"

YTDLP_JSON=$(yt-dlp \
    "$ARG_URL" \
    -f ba \
    --dump-json \
    --output "$ARG_OUTPUT%(title)s.%(ext)s" \
    --ignore-config \
    --no-config-locations \
    --abort-on-error \
    --no-simulate \
    --no-progress \
    --js-runtimes $JS_RUNTIME)

# validate yt-dlp returned JSON
if ! echo "$YTDLP_JSON" | grep -q '^{'; then
    print_err "yt-dlp did not return valid JSON output"
    exit 1
fi

# extract _filename field from JSON
DOWNLOADED_FILE=$(echo "$YTDLP_JSON" | awk '/_filename/{print $4;exit}' FS='[""]')

# if _filename is not absolute, prepend output dir
if ! echo "$DOWNLOADED_FILE" | grep -q '^/'; then
    DOWNLOADED_FILE="$ARG_OUTPUT/$DOWNLOADED_FILE"
fi

if [ ! -f "$DOWNLOADED_FILE" ]; then
    print_err "downloaded file not found: $DOWNLOADED_FILE"
    exit 1
fi

print_info "downloaded: $DOWNLOADED_FILE"

# convert to MP3 if -c flag is set
if [ "$ARG_CONVERT" == "true" ]; then
    BASENAME=$(basename "$DOWNLOADED_FILE")
    STEM="${BASENAME%.*}"
    MP3_FILE="$ARG_OUTPUT/${STEM}.mp3"

    print_info "converting to MP3: $MP3_FILE"

    if [ -n "$ARG_START" ] && [ -n "$ARG_TOTAL" ]; then
        ffmpeg -i "$DOWNLOADED_FILE" -ss "$ARG_START" -t "$ARG_TOTAL" -q:a 0 -map a "$MP3_FILE" -y -progress -
    elif [ -n "$ARG_START" ]; then
        ffmpeg -i "$DOWNLOADED_FILE" -ss "$ARG_START" -q:a 0 -map a "$MP3_FILE" -y -progress -
    elif [ -n "$ARG_TOTAL" ]; then
        ffmpeg -i "$DOWNLOADED_FILE" -t "$ARG_TOTAL" -q:a 0 -map a "$MP3_FILE" -y -progress -
    else
        ffmpeg -i "$DOWNLOADED_FILE" -q:a 0 -map a "$MP3_FILE" -y -progress -
    fi

    print_info "conversion complete: $MP3_FILE"

    rm "$DOWNLOADED_FILE"
    print_info "removed original file: $DOWNLOADED_FILE"
fi

print_info "done"
