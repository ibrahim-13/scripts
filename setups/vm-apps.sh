#!/usr/bin/env bash

# -e exit on error
# -u error on using unset variable
# -x print full command before running
# set -eux
set -eu

function prompt_confirmation {
  if [ "$2" == "true" ]; then
    return 0
  fi
	local TMP_ANS
	read -p "[ prompt ] $(echo -e -n " ${1} (y/N) ")" TMP_ANS
	case $TMP_ANS in
	[Yy])
		return 0
		;;
	*)
		return 1
		;;
	esac
}

ARCH="$(uname -m)"
MACHINE="$(uname -s)"

function print_info {
  echo "[ info   ] $1"
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

# read the state variables from file
# $1: file to read
function read_state {
  set -a
  [ -f "$1" ] && source "$1"
  set +a
}

# set variable in state file
# $1: state file location
# $2: variable name
# $3: value
function set_state {
	if [ -f "$1" ]; then
		cat "$1" | grep -v "$2=" > "$1"
		echo "$2=$3" > "$1"
	else
		print_error "state file not found"
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

########
# MAIN #
########

function usage() {
    if [ -n "$1" ]; then
        echo -e "[ error ] $1\n";
    fi
    echo "setup vm apps for dev"
    echo ""
    echo "Usage: $(basename "$0") [-y] [-h|--help]"
    echo ""
    echo "  -y          confirm everything as yes"
    echo " -h|--help    show help"
    echo ""
    exit 1
}

ARG_CONFIRM="false"

APPS_DIR="$HOME/apps"
mkdir -p "$APPS_DIR"

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -y) ARG_CONFIRM="true"; shift; shift;;
    -h|--help) usage;;
    *) usage "invalid arguments";;
esac; done

print_info "setting up directories and configs"
mkdir -p "$HOME/.bashrc.d"
tee "$HOME/.bashrc.d/apps.sh" > /dev/null <<EOT
export PATH="\$PATH:$APPS_DIR"
EOT

if prompt_confirmation "update packages?" $ARG_CONFIRM; then
    print_info "updating packages"
    sudo dnf update -y
fi

if prompt_confirmation "install yt-dlp?" $ARG_CONFIRM; then
    YTLDP_TAG=$(func_gh_version "yt-dlp" "yt-dlp")
    if ! [ -f "$APPS_DIR/ytdlp.tag" ] || ! [ "$YTLDP_TAG" == "$(cat "$APPS_DIR/ytdlp.tag")" ]; then
        print_info "installing golang"
      wget -q --show-progress -O "$APPS_DIR/yt-dlp" "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"
      chmod 755 "$APPS_DIR/yt-dlp"
        echo "$YTLDP_TAG" > "$APPS_DIR/ytdlp.tag"
    fi
fi

if prompt_confirmation "install golang?" $ARG_CONFIRM; then
    GOLANG_FILE_PATTERN="go.*.$(get_machine1)-$(get_arch1).tar.gz"
    GOLANG_FILENAME=$(wget -qO- "https://go.dev/dl/?mode=json" | grep -o "$GOLANG_FILE_PATTERN" | head -n 1 | tr -d '\r\n' )
    print_info "golang file name: $GOLANG_FILENAME"
    GOLANG_URL="https://go.dev/dl/$GOLANG_FILENAME"
    if ! [ -f "$APPS_DIR/golang.tag" ] || ! [ "$GOLANG_FILENAME" == "$(cat "$APPS_DIR/golang.tag")" ]; then
        wget -q --show-progress -O "$APPS_DIR/$GOLANG_FILENAME" "$GOLANG_URL"
        if [ -d /usr/local/go ]; then
            sudo rm -rf /usr/local/go
        fi
        sudo tar -C /usr/local -xzf "$APPS_DIR/$GOLANG_FILENAME"
        rm "$APPS_DIR/$GOLANG_FILENAME"
        print_info "adding path entry in .bashrc.d"
        tee "$HOME/.bashrc.d/golang.sh" > /dev/null <<EOT
export PATH="\$PATH:/usr/local/go/bin"
EOT
    fi
fi

if prompt_confirmation "install node version manager?" $ARG_CONFIRM; then
    print_info "installing node versiom manager"
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
    set +eu
    source $HOME/.bashrc
    nvm install --lts
    nvm use --lts
    set -eu
fi

if prompt_confirmation "install claude cli?" $ARG_CONFIRM; then
    print_info "installing claude cli"
    wget -qO- https://claude.ai/install.sh | bash
fi
