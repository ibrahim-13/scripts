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

alias fcd='cd "\$(find . -maxdepth 2 -type d | sort | fzf)"'
alias ff='find . -maxdepth 1 | sort | fzf'
alias ll='ls -AlhFr'
alias fk="ps -aux | fzf | awk '\$2 ~ /^[0-9]+\$/ { print \$2 }' | xargs kill -s SIGKILL"

$ALIAS_STR_END
EOF

echo done

