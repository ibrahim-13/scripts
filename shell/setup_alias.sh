#!/bin/sh

ALIAS_STR_START="# START:FCD,FF,LL"
ALIAS_STR_END="# END:FCD,FF,LL"

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

alias ff='find . -maxdepth 1 | sort | fzf'
alias ll='ls -AlhFr'
alias fk='func_fzf_px'

$ALIAS_STR_END
EOF

echo done

