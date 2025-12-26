#!/usr/bin/env bash

set -o allexport
source .env
set +o allexport

REGISTERED_OPT=""

function register_opt {
	if [[ "$REGISTERED_OPT" == "" ]]
	then
		REGISTERED_OPT="$1"
	else
		REGISTERED_OPT="$REGISTERED_OPT:$1"
	fi
}

function compose_up {
  if command -v docker &> /dev/null
  then
    docker compose up -d
  elif podman -v docker &> /dev/null
    podman compose up -d
  else
    echo "no container runtime"
  fi
}
register_opt compose_up

function connect_to_container {
  read -p "container name/id: " CONTAINER_NAME

  if command -v docker &> /dev/null
  then
    docker exec -it "$CONTAINER_NAME"
  elif podman -v docker &> /dev/null
    podman exec -it "$CONTAINER_NAME"
  else
    echo "no container runtime"
  fi
}
register_opt connect_to_container

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

echo "=============="
echo "= debian dev ="
echo "=============="
menu_opts