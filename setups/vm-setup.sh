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

function command_exists {
	if command -v $1 &> /dev/null; then return 0; else return 1; fi
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
    echo "setup vm for dev"
    echo ""
    echo "Usage: $(basename "$0") [-y] [-h|--help]"
    echo ""
    echo "  -y          confirm everything as yes"
    echo " -h|--help    show help"
    echo ""
    exit 1
}

ARG_CONFIRM="false"

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -y) ARG_CONFIRM="true"; shift; shift;;
    -h|--help) usage;;
    *) usage "invalid arguments";;
esac; done


if prompt_confirmation "set locale for mac?" $ARG_CONFIRM; then
  localectl set-locale "en_US.UTF8"
  localectl set-x11-keymap de pc105 mac
fi

if ! [ -f /etc/dnf/dnf.conf ]; then
  print_warn "dnf config file not found, configuration will be skipped"
elif prompt_confirmation "configure dnf?" $ARG_CONFIRM; then
  sudo tee /etc/dnf/dnf.conf > /dev/null <<EOT
# see \`man dnf.conf\` for defaults and possible options
[main]

# Use the fastest mirror
fastestmirror=True

# Number of parallel downloads 10
max_parallel_downloads=10

# Ensures DNF always tries to install the highest version of a package
best=1

# Automatically removes orphaned dependencies when a package is uninstalled
clean_requirements_on_remove=True

# Limits the number of old kernels or install-only packages retained to prevent disk space exhaustion
installonly_limit=3

# Removes downloaded package archives after installation to save disk space
keepcache=0

# Ensures DNF verifies package signatures against trusted GPG keys
gpgcheck=1

# Sets the cache expiration to 12 hours (in seconds)
metadata_expire=43200

# Disable installing weak dependencies (such as Recommends or Supplements) when installing a package
install_weak_deps=false
EOT
  print_info "dnf config updated"
fi

if prompt_confirmation "update all system packages?" $ARG_CONFIRM; then
  sudo dnf update -y
  print_info "packages updated"
fi

if prompt_confirmation "install xorg display server?" $ARG_CONFIRM; then
  sudo dnf group install base-x
  print_info "xorg display server installed"
fi

AWESOME_EXEC="exec awesome &> $HOME/awesomewm.log"
if ! [ -f "$HOME/.xinitrc" ]; then
  print_warn "$HOME/.xinitrc not found, xinit is not configured yet"
fi
if [ -f "$HOME/.xinitrc" ] && line_exists "$AWESOME_EXEC" "$HOME/.xinitrc"; then
  print_info "xinit already configured for awesome wm"
elif prompt_confirmation "set awesome wm for xinit?" $ARG_CONFIRM; then
  echo "$AWESOME_EXEC" >> $HOME/.xinitrc 2>&1
  print_info "xinit configured to start awesome wm"
fi

STARTX_EXEC='if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then exec startx; fi'
if ! command_exists startx; then
  print_warn "startx not found, xorg autostart will be skipped"
elif ! [ -f "$HOME/.bashrc" ]; then
  print_warn "$HOME/.bashrc not found, xorg autostart is not configured"
elif ! [ -f "$HOME/.xinitrc" ] || ! line_exists "$AWESOME_EXEC" "$HOME/.xinitrc"; then
  print_warn "xinit is not configured, it should be configured first"
elif line_exists "$STARTX_EXEC" "$HOME/.bashrc"; then
  print_info "bashrc already configured to start xorg display"
elif prompt_confirmation "start xorg display on login (append to .bashrc)?" $ARG_CONFIRM; then
  echo "$STARTX_EXEC" >> $HOME/.bashrc
  print_info "bashrc configured to start xorg display"
fi

if prompt_confirmation "install file manager, awesome wm, git, curl, rsync etc. packages?" $ARG_CONFIRM; then
  sudo dnf install thunar thunar-archive-plugin engrampa xdg-user-dirs awesome desktop-file-utils git wget curl xclip xinput xset rsync
  print_info "user packages installed"
fi

if prompt_confirmation "install neovim?" $ARG_CONFIRM; then
  sudo dnf install nvim ripgrep xsel
  print_info "neovim installed"
fi

if prompt_confirmation "install hugo?" $ARG_CONFIRM; then
  sudo dnf install hugo
  print_info "hugo installed"
fi

if prompt_confirmation "install xvkbd virtual keyboard?" $ARG_CONFIRM; then
  sudo dnf install xvkbd
  print_info "xvkbd virtual keyboard installed"
fi

if prompt_confirmation "install c/c++ dev packages?" $ARG_CONFIRM; then
  sudo dnf group install c-development development-tools
  print_info "c/c++ dev packages installed"
fi

if prompt_confirmation "install rpmfution repository and ffmpeg?" $ARG_CONFIRM; then
  if dnf repolist | grep -qi rpmfusion; then
    sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    print_info "rpm fusion repo added"
  else
    print_info "rpm fusion repo already exists"
  fi
  sudo dnf swap ffmpeg-free ffmpeg --allowerasing
  sudo dnf -y install ffmpeg
  print_info "ffmpeg installed"
fi

if prompt_confirmation "install ghostty?" $ARG_CONFIRM; then
    print_info "installing ghostty"
    if dnf copr list | grep -qF "scottames/ghostty"; then
        print_info "ghostty copr repo already enabled"
    else
        sudo dnf copr enable scottames/ghostty
    fi
    sudo dnf install ghostty -y
fi

echo "============="
print_info "to start xorg session, run: startx"
echo "============="

echo "============="
print_info "in case of failure related to xauth,"
print_info "    change enable_xauth=1 to enable_xauth=0 "
print_info "    in /usr/local/bin/startx to disable XAuth"
echo "============="
