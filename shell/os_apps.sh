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

# configure hostname, default is `fedora`
function set_hostname {
	local TMP_ANS
	read -p "hostname: " TMP_ANS
	if [[ ! -z "$TMP_ANS" ]]
	then
		sudo hostnamectl set-hostname $TMP_ANS
	else
		echo "empty input, hostname will not be changed"
	fi
}
register_opt set_hostname

# adjust how system time is stored
# ################################
# in case of dual-boot with windows, this is important to avoid system time conflict.
# because, windows stores system time in local format but fedora stores system time in utc format.
function set_local_rtc_system_time {
	echo "setting local rtc as system time"
	sudo timedatectl set-local-rtc 1 --adjust-system-clock
}
register_opt set_local_rtc_system_time

# enable flathub
function enable_flathub {
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
register_opt enable_flathub

# git source control
function install_git {
	sudo rpm-ostree install git
}
register_opt install_git

# gnome extension manager
function install_gnome_extensions {
	flatpak install flathub org.gnome.Extensions
}
register_opt install_gnome_extensions

# print out a curated list of gnome extensions
function print_gnome_extension_list {
	echo "KDE Connect for GNOME:"
	echo "https://extensions.gnome.org/extension/1319/gsconnect/"
	echo "UI Customization:"
	echo "https://extensions.gnome.org/extension/3843/just-perfection/"
	echo "Sleep and awake control:"
	echo "https://extensions.gnome.org/extension/517/caffeine/"
	echo "System monitoring:"
	echo "https://extensions.gnome.org/extension/1460/vitals/"
	echo "App Icons in Taskbar:"
	echo "https://extensions.gnome.org/extension/4944/app-icons-taskbar/"
	echo "Running app icon indicator:"
	echo "https://extensions.gnome.org/extension/615/appindicator-support/"
	echo "GNOME dock:"
	echo "https://extensions.gnome.org/extension/307/dash-to-dock/"
	echo "Systewide color picker:"
	echo "https://extensions.gnome.org/extension/3396/color-picker/"
	echo "Clipboard manager:"
	echo "https://extensions.gnome.org/extension/779/clipboard-indicator/"
	echo "Emoji selector:"
	echo "https://extensions.gnome.org/extension/1162/emoji-selector/"
	echo "Removable device icon in Taskbar:"
	echo "https://extensions.gnome.org/extension/7/removable-drive-menu/"
}
register_opt print_gnome_extension_list

function install_virt_manager {
	if command -v apt-get
	then
		echo "installing virt-manager packages"
		sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
		echo "adding $USER to group: kvm"
		sudo usermod -aG kvm $USER
		echo "adding $USER to group: libvirt"
		sudo usermod -aG libvirt $USER
		# echo "enabling systemd service: libvirtd"
		# sudo systemctl enable --now libvirtd
		# echo "systemd service status: libvirtd"
		# sudo systemctl start libvirtd
	else
		echo "package manager not found"
	fi
}
register_opt install_virt_manager

function install_podman {
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
register_opt install_podman

function install_font_mononoki {
	local FILE_ARCHIVE="/tmp/font-mononoki.tag.xz"
	local FONT_DOWNLOAD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.0/Mononoki.tar.xz"
	local DIR_EXTRACT="/tmp/font-mononoki"
	local DIR_FONT="$HOME/.local/share/fonts"

	mkdir -p "$DIR_EXTRACT"
	mkdir -p "$DIR_FONT"

	wget -q --show-progress -O "$FILE_ARCHIVE" "$FONT_DOWNLOAD_URL" || errexit "error downloading font archive"
	tar -xvf "$FILE_ARCHIVE" -C "$DIR_EXTRACT"
	cp "$DIR_EXTRACT/MononokiNerdFont-Regular.ttf" "$DIR_FONT/MononokiNerdFont-Regular.ttf"
	echo "installing mononoki font"
	fc-cache -fv

	# cleanup
	echo "cleaning up"
	rm "$FILE_ARCHIVE"
	rm -rf "$DIR_EXTRACT"
}
register_opt install_font_mononoki

# vscodium and add extensions
function install_vscodium {
	flatpak install flathub com.vscodium.codium

	echo --------------------
	echo Extension: Git Graph
	echo --------------------
	flatpak run com.vscodium.codium --install-extension mhutchie.git-graph # Git Graph
	echo -----------------
	echo Extension: Golang
	echo -----------------
	flatpak run com.vscodium.codium --install-extension golang.go # Golang
	echo ------------------------
	echo Extension: Spell Checker
	echo ------------------------
	flatpak run com.vscodium.codium --install-extension streetsidesoftware.code-spell-checker # Spell checker
}
register_opt install_vscodium

# google chrome
function install_google_chrome {
	flatpak install flathub com.google.Chrome
}
register_opt install_google_chrome

# brave browser
function install_brave_browser {
	flatpak install flathub com.brave.Browser
}
register_opt install_brave_browser

# microsoft edge browser
function install_microsoft_edge {
	flatpak install flathub com.microsoft.Edge
}
register_opt install_microsoft_edge

# kid3 audio tagger
function install_kid3 {
	flatpak install flathub org.kde.kid3
}
register_opt install_kid3

# discord
function install_discord {
	flatpak install flathub com.discordapp.Discord
}
register_opt install_discord

# bleachbit
function install_bleachbit {
	flatpak install flathub org.bleachbit.BleachBit
}
register_opt install_bleachbit

# gimp
function install_gimp {
	flatpak install flathub org.gimp.GIMP
}
register_opt install_gimp

# vlc media player
function install_vlc {
	flatpak install flathub org.videolan.VLC
}
register_opt install_vlc

# thunderbird email client
function install_thunderbird {
	flatpak install flathub org.mozilla.Thunderbird
}
register_opt install_thunderbird

# bitwarder passwd manager
function install_bitwarden {
	flatpak install flathub com.bitwarden.desktop
}
register_opt install_bitwarden

# cryptomator
function install_cryptomator {
	flatpak install flathub org.cryptomator.Cryptomator
}
register_opt install_cryptomator

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
