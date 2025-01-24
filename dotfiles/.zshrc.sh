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

#########
# Paths #
#########

# add golang binaries to path
export PATH="$PATH:$HOME/go/bin"

###############
# Completions #
###############

# (zsh) Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)
