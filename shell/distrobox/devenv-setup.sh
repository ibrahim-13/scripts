#!/usr/bin/env bash

echo "================"
echo "= devenv setup ="
echo "================"

if [[ ! -f /etc/apt/sources.list.d/github-cli.list ]]
then
	echo "adding repository: github-cli"
	sudo mkdir -p -m 755 /etc/apt/keyrings && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
	sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
else
	echo "repository already added: github-cli"
fi

if [[ ! -f /etc/apt/sources.list.d/vscodium.list ]]
then
	echo "adding repository: vscodium"
	wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
		| gpg --dearmor \
		| sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg
	echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
		| sudo tee /etc/apt/sources.list.d/vscodium.list
else
	echo "repository already added: vscodium"
fi

echo "updating system packages"
sudo apt-get update && sudo apt-get upgrade --with-new-pkgs

# add packages to install with ":" as separator
PACKAGES_TO_INSTALL="openssl:git:gh:codium"

function install_packages {
	local APPS_LIST=
	local IFS=':'
	read -ra APPS_LIST <<< "$PACKAGES_TO_INSTALL"
	for opt in "${APPS_LIST[@]}"
	do
		if ! sudo dpkg -s $opt &>/dev/null
		then
			echo "installing: $opt"
			sudo apt-get install $opt
		else
			echo "already installed: $opt"
		fi
	done
}

# install required packages
install_packages

# install vscodium extensions
if command -v codium
then
	codium --install-extension mhutchie.git-graph
	codium --install-extension golang.go
else
	echo "binary not found: codium"
	echo "extensions will not be installed"
fi

echo "devenv setup finished"

