#!/usr/bin/env bash

# Debugging
# ---------
# set -x : print out every line as it executes, with variables expanded
#		putting it at top of the script will enable this for the whole
#		script, or before a block of commands and end it with:
#		{ set +x; } 2>/dev/null
#
# bash -x script.sh : same as putting set -x at the top of script
# trap read DEBUG : stop before every line, can be put at the top
# trap '(read -p "[$BASE_SOURCE:$lineno] $bash_command")' DEBUG

# Text colors
_CRST="\033[0m" # Reset
_CBLA="\033[30m" # Black
_CRED="\033[31m" # Red
_CGRE="\033[32m" # Green
_CYEL="\033[33m" # Yellow
_CBLU="\033[34m" # Blue
_CMAG="\033[35m" # Magenta
_CCYA="\033[36m" # Cyan
_CWHI="\033[37m" # White
# Background Colors
_CBBLA="\033[40m" # Black
_CBRED="\033[41m" # Red
_CBGRE="\033[42m" # Green
_CBYEL="\033[43m" # Yellow
_CBBLU="\033[44m" # Blue
_CBMAG="\033[45m" # Magenta
_CBCYA="\033[46m" # Cyan
_CBWHI="\033[47m" # White
# Text
_TBOLD="\e[1m" # Bold
_TDIM="\e[2m" # Dim

# print message with color
# $1 : msg
function print_header {
	printf "${_CYEL} ${1} ${_CRST}\n"
}

function print_info {
	printf "${_CCYA} ${1} ${_CRST}\n"
}

function print_success {
	printf "${_CGRE} ${1} ${_CRST}\n"
}

function print_error {
	printf "${_CBRED} ${1} ${_CRST}\n"
}

function print_debug {
	printf "${_CBWHI} ${1} ${_CRST}\n"
}

# print error msg and exit
# $1 : error msg
function errexit {
	print_error "[ error ] $1" >&2
	exit 1
}

# prompt for confirmation of an action
# $1 : message
# returns 1 if yes, 0 if no
function prompt_confirmation {
	local TMP_ANS
	read -p "$(echo -e -n $_CBMAG" ${1} (y/N) "$_CRST)" TMP_ANS
	case $TMP_ANS in
	[Yy])
		return 0
		;;
	*)
		return 1
		;;
	esac
}

export -f print_header
export -f print_info
export -f print_success
export -f print_error
export -f print_debug
export -f errexit
export -f prompt_confirmation