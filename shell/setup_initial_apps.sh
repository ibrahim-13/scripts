#!/bin/sh

echo "============================="
echo "= Initial Application Setup ="
echo "============================="
echo

# If not running as ROOT, then exit
# This script required root priviledges to function.
# if [ $(id -u) -ne 0 ]
# then
# 	echo "Error! This script requires root priviledges to run"
# 	exit 1
# fi

# Git
echo Installing Git...
sudo apt-get install git

# Github Cli
echo Installing GitHub Cli...
type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
&& sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y

# Cryptomator
echo Installing Cryptomator...
sudo add-apt-repository ppa:sebastian-stenzel/cryptomator
sudo apt update
sudo apt-get install cryptomator

# Bitwarden
echo Installing Bitwarden...
sudo snap install bitwarden

# VLC Player
echo Installing VLC Player
sudo snap install vlc

# Thunderbird
echo Installing Thunderbird Email Client...
sudo snap install thunderbird

# Gimp
echo Installing Gimp...
sudo snap install gimp

# Visual Studio Code
echo Installing Visual Studio Code...
# Install source
sudo apt-get install wget gpg
if [ -e /tmp/packages.microsoft.gpg ]
then
    rm -f /tmp/packages.microsoft.gpg
fi
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f /tmp/packages.microsoft.gpg
# Install package
sudo apt install apt-transport-https
sudo apt update
sudo apt install code
# Install extensions
code --install-extension mhutchie.git-graph # Git Graph
code --install-extension golang.go # Golang
code --install-extension vscodevim.vim # VS Vim

# Node Version Manager (nvm)
echo Installing Node Version Manager 0.39.7...
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
command -v nvm
nvm install --reinstall-packages-from=current 'lts/*'

# BleachBit for Ubuntu 23.04
echo Installing BleachBit for Ubuntu 23.04...
wget -q --show-progress -O /tmp/bleachbit_2304.deb https://download.bleachbit.org/bleachbit_4.6.0-0_all_ubuntu2304.deb
sudo dpkg -i /tmp/bleachbit_2304.deb
rm /tmp/bleachbit_2304.deb

# Discord
echo Installing Discord...
sudo snap install discord

# Kid3
echo Installing Kid3...
sudo add-apt-repository ppa:ufleisch/kid3
sudo apt-get update
sudo apt-get install kid3     # KDE users
# sudo apt-get install kid3-qt  # without KDE dependencies
# sudo apt-get install kid3-cli # for the command-line interface

# ripgrep
sudo apt-get install ripgrep
