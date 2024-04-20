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

# global variables
REGISTERED_APPS=""
DIR_BASH_CONFIG="$HOME/.bashrc_custom"
DIR_APPS="$HOME/.apps"
DIR_APPS_BIN="$HOME/.bin"
FILE_BASHRC="$HOME/.bashrc"
HAS_RUN_SYSTEM_PACKAGE_LIST_UPDATE="f"
NEOVIM_IS_MINIMAL_CONFIG="n"

# color variables
TXT_RESET="\033[0m"
TXT_COL_BLACK="\033[30m"
TXT_COL_RED="\033[31m"
TXT_COL_GREEN="\033[32m"
TXT_COL_YELLOW="\033[33m"
TXT_COL_BLUE="\033[34m"
TXT_COL_MAGENTA="\033[35m"
TXT_COL_CYAN="\033[36m"
TXT_COL_WHITE="\033[37m"
TXT_COL_BH_BLACK="\033[40m"
TXT_COL_BG_RED="\033[41m"
TXT_COL_BG_GREEN="\033[42m"
TXT_COL_BG_YELLOW="\033[43m"
TXT_COL_BG_BLUE="\033[44m"
TXT_COL_BG_MAGENTA="\033[45m"
TXT_COL_BG_CYAN="\033[46m"
TXT_COL_BG_WHITE="\033[47m"
TXT_COL_BOLD="\e[1m"
TXT_COL_DIM="\e[2m"

# print message with color
# $1 : msg

function print_header {
	printf "${TXT_COL_YELLOW} ${1} ${TXT_RESET}\n"
}

function print_info {
	printf "${TXT_COL_CYAN} ${1} ${TXT_RESET}\n"
}

function print_success {
	printf "${TXT_COL_GREEN} ${1} ${TXT_RESET}\n"
}

function print_danger {
	printf "${TXT_COL_BG_RED} ${1} ${TXT_RESET}\n"
}

##########################
# how registration works #
#------------------------#
# 1. add a command by running `register_app APP_NAME`
# 2. app name should not contain spaces, special characters
# 3. each app must have the following function implementation-
# 	- APP_NAME_is_installed : returns 0 if installed, otherwise 1
# 	- APP_NAME_install : installs the app
# 	- APP_NAME_update : updates the app
# 	- APP_NAME_remove : removes/uninstall the app
# 	- APP_NAME_config : add/resets configuration
# 	- APP_NAME_config_remove : removes configuration
##########################
# $1 : name_of_the_app
function register_app {
	if [[ "$REGISTERED_APPS" == "" ]]
	then
		REGISTERED_APPS="$1"
	else
		REGISTERED_APPS="$REGISTERED_APPS:$1"
	fi
}

register_app tmux
register_app lf
register_app fzf
register_app hugo
register_app lazygit
register_app marktext
register_app golang
register_app neovim
register_app nvm
register_app distrobox

#############################
# start : utility functions #
#############################

# gitHub functions

function func_check_jq_installed {
	if ! commad -v jq
	then
		echo "jq is required, installing"
		package_install jq || errexit "can not install binaries from github without jq"
	fi
}

# get lastest release asset url from github with http api
# $1 : github username
# $2 : github repo
# $3 : jq selector for asset name
function func_gh_http {
	func_check_jq_installed
	local GH_URL
	local HEADER_ACCEPT
	local HEADER_VERSION
	local JSON_QUERY
	local GH_RESPONSE
	GH_URL="https://api.github.com/repos/$1/$2/releases/latest"
	HEADER_ACCEPT="Accept: application/vnd.github+json"
	HEADER_VERSION="X-GitHub-Api-Version: 2022-11-28"
	JSON_QUERY="{\
		\"created_at\":.created_at,\
		\"download_url\":.assets[] | $3 | .browser_download_url,\
		\"source\":\"http\",\
		\"msg\":\"$4\"\
	}"
	GH_RESPONSE="$(wget --header="$HEADER_ACCEPT" \
		--header="$HEADER_VERSION" \
		-qO- "$GH_URL" | \
		jq "$JSON_QUERY")"
	echo "$GH_RESPONSE"
	}

	# get lastest release asset url from github with gh cli
	# $1 : github username
	# $2 : github repo
	# $3 : jq selector for asset name
	function func_gh_cli {
	func_check_jq_installed
	local GH_URL
	local HEADER_ACCEPT
	local HEADER_VERSION
	local JSON_QUERY
	local GH_RESPONSE
	GH_URL="/repos/$1/$2/releases/latest"
	HEADER_ACCEPT="Accept: application/vnd.github+json"
	HEADER_VERSION="X-GitHub-Api-Version: 2022-11-28"
	JSON_QUERY="{\
		\"created_at\":.created_at,\
		\"download_url\":.assets[] | $3 | .browser_download_url,\
		\"source\":\"ghcli\",\
		\"msg\":\"$4\"\
	}"
	GH_RESPONSE="$(gh api -H "$HEADER_ACCEPT" \
		-H "$HEADER_VERSION" \
		"$GH_URL" | \
		jq "$JSON_QUERY")"
	echo "$GH_RESPONSE"
}

# get lastest release asset url from github
#	use gh cli if installed and loggedin,
#	use http api otherwise
# $1 : github username
# $2 : github repo
# $3 : jq selector for asset name
function func_github_asset {
	if ! [ -x "$(command -v gh)" ]
	then
		func_gh_http "$1" "$2" "$3" "gh: command not found, using http api"
	else
		local GH_AUTH_TOKEN
		GH_AUTH_TOKEN=$(gh auth token)
		if [ "$GH_AUTH_TOKEN" = "" ]
		then
			func_gh_http "$1" "$2" "$3" "gh: auth token not found, you may be not logged in, using http api"
		else
			func_gh_cli "$1" "$2" "$3" "gh: using gh cli"
		fi
	fi
}

# $1 : github response
function func_ghutil_get_downloadurl {
	local GH_DL_URL
	GH_DL_URL=$(echo "$1" | jq -r '.download_url')
	echo "$GH_DL_URL"
}

# $1 : github response
function func_ghutil_get_created_at {
	local GH_CREATED_AT
	GH_CREATED_AT=$(echo "$1" | jq -r '.created_at')
	echo "$GH_CREATED_AT"
}

# $1 : github response
function func_ghutil_get_source {
	local GH_SOURCE
	GH_SOURCE=$(echo "$1" | jq -r '.source')
	echo "$GH_SOURCE"
}

# $1 : github response
function func_ghutil_get_msg {
	local GH_MSG
	GH_MSG=$(echo "$1" | jq -r '.msg')
	echo "$GH_MSG"
}

# check if json is valid
# $1 : json string
function func_ghutil_check_valid_json {
	if [ "$(echo "$1" | jq empty > /dev/null 2>&1; echo $?)" -eq 0 ]
	then
		return 0
	else
		return 1
	fi
}

# helper functions

# run a function
# $1 : function
function run_func {
	$1
	return $?
}

# print error msg and exit
# $1 : error msg
function errexit {
	print_danger "$1" >&2
	exit 1
}

# promt for confirmation of an action
# $1 : message
# returns 1 if yes, 0 if no
function promt_confirmation {
	local TMP_ANS
	read -p "${1} (y/N) " TMP_ANS
	case $TMP_ANS in
	[Yy])
		return 0
		;;
	*)
		return 1
		;;
	esac
}

# bash config helper functions

# add custom folder for config and source them
function setup_bash_config {
	local ALIAS_STR_START="# START:CUSTOM_CONFIG_SOURCE"
	local ALIAS_STR_END="# END:CUSTOM_CONFIG_SOURCE"

	# make sure .bashrc_custom directory is present
	if [[ ! -d "$DIR_BASH_CONFIG" ]]
	then
		mkdir "$DIR_BASH_CONFIG"
	fi

	# make sure .config directory is present
	if [[ ! -d "$HOME/.config" ]]
	then
		echo "creating config directory"
		mkdir "$HOME/.config"
	fi

	# make sure .apps directory is present
	if [[ ! -d "$DIR_APPS" ]]
	then
		mkdir "$DIR_APPS"
	fi

	# make sure .bin directory is present
	if [[ ! -d "$DIR_APPS_BIN" ]]
	then
		mkdir "$DIR_APPS_BIN"
	fi

	if [[ -f "$FILE_BASHRC" ]]
	then
		if grep -Fxq "$ALIAS_STR_START" "$FILE_BASHRC" && grep -Fxq "$ALIAS_STR_END" "$FILE_BASHRC"
		then
			echo "config file already sourced: $FILE_BASHRC"
		else
			echo "appending to bashrc: $FILE_BASHRC"
			cat <<EOT >> "$FILE_BASHRC"
$ALIAS_STR_START

# add apps bin directory to path
export PATH=\$PATH:$DIR_APPS_BIN

# source config scripts from "$DIR_BASH_CONFIG"
if [ -d "$DIR_BASH_CONFIG" ]; then
for i in "$DIR_BASH_CONFIG"/*.sh; do
	if [ -r "\$i" ]; then
		. "\$i"
	fi
done
unset i
fi

$ALIAS_STR_END
EOT
		fi
	else
		print_danger "err!! not found $FILE_BASHRC"
	fi
}

# other helper functions

# update system package list
function package_list_update {
	if [[ ! "$HAS_RUN_SYSTEM_PACKAGE_LIST_UPDATE" == "t" ]]
	then
		if command -v dnf &> /dev/null
		then
			echo "dnf: updateing system packages"
			sudo dnf check-update
		elif command -v apt-get &> /dev/null
		then
			echo "apt-get: updateing system packages"
			sudo apt-get update
		else
			print_danger "err! : could not detect package manager"
		fi
		HAS_RUN_SYSTEM_PACKAGE_LIST_UPDATE="t"
	fi
}

# install system package
# $1 : package name
function package_install {
	package_list_update
	if command -v dnf &> /dev/null
	then
		echo "dnf: installing $1"
		sudo dnf install "$1"
	elif command -v apt-get &> /dev/null
	then
		echo "apt-get: installing $1"
		sudo apt-get install "$1"
	else
		print_danger "err! : could not detect package manager"
	fi
}

# update system package
# $1 : package name
function package_update {
	package_list_update
	if command -v dnf &> /dev/null
	then
		echo "dnf: installing $1"
		sudo dnf upgrade "$1"
	elif command -v apt-get &> /dev/null
	then
		echo "apt-get: installing $1"
		sudo apt-get install "$1"
	else
		print_danger "err! : could not detect package manager"
	fi
}

###########################
# end : utility functions #
###########################

################
# start : tmux #
################

function tmux_is_installed {
	if ! command -v tmux &> /dev/null
	then
		return 1
	else
		return 0
	fi
}

function tmux_install {
	package_install tmux
}

function tmux_update {
	package_update tmux
}

function tmux_remove {
	sudo dnf remove tmux
}

function tmux_config {
	if ! command -v git &> /dev/null
	then
		print_danger "git not installed, required for config"
		return
	fi

	local CONFIG_DIR
	local CONFIG_FILE
	local PLUGIN_DIR
	CONFIG_DIR="$HOME/.config/tmux"
	CONFIG_FILE="$CONFIG_DIR/tmux.conf"
	PLUGIN_DIR="$HOME/.tmux/plugins/tpm"

	if [[ ! -d "$CONFIG_DIR" ]]; then mkdir "$CONFIG_DIR"; fi;

	git clone "https://github.com/tmux-plugins/tpm" "$PLUGIN_DIR"
	if [[ -f "tmux.conf" ]]
	then
		cp "tmux.conf" "$CONFIG_FILE"
	else
		print_danger "tmux.conf not found at: $(pwd)"
	fi
}

function tmux_config_remove {
	local CONFIG_DIR="$HOME/.config/tmux"
	local PLUGIN_DIR="$HOME/.tmux"

	if [[ -d "$CONFIG_DIR" ]]; then rm -rf "$CONFIG_DIR"; fi;
	if [[ -d "$PLUGIN_DIR" ]]; then rm -rf "$PLUGIN_DIR"; fi;
}

##############
# end : tmux #
##############

##############
# start : lf #
##############

function lf_is_installed {
	if ! command -v lf &> /dev/null
	then
		# command found, return 1
		return 1
	else
		# command not found, return 0
		return 0
	fi
}

function lf_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset gokcehan lf 'select(.name | contains("lf-linux-amd64.tar.gz"))')
	if [[ -z "$GH_RESPONSE" ]]; then print_danger "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then print_danger "error getting created_at from github response"; exit 1; fi;

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then print_danger "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then print_danger "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local FILE_ARCHIVE
	local FILE_BIN
	local FILE_CREATED_AT
	local FILE_SYMLINK
	INSTALL_DIR="$DIR_APPS/lf"
	FILE_ARCHIVE="$INSTALL_DIR/lf.tar.gz"
	FILE_BIN="$INSTALL_DIR/lf"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="$DIR_APPS_BIN/lf"

	echo "response source: $GH_SOURCE"
	echo "response msg: $GH_MSG"

	# Check if already installed
	# If installed and created_at date is before the current release create_at date, then update
	if [[ -e "$FILE_CREATED_AT" ]]
	then
		local TMP_CURRENT_CREATED_AT
		local TMP_EXIST_CREATED_AT
		TMP_CURRENT_CREATED_AT=$(date +%s -d "$GH_CREATED_AT")
		TMP_EXIST_CREATED_AT=$(date +%s -d "$(cat "$FILE_CREATED_AT")")
		if [[ ! "$TMP_CURRENT_CREATED_AT" -gt "$TMP_EXIST_CREATED_AT" ]]
		then
			echo "up to date"
			return
		fi
	fi

	echo "latest release: $GH_CREATED_AT"

	if [[ ! -d $INSTALL_DIR ]]
	then
		mkdir $INSTALL_DIR
	fi

	wget -q --show-progress -O "$FILE_ARCHIVE" "$GH_DL_URL" || errexit "error downloading archive"

	chmod 666 "$FILE_ARCHIVE"
	echo "Extracting files:"
	tar -xvzf "$FILE_ARCHIVE" -C "$INSTALL_DIR"
	chmod 755 "$FILE_BIN"
	ln -s "$FILE_BIN" "$FILE_SYMLINK"
	rm "$FILE_ARCHIVE"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | tee "$FILE_CREATED_AT"
}

function lf_update {
	# update is same as installation
	lf_install
}

function lf_remove {
	rm "$DIR_APPS_BIN/lf"
	rm -rf "$DIR_APPS/lf"
}

function lf_config {
	local CONFIG_DIR
	local FILE_LFRC
	local DIR_ICONS
	CONFIG_DIR="$HOME/.config/lf"
	FILE_LFRC="$CONFIG_DIR/lfrc"
	DIR_ICONS="$CONFIG_DIR/icons"

	if [ ! -d "$CONFIG_DIR" ]
	then
		mkdir "$CONFIG_DIR"
	fi
	if [[ -f "lfrc" ]]
	then
		cp "lfrc" "$FILE_LFRC"
	else
		print_danger "lfrc not found: $(pwd)"
	fi
	chmod 666 "$FILE_LFRC"
	echo "Fetching icon config"
	wget -q --show-progress -O "$DIR_ICONS" "https://raw.githubusercontent.com/gokcehan/lf/master/etc/icons.example"
	chmod 666 "$DIR_ICONS"
	# echo Fetching color config
	# wget -q --show-progress -O $HOME/.config/lf/colors https://raw.githubusercontent.com/gokcehan/lf/master/etc/colors.example
	# chmod 666 $HOME/.config/lf/colors
}

function lf_config_remove {
	rm -rf "$HOME/.config/lf"
}

############
# end : lf #
############

###############
# start : fZf #
###############

function fzf_is_installed {
	if ! command -v fzf &> /dev/null
	then
		# command found, return 1
		return 1
	else
		# command not found, return 0
		return 0
	fi
}

function fzf_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset junegunn fzf 'select(.name | contains("linux_amd64.tar.gz"))')
	if [[ -z "$GH_RESPONSE" ]]; then print_danger "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then print_danger "error getting created_at from github response"; exit 1; fi;

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then print_danger "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then print_danger "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local FILE_ARCHIVE
	local FILE_BIN
	local FILE_CREATED_AT
	local FILE_SYMLINK
	INSTALL_DIR="$DIR_APPS/fzf"
	FILE_ARCHIVE="$INSTALL_DIR/fzf.tar.gz"
	FILE_BIN="$INSTALL_DIR/fzf"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="$DIR_APPS_BIN/fzf"

	echo "response source: $GH_SOURCE"
	echo "response msg: $GH_MSG"

	# Check if already installed
	# If installed and created_at date is before the current release create_at date, then update
	if [[ -e "$FILE_CREATED_AT" ]]
	then
		local TMP_CURRENT_CREATED_AT
		local TMP_EXIST_CREATED_AT
		TMP_CURRENT_CREATED_AT=$(date +%s -d "$GH_CREATED_AT")
		TMP_EXIST_CREATED_AT=$(date +%s -d "$(cat "$FILE_CREATED_AT")")
		if [[ ! "$TMP_CURRENT_CREATED_AT" -gt "$TMP_EXIST_CREATED_AT" ]]
		then
			echo "up to date"
			return
		fi
	fi

	echo "latest release: $GH_CREATED_AT"

	if [[ ! -d $INSTALL_DIR ]]
	then
		mkdir $INSTALL_DIR
	fi

	wget -q --show-progress -O "$FILE_ARCHIVE" "$GH_DL_URL" || errexit "error downloading archive"

	chmod 666 "$FILE_ARCHIVE"
	echo "Extracting files:"
	tar -xvzf "$FILE_ARCHIVE" -C "$INSTALL_DIR"
	chmod 755 "$FILE_BIN"
	ln -s "$FILE_BIN" "$FILE_SYMLINK"
	rm "$FILE_ARCHIVE"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | tee "$FILE_CREATED_AT"
}

function fzf_update {
	# update is same as installation
	fzf_install
}

function fzf_remove {
	rm "$DIR_APPS_BIN/fzf"
	rm -rf "$DIR_APPS/fzf"
}

function fzf_config {
	# Completion examples:
	# --------------------
	# Files under the current directory
	# - You can select multiple items with TAB key
	# vim **<TAB>

	# Files under parent directory
	# vim ../**<TAB>

	# Files under parent directory that match `fzf`
	# vim ../fzf**<TAB>

	# Files under your home directory
	# vim ~/**<TAB>


	# Directories under current directory (single-selection)
	# cd **<TAB>

	# Directories under ~/github that match `fzf`
	# cd ~/github/fzf**<TAB>

	# Set up fzf key bindings and fuzzy completion
	# Add the following in .bashrc for bash
	# eval "$(fzf --bash)"
	#
	# eval "$(fzf --zsh)"
	# fzf --fish | source
	# --------------------------------------------
	echo "no config defined"
}

function fzf_config_remove {
	echo "no config defined"
}

#############
# end : fzf #
#############

################
# start : hugo #
################

function hugo_is_installed {
	if ! command -v hugo &> /dev/null
	then
		# command found, return 1
		return 1
	else
		# command not found, return 0
		return 0
	fi
}

function hugo_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset gohugoio hugo 'select(.name | contains("linux-amd64.tar.gz") and contains("extended"))')
	if [[ -z "$GH_RESPONSE" ]]; then print_danger "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then print_danger "error getting created_at from github response"; exit 1; fi;

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then print_danger "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then print_danger "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local FILE_ARCHIVE
	local FILE_BIN
	local FILE_CREATED_AT
	local FILE_SYMLINK
	INSTALL_DIR="$DIR_APPS/hugo"
	FILE_ARCHIVE="$INSTALL_DIR/hugo.tar.gz"
	FILE_BIN="$INSTALL_DIR/hugo"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="$DIR_APPS_BIN/hugo"

	echo "response source: $GH_SOURCE"
	echo "response msg: $GH_MSG"

	# Check if already installed
	# If installed and created_at date is before the current release create_at date, then update
	if [[ -e "$FILE_CREATED_AT" ]]
	then
		local TMP_CURRENT_CREATED_AT
		local TMP_EXIST_CREATED_AT
		TMP_CURRENT_CREATED_AT=$(date +%s -d "$GH_CREATED_AT")
		TMP_EXIST_CREATED_AT=$(date +%s -d "$(cat "$FILE_CREATED_AT")")
		if [[ ! "$TMP_CURRENT_CREATED_AT" -gt "$TMP_EXIST_CREATED_AT" ]]
		then
			echo "up to date"
			return
		fi
	fi

	echo "latest release: $GH_CREATED_AT"

	if [[ ! -d $INSTALL_DIR ]]
	then
		mkdir $INSTALL_DIR
	fi

	wget -q --show-progress -O "$FILE_ARCHIVE" "$GH_DL_URL" || errexit "error downloading archive"

	chmod 666 "$FILE_ARCHIVE"
	echo "Extracting files:"
	tar -xvzf "$FILE_ARCHIVE" -C "$INSTALL_DIR"
	chmod 755 "$FILE_BIN"
	ln -s "$FILE_BIN" "$FILE_SYMLINK"
	rm "$FILE_ARCHIVE"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | tee "$FILE_CREATED_AT"
}

function hugo_update {
	# update is same as installation
	hugo_install
}

function hugo_remove {
	rm "$DIR_APPS_BIN/hugo"
	rm -rf "$DIR_APPS/hugo"
}

function hugo_config {
	echo "no config defined"
}

function hugo_config_remove {
	echo "no config defined"
}

##############
# end : hugo #
##############

####################
# start : lazygit #
####################

function lazygit_is_installed {
	if ! command -v lazygit &> /dev/null
	then
		# command found, return 1
		return 1
	else
		# command not found, return 0
		return 0
	fi
}

function lazygit_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset jesseduffield lazygit 'select(.name | contains("Linux_x86_64.tar.gz"))')
	if [[ -z "$GH_RESPONSE" ]]; then print_danger "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then print_danger "error getting created_at from github response"; exit 1; fi;

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then print_danger "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then print_danger "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local FILE_ARCHIVE
	local FILE_BIN
	local FILE_CREATED_AT
	local FILE_SYMLINK
	INSTALL_DIR="$DIR_APPS/lazygit"
	FILE_ARCHIVE="$INSTALL_DIR/lazygit.tar.gz"
	FILE_BIN="$INSTALL_DIR/lazygit"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="$DIR_APPS_BIN/lazygit"

	echo "response source: $GH_SOURCE"
	echo "response msg: $GH_MSG"

	# Check if already installed
	# If installed and created_at date is before the current release create_at date, then update
	if [[ -e "$FILE_CREATED_AT" ]]
	then
		local TMP_CURRENT_CREATED_AT
		local TMP_EXIST_CREATED_AT
		TMP_CURRENT_CREATED_AT=$(date +%s -d "$GH_CREATED_AT")
		TMP_EXIST_CREATED_AT=$(date +%s -d "$(cat "$FILE_CREATED_AT")")
		if [[ ! "$TMP_CURRENT_CREATED_AT" -gt "$TMP_EXIST_CREATED_AT" ]]
		then
			echo "up to date"
			return
		fi
	fi

	echo "latest release: $GH_CREATED_AT"

	if [[ ! -d $INSTALL_DIR ]]
	then
		mkdir $INSTALL_DIR
	fi

	wget -q --show-progress -O "$FILE_ARCHIVE" "$GH_DL_URL" || errexit "error downloading archive"

	chmod 666 "$FILE_ARCHIVE"
	echo "Extracting files:"
	tar -xvzf "$FILE_ARCHIVE" -C "$INSTALL_DIR"
	chmod 755 "$FILE_BIN"
	ln -s "$FILE_BIN" "$FILE_SYMLINK"
	rm "$FILE_ARCHIVE"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | tee "$FILE_CREATED_AT"
}

function lazygit_update {
	# update is same as installation
	lazygit_install
}

function lazygit_remove {
	rm "$DIR_APPS_BIN/lazygit"
	rm -rf "$DIR_APPS/lazygit"
}

function lazygit_config {
	echo "no config defined"
}

function lazygit_config_remove {
	echo "no config defined"
}

#################
# end : lazygit #
#################

####################
# start : marktext #
####################

function marktext_is_installed {
	if ! command -v marktext &> /dev/null
	then
		# command found, return 1
		return 1
	else
		# command not found, return 0
		return 0
	fi
}

function marktext_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset marktext marktext 'select(.name | contains("AppImage"))')
	if [[ -z "$GH_RESPONSE" ]]; then print_danger "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then print_danger "error getting created_at from github response"; exit 1; fi;

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then print_danger "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then print_danger "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local DESKTOP_DIR
	local FILE_APPIMAGE
	local FILE_CREATED_AT
	local FILE_SYMLINK
	local FILE_DESKTOP
	local FILE_LOGO
	local FILE_SYMLINK_DESKTOP
	INSTALL_DIR="$DIR_APPS/marktext"
	DESKTOP_DIR="$HOME/.local/share/applications"
	FILE_APPIMAGE="$INSTALL_DIR/marktext.AppImage"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_DESKTOP="$INSTALL_DIR/marktext.desktop"
	FILE_LOGO="$INSTALL_DIR/marktext_logo.png"
	FILE_SYMLINK="$DIR_APPS_BIN/marktext"
	FILE_SYMLINK_DESKTOP="$DESKTOP_DIR/marktext.desktop"

	echo "response source: $GH_SOURCE"
	echo "response msg: $GH_MSG"

	# Check if already installed
	# If installed and created_at date is before the current release create_at date, then update
	if [[ -e "$FILE_CREATED_AT" ]]
	then
		local TMP_CURRENT_CREATED_AT
		local TMP_EXIST_CREATED_AT
		TMP_CURRENT_CREATED_AT=$(date +%s -d "$GH_CREATED_AT")
		TMP_EXIST_CREATED_AT=$(date +%s -d "$(cat "$FILE_CREATED_AT")")
		if [[ ! "$TMP_CURRENT_CREATED_AT" -gt "$TMP_EXIST_CREATED_AT" ]]
		then
			echo "up to date"
			return
		fi
	fi

	echo "latest release: $GH_CREATED_AT"

	if [[ ! -d $INSTALL_DIR ]]
	then
		mkdir $INSTALL_DIR
	fi

	wget -q --show-progress -O "$FILE_APPIMAGE" "$GH_DL_URL" || errexit "error downloading archive"

	chmod 755 "$FILE_APPIMAGE"
	ln -s "$FILE_APPIMAGE" "$FILE_SYMLINK"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | tee "$FILE_CREATED_AT"
	# Create desktop file
	tee "$FILE_DESKTOP"> /dev/null <<EOT
[Desktop Entry]
Name=MarkText
Comment=Next generation markdown editor
Exec=marktext %F
Terminal=false
Type=Application
Icon=$DIR_APPS/marktext/marktext_logo.png
Categories=Office;TextEditor;Utility;
MimeType=text/markdown;
Keywords=marktext;
StartupWMClass=marktext
Actions=NewWindow;

[Desktop Action NewWindow]
Name=New Window
Exec=marktext --new-window %F
Icon=marktext
EOT
	# Download logo
	wget -q --show-progress -O "$FILE_LOGO" "https://raw.githubusercontent.com/marktext/marktext/develop/static/logo-small.png"
	ln -s "$FILE_DESKTOP" "$FILE_SYMLINK_DESKTOP"
	# Register app to the OS
	update-desktop-database "$DESKTOP_DIR"
}

function marktext_update {
	# update is same as installation
	marktext_install
}

function marktext_remove {
	DESKTOP_DIR="$HOME/.local/share/applications"
	FILE_SYMLINK_DESKTOP="$DESKTOP_DIR/marktext.desktop"

	rm "$DIR_APPS_BIN/marktext"
	rm -rf "$DIR_APPS/marktext"
	rm "$FILE_SYMLINK_DESKTOP"

	update-desktop-database "$DESKTOP_DIR"
}

function marktext_config {
	echo "no config defined"
}

function marktext_config_remove {
	echo "no config defined"
}

##################
# end : marktext #
##################

##################
# start : golang #
##################

function golang_is_installed {
	if ! command -v go &> /dev/null
	then
		# command found, return 1
		return 1
	else
		# command not found, return 0
		return 0
	fi
}

function golang_install {
	local ARCH
	local MACHINE
	local GO_VER
	local INSTALL_DIR="$DIR_APPS/go"
	ARCH=$(uname -s | tr '[:upper:]' '[:lower:]')
	MACHINE=$(uname -m)
	if [ "$MACHINE" = "x86_64" ]
	then
		MACHINE="amd64"
	fi

	if [[ -z $1 ]]
	then
		GO_VER=$(wget -qO- https://go.dev/VERSION?m=text | head --lines 1)
	else
		GO_VER="$1"
	fi
	GO_FILE_NAME="$GO_VER.$ARCH-$MACHINE.tar.gz"
	GO_DL_URL="https://go.dev/dl/$GO_FILE_NAME"
	GO_TMP_ARCHIVE="/tmp/$GO_FILE_NAME"

	# If previous updating attempt failed or abruptly exited
	# without cleaning up the archive file, then remove the
	# previous archive file and start over.
	if [ -e "$GO_TMP_ARCHIVE" ]
	then
		print_info "cleaning up previously downloaded archive..."
		rm "$GO_TMP_ARCHIVE"
	fi

	# Download Golang binary archive in temporary folder
	wget -q --show-progress -O "$GO_TMP_ARCHIVE" "$GO_DL_URL"

	if [ -d "$INSTALL_DIR" ]
	then
		rm -rf "$INSTALL_DIR"
	fi
	tar -C "$DIR_APPS" -xzf "$GO_TMP_ARCHIVE"

	# Clean up archive file
	rm "$GO_TMP_ARCHIVE"
}

function golang_update {
	local GO_VER_INSTALLED
	local GO_VER
	local INSTALL_DIR="$DIR_APPS/go"
	if [ -e "$INSTALL_DIR/VERSION" ]
	then
		GO_VER_INSTALLED=$(head --lines 1 < "$INSTALL_DIR/VERSION")
	fi
	GO_VER=$(wget -qO- https://go.dev/VERSION?m=text | head --lines 1)
	if [ "$GO_VER_INSTALLED" = "$GO_VER" ]
	then
		echo "up to date"
	else
		golang_install "$GO_VER"
	fi
}

function golang_remove {
	local INSTALL_DIR="$DIR_APPS/go"
	if [ -d "$INSTALL_DIR" ]
	then
		rm -rf "$INSTALL_DIR"
	fi
}

function golang_config {
	local CONFIG_FILE="$DIR_BASH_CONFIG/golang.sh"
	local INSTALL_DIR="$DIR_APPS/go"
tee "$CONFIG_FILE" > /dev/null <<EOT
#!/usr/bin/env bash

# START:Golang
export GOPATH=\$HOME/go
export PATH=\$PATH:$INSTALL_DIR/bin:\$GOPATH/bin

# END:Golang
EOT
}

function golang_config_remove {
	local CONFIG_FILE="$DIR_BASH_CONFIG/golang.sh"
	if [[ -f "$CONFIG_FILE" ]]
	then
		rm "$CONFIG_FILE"
	fi
}

################
# end : golang #
################

##################
# start : neovim #
##################

function neovim_minimal_config_propmt {
	if [[ "$NEOVIM_IS_MINIMAL_CONFIG" == "n" ]]
	then
		print_info "neovim will be using complete configuration"
		if promt_confirmation "use minimal config?"
		then
			echo "using minimal config"
			NEOVIM_IS_MINIMAL_CONFIG="t"
		else
			echo "using full config"
			NEOVIM_IS_MINIMAL_CONFIG="f"
		fi
	fi
}

function neovim_is_installed {
	if ! command -v nvim &> /dev/null
	then
		# command found, return 1
		return 1
	else
		# command not found, return 0
		return 0
	fi
}

function neovim_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset neovim neovim 'select(.name == "nvim.appimage")')
	if [[ -z "$GH_RESPONSE" ]]; then print_danger "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then print_danger "error getting created_at from github response"; exit 1; fi;

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then print_danger "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then print_danger "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local DESKTOP_DIR
	local FILE_APPIMAGE
	local FILE_CREATED_AT
	local FILE_SYMLINK
	local FILE_DESKTOP
	local FILE_LOGO
	local FILE_SYMLINK_DESKTOP
	INSTALL_DIR="$DIR_APPS/neovim"
	FILE_APPIMAGE="$INSTALL_DIR/nvim.AppImage"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="$DIR_APPS_BIN/nvim"

	echo "response source: $GH_SOURCE"
	echo "response msg: $GH_MSG"

	# Check if already installed
	# If installed and created_at date is before the current release create_at date, then update
	if [[ -e "$FILE_CREATED_AT" ]]
	then
		local TMP_CURRENT_CREATED_AT
		local TMP_EXIST_CREATED_AT
		TMP_CURRENT_CREATED_AT=$(date +%s -d "$GH_CREATED_AT")
		TMP_EXIST_CREATED_AT=$(date +%s -d "$(cat "$FILE_CREATED_AT")")
		if [[ ! "$TMP_CURRENT_CREATED_AT" -gt "$TMP_EXIST_CREATED_AT" ]]
		then
			echo "up to date"
			return
		fi
	fi

	echo "latest release: $GH_CREATED_AT"

	if [[ ! -d $INSTALL_DIR ]]
	then
		mkdir $INSTALL_DIR
	fi

	wget -q --show-progress -O "$FILE_APPIMAGE" "$GH_DL_URL" || errexit "error downloading archive"

	chmod 755 "$FILE_APPIMAGE"
	ln -s "$FILE_APPIMAGE" "$FILE_SYMLINK"
	# in case libfuse2 is not installed, then extract binary from AppImage
	type -p libfuse2 || {
		print_info "libfuse2 not found, extracting AppImage"
		local CURR_DIR="$PWD"
		cd "$INSTALL_DIR" || errexit "could not change directory to: $INSTALL_DIR"
		"$FILE_APPIMAGE" --appimage-extract >/dev/null
		rm "$FILE_SYMLINK"
		ln -s "$INSTALL_DIR/squashfs-root/AppRun" "$FILE_SYMLINK"
		rm "$FILE_APPIMAGE"
		cd "$CURR_DIR" || errexit "could not change directory to: $CURR_DIR"
	}
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | tee "$FILE_CREATED_AT"

	# install ripgrep if not installed
	if ! command -v rg &> /dev/null
	then
		if promt_confirmation "ripgrep is required for telescope, install now?"
		then
			echo "installing: ripgrep"
			package_install ripgrep
		else
			echo "ripgrep will not be installed"
		fi
	else
		echo "already installed: ripgrep"
	fi

	# install xsel if not installed
	if ! command -v xsel &> /dev/null
	then
		if promt_confirmation "xsel is required for clipboard operations, install now?"
		then
			echo "installing: xsel"
			package_install xsel
		else
			echo "xsel will not be installed"
		fi
	else
		echo "already installed: xsel"
	fi

	neovim_minimal_config_propmt
	if [[ "$NEOVIM_IS_MINIMAL_CONFIG" == "f" ]]
	then
		# installed required packages for treesitter and mason
		# treesitter: install gcc if not installed
		if ! command -v gcc &> /dev/null
		then
			echo "installing: gcc"
			if promt_confirmation "gcc is required for treesitter, install now?"
			then
				echo "installing gcc"
				package_install gcc
			else
				echo "gcc will not be installed"
			fi
		else
			echo "already installed: gcc"
		fi
		# treesitter: install g++ if not installed
		if ! command -v g++ &> /dev/null
		then
			echo "installing: g++"
			if promt_confirmation "g++ is required for treesitter, install now?"
			then
				echo "installing g++"
				package_install g++
			else
				echo "g++ will not be installed"
			fi
		else
			echo "already installed: g++"
		fi
		# mason: check if golang is installed
		if ! command -v go &> /dev/null
		then
			print_danger "go: not found, golang should be installed for current neovim lsp: sqls"
		fi
		# mason: check if node is installed
		if ! command -v node &> /dev/null
		then
			print_danger "node: not found, node.js should be installed for current neovim lsp: bashls"
		fi
	else
		echo "using minimal configuration, no extra packages will be installed"
	fi
}

function neovim_update {
	# update is same as installation
	neovim_install
}

function neovim_remove {
	rm "$DIR_APPS_BIN/nvim"
	rm -rf "$DIR_APPS/neovim"
}

function neovim_config {
	if [[ ! -d "$HOME/.config" ]]
	then
		mkdir "$HOME/.config"
	fi
	if [[ ! -d "$HOME/.config/nvim" ]]
	then
		mkdir "$HOME/.config/nvim"
	fi
	if [[ -f nvim_config.lua ]]
	then
		cp nvim_config.lua "$HOME/.config/nvim/init.lua"
		neovim_minimal_config_propmt
		if [[ "$NEOVIM_IS_MINIMAL_CONFIG" == "t" ]]
		then
			echo "setting minimal config"
			if [[ ! -f "$HOME/.config/nvim/minimal" ]]
			then
				touch "$HOME/.config/nvim/minimal"
			fi
		fi
	else
		print_danger "config file not found: $PWD/nvim_config.lua"
	fi
}

function neovim_config_remove {
	rm -rf "$HOME/.config/nvim"
	rm -rf "$HOME/.local/share/nvim"
	rm -rf "$HOME/.local/state/nvim"
}

################
# end : neovim #
################

###############
# start : nvm #
###############

function nvm_is_installed {
	# when running scritp with bash inside tmux, the sourcing of nvm
	# does not work properly, this is the alternative
	if [[ -f "$HOME/.config/nvm/nvm.sh" ]]
	then
		# shellcheck disable=SC1090
		source "$HOME/.config/nvm/nvm.sh"
	fi
	if ! command -v nvm &> /dev/null
	then
		# command found, return 1
		return 1
	else
		# command not found, return 0
		return 0
	fi
}

function nvm_install {
	# shellcheck disable=SC1090
	wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh" | bash
	# shellcheck disable=SC1090
	source "$HOME/.bashrc"
	if command -v nvm
	then
		print_success "nvm: installed successfully"
	fi
	echo "installing latest lts version of node.js"
	nvm install --reinstall-packages-from=current 'lts/*'
}

function nvm_update {
	print_info "nvm: installation script url should be changed before running update"
	nvm_install
}

function nvm_remove {
	local CUR_NVM_DIR
	CUR_NVM_DIR="${NVM_DIR:-~/.nvm}"
	nvm unload
	rm -rf "$CUR_NVM_DIR"
	grep -v "NVM_DIR" "$HOME/.bashrc" | tee "$HOME/.bashrc" > /dev/null
	unset nvm
}

function nvm_config {
	echo "no config defined"
}

function nvm_config_remove {
	echo "no config defined"
}

#############
# end : nvm #
#############

#####################
# start : distrobox #
#####################

function distrobox_is_installed {
	# when running scritp with bash inside tmux, the sourcing of nvm
	# does not work properly, this is the alternative
	# if [[ -f "$HOME/.nvm/nvm.sh" ]]
	# then
	# 	# shellcheck disable=SC1090
	# 	source "$HOME/.nvm/nvm.sh"
	# fi
	if ! command -v distrobox &> /dev/null
	then
		# command found, return 1
		return 1
	else
		# command not found, return 0
		return 0
	fi
}

function distrobox_install {
	echo "installing distrobox in $HOME/.local"
	# shellcheck disable=SC1090
	wget -qO- https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix "$HOME/.local"
}

function distrobox_update {
	distrobox_install
}

function distrobox_remove {
	echo "uninstalling distrobox"
	# shellcheck disable=SC1090
	wget -qO- https://raw.githubusercontent.com/89luca89/distrobox/main/uninstall | sh -s -- --prefix "$HOME/.local"
}

function distrobox_config {
	local BASH_CONFIG_FILE="$DIR_BASH_CONFIG/distrobox.sh"
	local INSTALL_DIR="$HOME/.local"
	local CONFIG_DIR="$HOME/.config/distrobox"
	mkdir -p "$CONFIG_DIR"
	tee "$BASH_CONFIG_FILE" > /dev/null <<EOT
#!/usr/bin/env bash

# START:distrobox
export PATH=\$PATH:$INSTALL_DIR/bin

# END:distrobox
EOT
	tee "$CONFIG_DIR/distrobox.conf" > /dev/null <<EOT
container_name_default="devenv"
container_user_custom_home="\$HOME/devenv"
skip_workdir="0"
EOT
}

function distrobox_config_remove {
	local BASH_CONFIG_FILE="$DIR_BASH_CONFIG/distrobox.sh"
	local CONFIG_DIR="$HOME/.config/distrobox"
	if [[ -f "$BASH_CONFIG_FILE" ]]
	then
		rm "$BASH_CONFIG_FILE"
	fi
	if [[ -d "$CONFIG_DIR" ]]
	then
		rm -rf "$CONFIG_DIR"
	fi
}

###################
# end : distrobox #
###################

################################
# start : custom bashrc config #
################################

function func_config_bash {
	local FILE_CONFIG="$DIR_BASH_CONFIG/bashrc_custom_init.sh"

	if [[ -f "bashrc_custom_init.sh" ]]
	then
		echo "writing to: $FILE_CONFIG"
		cp "bashrc_custom_init.sh" "$FILE_CONFIG"
	else
		echo "bashrc_custom_init.sh not found: $(pwd)"
	fi
}

##############################
# end : custom bashrc config #
##############################

##########################
# end : custom os config #
##########################

function menu_manage_app {
	if [[ $1 == "" ]]; then echo "invalid app: $1"; exit 1; fi;

	local PS3=$"select command for: $1: "
	local IFS=':'
	local AVAILABLE_APP_OPTS
	AVAILABLE_APP_OPTS="set_config:remove_config:remove:back"

	run_func "${1}_is_installed"
	if [[ "$?" == 0 ]]
	then
		AVAILABLE_APP_OPTS="update:$AVAILABLE_APP_OPTS"
	else
		AVAILABLE_APP_OPTS="install:$AVAILABLE_APP_OPTS"
	fi
	read -ra OPTIONS <<< "$AVAILABLE_APP_OPTS"
	select opt in "${OPTIONS[@]}"
	do
		case $opt in
			"install")
				print_info "# $1:install:start #"
				run_func "${1}_install"
				print_info "# $1:install:end #"

				print_info "# $1:config:start #"
				run_func "${1}_config"
				print_info "# $1:config:end #"

				break
				;;
			"update")
				print_info "# $1:update:start #"
				run_func "${1}_update"
				print_info "# $1:update:end #"

				break
				;;
			"set_config")
				print_info "# $1:config_remove:start #"
				run_func "${1}_config_remove"
				print_info "# $1:config_remove:end #"

				print_info "# $1:config:start #"
				run_func "${1}_config"
				print_info "# $1:config:end #"

				break
				;;
			"remove_config")
				print_info "# $1:config_remove:start #"
				run_func "${1}_config_remove"
				print_info "# $1:config_remove:end #"

				break
				;;
			"remove")
				print_info "# $1:remove:start #"
				run_func "${1}_remove"
				print_info "# $1:remove:end #"

				print_info "# $1:config_remove:start #"
				run_func "${1}_config_remove"
				print_info "# $1:config_remove:end #"

				break
				;;
			"back")
				break
				;;
			*) print_danger "invalid command: $REPLY";;
		esac
	done
}

# Menu for managing apps installation
function menu_apps {
	local PS3='select app: '
	local APPS_LIST=
	local MENU_OPTS=""
	local IFS=':'
	read -ra APPS_LIST <<< "$REGISTERED_APPS"
	for app in "${APPS_LIST[@]}"
	do
		run_func "${app}_is_installed"
		local IS_INSTALLED=$?
		if [[ $IS_INSTALLED == 0 ]]
		then
			MENU_OPTS="${MENU_OPTS}[X] $app:"
		else
			MENU_OPTS="${MENU_OPTS}[ ] $app:"
		fi
	done
	local MENU_OPTS="$MENU_OPTS<-- back"
	read -ra OPTIONS <<< "$MENU_OPTS"
	select opt in "${OPTIONS[@]}"
	do
		if [[ $opt == "<-- back" ]]
		then
			break
		fi
		local SELECTED_APP=${opt:4}
		if [[ $SELECTED_APP == "" ]] || [[ ! $REGISTERED_APPS == *"$SELECTED_APP"* ]]
		then
			print_danger "invalid app: $REPLY"
		else
			menu_manage_app "$SELECTED_APP"
		fi
	done
}

# This is the main menu where operations will be selected
function menu_main {
	local PS3=$'select operation: '
	local options=("manage apps" "config bash" "quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"manage apps")
				menu_apps
				;;
			"config bash")
				func_config_bash
				;;
			"quit")
				break
				;;
			*) print_danger "invalid operation $REPLY";;
		esac
	done
}

print_header "=================="
print_header "= app operations ="
print_header "=================="

# setup bash configurations
setup_bash_config
# run main menu function
menu_main

#############
# Resources #
#############
# Bash functions: https://linuxize.com/post/bash-functions/
#
