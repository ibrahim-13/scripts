#!/bin/sh

ALIAS_STR_START="# START:DEFAULT_ALIAS"
ALIAS_STR_END="# END:DEFAULT_ALIAS"

echo appending to $HOME/.bashrc

if [ -f $HOME/.bashrc ]
then
	if grep -Fxq "$ALIAS_STR_START" $HOME/.bashrc && grep -Fxq "$ALIAS_STR_END" $HOME/.bashrc
	then
		echo already appended
		exit 0
	fi
fi

cat <<EOF >> $HOME/.bashrc
$ALIAS_STR_START

func_fzf_px() {
	TMP_SELSECTED_PROCESS=\$(ps -aux | fzf | awk '\$2 ~ /^[0-9]+$/ { print \$2 }')
	if [ "\$TMP_SELSECTED_PROCESS" = "" ]
	then
		echo no process selected
	else
		read -p "Kill? (Y/n) " TMP_ANS
		case \$TMP_ANS in
			[Nn])
				echo will not kill
				;;
			*)
				echo killing pid: \$TMP_SELSECTED_PROCESS
				kill -s SIGKILL \$TMP_SELSECTED_PROCESS
				;;
			esac
	fi
	
}

func_lfcd () {
    cd "\$(command lf -single -print-last-dir "\$@")"
}

alias fd='cd \$(find . -maxdepth 1 -type d | sort | fzf)'
alias ll='ls -AlhFr'
alias llz='ls -AlhFr | sort | fzf'
alias fk='func_fzf_px'
alias lfcd='func_lfcd'

$ALIAS_STR_END
EOF

echo done

