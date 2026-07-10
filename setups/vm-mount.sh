#!/usr/bin/env bash

# -e exit on error
# -u error on using unset variable
# -x print full command before running
# set -eux
set -eu

# Debugging
# ---------
# set -x : print out every line as it executes, with variables expanded
#		putting it at top of the script will enable this for the whole
#		script, or before a block of commands and end it with:
#		{ set +x; } 2>/dev/null
#
# bash -x script.sh : same as putting set -x at the top of script
# trap read DEBUG : stop before every line, can be put at the top
# trap '(read -p "[$BASE_SOURCE:$lineno] $bash_command")' DEBUGDIR_TMP="$HOME/.tmp"

function prompt_confirmation {
  if [ "$2" == "true" ]; then return 0; fi
	local TMP_ANS
	read -p "[ prompt ] $(echo -e -n " ${1} (y/N) ")" TMP_ANS
	case $TMP_ANS in
    [Yy]) return 0 ;;
    *) return 1 ;;
	esac
}

# find if line exists in the file
# $1: text to find
# $2: file to search
function line_exists {
  if grep -qFx "$1" "$2"; then return 0; else return 1; fi
}

# check if directory is already mounted
# $1: mount directory
function mount_exists {
  if grep -q "[[:space:]]$1[[:space:]]" /proc/mounts; then return 0; else return 1; fi
}

function print_info {
  echo "[ info   ] $1"
}

function print_warn {
  echo "[ warn   ] $1"
}

function print_err {
  echo "[ error  ] $1" >&2
}

########
# MAIN #
########

function usage() {
    if [ -n "$1" ]; then
        echo -e "[ error ] $1\n";
    fi
    echo "setup virtio-9p shared directory for vm"
    echo ""
    echo "Usage: $(basename "$0") [-y] [-h|--help]"
    echo ""
    echo "  -l|--label          virtio device label"
    echo "  -m|--mount          mount directory"
    echo "  -mm|--map-mount     mapped mount directory"
    echo "  -y                  confirm everything as yes"
    echo " -h|--help            show help"
    echo ""
    exit 1
}

ARG_CONFIRM="false"
ARG_LABEL=""
ARG_MOUNT=""
ARG_MAP_MOUNT=""

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -y) ARG_CONFIRM="true"; shift; shift;;
    -l|--label) ARG_LABEL="$2"; shift; shift;;
    -m|--mount) ARG_MOUNT="$2"; shift; shift;;
    -mm|--map-mount) ARG_MAP_MOUNT="$2"; shift; shift;;
    -h|--help) usage;;
    *) usage "invalid arguments";;
esac; done

if [ -z $ARG_LABEL ]; then usage "label is required"; fi
if [ -z $ARG_MOUNT ]; then usage "mount directory is required"; fi
if [ -z $ARG_MAP_MOUNT ]; then usage "mount mapping directory is required"; fi

if mount_exists "$ARG_MOUNT"; then print_err "directory already mounted: $ARG_MOUNT"; exit 1; fi
if mount_exists "$ARG_MAP_MOUNT"; then print_err "directory already mounted: $ARG_MOUNT"; exit 1; fi

if prompt_confirmation "install fuse and bindfs?" $ARG_CONFIRM; then
  sudo dnf install fuse bindfs
  print_info "packages updated"
fi

sudo mkdir -p "$ARG_MOUNT"
sudo mkdir -p "$ARG_MAP_MOUNT"

sudo mount -t 9p -o trans=virtio "$ARG_LABEL" "$ARG_MOUNT" -oversion=9p2000.L
if ! [ "$?" == "0" ]; then print_err "could not mount directory, aborting"; exit 1; fi

MOUNT_UID=$(ls -nd "$ARG_MOUNT" | awk '{print $3}')
MOUNT_GID=$(ls -nd "$ARG_MOUNT" | awk '{print $4}')

if [ -z "$MOUNT_UID" ]; then print_err "unable to get user id of the mounted directory"; exit 1; fi
if [ -z "$MOUNT_GID" ]; then print_err "unable to get group id of the mounted directory"; exit 1; fi

USER_ID=$( id -u )
GROUP_ID=$( id -g )
LINE_A="$ARG_LABEL $ARG_MOUNT 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail,auto 0 0"
LINE_B="$ARG_MOUNT $ARG_MAP_MOUNT fuse.bindfs map=$MOUNT_UID/$USER_ID:@$MOUNT_GID/@$GROUP_ID,x-systemd.requires=$ARG_MOUNT,_netdev,nofail,auto 0 0"

if ! line_exists "$LINE_A" /etc/fstab; then
  sudo tee -a /etc/fstab > /dev/null <<EOT
$LINE_A
EOT
else
  print_info "mount entry already exists is /etc/fstab"
fi

if ! line_exists "$LINE_B" /etc/fstab; then
  sudo tee -a /etc/fstab > /dev/null <<EOT
$LINE_B
EOT
else
  print_info "mapped mount entry already exists is /etc/fstab"
fi

print_info "unmounting: $ARG_MOUNT"
sudo umount "$ARG_MOUNT"

print_warn "reboot required for the changes to take effect"
