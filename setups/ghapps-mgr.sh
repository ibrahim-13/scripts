#!/usr/bin/env bash

# -e exit on error
# -u error on using unset variable
# -x print full command before running
# set -eux
set -eu

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

# cleanup temp directory
if [ -d "$DIR_TMP" ]; then
    rm -rf "$DIR_TMP"
fi
mkdir -p $DIR_TMP

SCRIPT_SOURCE=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )
  SCRIPT_SOURCE=$(readlink "$SCRIPT_SOURCE")
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE=$SCRIPT_DIR/$SCRIPT_SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )

INSTALL_DIR="$HOME/apps"
STATE_DIR="$INSTALL_DIR/state"
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$INSTALL_DIR"
mkdir -p "$STATE_DIR"
mkdir -p "$DESKTOP_DIR"

ARCH="$(uname -m)"
MACHINE="$(uname -s)"

function print_info {
  echo "[ info   ] $1"
}

function print_warn {
  echo "[ warn   ] $1"
}

function print_error {
  echo "[ error  ] $1"
}

function get_machine1 {
	case "${MACHINE}" in
		Linux*) echo linux ;;
		Darwin*) echo darwin ;;
		CYGWIN*) echo cygwin ;;
		MINGW*) echo mingw ;;
		*) $MACHINE ;;
	esac
}

function get_machine2 {
	case "${MACHINE}" in
		Linux*) echo linux ;;
		Darwin*) echo osx ;;
		CYGWIN*) echo cygwin ;;
		MINGW*) echo mingw ;;
		*) $MACHINE ;;
	esac
}

function get_arch1 {
	case $ARCH in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) echo $ARCH ;;
	esac
}

function get_arch2 {
	case $ARCH in
    x86_64|amd64) echo x86_64 ;;
    aarch64|arm64) echo aarch64 ;;
    *) echo $ARCH ;;
	esac
}

function get_arch3 {
	case $ARCH in
    x86_64|amd64) echo x86_64 ;;
    aarch64|arm64) echo arm64 ;;
    *) echo $ARCH ;;
	esac
}

# find if line exists in the file
# $1: text to find
# $2: file to search
function line_exists {
  if grep -qFx "$1" "$2"; then
    return 0
  else
    return 1
  fi
}

# get lastest release asset url from github with http api
# $1 : github username
# $2 : github repo
function func_gh_version {
	local GH_URL
	local HEADER_ACCEPT
	local HEADER_VERSION
	local GH_RESPONSE
	GH_URL="https://api.github.com/repos/$1/$2/releases/latest"
	HEADER_ACCEPT="Accept: application/vnd.github+json"
	HEADER_VERSION="X-GitHub-Api-Version: 2022-11-28"
	if command -v wget &> /dev/null
	then
		GH_RESPONSE="$(wget --header="$HEADER_ACCEPT" --header="$HEADER_VERSION" -qO- "$GH_URL" | awk '/tag_name/{print $4;exit}' FS='[""]')"
	elif command -v curl &> /dev/null
	then
		GH_RESPONSE="$(curl -H "$HEADER_ACCEPT" -H "$HEADER_VERSION" -s -O "$GH_URL" | awk '/tag_name/{print $4;exit}' FS='[""]')"
	else
		exit 1
	fi
	echo "$GH_RESPONSE"
}

function app_lf {
    print_info "app: lf"
    local DOWNLOAD_FILE="$DIR_TMP/lf.tar.gz"
    local LF_STATE_FILE="$STATE_DIR/lf.gh.state"
    local LF_TAG=$(func_gh_version "gokcehan" "lf")

    if [ -f "$LF_STATE_FILE" ] && [ "$LF_TAG" == "$(cat "$LF_STATE_FILE")" ]; then
        print_info "lf already up to date"
        return
    fi

    print_info "downloading lf archive"
    wget -q --show-progress --progress=bar:force:noscroll -O "$DOWNLOAD_FILE" "https://github.com/gokcehan/lf/releases/download/$LF_TAG/lf-$(get_machine1)-$(get_arch1).tar.gz" 2>&1

    chmod 666 "$DOWNLOAD_FILE"
    print_info "extracting files:"
    tar -xvzf "$DOWNLOAD_FILE" -C "$INSTALL_DIR"
    print_info "updating file permissions"
    chmod 755 "$INSTALL_DIR/lf"
    print_info "removing downloaded archive"
    rm -f "$DOWNLOAD_FILE"

    echo "$LF_TAG" > "$LF_STATE_FILE"
}

function app_fzf {
    print_info "app: fzf"
    local DOWNLOAD_FILE="$DIR_TMP/fzf.tar.gz"
    local FZF_STATE_FILE="$STATE_DIR/fzf.gh.state"
    local FZF_TAG=$(func_gh_version "junegunn" "fzf")

    if [ -f "$FZF_STATE_FILE" ] && [ "$FZF_TAG" == "$(cat "$FZF_STATE_FILE")" ]; then
        print_info "fzf already up to date"
        return
    fi

    print_info "downloading fzf archive"
    wget -q --show-progress --progress=bar:force:noscroll -O "$DOWNLOAD_FILE" "https://github.com/junegunn/fzf/releases/download/$FZF_TAG/fzf-${FZF_TAG#?}-$(get_machine1)_$(get_arch1).tar.gz" 2>&1

    chmod 666 "$DOWNLOAD_FILE"
    print_info "extracting files:"
    tar -xvzf "$DOWNLOAD_FILE" -C "$INSTALL_DIR"
    print_info "updating file permissions"
    chmod 755 "$INSTALL_DIR/fzf"
    print_info "removing downloaded archive"
    rm -f "$DOWNLOAD_FILE"

    echo "$FZF_TAG" > "$FZF_STATE_FILE"
}

function app_helium_browser_linux {
    print_info "app: helium browser (linux)"
    local DOWNLOAD_FILE="$DIR_TMP/helium-browser.AppImage"
    local INSTALL_FILE="$INSTALL_DIR/helium-browser-linux.AppImage"
    local HELIUMBROWSER_STATE_FILE="$STATE_DIR/helium-browser.gh.state"
    local HELIUMBROWSER_TAG=$(func_gh_version "imputnet" "helium-linux")

    if [ -f "$HELIUMBROWSER_STATE_FILE" ] && [ "$HELIUMBROWSER_TAG" == "$(cat "$HELIUMBROWSER_STATE_FILE")" ]; then
        print_info "helium browser already up to date"
        return
    fi

    print_info "downloading helium browser appimage"
    wget -q --show-progress --progress=bar:force:noscroll -O "$DOWNLOAD_FILE" "https://github.com/imputnet/helium-linux/releases/download/$HELIUMBROWSER_TAG/helium-$HELIUMBROWSER_TAG-$(get_arch3).AppImage" 2>&1

    chmod 666 "$DOWNLOAD_FILE"
    print_info "copying files:"
    cp -f "$DOWNLOAD_FILE" "$INSTALL_FILE"
    print_info "updating file permissions"
    chmod 755 "$INSTALL_FILE"
    tee "$DESKTOP_DIR/helium-browser-linux.desktop"> /dev/null <<EOT
[Desktop Entry]
Name=Helium Browser
Comment=Private, fast, and honest web browser
Exec=$INSTALL_FILE %F
Terminal=false
Type=Application
Categories=Internet;
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
    print_info "removing downloaded appimage"
    rm -f "$DOWNLOAD_FILE"

    echo "$HELIUMBROWSER_TAG" > "$HELIUMBROWSER_STATE_FILE"
}

function app_rclone {
    print_info "app: rclone"
    local DOWNLOAD_DIR="$DIR_TMP/rclone"
    local DOWNLOAD_FILE="$DOWNLOAD_DIR/rclone.zip"
    local INSTALL_FILE_NEW="/usr/bin/rclone.new"
    local INSTALL_FILE="/usr/bin/rclone"
    local RCLONE_STATE_FILE="$STATE_DIR/rclone.gh.state"
    local RCLONE_TAG=$(func_gh_version "rclone" "rclone")
    mkdir -p $DOWNLOAD_DIR

    if [ -f "$RCLONE_STATE_FILE" ] && [ "$RCLONE_TAG" == "$(cat "$RCLONE_STATE_FILE")" ]; then
        print_info "rclone already up to date"
        return
    fi

    print_info "downloading rclone archive"
    wget -q --show-progress --progress=bar:force:noscroll -O "$DOWNLOAD_FILE" "https://github.com/rclone/rclone/releases/download/$RCLONE_TAG/rclone-$RCLONE_TAG-$(get_machine2)-$(get_arch1).zip" 2>&1

    chmod 666 "$DOWNLOAD_FILE"
    print_info "extracting files:"
    unzip -a "$DOWNLOAD_FILE" -d "$DOWNLOAD_DIR"
    print_info "copying binary"
    local EXTRACT_DIR=$(find "$DOWNLOAD_DIR" -maxdepth 1 -type d | grep --color=never -P '.+/rclone/rclone-.+-linux-amd64$')
    sudo cp -f "$EXTRACT_DIR/rclone" "$INSTALL_FILE_NEW"
    print_info "updating file ownership"
    sudo chown root:root "$INSTALL_FILE_NEW"
    print_info "updating file permissions"
    sudo chmod 755 "$INSTALL_FILE_NEW"
    print_info "replacing with existing binary"
    sudo mv "$INSTALL_FILE_NEW" "$INSTALL_FILE"
    if ! [ -x "$(command -v mandb)" ]; then
        print_warn "mandb not found, rclone man docs will not be installed"
    else
        print_info "updating mandb for rclone"
        sudo mkdir -p /usr/local/share/man/man1
        sudo cp -f "$EXTRACT_DIR/rclone.1" /usr/local/share/man/man1/rclone.1
        sudo mandb
    fi
    cd ..
    print_info "removing temp directory"
    rm -rf "$DOWNLOAD_DIR"

    echo "$RCLONE_TAG" > "$RCLONE_STATE_FILE"
}

########
# MAIN #
########

function usage() {
    if [ -n "$1" ]; then
        print_error "$1";
        echo ""
    fi
    echo "usage: apps setup for installing from github releases"
    echo ""
    echo "Usage: $(basename "$0") [--lf] [--fzf] [--helium] [--rclone] [-u|--update]"
    echo ""
    echo "  --lf             lf terminal file explorer"
    echo "  --fzf            fzf fuzzy finder"
    echo "  --helium         helium browser"
    echo "  --rclone         rclone cloud storage sync"
    echo "  -u|--update      update all from existing state file"
    echo ""
    exit 1
}

if [ $# -eq 0 ]; then
    usage  "no arguments provided."
fi

ARG_LF=0
ARG_FZF=0
ARG_HELIUM=0
ARG_RCLONE=0
ARG_UPDATE=0

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    --lf) ARG_LF=1; shift;;
    --fzf) ARG_FZF=1; shift;;
    --helium) ARG_HELIUM=1; shift;;
    --rclone) ARG_RCLONE=1; shift;;
    -u|--update) ARG_UPDATE=1; shift;;
    *) usage "invalid arguments";;
esac; done

if [[ "$ARG_UPDATE" == "1" ]]; then
    if [[ -f "$STATE_DIR/lf.gh.state" ]]; then ARG_LF=1; else print_warn "lf not installed, skipping"; fi
    if [[ -f "$STATE_DIR/fzf.gh.state" ]]; then ARG_FZF=1; else print_warn "fzf not installed, skipping"; fi
    if [[ -f "$STATE_DIR/helium-browser.gh.state" ]]; then ARG_HELIUM=1; else print_warn "helium browser not installed, skipping"; fi
    if [[ -f "$STATE_DIR/rclone.gh.state" ]]; then ARG_RCLONE=1; else print_warn "rclone not installed, skipping"; fi
fi

if [[ "$ARG_LF" == "1" ]]; then app_lf; fi
if [[ "$ARG_FZF" == "1" ]]; then app_fzf; fi
if [[ "$ARG_HELIUM" == "1" ]]; then app_helium_browser_linux; fi
if [[ "$ARG_RCLONE" == "1" ]]; then app_rclone; fi
