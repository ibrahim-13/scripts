#!/usr/bin/env bash

# Mount a virtio shared folder inside a QEMU/UTM virtual machine.
#
# Supports both virtiofs and virtio-9p transports, with optional bindfs
# UID/GID remapping (9p only) and optional /etc/fstab persistence.
#
# Merged from virtio-mount.sh (virtiofs->9p auto-fallback) and
# vm-mount.sh (9p + bindfs remapping). See virtio-mount-mac.md for the
# background on the bindfs technique.
#
# Type selection:
#   - no --type, no --map-mount : try virtiofs, fall back to 9p
#   - --map-mount given         : force 9p (bindfs remapping is 9p-only)
#   - --type given              : force that transport, no fallback
#
# Debugging
# ---------
# set -x : print out every line as it executes, with variables expanded.
# bash -x mount.sh : same as putting set -x at the top of the script.

set -euo pipefail

########
# LOG  #
########

function print_info {
  echo "[ info  ] $1"
}

function print_warn {
  echo "[ warn  ] $1"
}

function print_err {
  echo "[ error ] $1" >&2
}

# print error msg and exit
# $1 : error msg
function errexit {
  print_err "$1"
  exit 1
}

########
# UTIL #
########

# prompt for confirmation, auto-yes when confirm flag is set
# $1: prompt message
# returns 0 on yes, 1 on no
function prompt_confirmation {
  if [ "$ARG_CONFIRM" == "true" ]; then return 0; fi
  local TMP_ANS
  read -r -p "[ prompt ] $1 (y/N) " TMP_ANS
  case "$TMP_ANS" in
    [Yy]) return 0 ;;
    *) return 1 ;;
  esac
}

# find if an exact line exists in a file
# $1: text to find
# $2: file to search
function line_exists {
  grep -qFx "$1" "$2"
}

# check if a directory is currently a mount point
# $1: directory
function mount_exists {
  grep -q "[[:space:]]$1[[:space:]]" /proc/mounts
}

# expand a leading ~ and environment variables in a typed path.
# Command substitution ($(...) / backticks) is rejected as unsafe.
# $1: raw path
# prints the expanded path
function expand_path {
  local p="$1"
  if [[ "$p" == *'`'* || "$p" == *'$('* ]]; then
    errexit "unsafe characters in path: $p"
  fi
  case "$p" in
    "~") p="$HOME" ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
  esac
  # expand $VARS only (command substitution already rejected above)
  eval "printf '%s' \"$p\""
}

# prompt repeatedly until a non-empty value is entered
# $1: prompt message
# prints the entered value
function ask_required {
  local ans=""
  while [ -z "$ans" ]; do
    read -r -p "[ prompt ] $1: " ans
    if [ -z "$ans" ]; then print_warn "a value is required"; fi
  done
  printf '%s' "$ans"
}

# collect any parameters not supplied on the command line.
# Prompt order and rules follow the interactive-mode spec.
function run_interactive {
  print_info "interactive mode: prompting for missing parameters"

  # required text inputs
  if [ -z "$ARG_LABEL" ]; then
    ARG_LABEL="$(ask_required "virtio device label/tag")"
  fi
  if [ -z "$ARG_MOUNT" ]; then
    ARG_MOUNT="$(expand_path "$(ask_required "base mount directory")")"
  fi

  # map-mount: only when not preset and type isn't forced to virtiofs.
  # A given path forces 9p, so we ask it before (and instead of) type.
  if [ -z "$ARG_MAP_MOUNT" ] && [ "$ARG_TYPE" != "virtiofs" ]; then
    local map_in=""
    read -r -p "[ prompt ] bindfs remap directory (blank = none): " map_in
    if [ -n "$map_in" ]; then
      ARG_MAP_MOUNT="$(expand_path "$map_in")"
    fi
  fi

  # type: only when not preset and no map-mount (map-mount forces 9p).
  if [ -z "$ARG_TYPE" ] && [ -z "$ARG_MAP_MOUNT" ]; then
    local choice=""
    echo "[ prompt ] select transport:"
    PS3="[ prompt ] choice: "
    select choice in "auto (virtiofs, fall back to 9p)" "virtiofs" "9p"; do
      case "$REPLY" in
        1) ARG_TYPE=""; break ;;
        2) ARG_TYPE="virtiofs"; break ;;
        3) ARG_TYPE="9p"; break ;;
        *) print_warn "invalid choice, pick 1-3" ;;
      esac
    done
  fi

  # fstab persistence: only ask if not already enabled on the CLI
  if [ "$ARG_FSTAB" != "true" ]; then
    local fstab_in=""
    read -r -p "[ prompt ] persist to /etc/fstab? (y/N) " fstab_in
    case "$fstab_in" in [Yy]) ARG_FSTAB="true" ;; esac
  fi
}

# append a line to /etc/fstab if it is not already present
# $1: fstab line
# $2: human-readable label for messages
function fstab_add {
  if line_exists "$1" /etc/fstab; then
    print_info "$2 entry already exists in /etc/fstab"
  else
    sudo tee -a /etc/fstab > /dev/null <<EOT
$1
EOT
    print_info "added $2 entry to /etc/fstab"
  fi
}

# unmount a directory if mounted, aborting if it is busy
# $1: directory
function ensure_unmounted {
  if ! mount_exists "$1"; then return 0; fi
  print_warn "already mounted, unmounting: $1"
  if ! sudo umount "$1" 2>/dev/null; then
    errexit "mount is busy, refusing to force: $1"
  fi
}

########
# MAIN #
########

function usage {
  if [ -n "${1:-}" ]; then
    echo -e "[ error ] $1\n"
  fi
  cat <<EOF
Mount a virtio shared folder (virtiofs or virtio-9p) inside a VM.

Usage: $(basename "$0") -l LABEL -m MOUNT_DIR [options]

  -l, --label        virtio device label/tag (required)
  -m, --mount-dir    base mount directory (required)
  -mm, --map-mount   bindfs remapped directory (optional; forces 9p)
  -t, --type         force transport: virtiofs | 9p (optional)
      --fstab        persist entries to /etc/fstab and daemon-reload
  -i, --interactive  prompt for any parameters not given on the CLI
  -y                 auto-confirm all prompts (ignored with -i)
  -h, --help         show this help

Examples:
  # auto: try virtiofs, fall back to 9p
  $(basename "$0") -l share -m /mnt/shared

  # 9p with bindfs UID/GID remapping, persisted
  $(basename "$0") -l share -m /mnt/shared -mm "\$HOME/shared" --fstab -y
EOF
  exit 1
}

ARG_CONFIRM="false"
ARG_INTERACTIVE="false"
ARG_LABEL=""
ARG_MOUNT=""
ARG_MAP_MOUNT=""
ARG_TYPE=""
ARG_FSTAB="false"

if [ $# -eq 0 ]; then
  usage "no arguments provided."
fi

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [ "$#" -gt 0 ]; do
  case "$1" in
    -l|--label) ARG_LABEL="${2:-}"; shift 2 ;;
    -m|--mount-dir) ARG_MOUNT="${2:-}"; shift 2 ;;
    -mm|--map-mount) ARG_MAP_MOUNT="${2:-}"; shift 2 ;;
    -t|--type) ARG_TYPE="${2:-}"; shift 2 ;;
    --fstab) ARG_FSTAB="true"; shift ;;
    -i|--interactive) ARG_INTERACTIVE="true"; shift ;;
    -y) ARG_CONFIRM="true"; shift ;;
    -h|--help) usage ;;
    *) usage "invalid argument: $1" ;;
  esac
done

# interactive mode: fill in whatever the CLI did not supply
if [ "$ARG_INTERACTIVE" == "true" ]; then
  if [ "$ARG_CONFIRM" == "true" ]; then
    print_warn "-y is redundant with -i and will be ignored; prompts drive everything"
    ARG_CONFIRM="false"
  fi
  run_interactive
fi

# validate required args
if [ -z "$ARG_LABEL" ]; then usage "label is required"; fi
if [ -z "$ARG_MOUNT" ]; then usage "mount directory is required"; fi

# validate --type value
if [ -n "$ARG_TYPE" ] && [ "$ARG_TYPE" != "virtiofs" ] && [ "$ARG_TYPE" != "9p" ]; then
  usage "invalid type: $ARG_TYPE (expected 'virtiofs' or '9p')"
fi

# reject contradictory combination: bindfs is a 9p-only concern
if [ -n "$ARG_MAP_MOUNT" ] && [ "$ARG_TYPE" == "virtiofs" ]; then
  errexit "--type virtiofs cannot be combined with --map-mount (bindfs remapping is 9p-only)"
fi

# macOS/UTM host note (see virtio-mount-mac.md)
print_info "note: macOS/UTM hosts use the fixed device label 'share'; host UID/GID differ from the guest (hence bindfs remap)"

# decide transport
#   --type wins; else --map-mount forces 9p; else auto-fallback
USE_FALLBACK="false"
if [ -n "$ARG_TYPE" ]; then
  MOUNT_TYPE="$ARG_TYPE"
elif [ -n "$ARG_MAP_MOUNT" ]; then
  MOUNT_TYPE="9p"
else
  MOUNT_TYPE="virtiofs"
  USE_FALLBACK="true"
fi

# interactive mode: show a summary and confirm before doing anything
if [ "$ARG_INTERACTIVE" == "true" ]; then
  echo ""
  echo "[ info  ] review:"
  echo "            label      : $ARG_LABEL"
  echo "            mount-dir  : $ARG_MOUNT"
  if [ "$USE_FALLBACK" == "true" ]; then
    echo "            type       : auto (virtiofs, fall back to 9p)"
  else
    echo "            type       : $MOUNT_TYPE"
  fi
  echo "            map-mount  : ${ARG_MAP_MOUNT:-none}"
  echo "            fstab      : $([ "$ARG_FSTAB" == "true" ] && echo yes || echo no)"
  echo ""
  read -r -p "[ prompt ] proceed? (y/N) " CONFIRM_ANS
  case "$CONFIRM_ANS" in
    [Yy]) : ;;
    *) errexit "aborted by user" ;;
  esac
fi

# ensure target directories are free before (re)mounting
ensure_unmounted "$ARG_MOUNT"
if [ -n "$ARG_MAP_MOUNT" ]; then
  ensure_unmounted "$ARG_MAP_MOUNT"
fi

# install bindfs deps up front (only when needed and missing)
if [ -n "$ARG_MAP_MOUNT" ] && ! command -v bindfs >/dev/null 2>&1; then
  if prompt_confirmation "bindfs is not installed; install fuse and bindfs?"; then
    sudo dnf install fuse bindfs
    print_info "packages installed"
  else
    errexit "bindfs is required for --map-mount but was not installed"
  fi
fi

sudo mkdir -p "$ARG_MOUNT"
if [ -n "$ARG_MAP_MOUNT" ]; then
  sudo mkdir -p "$ARG_MAP_MOUNT"
fi

# mount helpers
function mount_virtiofs {
  sudo mount -t virtiofs "$ARG_LABEL" "$ARG_MOUNT"
}

function mount_9p {
  sudo mount -t 9p -o trans=virtio,version=9p2000.L,rw "$ARG_LABEL" "$ARG_MOUNT"
}

# perform the mount
print_info "mounting '$ARG_LABEL' to '$ARG_MOUNT'"
# https://wiki.qemu.org/Documentation/9psetup
# https://www.linux-kvm.org/page/9p_virtio
if [ "$MOUNT_TYPE" == "virtiofs" ]; then
  if [ "$USE_FALLBACK" == "true" ]; then
    print_info "trying to mount as virtiofs"
    if mount_virtiofs; then
      MOUNT_TYPE="virtiofs"
    else
      print_warn "failed to mount as virtiofs, trying virtio-9p"
      mount_9p || errexit "failed to mount as virtio-9p"
      MOUNT_TYPE="9p"
    fi
  else
    mount_virtiofs || errexit "failed to mount as virtiofs"
  fi
else
  mount_9p || errexit "failed to mount as virtio-9p"
fi
print_info "mounted as $MOUNT_TYPE"

# fstab entry for the base mount
if [ "$MOUNT_TYPE" == "virtiofs" ]; then
  FSTAB_MOUNT="$ARG_LABEL $ARG_MOUNT virtiofs defaults,rw,nofail,noatime,nodiratime 0 0"
else
  FSTAB_MOUNT="$ARG_LABEL $ARG_MOUNT 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail,auto 0 0"
fi

# bindfs UID/GID remapping (9p only, when --map-mount is given)
if [ -n "$ARG_MAP_MOUNT" ]; then
  # read host ownership off the freshly mounted directory
  MOUNT_UID=$(ls -nd "$ARG_MOUNT" | awk '{print $3}')
  MOUNT_GID=$(ls -nd "$ARG_MOUNT" | awk '{print $4}')
  if [ -z "$MOUNT_UID" ]; then errexit "unable to read UID of the mounted directory"; fi
  if [ -z "$MOUNT_GID" ]; then errexit "unable to read GID of the mounted directory"; fi

  USER_ID=$(id -u)
  GROUP_ID=$(id -g)
  MAP_SPEC="$MOUNT_UID/$USER_ID:@$MOUNT_GID/@$GROUP_ID"

  print_info "setting up bindfs remap ($MAP_SPEC): $ARG_MAP_MOUNT"
  sudo bindfs "--map=$MAP_SPEC" "$ARG_MOUNT" "$ARG_MAP_MOUNT" \
    || errexit "failed to set up bindfs mount"

  FSTAB_MAP="$ARG_MOUNT $ARG_MAP_MOUNT fuse.bindfs map=$MAP_SPEC,x-systemd.requires=$ARG_MOUNT,_netdev,nofail,auto 0 0"
fi

# persist to /etc/fstab
if [ "$ARG_FSTAB" == "true" ]; then
  fstab_add "$FSTAB_MOUNT" "mount"
  if [ -n "$ARG_MAP_MOUNT" ]; then
    fstab_add "$FSTAB_MAP" "bindfs mapped mount"
  fi

  # optionally live-mount from the new fstab entries via systemd
  if prompt_confirmation "live-mount from /etc/fstab now (unmount current mounts and reload)?"; then
    # unmount individually, based on which were actually mounted; with no
    # map-mount the only mount is the base (label) mount
    if [ -n "$ARG_MAP_MOUNT" ] && mount_exists "$ARG_MAP_MOUNT"; then
      print_info "unmounting: $ARG_MAP_MOUNT"
      sudo umount "$ARG_MAP_MOUNT" || print_warn "could not unmount $ARG_MAP_MOUNT"
    fi
    if mount_exists "$ARG_MOUNT"; then
      print_info "unmounting: $ARG_MOUNT"
      sudo umount "$ARG_MOUNT" || print_warn "could not unmount $ARG_MOUNT"
    fi

    # daemon-reload re-runs systemd-fstab-generator so the new /etc/fstab
    # lines become .mount units; it does NOT mount anything itself, so the
    # target restart below is what actually mounts them.
    print_info "reloading systemd to regenerate mount units from /etc/fstab"
    sudo systemctl daemon-reload

    print_info "restarting network-fs.target (fallback: remote-fs.target)"
    if ! sudo systemctl restart network-fs.target 2>/dev/null; then
      sudo systemctl restart remote-fs.target \
        || errexit "failed to restart network-fs.target / remote-fs.target"
    fi
    # debugging: check the generated mount units are active with
    #   systemctl list-units --type=mount
  fi
fi

print_info "done"
