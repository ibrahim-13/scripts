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

# color variables
TXT_RESET="\033[0m"
TXT_COL_BLACK="\033[30m"
TXT_COL_RED="\033[31m"
TXT_COL_GREEN="\033[32m"
TXT_COL_YELLOW="\033[33m"
TXT_COL_BLUE="\033[34m"
TXT_COL_MAGENTA="\033[35m"
TXT_COL_CYAN="\033[36m"
TXT_COL_WHITE="\033[37m"
TXT_COL_BG_BLACK="\033[40m"
TXT_COL_BG_RED="\033[41m"
TXT_COL_BG_GREEN="\033[42m"
TXT_COL_BG_YELLOW="\033[43m"
TXT_COL_BG_BLUE="\033[44m"
TXT_COL_BG_MAGENTA="\033[45m"
TXT_COL_BG_CYAN="\033[46m"
TXT_COL_BG_WHITE="\033[47m"
TXT_COL_BOLD="\e[1m"
TXT_COL_DIM="\e[2m"

# print message with color
# $1 : msg
function print_header {
	printf "${TXT_COL_YELLOW} ${1} ${TXT_RESET}\n"
}

function print_info {
	printf "${TXT_COL_CYAN} ${1} ${TXT_RESET}\n"
}

function print_success {
	printf "${TXT_COL_GREEN} ${1} ${TXT_RESET}\n"
}

function print_error {
	printf "${TXT_COL_BG_RED} ${1} ${TXT_RESET}\n"
}

function print_debug {
	printf "${TXT_COL_BG_WHITE} ${1} ${TXT_RESET}\n"
}

export -f print_header
export -f print_info
export -f print_success
export -f print_error
export -f print_debug