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

# promt for confirmation of an action
# $1 : message
# returns 1 if yes, 0 if no
function promt_confirmation {
	local TMP_ANS
	read -p "${1} (y/N) " TMP_ANS
	case $TMP_ANS in
	[Yy])
		return 1
		;;
	*)
		return 0
		;;
	esac
}

function setup_devenv {
	local DEVENV_HOME="$HOME/devenv"
	local CONFIG_OUTPUT_DIR="$HOME/.config/distrobox"
	local CONFIG_OUTPUT_FILE="$CONFIG_OUTPUT_DIR/devenv.ini"
	local SHARED_PROJECTS_SRC="$HOME/Projects"
	local SHARED_PROJECTS_DEST="$DEVENV_HOME/Projects"
	echo "setting up devenv: $CONFIG_OUTPUT_FILE"
	mkdir -p "$DEVENV_HOME"
	mkdir -p "$CONFIG_OUTPUT_DIR"
	mkdir -p "$SHARED_PROJECTS_SRC"
	mkdir -p "$SHARED_PROJECTS_DEST"
	cp "$SCRIPT_DIR/devenv-pre-init.sh" "$DEVENV_HOME/devenv-pre-init.sh"
	cat > "$CONFIG_OUTPUT_FILE" <<EOT
[devenv]
home="$DEVENV_HOME"
image=ubuntu:22.04
nvidia=true
init=false
start_now=false
pull=true
root=false
replace=true
pre_init_hooks="\$HOME/devenv-pre-init.sh" # add external repositories
additional_packages="openssl git git-credential-libsecret" # system apps
additional_packages="gh codium" # development apps
init_hooks="codium --install-extension mhutchie.git-graph" # install git graph extension in vscoium
init_hooks="codium --install-extension golang.go" # install golang extension in vscoium
volume="$SHARED_PROJECTS_SRC:\$HOME/Projects"
EOT
}
register_opt setup_devenv

# sometimes, the root is not mounted as shared mount,
# this is required for some system file mapping
function remount_root_as_shared {
	promt_confirmation "make root mountponit as shared?" && {
		echo "mounting root filesystem as sharabe"
		mount --make-rshared /
	} || echo "root filesystem won't be mounted as sharable"
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
