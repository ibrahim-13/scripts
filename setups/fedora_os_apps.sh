#!/usr/bin/env bash

# If not running as ROOT, then exit
# This script required root priviledges to function.
# if [ $(id -u) -ne 0 ]
# then
# 	echo "Error! This script requires root priviledges to run"
# 	exit 1
# fi

# echo ==============
# echo = GitHub Cli =
# echo ==============
# dnf install 'dnf-command(config-manager)'
# dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
# dnf install gh

#--------------------------------------------------------------

REGISTERED_OPT=""

function register_opt {
	if [[ "$REGISTERED_OPT" == "" ]]
	then
		REGISTERED_OPT="$1"
	else
		REGISTERED_OPT="$REGISTERED_OPT:$1"
	fi
}

#################################
# START: Configuration for `os` #
#################################

# configure hostname, default is `fedora`
function os_set_hostname {
	local TMP_ANS
	read -p "hostname: " TMP_ANS
	if [[ ! -z "$TMP_ANS" ]]
	then
		sudo hostnamectl set-hostname $TMP_ANS
	else
		echo "empty input, hostname will not be changed"
	fi
}
register_opt os_set_hostname

# adjust how system time is stored
# ################################
# in case of dual-boot with windows, this is important to avoid system time conflict.
# because, windows stores system time in local format but fedora stores system time in utc format.
function os_set_local_rtc_system_time {
	echo "setting local rtc as system time"
	sudo timedatectl set-local-rtc 1 --adjust-system-clock
}
register_opt os_set_local_rtc_system_time

# Mononoki font from github
function os_install_font_mononoki {
	local DIR_TMP="$HOME/.tmp"
	local FILE_ARCHIVE="$DIR_TMP/font-mononoki.tag.xz"
	local FONT_DOWNLOAD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.0/Mononoki.tar.xz"
	local DIR_EXTRACT="$DIR_TMP/font-mononoki"
	local DIR_FONT="$HOME/.local/share/fonts"

	mkdir -p "$DIR_EXTRACT"
	mkdir -p "$DIR_FONT"

	if wget --help | grep -i "show-progress" &> /dev/null
	then
		wget -q --show-progress -O "$FILE_ARCHIVE" "$FONT_DOWNLOAD_URL" || errexit "error downloading font archive"
	else
		wget -q -O "$FILE_ARCHIVE" "$FONT_DOWNLOAD_URL" || errexit "error downloading font archive"
	fi
	tar -xvf "$FILE_ARCHIVE" -C "$DIR_EXTRACT"
	cp "$DIR_EXTRACT/MononokiNerdFont-Regular.ttf" "$DIR_FONT/MononokiNerdFont-Regular.ttf"
	echo "installing mononoki font"
	fc-cache -fv

	# cleanup
	echo "cleaning up"
	rm "$FILE_ARCHIVE"
	rm -rf "$DIR_EXTRACT"
}
register_opt os_install_font_mononoki

###############################
# END: Configuration for `os` #
###############################

######################
# START: System apps #
######################

function system_install_git {
	if command -v dnf
	then
		echo "installing git"
		sudo dnf install git
	else
		echo "package manager not found"
	fi
}
register_opt system_install_git

function system_install_github_cli {
	if command -v dnf
	then
		echo "installing github cli"
		sudo dnf install dnf5-plugins
		sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
		sudo dnf install gh --repo gh-cli
	else
		echo "package manager not found"
	fi
}
register_opt system_install_github_cli

function system_install_tmux {
	if command -v dnf
	then
		echo "installing tmux"
		sudo dnf install tmux
	else
		echo "package manager not found"
	fi
}
register_opt system_install_tmux

function system_install_virt_manager {
	if command -v dnf
	then
		echo "installing virtualization packages"
		sudo dnf install @virtualization
		echo "use the following command to start virtualization service: sudo systemctl start libvirtd"
		# echo "adding $USER to group: kvm"
		# sudo usermod -aG kvm $USER
		# echo "adding $USER to group: libvirt"
		# sudo usermod -aG libvirt $USER
		# echo "enabling systemd service: libvirtd"
		# sudo systemctl enable --now libvirtd
		# echo "systemd service status: libvirtd"
		# sudo systemctl start libvirtd
	else
		echo "package manager not found"
	fi
}
register_opt system_install_virt_manager

####################
# END: System apps #
####################

#######################
# START: Flatpak apps #
#######################

# enable flathub
function flatpak_enable_flathub {
	if flatpak remotes | grep -q flathub
	then
		echo "flathub exists in the repo list"
		if flatpak remotes --show-disabled | grep -q flathub
		then
			echo "flathub was disabled, enabling with no filter"
			flatpak remote-modify --enable --no-filter flathub
		fi
	else
		echo "adding flathub remote"
		flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	fi
}
register_opt flatpak_enable_flathub

# gnome extension manager
function flatpak_install_gnome_extensions {
	flatpak install flathub org.gnome.Extensions
}
register_opt flatpak_install_gnome_extensions

# podman container manager
function flatpak_install_podman {
	if command -v apt-get
	then
		echo "installing podmand"
		sudo apt-get -y install podman
	else
		echo "package manager not found while installing podman"
	fi
	if command -v flatpak
	then
		echo "installing podman desktop"
		flatpak install flathub io.podman_desktop.PodmanDesktop
	else
		echo "flatpak not found while installing podman desktop"
		flatpak install flathub io.podman_desktop.PodmanDesktop
	fi
}
register_opt flatpak_install_podman

# vscodium and add extensions
function flatpak_install_vscodium {
	flatpak install flathub com.vscodium.codium

	echo --------------------
	echo Extension: Git Graph
	echo --------------------
	flatpak run com.vscodium.codium --install-extension mhutchie.git-graph
	echo -----------------
	echo Extension: Golang
	echo -----------------
	flatpak run com.vscodium.codium --install-extension golang.go
	echo ------------------------
	echo Extension: Spell Checker
	echo ------------------------
	flatpak run com.vscodium.codium --install-extension streetsidesoftware.code-spell-checker
	echo ------------------------
	echo Extension: VIM
	echo ------------------------
	flatpak run com.vscodium.codium --install-extension vscodevim.vim
}
register_opt flatpak_install_vscodium

# google chrome
function flatpak_install_google_chrome {
	flatpak install flathub com.google.Chrome
}
register_opt flatpak_install_google_chrome

# brave browser
function flatpak_install_brave_browser {
	flatpak install flathub com.brave.Browser
}
register_opt flatpak_install_brave_browser

# microsoft edge browser
function flatpak_install_microsoft_edge {
	flatpak install flathub com.microsoft.Edge
}
register_opt flatpak_install_microsoft_edge

# kid3 audio tagger
function flatpak_install_kid3 {
	flatpak install flathub org.kde.kid3
}
register_opt flatpak_install_kid3

# discord
function flatpak_install_discord {
	flatpak install flathub com.discordapp.Discord
}
register_opt flatpak_install_discord

# bleachbit
function flatpak_install_bleachbit {
	flatpak install flathub org.bleachbit.BleachBit
}
register_opt flatpak_install_bleachbit

# gimp
function flatpak_install_gimp {
	flatpak install flathub org.gimp.GIMP
}
register_opt flatpak_install_gimp

# vlc media player
function flatpak_install_vlc {
	flatpak install flathub org.videolan.VLC
}
register_opt flatpak_install_vlc

# thunderbird email client
function flatpak_install_thunderbird {
	flatpak install flathub org.mozilla.Thunderbird
}
register_opt flatpak_install_thunderbird

# bitwarder passwd manager
function flatpak_install_bitwarden {
	flatpak install flathub com.bitwarden.desktop
}
register_opt flatpak_install_bitwarden

# cryptomator
function flatpak_install_cryptomator {
	flatpak install flathub org.cryptomator.Cryptomator
}
register_opt flatpak_install_cryptomator

# cryptomator
function flatpak_install_flatseal {
	flatpak install flathub com.github.tchx84.Flatseal
}
register_opt flatpak_install_flatseal

#####################
# END: Flatpak apps #
#####################

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

echo "=============="
echo "= operations ="
echo "=============="

# run main menu function
menu_opts
