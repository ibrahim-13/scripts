#!/usr/bin/env bash

# Debugging
# ---------
# set -x : print out every line as it executes, with variables expanded
#		putting it at top of the script will enable this for the whole
#		script, or before a block of commands and end it with:
#		{ set +x; } 2>/dev/null
#
# bash -x script.sh : same as putting set -x at the top of script
# trap read DEBUG : stop before every line, can be put at the top
# trap '(read -p "[$BASE_SOURCE:$lineno] $bash_command")' DEBUG

# print error msg and exit
# $1 : error msg
function errexit {
	echo "[ error ] $1" >&2
	exit 1
}

INSTALL_DIR="$HOME/apps"
STATE_DIR="$INSTALL_DIR/state"
mkdir -p $INSTALL_DIR
mkdir -p $STATE_DIR

function app_lf {
    echo "app: lf"
    local DOWNLOAD_DIR="/tmp/lf"
    local DOWNLOAD_FILE="$DOWNLOAD_DIR/lf.tar.gz"
    mkdir -p $DOWNLOAD_DIR

    bash ./ghbin-dl.sh -upd -d "$DOWNLOAD_FILE" -u "gokcehan" -r "lf" -p 'select(.name | contains("lf-linux-amd64.tar.gz"))' -s "$STATE_DIR/lf.gh.state"
    local GH_EXIT_CODE="$?"
    if ! [ "$GH_EXIT_CODE" == "0" ]; then
        if [ "$GH_EXIT_CODE" == "255" ]; then return; fi
        errexit "github binary downloader failed"
    fi

    chmod 666 "$DOWNLOAD_FILE"
    echo "extracting files:"
    tar -xvzf "$DOWNLOAD_FILE" -C "$INSTALL_DIR"
    echo "updating file permissions"
    chmod 755 "$INSTALL_DIR/lf"
    echo "removing temp directory"
    rm -rf "$DOWNLOAD_DIR"
}

function app_fzf {
    echo "app: fzf"
    local DOWNLOAD_DIR="/tmp/fzf"
    local DOWNLOAD_FILE="$DOWNLOAD_DIR/fzf.tar.gz"
    mkdir -p $DOWNLOAD_DIR

    bash ./ghbin-dl.sh -upd -d "$DOWNLOAD_FILE" -u "junegunn" -r "fzf" -p 'select(.name | contains("linux_amd64.tar.gz"))' -s "$STATE_DIR/fzf.gh.state"
    local GH_EXIT_CODE="$?"
    if ! [ "$GH_EXIT_CODE" == "0" ]; then
        if [ "$GH_EXIT_CODE" == "255" ]; then return; fi
        errexit "github binary downloader failed"
    fi

    chmod 666 "$DOWNLOAD_FILE"
    echo "extracting files:"
    tar -xvzf "$DOWNLOAD_FILE" -C "$INSTALL_DIR"
    echo "updating file permissions"
    chmod 755 "$INSTALL_DIR/fzf"
    echo "removing temp directory"
    rm -rf "$DOWNLOAD_DIR"
}

# run installer functions
app_lf
app_fzf
