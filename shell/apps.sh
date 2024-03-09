#!/bin/bash

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
FILE_BASHRC="$HOME/.bashrc"

##########################
# how registration works #
#------------------------#
# 1. add a command by running `register_app APP_NAME`
# 2. app name should not contain spaces, special characters
# 3. each app must have the following function implementation-
# 	- APP_NAME_is_installed : returns 1 if installed, otherwise 0
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

#############################
# start : utility functions #
#############################

# gitHub functions

# get lastest release asset url from github with http api
# $1 : github username
# $2 : github repo
# $3 : jq selector for asset name
function func_gh_http {
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
func_gh_cli() {
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
func_github_asset() {
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
	if [ "$(echo "$1" | jq empty > "/dev/null" 2>&1; echo $?)" -eq 0 ]
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
	echo "$1" >&2
	exit 1
}

# bash config helper functions

# add custom folder for config and source them
function setup_bash_config {
	local ALIAS_STR_START="# START:CUSTOM_CONFIG_SOURCE"
	local ALIAS_STR_END="# END:CUSTOM_CONFIG_SOURCE"

	if [[ ! -d "$DIR_BASH_CONFIG" ]]
	then
		mkdir "$DIR_BASH_CONFIG"
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

# source config scripts from "$DIR_BASH_CONFIG"
if [ -d "$DIR_BASH_CONFIG" ]; then
	for i in "$DIR_BASH_CONFIG"/*.sh; do
		if [ -r "\$i" ]; then
			. "\$i"
		fi
	done
	unser i
fi

$ALIAS_STR_END
EOT
		fi
	else
		echo "err!! not found $FILE_BASHRC"
	fi
}

###########################
# end : utility functions #
###########################

################
# start : tmux #
################

function tmux_is_installed {
	if ! command -v tmux &> "/dev/null"
	then
		return 0
	else
		return 1
	fi
}

function tmux_install {
	sudo dnf install tmux
}

function tmux_update {
	sudo dnf check-update
	sudo dnf upgrade tmux
}

function tmux_remove {
	sudo dnf remove tmux
}

function tmux_config {
	if ! command -v git &> "/dev/null"
	then
		echo "git not installed, required for config"
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
	tee "$CONFIG_FILE" > "/dev/null" <<EOT
# Base config- https://github.com/dreamsofcode-io/tmux/blob/main/tmux.conf
# Common commands:
#	tmux		: create a default session and start
#	tmux ls		: list sesstions
#	tmux a		: attach to default session
#	tmux new -s name	: create a named sesstion
#	tmux attach -t name	: attach to a named session
#	tmxu lscm			: list all tmux commands
# Common bindings:
#	[	: copy mode
#	d	: detach
#	z	: toggle zoom on a pane
#	c	: create new window
#	q	: show panes with numbers, press number to select
#	w	: manage windows
#	s	: manage windows and sesstions
#	?	: show all key bindings
#	1-9	: select pane
#

# enable 24bit color
set-option -sa terminal-overrides ",xterm*:Tc"
# enable mouse support
set -g mouse on
# enable system clipboard
# set-clipboard on

# remap binding from CTRL-b to CTRL-space
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# Start windows and panes at 1, not 0
set -g base-index 1
set -g pane-base-index 1
set-window-option -g pane-base-index 1
set-option -g renumber-windows on

# Use Alt-arrow keys without prefix key to switch panes
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Shift arrow to switch windows
bind -n S-Left  previous-window
bind -n S-Right next-window

# Shift Alt vim keys to switch windows
# bind -n M-H previous-window
# bind -n M-L next-window

# Plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
# set -g @plugin 'christoomey/vim-tmux-navigator'
# set -g @plugin 'dreamsofcode-io/catppuccin-tmux'
set -g @plugin 'tmux-plugins/tmux-yank'

run '~/.tmux/plugins/tpm/tpm'

# set vi-mode
set-window-option -g mode-keys vi
# keybindings
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

bind '"' split-window -v -c "#{pane_current_path}"
bind % split-window -h -c "#{pane_current_path}"

EOT
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
	if ! command -v lf &> "/dev/null"
	then
		# command not found, return 0
		return 0
	else
		# command found, return 1
		return 1
	fi
}

function lf_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset gokcehan lf 'select(.name | contains("lf-linux-amd64.tar.gz"))')
	if [[ -z "$GH_RESPONSE" ]]; then echo "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then echo "error getting created_at from github response"; exit 1; fi;
	echo "last updated: $GH_CREATED_AT"

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then echo "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then echo "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local FILE_ARCHIVE
	local FILE_BIN
	local FILE_CREATED_AT
	local FILE_SYMLINK
	INSTALL_DIR="/opt/lf"
	FILE_ARCHIVE="$INSTALL_DIR/lf.tar.gz"
	FILE_BIN="$INSTALL_DIR/lf"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="/bin/lf"

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
		sudo mkdir $INSTALL_DIR
	fi

	sudo wget -q --show-progress -O "$FILE_ARCHIVE" "$GH_DL_URL" || errexit "error downloading archive"

	sudo chmod 666 "$FILE_ARCHIVE"
	echo "Extracting files:"
	sudo tar -xvzf "$FILE_ARCHIVE" -C "$INSTALL_DIR"
	sudo chmod 755 "$FILE_BIN"
	sudo ln -s "$FILE_BIN" "$FILE_SYMLINK"
	sudo rm "$FILE_ARCHIVE"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | sudo tee "$FILE_CREATED_AT"
}

function lf_update {
	# update is same as installation
	lf_install
}

function lf_remove {
	sudo rm "/bin/lf"
	sudo rm -rf "/opt/lf"
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
	sudo tee "$FILE_LFRC" > /dev/null <<EOT
# keybindings

map x 'cut'
map d 'delete'

# ui
set hidden
set info size:time
set sortby "name"
EOT
	sudo chmod 666 "$FILE_LFRC"
	echo "Fetching icon config"
	sudo wget -q --show-progress -O "$DIR_ICONS" "https://raw.githubusercontent.com/gokcehan/lf/master/etc/icons.example"
	sudo chmod 666 "$DIR_ICONS"
	# echo Fetching color config
	# sudo wget -q --show-progress -O $HOME/.config/lf/colors https://raw.githubusercontent.com/gokcehan/lf/master/etc/colors.example
	# sudo chmod 666 $HOME/.config/lf/colors
}

function lf_config_remove {
	sudo rm -rf "$HOME/.config/lf"
}

############
# end : lf #
############

###############
# start : fZf #
###############

function fzf_is_installed {
	if ! command -v fzf &> "/dev/null"
	then
		# command not found, return 0
		return 0
	else
		# command found, return 1
		return 1
	fi
}

function fzf_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset junegunn fzf 'select(.name | contains("linux_amd64.tar.gz"))')
	if [[ -z "$GH_RESPONSE" ]]; then echo "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then echo "error getting created_at from github response"; exit 1; fi;
	echo "last updated: $GH_CREATED_AT"

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then echo "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then echo "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local FILE_ARCHIVE
	local FILE_BIN
	local FILE_CREATED_AT
	local FILE_SYMLINK
	INSTALL_DIR="/opt/fzf"
	FILE_ARCHIVE="$INSTALL_DIR/fzf.tar.gz"
	FILE_BIN="$INSTALL_DIR/fzf"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="/bin/fzf"

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
		sudo mkdir $INSTALL_DIR
	fi

	sudo wget -q --show-progress -O "$FILE_ARCHIVE" "$GH_DL_URL" || errexit "error downloading archive"

	sudo chmod 666 "$FILE_ARCHIVE"
	echo "Extracting files:"
	sudo tar -xvzf "$FILE_ARCHIVE" -C "$INSTALL_DIR"
	sudo chmod 755 "$FILE_BIN"
	sudo ln -s "$FILE_BIN" "$FILE_SYMLINK"
	sudo rm "$FILE_ARCHIVE"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | sudo tee "$FILE_CREATED_AT"
}

function fzf_update {
	# update is same as installation
	fzf_install
}

function fzf_remove {
	sudo rm "/bin/fzf"
	sudo rm -rf "/opt/fzf"
}

function fzf_config {
	echo "no confige defined"
}

function fzf_config_remove {
	echo "no confige defined"
}

#############
# end : fzf #
#############

################
# start : hugo #
################

function hugo_is_installed {
	if ! command -v hugo &> "/dev/null"
	then
		# command not found, return 0
		return 0
	else
		# command found, return 1
		return 1
	fi
}

function hugo_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset gohugoio hugo 'select(.name | contains("linux-amd64.tar.gz") and contains("extended"))')
	if [[ -z "$GH_RESPONSE" ]]; then echo "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then echo "error getting created_at from github response"; exit 1; fi;
	echo "last updated: $GH_CREATED_AT"

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then echo "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then echo "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local FILE_ARCHIVE
	local FILE_BIN
	local FILE_CREATED_AT
	local FILE_SYMLINK
	INSTALL_DIR="/opt/hugo"
	FILE_ARCHIVE="$INSTALL_DIR/hugo.tar.gz"
	FILE_BIN="$INSTALL_DIR/hugo"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="/bin/hugo"

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
		sudo mkdir $INSTALL_DIR
	fi

	sudo wget -q --show-progress -O "$FILE_ARCHIVE" "$GH_DL_URL" || errexit "error downloading archive"

	sudo chmod 666 "$FILE_ARCHIVE"
	echo "Extracting files:"
	sudo tar -xvzf "$FILE_ARCHIVE" -C "$INSTALL_DIR"
	sudo chmod 755 "$FILE_BIN"
	sudo ln -s "$FILE_BIN" "$FILE_SYMLINK"
	sudo rm "$FILE_ARCHIVE"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | sudo tee "$FILE_CREATED_AT"
}

function hugo_update {
	# update is same as installation
	hugo_install
}

function hugo_remove {
	sudo rm "/bin/hugo"
	sudo rm -rf "/opt/hugo"
}

function hugo_config {
	echo "no confige defined"
}

function hugo_config_remove {
	echo "no confige defined"
}

##############
# end : hugo #
##############

####################
# start : lazygit #
####################

function lazygit_is_installed {
	if ! command -v lazygit &> "/dev/null"
	then
		# command not found, return 0
		return 0
	else
		# command found, return 1
		return 1
	fi
}

function lazygit_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset jesseduffield lazygit 'select(.name | contains("Linux_x86_64.tar.gz"))')
	if [[ -z "$GH_RESPONSE" ]]; then echo "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then echo "error getting created_at from github response"; exit 1; fi;
	echo "last updated: $GH_CREATED_AT"

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then echo "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then echo "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local FILE_ARCHIVE
	local FILE_BIN
	local FILE_CREATED_AT
	local FILE_SYMLINK
	INSTALL_DIR="/opt/lazygit"
	FILE_ARCHIVE="$INSTALL_DIR/lazygit.tar.gz"
	FILE_BIN="$INSTALL_DIR/lazygit"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="/bin/lazygit"

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
		sudo mkdir $INSTALL_DIR
	fi

	sudo wget -q --show-progress -O "$FILE_ARCHIVE" "$GH_DL_URL" || errexit "error downloading archive"

	sudo chmod 666 "$FILE_ARCHIVE"
	echo "Extracting files:"
	sudo tar -xvzf "$FILE_ARCHIVE" -C "$INSTALL_DIR"
	sudo chmod 755 "$FILE_BIN"
	sudo ln -s "$FILE_BIN" "$FILE_SYMLINK"
	sudo rm "$FILE_ARCHIVE"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | sudo tee "$FILE_CREATED_AT"
}

function lazygit_update {
	# update is same as installation
	lazygit_install
}

function lazygit_remove {
	sudo rm "/bin/lazygit"
	sudo rm -rf "/opt/lazygit"
}

function lazygit_config {
	echo "no confige defined"
}

function lazygit_config_remove {
	echo "no confige defined"
}

#################
# end : lazygit #
#################

####################
# start : marktext #
####################

function marktext_is_installed {
	if ! command -v marktext &> "/dev/null"
	then
		# command not found, return 0
		return 0
	else
		# command found, return 1
		return 1
	fi
}

function marktext_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset marktext marktext 'select(.name | contains("AppImage"))')
	if [[ -z "$GH_RESPONSE" ]]; then echo "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then echo "error getting created_at from github response"; exit 1; fi;
	echo "last updated: $GH_CREATED_AT"

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then echo "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then echo "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local DESKTOP_DIR
	local FILE_APPIMAGE
	local FILE_CREATED_AT
	local FILE_SYMLINK
	local FILE_DESKTOP
	local FILE_LOGO
	local FILE_SYMLINK_DESKTOP
	INSTALL_DIR="/opt/marktext"
	DESKTOP_DIR="$HOME/.local/share/applications"
	FILE_APPIMAGE="$INSTALL_DIR/marktext.AppImage"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_DESKTOP="$INSTALL_DIR/marktext.desktop"
	FILE_LOGO="$INSTALL_DIR/marktext_logo.png"
	FILE_SYMLINK="/bin/marktext"
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
		sudo mkdir $INSTALL_DIR
	fi

	sudo wget -q --show-progress -O "$FILE_APPIMAGE" "$GH_DL_URL" || errexit "error downloading archive"

	sudo chmod 755 "$FILE_APPIMAGE"
	sudo ln -s "$FILE_APPIMAGE" "$FILE_SYMLINK"
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | sudo tee "$FILE_CREATED_AT"
	# Create desktop file
	sudo tee "$FILE_DESKTOP"> /dev/null <<EOT
[Desktop Entry]
Name=MarkText
Comment=Next generation markdown editor
Exec=marktext %F
Terminal=false
Type=Application
Icon=/opt/marktext/marktext_logo.png
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
	sudo wget -q --show-progress -O "$FILE_LOGO" "https://raw.githubusercontent.com/marktext/marktext/develop/static/logo-small.png"
	sudo ln -s "$FILE_DESKTOP" "$FILE_SYMLINK_DESKTOP"
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

	sudo rm "/bin/marktext"
	sudo rm -rf "/opt/marktext"
	sudo rm "$FILE_SYMLINK_DESKTOP"

	update-desktop-database "$DESKTOP_DIR"
}

function marktext_config {
	echo "no confige defined"
}

function marktext_config_remove {
	echo "no confige defined"
}

##################
# end : marktext #
##################

##################
# start : golang #
##################

function golang_is_installed {
	if ! command -v go &> "/dev/null"
	then
		# command not found, return 0
		return 0
	else
		# command found, return 1
		return 1
	fi
}

function golang_install {
	local ARCH
	local MACHINE
	local GO_VER
	local INSTALL_DIR="/opt/go"
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
		echo "cleaning up previously downloaded archive..."
		sudo rm "$GO_TMP_ARCHIVE"
	fi

	# Download Golang binary archive in temporary folder
	sudo wget -q --show-progress -O "$GO_TMP_ARCHIVE" "$GO_DL_URL"

	if [ -d "$INSTALL_DIR" ]
	then
		sudo rm -rf "$INSTALL_DIR"
	fi
	sudo tar -C "/opt" -xzf "$GO_TMP_ARCHIVE"

	# Clean up archive file
	sudo rm $GO_TMP_ARCHIVE
}

function golang_update {
	local GO_VER_INSTALLED
	local GO_VER
	local INSTALL_DIR="/opt/go"
	if [ -e "$INSTALL_DIR/VERSION" ]
	then
		GO_VER_INSTALLED=$(cat "$INSTALL_DIR/VERSION" | head --lines 1)
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
	local INSTALL_DIR="/opt/go"
	if [ -d "$INSTALL_DIR" ]
	then
		sudo rm -rf "$INSTALL_DIR"
	fi
}

function golang_config {
	local CONFIG_FILE="$DIR_BASH_CONFIG/golang.sh"
	local INSTALL_DIR="/opt/go"
	tee "$CONFIG_FILE" > /dev/null <<EOT
#!/bin/bash

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

function neovim_is_installed {
	if ! command -v nvim &> "/dev/null"
	then
		# command not found, return 0
		return 0
	else
		# command found, return 1
		return 1
	fi
}

function neovim_install {
	local GH_RESPONSE
	local GH_CREATED_AT
	local GH_DL_URL
	local GH_SOURCE
	local GH_MSG

	GH_RESPONSE=$(func_github_asset neovim neovim 'select(.name == "nvim.appimage")')
	if [[ -z "$GH_RESPONSE" ]]; then echo "error fetching github response"; exit 1; fi;

	GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
	if [[ -z "$GH_CREATED_AT" ]]; then echo "error getting created_at from github response"; exit 1; fi;
	echo "last updated: $GH_CREATED_AT"

	GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
	if [[ -z "$GH_DL_URL" ]]; then echo "error getting download_url from github response"; exit 1; fi;

	GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
	if [[ -z "$GH_SOURCE" ]]; then echo "error getting source from github response"; exit 1; fi;

	GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

	local INSTALL_DIR
	local DESKTOP_DIR
	local FILE_APPIMAGE
	local FILE_CREATED_AT
	local FILE_SYMLINK
	local FILE_DESKTOP
	local FILE_LOGO
	local FILE_SYMLINK_DESKTOP
	INSTALL_DIR="/opt/neovim"
	FILE_APPIMAGE="$INSTALL_DIR/nvim.AppImage"
	FILE_CREATED_AT="$INSTALL_DIR/created_at"
	FILE_SYMLINK="/bin/nvim"

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
		sudo mkdir $INSTALL_DIR
	fi

	sudo wget -q --show-progress -O "$FILE_APPIMAGE" "$GH_DL_URL" || errexit "error downloading archive"

	sudo chmod 755 "$FILE_APPIMAGE"
	sudo ln -s "$FILE_APPIMAGE" "$FILE_SYMLINK"
	# in case libfuse2 is not installed, then extract binary from AppImage
	type -p libfuse2 || {
		echo "libfuse2 not found, extracting AppImage"
		local CURR_DIR="$PWD"
		cd "$INSTALL_DIR"
		echo "extracting AppImage contents"
		sudo "$FILE_APPIMAGE" --appimage-extract >/dev/null
		sudo rm "$FILE_SYMLINK"
		sudo ln -s "$INSTALL_DIR/squashfs-root/AppRun" "$FILE_SYMLINK"
		sudo rm "$FILE_APPIMAGE"
		cd "$CURR_DIR"
	}
	# Store created_at so that we can compare later for updating the app
	echo "$GH_CREATED_AT" | sudo tee "$FILE_CREATED_AT"
}

function neovim_update {
	# update is same as installation
	neovim_install
}

function neovim_remove {
	sudo rm "/bin/nvim"
	sudo rm -rf "/opt/neovim"
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
	else
		echo "config file not found: $PWD/nvim_config.lua"
	fi
}

function neovim_config_remove {
	sudo rm -rf "$HOME/.config/nvim"
	sudo rm -rf "$HOME/.local/share/nvim"
	sudo rm -rf "$HOME/.local/state/nvim"
}

################
# end : neovim #
################

################################
# start : custom bashrc config #
################################

function func_config_bash {
	local FILE_CONFIG="$DIR_BASH_CONFIG/custom_bashrc.sh"

	echo "writing to: $FILE_CONFIG"
	tee "$FILE_CONFIG" > "/dev/null" <<EOT
#!/bin/bash

func_fzf_px() {
	TMP_SELSECTED_PROCESS=\$(ps -aux | fzf | awk '\$2 ~ /^[0-9]+$/ { print \$2 }')
	if [ "\$TMP_SELSECTED_PROCESS" = "" ]
	then
		echo no process selected
	else
		read -p "Kill? (Y/n) " TMP_ANS
		case \$TMP_ANS in
			[Nn])
				echo will not kill
				;;
			*)
				echo killing pid: \$TMP_SELSECTED_PROCESS
				kill -s SIGKILL \$TMP_SELSECTED_PROCESS
				;;
			esac
	fi
}

func_lfcd () {
    cd "\$(command lf -single -print-last-dir "\$@")"
}

alias fd='cd \$(find . -maxdepth 1 -type d | sort | fzf)'
alias ll='ls -AlhFr'
alias llz='ls -AlhFr | sort | fzf'
alias fk='func_fzf_px'
alias lfcd='func_lfcd'
EOT
}

##############################
# end : custom bashrc config #
##############################

############################
# start : custom os config #
############################

function func_config_os {
	echo "applying kde configs"
	if command -v kwriteconfig5
	then
		echo "disabling activity tracking in settings"
		kwriteconfig5 --file kactivitymanagerdrc --group Plugins --key org.kde.ActivityManager.ResourceScoringEnabled --type bool false

		echo "disable certain KRunner searching sources"
		kwriteconfig5 --file krunnerrc --group Plugins --key appstreamEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key CharacterRunnerEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key baloosearchEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key bookmarksEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key browserhistoryEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key browsertabsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key calculatorEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key desktopsessionsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key DictionaryEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key helprunnerEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key katesessionsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key konsoleprofilesEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key krunner_spellcheckEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key kwinEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key locationsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key org.kde.activities2Enabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key org.kde.datetimeEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key org.kde.windowedwidgetsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key "PIM Contacts Search RunnerEnabled" --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key placesEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key plasma-desktopEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key recentdocumentsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key shellEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key unitconverterEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key webshortcutsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key windowsEnabled --type bool false

		echo "enable Night Color"
		kwriteconfig5 --file kwinrc --group NightColor --key Active --type bool true # Enable night color
		kwriteconfig5 --file kwinrc --group NightColor --key Mode Times # set mode custom time
		kwriteconfig5 --file kwinrc --group NightColor --key MorningBeginFixed 0800 # set start of morning
		kwriteconfig5 --file kwinrc --group NightColor --key EveningBeginFixed 1700 # set start of evening
		kwriteconfig5 --file kwinrc --group NightColor --key NightTemperature 5100 # set night temparature
	else
		echo "not found: kwriteconfig5"
	fi

	echo "disabling kactivitymanagerd"
	local DIR_KACTIVITYMANAGERD="$HOME/.local/share/kactivitymanagerd"
	if [[ -d "$DIR_KACTIVITYMANAGERD" ]]
	then
		rm -rf "$DIR_KACTIVITYMANAGERD"
		touch "$DIR_KACTIVITYMANAGERD"
	else
		echo "directory not found: $DIR_KACTIVITYMANAGERD"
	fi

	echo "disabling gnome/gtk recent files"
	if command -v gsettings
	then
		gsettings set org.gnome.desktop.privacy remember-recent-files false
		gsettings set org.gnome.desktop.privacy remember-app-usage false
		gsettings set org.gnome.desktop.privacy recent-files-max-age 0
	else
		echo "not found: gsettings"
	fi

	echo "deleting recent documents"
	local DIR_RECENTDOCUMENTS="$HOME/.local/share/RecentDocuments"
	if [[ -d "$DIR_RECENTDOCUMENTS" ]]
	then
		rm -rf "$DIR_RECENTDOCUMENTS"
		touch "$DIR_RECENTDOCUMENTS"
	else
		echo "directory not found: $DIR_RECENTDOCUMENTS"
	fi

	echo "deleting recently used history database"
	local FILE_RECENTDOCUMENTSXBEL="$HOME/.local/share/recently-used.xbel"
	if [[ -f "$FILE_RECENTDOCUMENTSXBEL" ]]
	then
		rm "$FILE_RECENTDOCUMENTSXBEL"
		mkdir "$FILE_RECENTDOCUMENTSXBEL"
	else
		echo "file not found: $FILE_RECENTDOCUMENTSXBEL"
	fi

	echo "deleting user places history database"
	local FILE_USERPLACESXBEL="$HOME/.local/share/user-places.xbel"
	if [[ -f "$FILE_USERPLACESXBEL" ]]
	then
		rm "$FILE_USERPLACESXBEL"
	else
		echo "file not found: $FILE_USERPLACESXBEL"
	fi


	local DIR_THUMBNAILSCACHE="$HOME/.cache/thumbnails"
	echo "deleting thumbnails in cache"
	if [[ -d "$DIR_THUMBNAILSCACHE" ]]
	then
		rm -rf "$DIR_THUMBNAILSCACHE"
		touch "$DIR_THUMBNAILSCACHE"
	else
		echo "directory not found: $DIR_THUMBNAILSCACHE"
	fi
}

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
	if [[ "$?" == 1 ]]
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
				echo "# $1:install:start #"
				run_func "${1}_install"
				echo "# $1:install:end #"

				echo "# $1:config:start #"
				run_func "${1}_config"
				echo "# $1:config:end #"

				break
				;;
			"update")
				echo "# $1:update:start #"
				run_func "${1}_update"
				echo "# $1:update:end #"

				break
				;;
			"set_config")
				echo "# $1:config_remove:start #"
				run_func "${1}_config_remove"
				echo "# $1:config_remove:end #"

				echo "# $1:config:start #"
				run_func "${1}_config"
				echo "# $1:config:end #"

				break
				;;
			"remove_config")
				echo "# $1:config_remove:start #"
				run_func "${1}_config_remove"
				echo "# $1:config_remove:end #"

				break
				;;
			"remove")
				echo "# $1:remove:start #"
				run_func "${1}_remove"
				echo "# $1:remove:end #"

				echo "# $1:config_remove:start #"
				run_func "${1}_config_remove"
				echo "# $1:config_remove:end #"

				break
				;;
			"back")
				break
				;;
			*) echo "invalid command: $REPLY";;
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
		if [[ $IS_INSTALLED == 1 ]]
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
			echo "invalid app: $REPLY"
		else
			menu_manage_app "$SELECTED_APP"
		fi
	done
}

# This is the main menu where operations will be selected
function menu_main {
	local PS3=$'select operation: '
	local options=("manage apps" "config bash" "config_os" "quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"manage apps")
				menu_apps
				;;
			"config bash")
				func_config_bash
				;;
			"config_os")
				func_config_os
				;;
			"quit")
				break
				;;
			*) echo "invalid operation $REPLY";;
		esac
	done
}

echo "=================="
echo "= app operations ="
echo "=================="

# setup bash configurations
setup_bash_config
# run main menu function
menu_main

#############
# Resources #
#############
# Bash functions: https://linuxize.com/post/bash-functions/
#
