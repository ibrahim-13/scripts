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

###########################
# end : utility functions #
###########################

register_app tmux
register_app lf

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
	echo "ggwp"
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

################################
# start : custom bashrc config #
################################

function func_config_bash {
local ALIAS_STR_START="# START:CUSTOM_ALIAS_SOURCE"
local ALIAS_STR_END="# END:CUSTOM_ALIAS_SOURCE"
local FILE_CONFIG="$HOME/.custom_bashrc"
local FILE_BASHRC="$HOME/.bashrc"

if [ -f "$FILE_BASHRC" ]
then {
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
		if grep -Fxq "$ALIAS_STR_START" "$FILE_BASHRC" && grep -Fxq "$ALIAS_STR_END" "$FILE_BASHRC"
		then
			echo "config file already sourced: $FILE_BASHRC"
		else
			echo "appending to bashrc: $FILE_BASHRC"
			cat <<EOF >> "$FILE_BASHRC"
$ALIAS_STR_START

if [ -f $FILE_CONFIG ]; then
    . $FILE_CONFIG
fi

$ALIAS_STR_END
EOF
		fi
	}
	else {
		echo "err ! not found $FILE_BASHRC"
		exit 1
	}
	fi
}

##############################
# end : custom bashrc config #
##############################

#############################
# start : custom kde config #
#############################

function func_config_kde {
	echo "applying kde configs"
	if command -v kwriteconfig5
	then
		echo "disabling activity tracking in settings"
		kwriteconfig5 --file kactivitymanagerdrc --group Plugins --key org.kde.ActivityManager.ResourceScoringEnabled --type bool false

		echo "disable certain KRunner searching sources"
		kwriteconfig5 --file krunnerrc --group Plugins --key "PIM Contacts Search RunnerEnabled" --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key appstreamEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key baloosearchEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key browserhistoryEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key locationsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key recentdocumentsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key webshortcutsEnabled --type bool false

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
		touch "$FILE_RECENTDOCUMENTSXBEL"
		sudo chattr +i "$FILE_RECENTDOCUMENTSXBEL"
	else
		echo "file not found: $FILE_RECENTDOCUMENTSXBEL"
	fi

	echo "deleting user places history database"
	local FILE_USERPLACESXBEL="$HOME/.local/share/user-places.xbel"
	if [[ -f "$FILE_USERPLACESXBEL" ]]
	then
		rm "$FILE_USERPLACESXBEL"
		touch "$FILE_USERPLACESXBEL"
		sudo chattr +i "$FILE_USERPLACESXBEL"
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

###########################
# end : custom kde config #
###########################

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
		echo "app: $app"
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
	local options=("manage apps" "config bash" "config_kde" "quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"manage apps")
				menu_apps
				;;
			"config bash")
				func_config_bash
				;;
			"config_kde")
				func_config_kde
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

menu_main

#############
# Resources #
#############
# Bash functions: https://linuxize.com/post/bash-functions/
#
