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
    echo "  -f, --file        file path of the dmg file"
    echo ""
    exit 1
}

if [ $# -eq 0 ]; then
    usage  "no arguments provided."
fi

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -u|--url) ARG_URL="$2"; shift; shift;;
    -f|--file) ARG_FILE="$2"; shift; shift;;
    *) usage "invalid arguments";;
esac; done

if [ -z "$ARG_URL" ] && [ -z "$ARG_FILE" ]; then usage "url or file path is required"; fi;

if ! [ -z "$ARG_FILE" ]
then
  DOWNLOAD_PATH="$ARG_FILE"
else
  TMP_DIR=$(mktemp -d)
  DOWNLOAD_PATH="$TMP_DIR/pkg.dmg"
  wget -q --show-progress -O "$DOWNLOAD_PATH" "$ARG_URL" || errexit "error downloading file from url"
fi

cleanup() {
  if [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

LISTING=$(hdiutil attach "$DOWNLOAD_PATH" -nobrowse | grep Volumes)
VOLUME=$(echo "$LISTING" | cut -f 3)
if [ -e "$VOLUME"/*.app ]; then
  sudo cp -rf "$VOLUME"/*.app /Applications
elif [ -e "$VOLUME"/*.pkg ]; then
  PACKAGE=$(ls -1 "$VOLUME" | grep .pkg | head -1)
  sudo installer -pkg "$VOLUME"/"$PACKAGE" -target /
fi
hdiutil detach "$VOLUME"
cleanup