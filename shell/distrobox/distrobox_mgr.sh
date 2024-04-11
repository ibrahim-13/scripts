#!/usr/bin/env bash

REGISTERED_OPT=""

SCRIPT_SOURCE=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )
  SCRIPT_SOURCE=$(readlink "$SCRIPT_SOURCE")
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE=$SCRIPT_DIR/$SCRIPT_SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )

function register_opt {
	if [[ "$REGISTERED_OPT" == "" ]]
	then
		REGISTERED_OPT="$1"
	else
		REGISTERED_OPT="$REGISTERED_OPT:$1"
	fi
}

# prompt for confirmation of an action
# $1 : message
# returns 1 if yes, 0 if no
function prompt_confirmation {
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

function setup_devenv {
	local DEVENV_HOME="$HOME/devenv"
	local SHARED_PROJECTS_SRC="$HOME/Projects"
	local SHARED_PROJECTS_DEST="$DEVENV_HOME/Projects"
	echo "setting up devenv: $CONFIG_OUTPUT_FILE"
	mkdir -p "$DEVENV_HOME"
	mkdir -p "$SHARED_PROJECTS_DEST"
	echo "copying setup script: $DEVENV_HOME/devenv-setup.sh"
	cp "$SCRIPT_DIR/devenv-setup.sh" "$DEVENV_HOME/devenv-setup.sh"
	echo "creating devenv"
	# --no-entry: do not generate container entry in app list
	# --init: use with container that has init system
	# --nvidia: use with container that has nvidia drivers
	distrobox create --image "ubuntu:jammy" \
		--name devenv \
		--pull \
		--home "$DEVENV_HOME" \
		--volume "$SHARED_PROJECTS_SRC:$SHARED_PROJECTS_DEST:rw" \
		--verbose
}
register_opt setup_devenv

function remove_devenv {
	local DEVENV_HOME="$HOME/devenv"
	local CONFIG_OUTPUT_DIR="$HOME/.config/distrobox"
	if prompt_confirmation "remove devenv?"
	then
		echo "removing devenv assembly"
		distrobox rm devenv --force --verbose
	fi
	rm -rf "$CONFIG_OUTPUT_DIR"
}
register_opt remove_devenv

# sometimes, the root is not mounted as shared mount,
# this is required for some system file mapping
function remount_root_as_shared {
	if prompt_confirmation "make root mountponit as shared?"
	then
		echo "mounting root filesystem as sharabe"
		mount --make-rshared /
	else
		echo "root filesystem won't be mounted as sharable"
	fi
}
register_opt remount_root_as_shared

# Menu for managing apps installation
function menu_opts {
	register_opt "quit"
	local PS3='select opt: '
	local APPS_LIST=
	local IFS=':'
	read -ra APPS_LIST <<< "$REGISTERED_OPT"
	echo $APPS_LIST
	select opt in "${APPS_LIST[@]}"
	do
		if [[ $opt == "quit" ]]
		then
			break
		fi
		if [[ $opt == "" ]] || [[ ! $APPS_LIST == *"$APPS_LIST"* ]]
		then
			echo "invalid opt: $REPLY"
		else
			$opt
		fi
	done
}

echo "=============="
echo "= operations ="
echo "=============="

# run main menu function
menu_opts
