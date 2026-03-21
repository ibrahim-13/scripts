#!/usr/bin/env bash

function usage() {
    if [ -n "$1" ]; then
        echo -e "[ error ] $1\n";
    fi
    echo "start debian container for development"
    echo ""
    echo "Usage: $(basename "$0") [-m|--mount directory]"
    echo ""
    echo "  -m|--mount      project directory to mount"
    echo ""
    echo "  --claude        use container for claude"
    echo "  --claude-dir    directory for claude settings"
    echo ""
    exit 1
}

if [ $# -eq 0 ]; then
    usage "no arguments provided."
fi

DEV_USER=dev
CLAUDE_CONTAINER="false"

function print_env() {
    echo "DEV_USER=$DEV_USER"
    echo "CLAUDE_CONTAINER=$CLAUDE_CONTAINER"
}

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -m|--mount) DIR_TO_MOUNT=$2; shift; shift;;
    --claude) CLAUDE_CONTAINER="true"; shift;;
    ---claude-dir) CLAUDE_SETTINGS_DIR=$2; shift; shift;;
    *) echo "invalid arguments: $1"; shift;;
esac; done

if [ ! -d "$DIR_TO_MOUNT" ]; then
  usage "mount location is not a directory"
fi

if [ "$CLAUDE_CONTAINER" == "true" ] && [ ! -d "$CLAUDE_SETTINGS_DIR" ]; then usage "claude setting location is not a directory"; fi;

if ! [ -f ./dev-debian.compose ]; then echo "dev-debian.compose file not found"; exit 1; fi

COMPOSE_PROFILE=default

if [ "$CLAUDE_CONTAINER" == "true" ] ; then COMPOSE_PROFILE=claude; fi;

print_env

if command -v podman &> /dev/null
then
  MOUNT_DIR="$DIR_TO_MOUNT" DEV_USER="$DEV_USER" podman \
    compose \
    -f dev-debian.compose \
    --profile $COMPOSE_PROFILE \
    up -d \
    ;
elif command -v docker &> /dev/null
then
  MOUNT_DIR="$DIR_TO_MOUNT" DEV_USER="$DEV_USER" docker \
    compose \
    -f dev-debian.compose \
    --profile $COMPOSE_PROFILE \
    up -d \
    ;
fi