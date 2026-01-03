#!/usr/bin/env bash

SCRIPT_SOURCE=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )
  SCRIPT_SOURCE=$(readlink "$SCRIPT_SOURCE")
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE=$SCRIPT_DIR/$SCRIPT_SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )

set -o allexport
source .env
set +o allexport

function compose_up {
  if command -v docker &> /dev/null
  then
    docker compose up -d -f "$SCRIPT_DIR/debian.compose"
  elif podman -v docker &> /dev/null
    podman compose up -d -f "$SCRIPT_DIR/debian.compose"
  else
    echo "no container runtime"
		exit 1
  fi
}

function compose_down {
  if command -v docker &> /dev/null
  then
    docker compose down -f "$SCRIPT_DIR/debian.compose"
  elif podman -v docker &> /dev/null
    podman compose down -f "$SCRIPT_DIR/debian.compose"
  else
    echo "no container runtime"
		exit 1
  fi
}

function list_containers {
  if command -v docker &> /dev/null
  then
    docker ls
  elif podman -v docker &> /dev/null
    podman ls
  else
    echo "no container runtime"
		exit 1
  fi
}

function container_setup {
	sudo apt update

  if ! command -v which &> /dev/null
  then
    echo "installing which"
    sudo apt install which -y
  fi

  echo "installing openssh server"
  sudo apt install openssh-server -y
}

function container_status {
  sudo systemctl status ssh
}

function container_restart {
	echo "restarting ssh server"
  sudo systemctl restart ssh
}

function container_config {
  echo "enable the following options in the configuration file: /etc/ssh/sshd_config"
  echo "Port 22"
  echo "PermitRootLogin yes"
  read -p "press any key to edit" TMP
  sudo vi /etc/ssh/sshd_config

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

function connect_to_container {
  if command -v docker &> /dev/null
  then
    docker exec -it "$1" /bin/bash
  elif podman -v docker &> /dev/null
    podman exec -it "$1" /bin/bash
  else
    echo "no container runtime"
		exit 1
  fi
}

########
# MAIN #
########

function usage() {
    if [ -n "$1" ]; then
        echo -e "[ error ] $1\n";
    fi
    echo "manage debian container for development"
		echo "note: container commands are usually supposed to run inside the container"
    echo ""
    echo "Usage: $(basename "$0") [host|container]"
    echo ""
    echo "  up             start containers"
    echo "  down           stop containers"
    echo "  ls             list containers"
    echo "  connect NAME   connect to a container"
    echo ""
		echo "  container"
    echo "        setup          install necessary components"
    echo "        status         show ssh server systemd status"
    echo "        restart        restart ssh server"
    echo "        config         configure ssh server"
    echo "                -p|--passwd         user password"
    echo ""
    exit 1
}

function container() {
	while [[ "$#" > 0 ]]; do case $1 in
			setup) container_setup; exit 0;;
			status) container_status; exit 0;;
			restart) container_restart; exit 0;;
			config) container_config; exit 0;;
			*) usage "invalid arguments"; exit 1;;
	esac; done
}

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    up) compose_up; exit 0;;
    down) compose_down; exit 0;;
    ls) list_containers; exit 0;;
    connect) connect_to_container "$2"; exit 0;;
    container) shift; container; exit 0;;
    *) usage "invalid arguments"; exit 1;;
esac; done
