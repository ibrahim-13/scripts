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

function app_lf {
    echo "app: lf"
    local DOWNLOAD_DIR="/tmp/lf"
    local DOWNLOAD_FILE="$DOWNLOAD_DIR/lf.tar.gz"
    mkdir -p $DOWNLOAD_DIR

    bash "$SCRIPT_DIR/../util/ghbin-dl.sh" -upd -d "$DOWNLOAD_FILE" -u "gokcehan" -r "lf" -p 'select(.name | contains("lf-linux-amd64.tar.gz"))' -s "$STATE_DIR/lf.gh.state"
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

    bash "$SCRIPT_DIR/../util/ghbin-dl.sh" -upd -d "$DOWNLOAD_FILE" -u "junegunn" -r "fzf" -p 'select(.name | contains("linux_amd64.tar.gz"))' -s "$STATE_DIR/fzf.gh.state"
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

function app_helium_browser_linux {
    echo "app: helium browser (linux)"
    local DOWNLOAD_DIR="/tmp/heliumbrowserlinux"
    local DOWNLOAD_FILE="$DOWNLOAD_DIR/helium-browser-linux.AppImage"
    local INSTALL_FILE="$INSTALL_DIR/helium-browser-linux.AppImage"
    mkdir -p $DOWNLOAD_DIR

    bash "$SCRIPT_DIR/../util/ghbin-dl.sh" -upd -d "$DOWNLOAD_FILE" -u "imputnet" -r "helium-linux" -p 'select(.name | startswith("helium-") and endswith("-arm64.AppImage") and (contains("zsync") | not))' -s "$STATE_DIR/helium-browser-linux.gh.state"
    local GH_EXIT_CODE="$?"
    if ! [ "$GH_EXIT_CODE" == "0" ]; then
        if [ "$GH_EXIT_CODE" == "255" ]; then return; fi
        errexit "github binary downloader failed"
    fi

    chmod 666 "$DOWNLOAD_FILE"
    echo "copying files:"
    cp -f "$DOWNLOAD_FILE" -C "$INSTALL_FILE"
    echo "updating file permissions"
    chmod 755 "$INSTALL_FILE"
    echo "removing temp directory"
    rm -rf "$DOWNLOAD_DIR"

    tee "$DESKTOP_DIR/helium-browser-linux.desktop"> /dev/null <<EOT
[Desktop Entry]
Name=Helium Browser
Comment=Private, fast, and honest web browser
Exec=$INSTALL_FILE %F
Terminal=false
Type=Application
Categories=Browser;Internet;
Keywords=helium-browser;
Actions=NewWindow;NewIncognitoWindow;

[Desktop Action NewWindow]
Name=New Window
Exec=$INSTALL_FILE --new-window %F

[Desktop Action NewIncognitoWindow]
Name=New Incognito Window
Exec=$INSTALL_FILE --incognito %F
EOT
    # Register app to the OS
	update-desktop-database "$DESKTOP_DIR"
}

# run installer functions
app_lf
app_fzf
# app_helium_browser_linux
