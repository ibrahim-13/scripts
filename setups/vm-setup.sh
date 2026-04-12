#!/usr/bin/env bash

# Exit script on error
set -e

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
  if [ "$2" == "true"]; then
    return 0
  fi
	local TMP_ANS
	read -p "$(echo -e -n " ${1} (y/N) ")" TMP_ANS
	case $TMP_ANS in
	[Yy])
		return 0
		;;
	*)
		return 1
		;;
	esac
}

function line_exists {
  if grep -qFx "STRING_TO_FIND" $1; then
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
  echo "[ info  ] $1"
}

function print_warn {
  echo "[ warn  ] $1"
}

function print_err {
  echo "[ error ] $1"
}

function func_dnf_weak_deps {
  echo "install_weak_deps=false" >> /etc/dnf/dnf.conf 2>&1
}

function func_xinitrc {
  echo "exec awesome" >> $HOME/.xinitrc 2>&1
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

if [ $# -eq 0 ]; then
    usage  "no arguments provided."
fi

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -y) ARG_CONFIRM="true"; shift; shift;;
    -h|--help) usage;;
    *) usage "invalid arguments";;
esac; done

if [ -f /etc/dnf/dnf.conf ]; then
  print_info "disabling weak dependencies for dnf"
  if ! line_exists "install_weak_deps=false"; then
    if prompt_confirmation "disable weak dependencies for dnf?" $ARG_CONFIRM; then
      func_dnf_weak_deps
    else
      print_warn "weak dependencies for dnf NOT disabled"
    fi
  else
    print_info "weak dependencies are disabled for dnf"
  fi
fi

print_info "setting xinitrc to start awesome wm"
if ! [ -f $HOME/.xinitrc ]; then
  if ! line_exists "exec awesome"; then
    if prompt_confirmation "set awesome wm for xinit?" $ARG_CONFIRM; then
      func_xinitrc
    else
      print_warn "weak dependencies for dnf NOT disabled"
    fi
  else
    print_info "awesome is set as wm in xinit"
  fi
else
  func_xinitrc
fi

print_info "updating packages"
if prompt_confirmation "update all system packages?" $ARG_CONFIRM; then
  sudo dnf check-update
  sudo dnf update
else
  print_warn "system packages not updated"
fi

print_info "installing xorg"
if prompt_confirmation "install xorg and the required packages?" $ARG_CONFIRM; then
  sudo dnf group install base-x awesome desktop-file-utils
else
  print_warn "xorg display server not installed"
fi

print_info "installing necessary user packages"
if prompt_confirmation "install the necessary packages?" $ARG_CONFIRM; then
  sudo dnf install thunar thunar-archive-plugin xdg-user-dirs nvim
else
  print_warn "user packages not installed"
fi

echo ""
print_info "to start xorg session, run: startx"
echo ""

echo ""
print_info "in case of failure related to xauth,"
print_info "    change enable_xauth=1 to enable_xauth=0 "
print_info "    in /usr/local/bin/startx to disable XAuth"
echo ""