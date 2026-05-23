#!/usr/bin/env bash

case "$OSTYPE" in
    linux*)   MACHINE=linux ;;
    darwin*)  MACHINE=darwin ;;
    *)        echo "Unknown OS: $OSTYPE" ;;
esac

DEV_USER=dev
CONTAINER_TAG=devcontainer/debian
CLAUDE_SETUP="false"
DOCKERFILE="./dev-debian.Dockerfile"
ROOTFS="./rootfs" # should be relative to build context, update .gitignore and Dockerfile as well when this changes
DOCKER_CTX="."
USER_ID=1000
GROUP_ID=1000

if [ "$MACHINE" == "linux" ]; then
    echo "[ info ] current system is linux"
    echo "[ info ] setting user and group id from system"
    USER_ID=$(id -u)
    GROUP_ID=$(id -g)
elif [ "$MACHINE" == "darwin" ]; then
    echo "[ info ] current system is darwin"
    echo "[ info ] setting user id from system"
    USER_ID=$(id -u)
fi

function usage() {
    if [ -n "$1" ]; then
        echo -e "[ error ] $1\n";
    fi
    echo "build debian container for development"
    echo ""
    echo "Usage: $(basename "$0") [--claude] [-y]"
    echo "To copy files into container, place them in: $ROOTFS"
    echo ""
    echo "  --claude      build for claude ai"
    echo ""
    echo "  -y            always yes for confirmation"
    echo ""
    exit 1
}

function print_env() {
    echo "DEV_USER=$DEV_USER"
    echo "CONTAINER_TAG=$CONTAINER_TAG"
    echo "CLAUDE_SETUP=$CLAUDE_SETUP"
    echo "DOCKERFILE=$DOCKERFILE"
    echo "DOCKER_CTX=$DOCKER_CTX"
    echo "ROOTFS=$ROOTFS"
    echo "USER_ID:$USER_ID"
    echo "GROUP_ID:$GROUP_ID"
}

# if [ $# -eq 0 ]; then
#     usage "no arguments provided."
# fi

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    --claude) CLAUDE_SETUP="true"; shift;;
    -y) CONFIRM_YES="true"; shift;;
    *) echo "[ error ] invalid arguments: $1"; shift;;
esac; done

if [ "$CLAUDE_SETUP" == "true" ]; then CONTAINER_TAG="$CONTAINER_TAG/claude"; fi;

if ! [ -f "$DOCKERFILE" ]; then echo "[ error ] file not found: $DOCKERFILE"; exit 1; fi
if ! [ -d "$ROOTFS" ]; then mkdir -p $ROOTFS; fi

print_env

if ! [ "$CONFIRM_YES" == "true" ]; then read -p "press enter to continue"; fi;

if command -v podman &> /dev/null
then
  podman build \
    --build-arg DEV_USER="$DEV_USER" \
    --build-arg CLAUDE_SETUP="$CLAUDE_SETUP" \
    --build-arg USER_ID="$USER_ID" \
    --build-arg GROUP_ID="$GROUP_ID" \
    -t "$CONTAINER_TAG" \
    -f "$DOCKERFILE" "$DOCKER_CTX" \
    ;
elif command -v podman &> /dev/null
then
  docker build \
    --build-arg DEV_USER="$DEV_USER" \
    --build-arg CLAUDE_SETUP="$CLAUDE_SETUP" \
    --build-arg USER_ID="$USER_ID" \
    --build-arg GROUP_ID="$GROUP_ID" \
    -t "$CONTAINER_TAG" \
    -f "$DOCKERFILE" "$DOCKER_CTX" \
    ;
fi