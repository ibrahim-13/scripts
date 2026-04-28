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
  if [ "$2" == "true" ]; then
    return 0
  fi
	local TMP_ANS
	read -p "[ prompt ] $(echo -e -n " ${1} (y/N) ")" TMP_ANS
	case $TMP_ANS in
	[Yy])
		return 0
		;;
	*)
		return 1
		;;
	esac
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

function command_exists {
	if command -v $1 &> /dev/null
	then
    return 0
  else
    return 1
	fi
}

function print_info {
  echo "[ info   ] $1"
}

function print_warn {
  echo "[ warn   ] $1"
}

function print_err {
  echo "[ error  ] $1"
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

if ! [ -f /etc/dnf/dnf.conf ]; then
  print_warn "dnf config file not found, configuration will be skipped"
elif line_exists "install_weak_deps=false" "/etc/dnf/dnf.conf"; then
  print_info "dnf already configured to disable weak deps"
elif prompt_confirmation "disable weak dependencies for dnf?" $ARG_CONFIRM; then
  sudo tee -a /etc/dnf/dnf.conf > /dev/null <<EOT
install_weak_deps=false
EOT
  print_info "dnf weak dependencies disabled"
else
  print_warn "weak dependencies for dnf NOT disabled"
fi

AWESOME_EXEC="exec awesome &> $HOME/awesomewm.log"
if line_exists "$AWESOME_EXEC" "$HOME/.xinitrc"; then
  print_info "xinit already configured for awesome wm"
elif prompt_confirmation "set awesome wm for xinit?" $ARG_CONFIRM; then
  echo "$AWESOME_EXEC" >> $HOME/.xinitrc 2>&1
  print_info "xinit configured to start awesome wm"
fi

if prompt_confirmation "update all system packages?" $ARG_CONFIRM; then
  sudo dnf update -y
  print_info "packages updated"
fi

if prompt_confirmation "install xorg and the required packages?" $ARG_CONFIRM; then
  sudo dnf group install base-x
  print_info "xorg display server installed"
fi

if prompt_confirmation "install the necessary packages?" $ARG_CONFIRM; then
  sudo dnf install thunar thunar-archive-plugin xdg-user-dirs awesome desktop-file-utils git wget
  print_info "user packages installed"
fi

if prompt_confirmation "install neovim?" $ARG_CONFIRM; then
  sudo dnf install nvim
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

echo "============="
print_info "to start xorg session, run: startx"
echo "============="

echo "============="
print_info "in case of failure related to xauth,"
print_info "    change enable_xauth=1 to enable_xauth=0 "
print_info "    in /usr/local/bin/startx to disable XAuth"
echo "============="
