#!/usr/bin/env bash

REGISTERED_OPT=""

function register_opt {
	if [[ "$REGISTERED_OPT" == "" ]]
	then
		REGISTERED_OPT="$1"
	else
		REGISTERED_OPT="$REGISTERED_OPT:$1"
	fi
}

function setup_gh_cli_repo {
	echo "setup github cli repoitory"
	sudo mkdir -p -m 755 /etc/apt/keyrings && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
	sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
}
register_opt setup_gh_cli_repo

function setup_vscodium_repo {
	echo "setup vscodium repository"
	wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
		| gpg --dearmor \
		| sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg
	echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
		| sudo tee /etc/apt/sources.list.d/vscodium.list
}
register_opt setup_vscodium_repo

function update_system_packages {
	echo "updating packages"
	sudo apt-get update && sudo apt-get upgrade --with-new-pkgs
}
register_opt update_system_packages

function install_packages {
	echo "installing packages"
	sudo apt-get install openssl git gh codium 
}
register_opt install_packages

function install_vscodium_extensions {
	echo "installing vscodium extensions"
	codium --install-extension mhutchie.git-graph
	codium --install-extension golang.go
}
register_opt install_vscodium_extensions

# Menu for managing apps installation
function menu_opts {
	register_opt "quit"
	local PS3='select opt: '
	local APPS_LIST=
	local IFS=':'
	read -ra APPS_LIST <<< "$REGISTERED_OPT"
	echo $APPS_LIST
	select opt in "${APPS_LIST[@]}"
	do
		if [[ $opt == "quit" ]]
		then
			break
		fi
		if [[ $opt == "" ]] || [[ ! $APPS_LIST == *"$APPS_LIST"* ]]
		then
			echo "invalid opt: $REPLY"
		else
			$opt
		fi
	done
}

echo "================"
echo "= devenv setup ="
echo "================"

# run main menu function
menu_opts

