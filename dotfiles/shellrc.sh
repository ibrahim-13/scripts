if [ -n "$ZSH_VERSION" ]; then
	CURRENT_SHELL="zsh"
elif [ -n "$BASH_VERSION" ]; then
	CURRENT_SHELL="bash"
fi

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

function func_alias_help {
	echo "alias list"
	echo "fd             fuzzy find and cd into directory with depth 1"
	echo "ll             customized ls command"
	echo "llz            customized ls command with fuzzy find"
	echo "fk             force kill process with fuzzy find"
	echo "lfcd           cd into directory with lf"
	echo "http_server    http file server with python"
}

# fuzzy find and cd into directory with depth 1
# alias fd='cd $(find . -maxdepth 1 -type d | sort | fzf)'

# customized ls command
# alias ll='ls -AlhFr'

# customized ls command with fuzzy find
# alias llz='ls -AlhFr | sort | fzf'

# force kill process with fuzzy find
# alias fk='func_fzf_px'

# cd into directory with lf
# alias lfcd='func_lfcd'

# http file server with python
# alias http_server='func_http_server'

# show list of alias
# alias hh='func_alias_help'

########################
# Prompt Customization #
########################
# 	https://wiki.archlinux.org/title/Bash/Prompt_customization
# 	https://opensource.com/article/17/7/bash-prompt-tips-and-tricks
# nerd prompt cheatsheet: https://www.nerdfonts.com/cheat-sheet

# codes need to be escaped, otherwise, readline can not properly determine the length
# of the multiline input (ex. newline)
# Text colors
_CRST="\[\033[0m\]" # Reset
_CBLA="\[\033[30m\]" # Black
_CRED="\[\033[31m\]" # Red
_CGRE="\[\033[32m\]" # Green
_CYEL="\[\033[33m\]" # Yellow
_CBLU="\[\033[34m\]" # Blue
_CMAG="\[\033[35m\]" # Magenta
_CCYA="\[\033[36m\]" # Cyan
_CWHI="\[\033[37m\]" # White
# Background Colors
_CBBLA="\[\033[40m\]" # Black
_CBRED="\[\033[41m\]" # Red
_CBGRE="\[\033[42m\]" # Green
_CBYEL="\[\033[43m\]" # Yellow
_CBBLU="\[\033[44m\]" # Blue
_CBMAG="\[\033[45m\]" # Magenta
_CBCYA="\[\033[46m\]" # Cyan
_CBWHI="\[\033[47m\]" # White
# Text
_TBOLD="\[\e[1m\]" # Bold
_TDIM="\[\e[2m\]" # Dim
# get host name of the machine
# _HOSTNAME="$(hostname -s)"

_prompt_command() {
	local EXIT_CODE="$?";

	local ECOL=""
	local ECBG=""
	if [[ "$EXIT_CODE" == "0" ]]
	then
			ECBG="$_CGRE"
			ECOL=""
	else
			ECBG="$_CRED"
			ECOL=""
	fi
	PS1="$_CBLU \u@\h $_CCYA \w $_CYEL \D{%I:%M:%S %p} $ECOL$ECBG $EXIT_CODE $_CRST > "
}


# customized prompt command
# PROMPT_COMMAND=_prompt_command

#########
# Paths #
#########

# add golang binaries to path
# export PATH="$PATH:$HOME/go/bin"

# add github app binaries to path 
# export PATH="$PATH:$HOME/apps"

###############
# Completions #
###############

# Set up fzf key bindings and fuzzy completion
function func_fzf_completion {
	if [ "$CURRENT_SHELL" == "bash" ]; then eval "$(fzf --bash)"; fi
	if [ "$CURRENT_SHELL" == "zsh" ]; then source <(fzf --zsh); fi
}
# func_fzf_completion
