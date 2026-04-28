#!/usr/bin/env bash

if [ -n "$ZSH_VERSION" ]; then
	CURRENT_SHELL="zsh"
elif [ -n "$BASH_VERSION" ]; then
	CURRENT_SHELL="bash"
fi

# Enable bash programmable completion features in interactive shells
if [ -f /usr/share/bash-completion/bash_completion ]; then
	. /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
	. /etc/bash_completion
fi

# Ignore case on auto-completion
# Note: bind used instead of sticking these in .inputrc
bind "set completion-ignore-case on"

# Show auto-completion list automatically, without double tab
bind "set show-all-if-ambiguous On"

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T" # add timestamp to history

# Don't put duplicate lines in the history and do not add lines that start with a space
export HISTCONTROL=erasedups:ignoredups:ignorespace

# Causes bash to append to history instead of overwriting it so if you start a new terminal, you have old session history
shopt -s histappend
PROMPT_COMMAND='history -a'

# set up XDG folders
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# Set the default editor
# export EDITOR=nvim
# export VISUAL=nvim

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

#########
# Alias #
#########

# alias chmod commands
alias mx='chmod a+x'
alias 000='chmod -R 000'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# Search command line history
alias h="history | grep "

# Search running processes
alias p="ps aux | grep "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"

# Search files in the current folder
alias f="find . | grep "

# Count all files (recursively) in the current folder
alias countfiles="for t in files links directories; do echo \`find . -type \${t:0:1} | wc -l\` \$t; done 2> /dev/null"

# To see if a command is aliased, a file, or a built-in command
alias checkcommand="type -t"

# Show open ports
alias openports='netstat -nape --inet'

# Alias's for safe and forced reboots
alias rebootsafe='sudo shutdown -r now'
alias rebootforce='sudo shutdown -r -n now'

# Alias's to show disk space and space used in a folder
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# Alias's for archives
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

# Show all logs in /var/log
alias logs="sudo find /var/log -type f -exec file {} \; | grep 'text' | cut -d' ' -f1 | sed -e's/:$//g' | grep -v '[0-9]$' | xargs tail -f"

# SHA
alias sha1='openssl sha1'
alias sha256='openssl sha256'

# alias to cleanup unused docker containers, images, networks, and volumes

alias docker-clean=' \
  docker container prune -f ; \
  docker image prune -f ; \
  docker network prune -f ; \
  docker volume prune -f '

#######################################################
# SPECIAL FUNCTIONS
#######################################################
# Extracts any archive(s) (if unp isn't installed)
extract() {
	for archive in "$@"; do
		if [ -f "$archive" ]; then
			case $archive in
			*.tar.bz2) tar xvjf $archive ;;
			*.tar.gz) tar xvzf $archive ;;
			*.bz2) bunzip2 $archive ;;
			*.rar) rar x $archive ;;
			*.gz) gunzip $archive ;;
			*.tar) tar xvf $archive ;;
			*.tbz2) tar xvjf $archive ;;
			*.tgz) tar xvzf $archive ;;
			*.zip) unzip $archive ;;
			*.Z) uncompress $archive ;;
			*.7z) 7z x $archive ;;
			*) echo "don't know how to extract '$archive'..." ;;
			esac
		else
			echo "'$archive' is not a valid file!"
		fi
	done
}

# Searches for text in all files in the current folder
ftext() {
	# -i case-insensitive
	# -I ignore binary files
	# -H causes filename to be printed
	# -r recursive search
	# -n causes line number to be printed
	# optional: -F treat search term as a literal, not a regular expression
	# optional: -l only print filenames and not the matching lines ex. grep -irl "$1" *
	grep -iIHrn --color=always "$1" . | less -r
}

# Copy file with a progress bar
cpp() {
    set -e
    strace -q -ewrite cp -- "${1}" "${2}" 2>&1 |
    awk '{
        count += $NF
        if (count % 10 == 0) {
            percent = count / total_size * 100
            printf "%3d%% [", percent
            for (i=0;i<=percent;i++)
                printf "="
            printf ">"
            for (i=percent;i<100;i++)
                printf " "
            printf "]\r"
        }
    }
    END { print "" }' total_size="$(stat -c '%s' "${1}")" count=0
}

# Automatically do an ls after each cd, z, or zoxide
cd ()
{
	if [ -n "$1" ]; then
		builtin cd "$@" && ls
	else
		builtin cd ~ && ls
	fi
}

# IP address lookup
alias whatismyip="whatsmyip"
function whatsmyip () {
    # Internal IP Lookup.
    if command -v ip &> /dev/null; then
        echo -n "Internal IP: "
        ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
    else
        echo -n "Internal IP: "
        ifconfig wlan0 | grep "inet " | awk '{print $2}'
    fi

    # External IP Lookup
    echo -n "External IP: "
    curl -4 ifconfig.me
}

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
