#########
# Alias #
#########

function func_fzf_px {
	TMP_SELSECTED_PROCESS=$(ps -e -o user,pid,comm | fzf | awk '$2 ~ /^[0-9]+$/ { print $2 }')
	if [ "$TMP_SELSECTED_PROCESS" = "" ]
	then
		echo no process selected
	else
		read -p "Kill? (Y/n) " TMP_ANS
		case $TMP_ANS in
			[Nn])
				echo will not kill
				;;
			*)
				echo killing pid: $TMP_SELSECTED_PROCESS
				kill -s SIGKILL $TMP_SELSECTED_PROCESS
				;;
			esac
	fi
}

function func_http_server {
	if ! command -v python3 &>/dev/null
	then
		echo "python3 is required"
		exit 1
	fi
	echo "ip addresses:"
	for i in $(hostname -I); do echo "> $i"; done
	echo "port: 9000"
	echo "if firewall is enabled, add rule for port 9000"
	python3 -m http.server 9000
}

function func_lfcd {
    cd "$(command lf -single -print-last-dir "$@")"
}

alias fd='cd $(find . -maxdepth 1 -type d | sort | fzf)'
alias ll='ls -AlhFr'
alias llz='ls -AlhFr | sort | fzf'
alias fk='func_fzf_px'
alias lfcd='func_lfcd'
alias http_server='func_http_server'

########################
# Prompt Customization #
########################
# 	https://wiki.archlinux.org/title/Bash/Prompt_customization
# 	https://opensource.com/article/17/7/bash-prompt-tips-and-tricks
# nerd prompt cheatsheet: https://www.nerdfonts.com/cheat-sheet

PROMPT_COMMAND=_prompt_command

# codes need to be escaped, otherwise, readline can not properly determine the length
# of the multiline input (ex. newline)
TXT_RESET="\[\033[0m\]"
TXT_COL_BLACK="\[\033[30m\]"
TXT_COL_RED="\[\033[31m\]"
TXT_COL_GREEN="\[\033[32m\]"
TXT_COL_YELLOW="\[\033[33m\]"
TXT_COL_BLUE="\[\033[34m\]"
TXT_COL_MAGENTA="\[\033[35m\]"
TXT_COL_CYAN="\[\033[36m\]"
TXT_COL_WHITE="\[\033[37m\]"
TXT_COL_BG_BLACK="\[\033[40m\]"
TXT_COL_BG_RED="\[\033[41m\]"
TXT_COL_BG_GREEN="\[\033[42m\]"
TXT_COL_BG_YELLOW="\[\033[43m\]"
TXT_COL_BG_BLUE="\[\033[44m\]"
TXT_COL_BG_MAGENTA="\[\033[45m\]"
TXT_COL_BG_CYAN="\[\033[46m\]"
TXT_COL_BG_WHITE="\[\033[47m\]"
TXT_COL_BOLD="\[\e[1m\]"
TXT_COL_DIM="\[\e[2m\]"
_HOSTNAME="$(hostname -s)"

_prompt_command() {
	local EXIT_CODE="$?";

	local EXIT_CODE_COLOR=""
	local EXIT_CODE_COLOR_BG=""
	if [[ "$EXIT_CODE" == "0" ]]
	then
		EXIT_CODE_COLOR_BG="$TXT_COL_BG_GREEN"
		EXIT_CODE_COLOR="$TXT_COL_GREEN"
	else
		EXIT_CODE_COLOR_BG="$TXT_COL_BG_RED"
		EXIT_CODE_COLOR="$TXT_COL_RED"
	fi
	PS1="\u@\h | \w \D{%I:%M:%S %p} | $EXIT_CODE > "
}

#########
# Paths #
#########

# add golang binaries to path
export PATH="$PATH:$HOME/go/bin"

###############
# Completions #
###############ngs and fuzzy completion
eval "$(fzf --bash)"
