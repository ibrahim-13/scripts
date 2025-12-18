#!/usr/bin/env bash

# If not running as ROOT, then exit
# This script required root priviledges to function.
# if [ $(id -u) -ne 0 ]
# then
# 	echo "Error! This script requires root priviledges to run"
# 	exit 1
# fi

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

DIR_TMP="$HOME/.tmp"

function cleanup {
	if [ -d "$DIR_TMP" ]; then
			rm -rf "$DIR_TMP"
	fi
	mkdir -p $DIR_TMP
}
# cleanup when exiting
trap cleanup EXIT
# cleanup at startup
cleanup

#################################
# START: Configuration for `os` #
#################################

# add noatime option for filesystem, to get better performance
function os_set_fs_noatime {
	echo "instructions to add noatime for filesystem in /etc/fstab:"
	echo ""
	echo "#In Fedora, also see: /mnt/sysroot/etc/fstab"
	echo "# Use nano or vi"
	echo "-subvol=root,compress-zstd:1"
	echo "+subvol=root,noatime,compress-zstd:1"
	echo ""
	echo "# alternatively"
	echo "-defaults"
	echo "+defaults,noatime"
}
register_opt os_set_fs_noatime

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
function os_font_mononoki_install {
	local 
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
register_opt os_font_mononoki_install

###############################
# END: Configuration for `os` #
###############################

######################
# START: System apps #
######################

function system_upgrade_packages {
	# https://docs.fedoraproject.org/en-US/quick-docs/dnf-vs-apt/
	if command -v apt-get
	then
		echo "upgrading packages"
		sudo apt-get update
		sudo apt-get upgrade
	elif command -v dnf
	then
		echo "upgrading packages"
		sudo dnf check-update
		sudo dnf upgrade
	else
		echo "package manager not found"
	fi
}
register_opt system_upgrade_packages

function system_git_install {
	if command -v dnf
	then
		echo "installing git"
		sudo dnf check-update
		sudo dnf install git
	else
		echo "package manager not found"
	fi
}
register_opt system_git_install

function system_github_cli_install {
	if command -v dnf
	then
		echo "installing github cli"
		sudo dnf check-update
		sudo dnf install dnf5-plugins
		sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
		sudo dnf install gh --repo gh-cli
	else
		echo "package manager not found"
	fi
}
register_opt system_github_cli_install

function system_neovim_install {
	if command -v dnf
	then
		echo "installing neovim"
		sudo dnf check-update
		sudo dnf install neovim
	else
		echo "package manager not found"
	fi
}
register_opt system_neovim_install

function system_neovim_reset_conf {
	rm -rf "$HOME/.config/nvim"
	rm -rf "$HOME/.local/share/nvim"
	rm -rf "$HOME/.local/state/nvim"
}
register_opt system_neovim_reset_conf

function system_tmux_install {
	if command -v dnf
	then
		echo "installing tmux"
		sudo dnf install tmux
	else
		echo "package manager not found"
	fi
}
register_opt system_tmux_install

function system_install_distrobox {
	# https://docs.fedoraproject.org/en-US/quick-docs/dnf-vs-apt/
	if command -v apt-get
	then
		echo "installing distrobox"
		sudo apt-get update
		sudo apt-get instal distrobox
	elif command -v dnf
	then
		echo "installing distrobox"
		sudo dnf check-update
		sudo dnf install distrobox
	else
		echo "package manager not found"
	fi
}
register_opt system_install_distrobox

function system_virt_manager_install {
	if command -v apt-get
	then
		echo "installing virt-manager packages"
		sudo apt-get update
		sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
		echo "adding $USER to group: kvm"
		sudo usermod -aG kvm $USER
		echo "adding $USER to group: libvirt"
		sudo usermod -aG libvirt $USER
		# echo "enabling systemd service: libvirtd"
		# sudo systemctl enable --now libvirtd
		# echo "systemd service status: libvirtd"
		# sudo systemctl start libvirtd
	elif command -v dnf
	then
		echo "installing virtualization packages"
		sudo dnf check-update
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
register_opt system_virt_manager_install

function system_build_tools {
	if command -v apt-get
	then
		echo "installing build tools"
		sudo apt-get update
		sudo apt-get install build-essential
	elif command -v dnf
	then
		echo "installing build tools"
		sudo dnf check-update
		sudo dnf install @c-development @development-tools
	else
		echo "package manager not found"
	fi
}
register_opt system_build_tools

####################
# END: System apps #
####################

#######################
# START: Flatpak apps #
#######################

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

function flatpak_gnome_extensions_install {
	flatpak install flathub org.gnome.Extensions
}
register_opt flatpak_gnome_extensions_install

function flatpak_podman_install {	
	echo "installing podman desktop"
	flatpak install flathub io.podman_desktop.PodmanDesktop
}
register_opt flatpak_podman_install

function flatpak_vscodium_install {
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
register_opt flatpak_vscodium_install

function flatpak_google_chrome_install {
	flatpak install flathub com.google.Chrome
}
register_opt flatpak_google_chrome_install

function flatpak_brave_browser_install {
	flatpak install flathub com.brave.Browser
}
register_opt flatpak_brave_browser_install

function flatpak_microsoft_edge_install {
	flatpak install flathub com.microsoft.Edge
}
register_opt flatpak_microsoft_edge_install

function flatpak_kid3_install {
	flatpak install flathub org.kde.kid3
}
register_opt flatpak_kid3_install

function flatpak_discord_install {
	flatpak install flathub com.discordapp.Discord
}
register_opt flatpak_discord_install

function flatpak_bleachbit_install {
	flatpak install flathub org.bleachbit.BleachBit
}
register_opt flatpak_bleachbit_install

function flatpak_gimp_install {
	flatpak install flathub org.gimp.GIMP
}
register_opt flatpak_gimp_install

function flatpak_vlc_install {
	flatpak install flathub org.videolan.VLC
}
register_opt flatpak_vlc_install

function flatpak_thunderbird_install {
	flatpak install flathub org.mozilla.Thunderbird
}
register_opt flatpak_thunderbird_install

function flatpak_bitwarden_install {
	flatpak install flathub com.bitwarden.desktop
}
register_opt flatpak_bitwarden_install

function flatpak_cryptomator_install {
	flatpak install flathub org.cryptomator.Cryptomator
}
register_opt flatpak_cryptomator_install

function flatpak_flatseal_install {
	flatpak install flathub com.github.tchx84.Flatseal
}
register_opt flatpak_flatseal_install

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
