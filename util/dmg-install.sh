#!/usr/bin/env bash

# print error msg and exit
# $1 : error msg
function errexit {
	echo "[ error ] $1" >&2
	exit 1
}

########
# MAIN #
########

function usage() {
    if [ -n "$1" ]; then
        echo -e "[ error ] $1\n";
    fi
    echo "Utility to install DMG files in OSX"
    echo ""
    echo "Usage: $(basename "$0") [-u|--url] URL"
    echo ""
    echo "  -u, --url         url of the dmg file"
    echo ""
    exit 1
}

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -u|--url) ARG_URL="$2"; shift; shift;;
    *) usage "invalid arguments";;
esac; done

if [ -z "$ARG_URL" ]; then usage "url is required"; fi;

TMP_DIR=$(mktemp -d)
DOWNLOAD_PATH="$TMP_DIR/pkg.dmg"

cleanup() {
  if [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

wget -q --show-progress -O "$DOWNLOAD_PATH" "$ARG_URL" || errexit "error downloading file from url"
LISTING=$(hdiutil attach "$TMP_DIR"/pkg.dmg -nobrowse | grep Volumes)
VOLUME=$(echo "$LISTING" | cut -f 3)
if [ -e "$VOLUME"/*.app ]; then
  cp -rf "$VOLUME"/*.app /Applications
elif [ -e "$VOLUME"/*.pkg ]; then
  PACKAGE=$(ls -1 "$VOLUME" | grep .pkg | head -1)
  installer -pkg "$VOLUME"/"$PACKAGE" -target /
fi
hdiutil detach "$VOLUME"
rm -rf "$TMP_DIR"