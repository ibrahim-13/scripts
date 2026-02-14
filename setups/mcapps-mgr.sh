#!/usr/bin/env bash

if [ "$EUID" -eq 0 ]; then echo "do not run under root"; exit 1; fi

# Debugging
# ---------
# set -x : print out every line as it executes, with variables expanded
#		putting it at top of the script will enable this for the whole
#		script, or before a block of commands and end it with:
#		{ set +x; } 2>/dev/null
#
# bash -x script.sh : same as putting set -x at the top of script
# trap read DEBUG : stop before every line, can be put at the top
# trap '(read -p "[$BASE_SOURCE:$lineno] $bash_command")' DEBUGDIR_TMP="$HOME/.tmp"

DIR_TMP="$HOME/.tmp"

function cleanup {
	if [ -d "$DIR_TMP" ]; then
		rm -rf "$DIR_TMP"
	fi
	mkdir -p $DIR_TMP
}
# cleanup when exiting
trap cleanup EXIT
# cleanup at startup
cleanup

SCRIPT_SOURCE=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )
  SCRIPT_SOURCE=$(readlink "$SCRIPT_SOURCE")
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE=$SCRIPT_DIR/$SCRIPT_SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )

source "$SCRIPT_DIR/../util/common.sh"

INSTALL_DIR="$HOME/apps"
STATE_DIR="$INSTALL_DIR/state"
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$INSTALL_DIR"
mkdir -p "$STATE_DIR"
mkdir -p "$DESKTOP_DIR"

function app_lulu {
    print_info "app: LuLu"
    local DOWNLOAD_DIR="$DIR_TMP/lulu"
    local DOWNLOAD_FILE="$DOWNLOAD_DIR/LuLu.dmg"
    mkdir -p $DOWNLOAD_DIR

    bash "$SCRIPT_DIR/../util/ghbin-dl.sh" -upd -d "$DOWNLOAD_FILE" -u "objective-see" -r "LuLu" -p 'select(.name | startswith("LuLu_") and endswith(".dmg"))' -s "$STATE_DIR/lulu.gh.state"
    local GH_EXIT_CODE="$?"
    if ! [ "$GH_EXIT_CODE" == "0" ]; then
        if [ "$GH_EXIT_CODE" == "255" ]; then return; fi
        errexit "github binary downloader failed"
    fi

    echo "installing"
    bash "$SCRIPT_DIR/../util/dmg-install.sh" -f "$DOWNLOAD_FILE"

    echo "removing temp directory"
    rm -rf "$DOWNLOAD_DIR"
}

########
# MAIN #
########

function usage() {
    if [ -n "$1" ]; then
        echo -e "[ error ] $1\n";
    fi
    echo "apps setup for mcos"
    echo ""
    echo "Usage: $(basename "$0") [--lulu] [-u|--update]"
    echo ""
    echo "  --lulu             LuLu Network Firewall"
    echo "  -u|--update      update all from existing state file"
    echo ""
    exit 1
}

if [ $# -eq 0 ]; then
    usage  "no arguments provided."
fi

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    --lulu) ARG_LULU=1; shift;;
    -u|--update) ARG_UPDATE=1; shift;;
    *) usage "invalid arguments";;
esac; done

if [[ "$ARG_UPDATE" == "1" ]]; then
    if [[ -f "$STATE_DIR/lulu.gh.state" ]]; then ARG_LULU=1; else print_debug "LuLu not installed, skipping"; fi
fi

if [[ "$ARG_LULU" == "1" ]]; then app_lulu; fi
