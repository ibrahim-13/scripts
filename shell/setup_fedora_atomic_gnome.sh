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

# rpmfution sources
function install_rpmfusion_source {
	sudo rpm-ostree install \
		https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
		https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
	sudo reboot
}
register_opt install_rpmfusion_source

# update pakages
function rpmostree_update_packages {
	sudo rpm-ostree check-update
}
register_opt rpmostree_update_packages

# rpmfusion source update after major os upgrade
function rebase_rpmfusion_source {
	sudo rpm-ostree update --uninstall rpmfusion-free-release --uninstall rpmfusion-nonfree-release --install rpmfusion-free-release --install rpmfusion-nonfree-release
}
register_opt rebase_rpmfusion_source

function remove_unwanted_repos {
	local REPO_NAMES=("google-chrome.repo" \
		"rpmfusion-nonfree-nvidia-driver.repo" \
		"rpmfusion-nonfree-steam.repo")

	for REPO in "${REPO_NAMES[@]}"
	do
		if [[ -f "/etc/yum.repos.d/$REPO" ]]
		then
			echo "removing $REPO"
			sudo mv "/etc/yum.repos.d/$REPO" "/etc/yum.repos.d/$REPO.bak"
		fi
	done
}
register_opt remove_unwanted_repos

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

# add hardware codecs
function install_hardware_codecs {
	# for intel
	sudo rpm-ostree install intel-media-driver
	# for amd
	# sudo rpm-ostree override remove mesa-va-drivers --install mesa-va-drivers-freeworld
	# sudo rpm-ostree override remove mesa-vdpau-drivers --install mesa-vdpau-drivers-freeworld
}
register_opt install_hardware_codecs

# update sound and video group packages
function install_software_codec {
	# for kde-kionite
	# sudo rpm-ostree override remove libavcodec-free libavfilter-free libavformat-free libavutil-free libpostproc-free libswresample-free libswscale-free --install ffmpeg
	# sudo rpm-ostree install \
	# 	gstreamer1-plugin-libav \
	# 	gstreamer1-plugins-bad-free-extras \
	# 	gstreamer1-plugins-bad-freeworld \
	# 	gstreamer1-plugins-ugly \
	# 	gstreamer1-vaapi \
	# 	--allow-inactive

	# for gnone-sliverblue
	sudo rpm-ostree install \
		ffmpeg \
		gstreamer1-plugin-libav \
		gstreamer1-plugins-bad-free-extras \
		gstreamer1-plugins-bad-freeworld \
		gstreamer1-plugins-ugly \
		gstreamer1-vaapi \
		# --allow-inactive
}
register_opt install_software_codec

# akmod-nvidia : rhel/centos users can use kmod-nvidia instead
# xorg-x11-drv-nvidia : nvidia dirver
# intel-media-driver : hardware accelerated codec- intel
# mesa-va-drivers-freeworld: hardware accelerated codec- amd
# mesa-vdpau-drivers-freeworld: hardware accelerated codec- amd
# nvidia-vaapi-backend : hardware codec
# nvidia-vaapi-driver : nvidia vdpau/vaapi
# libva-utils : nvidia vdpau/vaapi
# vdpauinfo : nvidia vdpau/vaapi
# xorg-x11-drv-nvidia-cuda : optional for cuda/nvdec/nvenc support
# xorg-x11-drv-nvidia-cuda-libs: enable nvenc/nvdec
function install_nvidia_drivers {
	sudo rpm-ostree install \
		akmod-nvidia \
		nvidia-vaapi-backend \
		nvidia-vaapi-driver \
		libva-utils \
		vdpauinfo \
		xorg-x11-drv-nvidia-cuda \
		xorg-x11-drv-nvidia-cuda-libs
	sudo rpm-ostree kargs --append=rd.driver.blacklist=nouveau \
		--append=modprobe.blacklist=nouveau \
		--append=nvidia-drm.modeset=1 \
		initcall_blacklist=simpledrm_platform_driver_init
	rpm-ostree install nvidia-vaapi-backend
}
register_opt install_nvidia_drivers

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
	# echo ----------------------
	# echo Extension: VS Code Vim
	# echo ----------------------
	# flatpak run com.vscodium.codium --install-extension vscodevim.vim # VS Vimscodium.codium
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
