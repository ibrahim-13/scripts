#!/bin/bash

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

# update pakages
function func_update_packages {
	sudo rpm-ostree check-update
}

# rpmfution sources
function func_install_rpmfution_source {
	sudo rpm-ostree install \
		https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
		https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
	sudo reboot
}

# rpmfusion source update after major os upgrade
function func_update_rpmfusion_source {
	sudo rpm-ostree update --uninstall rpmfusion-free-release --uninstall rpmfusion-nonfree-release --install rpmfusion-free-release --install rpmfusion-nonfree-release
}

# configure hostname, default is `fedora`
function func_set_hostname {
	local TMP_ANS
	read -p "hostname: " TMP_ANS
	if [[ ! -z $TMP_AND ]]
	then
		sudo hostnamectl set-hostname $TMP_ANS
	else
		echo "empty input, hostname will not be changed"
	fi
}

# adjust how system time is stored
# ################################
# in case of dual-boot with windows, this is important to avoid system time conflict.
# because, windows stores system time in local format but fedora stores system time in utc format.
function func_set_system_time_local {
	sudo timedatectl set-local-rtc 1 --adjust-system-clock
}

# switch to full ffmpeg
function func_use_full_ffmpeg {
	sudo rpm-ostree swap ffmpeg-free ffmpeg --allowerasing
}

# enable fedora-cisco-openh264
function func_install_fedora_cisco_openh264 {
	sudo rpm-ostree config-manager --enable fedora-cisco-openh264
}

# update and multimedia group packages
function func_install_additional_codec {
	sudo rpm-ostree groupupdate multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
}

# update sound and video group packages
function func_upd_sound_video {
	sudo rpm-ostree groupupdate sound-and-video
}

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
function func_install_nvidia_drivers {
	sudo rpm-ostree install \
		akmod-nvidia \
		intel-media-driver \
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
	# sudo rpm-ostree override remove mesa-va-drivers --install mesa-va-drivers-freeworld
	# sudo rpm-ostree override remove mesa-vdpau-drivers --install mesa-vdpau-drivers-freeworld
	rpm-ostree install nvidia-vaapi-backend
}

# git source control
function func_install_git {
	sudo rpm-ostree install git
}

# vscodium and add extensions
function func_install_vscodium {
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

# google chrome
function func_install_google_chrome {
	flatpak install flathub com.google.Chrome
}

# brave browser
function func_install_brave_browser {
	flatpak install flathub com.brave.Browser
}

# microsoft edge browser
function func_install_microsoft_edge {
	flatpak install flathub com.microsoft.Edge
}

# kid3 audio tagger
function func_install_kid3 {
	flatpak install flathub org.kde.kid3
}

# discord
function func_install_discord {
	flatpak install flathub com.discordapp.Discord
}

# bleachbit
function func_install_bleachbit {
	flatpak install flathub org.bleachbit.BleachBit
}

# gimp
function func_install_gimp {
	flatpak install flathub org.gimp.GIMP
}

# vlc media player
function func_install_vlc {
	flatpak install flathub org.videolan.VLC
}

# thunderbird email client
function func_install_thunderbird {
	flatpak install flathub org.mozilla.Thunderbird
}

# bitwarder passwd manager
function func_install_bitwarden {
	flatpak install flathub com.bitwarden.desktop
}

# cryptomator
function func_install_cryptomator {
	flatpak install flathub org.cryptomator.Cryptomator
}

# This is the main menu where operations will be selected
function menu_main {
	local PS3=$'select operation: '
	local options=("update packages" \
		"rpmfution source" \
		"rpmfusion source upgrade (major ver)"\
		"set hostname" \
		"system time in local" \
		"switch to full ffmpeg" \
		"enable fedora-cisco-openh264" \
		"additional codec" \
		"sound and video" \
		"nvidia drivers" \
		"vscodium" \
		"google chrome" \
		"brave browser" \
		"microsoft edge" \
		"kid3" \
		"discord" \
		"bleachbit" \
		"gimp" \
		"vlc" \
		"thunderbird" \
		"bitwarden" \
		"cryptomator" \
		"quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"update packages")
				func_update_packages
				;;
			"rpmfution source")
				func_install_rpmfution_source
				;;
			"rpmfusion source upgrade (major ver)")
				func_update_rpmfusion_source
				;;
			"set hostname")
				func_set_hostname
				;;
			"system time in local")
				func_set_system_time_local
				;;
			"switch to full ffmpeg")
				func_use_full_ffmpeg
				;;
			"enable fedora-cisco-openh264")
				func_install_fedora_cisco_openh264
				;;
			"additional codec")
				func_install_additional_codec
				;;
			"sound and video")
				func_install_additional_codec
				;;
			"nvidia drivers")
				func_install_nvidia_drivers
				;;
			"vscodium")
				func_install_vscodium
				;;
			"google chrome")
				func_install_google_chrome
				;;
			"brave browser")
				func_install_brave_browser
				;;
			"microsoft edge")
				func_install_microsoft_edge
				;;
			"kid3")
				func_install_kid3
				;;
			"discord")
				func_install_discord
				;;
			"bleachbit")
				func_install_bleachbit
				;;
			"gimp")
				func_install_gimp
				;;
			"vlc")
				func_install_vlc
				;;
			"thunderbird")
				func_install_thunderbird
				;;
			"bitwarden")
				func_install_bitwarden
				;;
			"cryptomator")
				func_install_cryptomator
				;;
			"quit")
				break
				;;
			*) print_danger "invalid operation $REPLY";;
		esac
	done
}

echo "=============="
echo "= operations ="
echo "=============="

# run main menu function
menu_main
