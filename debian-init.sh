#!/usr/bin/env bash

REGISTERED_OPT=""

function register_opt {
	if [[ "$REGISTERED_OPT" == "" ]]
	then
		REGISTERED_OPT="$1"
	else
		REGISTERED_OPT="$REGISTERED_OPT:$1"
	fi
}

function install_which {
  if ! command -v which &> /dev/null
  then
    echo "installing which"
    sudo apt update
    sudo apt install which -y
  fi
}
register_opt install_which

function install_openssh_server {
  echo "installing openssh server"
  sudo apt update
  sudo apt install openssh-server -y
}
register_opt install_openssh_server

function openssh_server_status {
  sudo systemctl status ssh
}
register_opt openssh_server_status

function openssh_server_restart {
  sudo systemctl restart ssh
}
register_opt openssh_server_restart

function openssh_server_configure {
  echo "enable the following options in the configuration file: /etc/ssh/sshd_config"
  echo "Port 22"
  echo "PermitRootLogin yes"
  read -p "press any key to edit" TMP
  sudo vi /etc/ssh/sshd_config
}
register_opt openssh_server_configure

function openssh_server_keygen {
  echo "generating all keys for ssh server"
  sudo ssh-keygen -A

  if ! command -v passwd &> /dev/null
  then
    echo "installing passwd"
    sudo apt update
    sudo apt install which -y
  fi

  read -p "setting password for root, press any key to continue"
  passwd root
}
register_opt openssh_server_keygen

function menu_opts {
	register_opt "quit"
	local PS3='select opt: '
	local APPS_LIST=
	local IFS=':'
	read -ra APPS_LIST <<< "$REGISTERED_OPT"
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

echo "==============="
echo "= debian init ="
echo "==============="
menu_opts