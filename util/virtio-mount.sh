#!/usr/bin/env bash

function print_info {
    echo "[ info  ] $1"
}

function print_err {
    echo "[ error ] $1"
}

# print error msg and exit
# $1 : error msg
function errexit {
	print_err "$1" >&2
	exit 1
}

# find if line exists in the file
# $1: text to find
# $2: file to search
function line_exists {
  if grep -qFx "$1" "$2"; then
    return 0
  else
    return 1
  fi
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
    echo "Usage: $(basename "$0") [-t|--target] TARGET [-m|--mount-dir MOUNT_DIRECTORY]"
    echo ""
    echo "  -t, --target         target/label"
    echo "  -m, --mount-dir      mount directory"
    echo "  --fstab              add entry to /etc/fstab"
    echo ""
    exit 1
}

if [ $# -eq 0 ]; then
    usage  "no arguments provided."
fi

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -t|--target) ARG_TARGET_PATH="$2"; shift; shift;;
    -m|--mount-dir) ARG_MOUNT_DIR="$2"; shift; shift;;
    --fstab) ARG_FSTAB="true"; shift;;
    *) usage "invalid arguments";;
esac; done

if [ -z "$ARG_TARGET_PATH" ]; then usage "target is required"; fi;
if [ -z "$ARG_MOUNT_DIR" ]; then usage "mount directory is required"; fi;

echo "mounting $ARG_TARGET_PATH to $ARG_MOUNT_DIR"
# https://wiki.qemu.org/Documentation/9psetup
# https://www.linux-kvm.org/page/9p_virtio
sudo mkdir -p "$ARG_MOUNT_DIR"
print_info "trying to mount as virtiofs"
sudo mount -t virtiofs "$ARG_TARGET_PATH" "$ARG_MOUNT_DIR"
if [ $? -ne 0 ]; then
    print_err "failed to mount as virtiofs"
    print_info "trying to mount as virtio-9p"
    sudo mount -t 9p -o trans=virtio "$ARG_TARGET_PATH" "$ARG_MOUNT_DIR" -oversion=9p2000.L || errexit "failed to mount as virio-9p"
    if [ "$ARG_FSTAB" == "true" ]; then
        local FSTAB_ENTRY="$ARG_TARGET_PATH $ARG_MOUNT_DIR 9p trans=virtio,version=9p2000.L 0 0"
        if ! line_exists "$FSTAB_ENTRY" /etc/fstab; then
            print_info "fstab entry already exists for virtio-9p"
        else
            sudo tee -a /etc/fstab > /dev/null <<EOT
$FSTAB_ENTRY
EOT
        fi
    fi
else
    if [ "$ARG_FSTAB" == "true" ]; then
        local FSTAB_ENTRY="$ARG_TARGET_PATH $ARG_MOUNT_DIR virtiofs defaults 0 0"
        if ! line_exists "$FSTAB_ENTRY" /etc/fstab; then
            print_info "fstab entry already exists for virtiofs"
        else
            sudo tee -a /etc/fstab > /dev/null <<EOT
$FSTAB_ENTRY
EOT
        fi
    fi
fi
