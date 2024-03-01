#!/bin/bash

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
function register_app {
	if [[ $REGISTERED_APPS == "" ]]
	then
		REGISTERED_APPS=$1
	else
		REGISTERED_APPS=$REGISTERED_APPS":$1"
	fi
}

register_app tmux
register_app lf

################
# start : tmux #
################

function tmux_is_installed {
	if ! command -v tmux &> /dev/null
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
	if ! command -v git &> /dev/null
	then
		echo "git not installed, required for config"
		return
	fi
	local CONFIG_DIR="$HOME/.config/tmux"
	local CONFIG_FILE="$CONFIG_DIR/tmux.conf"
	local PLUGIN_DIR="$HOME/.tmux/plugins/tpm"
	
	if [[ ! -d $CONFIG_DIR ]]; then mkdir $CONFIG_DIR; fi;

	git clone https://github.com/tmux-plugins/tpm $PLUGIN_DIR
	tee $CONFIG_FILE > /dev/null <<EOT
# https://github.com/dreamsofcode-io/tmux/blob/main/tmux.conf

# enable 24bit color
set-option -sa terminal-overrides ",xterm*:Tc"
# enable mouse support
set -g mouse on

# remap binding from CTRL-b to CTRL-space
# unbind C-b
# set -g prefix C-Space
# bind C-Space send-prefix

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
# set-window-option -g mode-keys vi
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

	if [[ -d $CONFIG_DIR ]]; then rm -rf $CONFIG_DIR; fi;
	if [[ -d $PLUGIN_DIR ]]; then rm -rf $PLUGIN_DIR; fi;
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
		return 0
	else
		return 1
	fi
}
function lf_install {
	echo "tbd"
}
function lf_update {
	echo "tbd"
}
function lf_remove {
	echo "tbd"
}

############
# end : lf #
############

function menu_manage_app {
	if [[ $1 == "" ]]; then echo "invalid app: $1"; exit 1; fi;

	local PS3=$"[$1] select command: "
	local IFS=':'
	local available_app_opts="set_config:remove_config:remove:back"
	local CMD=$1"_is_installed"
	$CMD
	if [[ "$?" == 1 ]]
	then
		local available_app_opts="update:"$available_app_opts
	else
		local available_app_opts="install:"$available_app_opts
	fi
	local options=($available_app_opts)
	select opt in "${options[@]}"
	do
		case $opt in
			"install")
				local CMD=$1"_install"
				$CMD
				local CMD=$1"_config"
				$CMD
				break
				;;
			"update")
				local CMD=$1"_update"
				$CMD
				break
				;;
			"set_config")
				local CMD=$1"_config_remove"
				$CMD
				local CMD=$1"_config"
				$CMD
				break
				;;
			"remove_config")
				local CMD=$1"_config_remove"
				$CMD
				break
				;;
			"remove")
				local CMD=$1"_remove"
				$CMD
				local CMD=$1"_config_remove"
				$CMD
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
	local apps_list=
	local menu_opts=""
	local IFS=':'
	read -ra apps_list <<< $REGISTERED_APPS
	for app in "${apps_list[@]}"
	do
		local CMD=$app"_is_installed"
		$CMD
		local IS_INSTALLED=$?
		if [[ $IS_INSTALLED == 1 ]]
		then
			local menu_opts=$menu_opts"[X] $app:"
		else
			local menu_opts=$menu_opts"[ ] $app:"
		fi
	done
	local menu_opts=$menu_opts"<-- back"
	local options=($menu_opts)
	select opt in "${options[@]}"
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
			menu_manage_app $SELECTED_APP
		fi
	done
}

# This is the main menu where operations will be selected
function menu_main {
	local PS3=$'select operation: '
	local options=("manage apps" "quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"manage apps")
				menu_apps
				;;
			"quit")
				break
				;;
			*) echo "invalid operation $REPLY";;
		esac
	done
}

echo ==================
echo = app operations =
echo ==================

menu_main

#############
# Resources #
#############
# Bash functions: https://linuxize.com/post/bash-functions/
#
