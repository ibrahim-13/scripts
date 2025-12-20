#!/usr/bin/env bash

# print error msg and exit
# $1 : error msg
function errexit {
	echo "[ error ] $1" >&2
	exit 1
}

########
# MAIN #
########

function usage() {
    if [ -n "$1" ]; then
        echo -e "[ error ] $1\n";
    fi
    echo "Mount virtio-9p shared devices inside qemu virtual machine"
    echo ""
    echo "Usage: $(basename "$0") [-t|--target] TARGET_PATH [-m|--mount-dir MOUNT_DIRECTORY]"
    echo ""
    echo "  -t, --target         virtio-9p target path"
    echo "  -m, --mount-dir      mount directory"
    echo ""
    exit 1
}

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -t|--target) ARG_TARGET_PATH="$2"; shift; shift;;
    -t|--mount-dir) ARG_MOUNT_DIR="$2"; shift; shift;;
    *) usage "invalid arguments";;
esac; done

if [ -z "$ARG_TARGET_PATH" ]; then usage "virtio-9p target path is required"; fi;
if [ -z "$ARG_MOUNT_DIR" ]; then usage "mount directory is required"; fi;

echo "mounting $ARG_TARGET_PATH to $ARG_MOUNT_DIR"
# https://wiki.qemu.org/Documentation/9psetup
# https://www.linux-kvm.org/page/9p_virtio
sudo mkdir -p "$ARG_MOUNT_DIR"
sudo mount -t 9p -o trans=virtio "$ARG_TARGET_PATH" "$ARG_MOUNT_DIR" -oversion=9p2000.L || errexit "error mounting virio-9p target"
