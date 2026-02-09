#!/usr/bin/env bash

if [ "$EUID" -eq 0 ]; then echo "do not run under root"; exit 1; fi

# Debugging
# ---------
# set -x : print out every line as it executes, with variables expanded
#		putting it at top of the script will enable this for the whole
#		script, or before a block of commands and end it with:
#		{ set +x; } 2>/dev/null
#
# bash -x script.sh : same as putting set -x at the top of script
# trap read DEBUG : stop before every line, can be put at the top
# trap '(read -p "[$BASE_SOURCE:$lineno] $bash_command")' DEBUG

# If not running as ROOT, then exit
# This script required root priviledges to function.
# if [ $(id -u) -ne 0 ]
# then
# 	echo "Error! This script requires root priviledges to run"
# 	exit 1
# fi

#--------------------------------------------------------------

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

SCRIPT_SOURCE=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )
  SCRIPT_SOURCE=$(readlink "$SCRIPT_SOURCE")
  [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE=$SCRIPT_DIR/$SCRIPT_SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR=$( cd -P "$( dirname "$SCRIPT_SOURCE" )" >/dev/null 2>&1 && pwd )

source "$SCRIPT_DIR/../util/common.sh"
source "$SCRIPT_DIR/../util/required.sh"


# set environment variables from .env file
# set -o allexport
# if [[ -f "$SCRIPT_DIR/.env" ]]; then source "$SCRIPT_DIR/.env"; fi
# set +o allexport

REGISTERED_OPT=()

# register menu option for display
# $1    function
# $2    name of the option
function register_opt {
	if [ -z "$1" ] || [ -z "$1" ]; then return; fi;
	REGISTERED_OPT+=("$1" "$2")
}

#################################
# START: Configuration for `os` #
#################################

# add noatime option for filesystem, to get better performance
function os_set_fs_noatime {
	print_info "instructions to add noatime for filesystem in /etc/fstab:"
	echo ""
	echo "After setup has finished and reboot button is shown, then go to another tty with alt + ctrl + F3 and then edit fstab file"
	echo ""
	echo "  #In Fedora, also see: /mnt/sysroot/etc/fstab"
	echo "  # Use nano or vi"
	echo "  -subvol=root,compress-zstd:1"
	echo "  +subvol=root,noatime,compress-zstd:1"
	echo ""
	echo "  # alternatively"
	echo "  -defaults"
	echo "  +defaults,noatime"
}
register_opt os_set_fs_noatime "Set noatime for filesystem"

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
register_opt os_set_hostname "Set hotname"

# adjust how system time is stored
# ################################
# in case of dual-boot with windows, this is important to avoid system time conflict.
# because, windows stores system time in local format but fedora stores system time in utc format.
function os_set_local_rtc_system_time {
	echo "setting local rtc as system time"
	sudo timedatectl set-local-rtc 1 --adjust-system-clock
}
register_opt os_set_local_rtc_system_time "Set Local RTC as System time"

function os_setup_tplink_tl_wn722n {
	local ERR_CODE
	print_info "setting up module for TPLINK TL-WN722N"
	echo "removing pci module: rtl8192cu"
	sudo modprobe -r rtl8192cu
	ERR_CODE=$?
	if [ ! "$ERR_CODE" == "0" ]
	then
		echo "failed to remove rtl8192cu with modprobe, adding to blacklist file"
		echo 'blacklist rtl8192cu' | sudo tee /etc/modprobe.d/blacklist-rtl8192cu.conf
	fi
	echo "loading usb module: rtl8xxxu"
	sudo modprobe rtl8xxxu
	if prompt_confirmation "update initramfs so that the changes are applied on boot?"
	then
		# This will update initramfs to always remove the PCI module
		# and load the USB module, when booting
		echo "updating initramfs"
		sudo update-initramfs -uk all
	else
		echo "initfamfs will not be updated"
	fi
	if prompt_confirmation "trigger usb device probe?"
	then
		sudo udevadm trigger
		sudo partprobe
		echo "alternatively follow any of these steps:"
		echo "1. usbreset"
		echo "    run lsusb, find id of the target device, then run-"
		echo "    > sudo usbreset XXXX:XXXX"
		echo "2. unbind/bind"
		echo "    run lsusb, find bus number of the target device, then run-"
		echo "    > echo '2-1' | sudo tee /sys/bus/usb/drivers/usb/unbind"
		echo "    > echo '2-1' | sudo tee /sys/bus/usb/drivers/usb/bind"
		echo ""
		echo "note: sometimes the usb device is initialized already and does not respond to probe."
		echo "      in this case, shut down the machine completely, shut off power, turn on the power and start again."
	else
		echo "device probe not triggered"
	fi
}
register_opt os_setup_tplink_tl_wn722n "Setup kernel module for TPLINK TL-WN722N"


function os_setup_bluetooth {
	local ERR_CODE
	print_info "setting up bluetooth"
	if systemctl is-active --quiet "bluetooth.service"
	then
		echo "bluetooth service not running"
		if prompt_confirmation "start bluetooth service?"
		then
			sudo systemctl start bluetooth
		fi
	fi
	
	if prompt_confirmation "enable bluetooth service?"
	then
		sudo systemctl enable bluetooth
	fi

	if command -v apt-get
	then
		echo "installing packages"
		sudo apt-get update
		sudo apt install pulseaudio-module-bluetooth
		sudo apt install pipewire-audio-client-libraries libspa-0.2-bluetooth
	elif command -v dnf
	then
		echo "installing packages"
		sudo dnf check-update
		sudo dnf install pulseaudio-module-bluetooth
		sudo dnf install pipewire-pulseaudio pipewire-alsa pipewire-jack
	elif command -v pacman
	then
		echo "installing packages"
		sudo pacman -S pulseaudio-bluetooth
		sudo pacman -S pipewire pipewire-alsa pipewire-jack
	else
		print_error "package manager not found"
	fi
}
register_opt os_setup_bluetooth "Setup packages for Bluetooth audio streaming"

function os_font_install_info {
	print_info "installing nerd font"
	echo "nerd font is required for showing icons in the terminal"
	echo "    1. go to https://github.com/ryanoasis/nerd-fonts/releases"
	echo "    2. download any (or Mononoki) nerd font from the release assets"
	echo "    3. installing by double clicking or throw system font management app"
	print_info "installing bangla font"
	echo "bangla font is required to show complex characters"
	echo "    1. go to https://www.omicronlab.com/bangla-fonts.html"
	echo "    2. download Kalpurush font"
	echo "    3. installing by double clicking or throw system font management app"
}
register_opt os_font_install_info "Print required font information"

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
		print_info "upgrading packages"
		sudo sudo apt clean
		sudo apt-get update
		sudo apt-get upgrade
	elif command -v dnf
	then
		print_info "upgrading packages"
		sudo dnf clean all
		sudo dnf check-update
		sudo dnf upgrade
	else
		print_error "package manager not found"
	fi
}
register_opt system_upgrade_packages "Upgrade system packages"

function system_setup_rpmfusion_repo {
	if ! command -v dnf &> /dev/null
	then
		print_error "not applicable for current system (no dnf)"
		return
	fi

	print_info "setting up rpm fusion"
	sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
	sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
}
register_opt system_setup_rpmfusion_repo "Setup RPM Fusion repository"

function system_setup_rpm_fusion_packages {
	if ! command -v dnf &> /dev/null
	then
		print_error "not applicable for current system (no dnf)"
		return
	fi

	echo "updating system packages"
	sudo dnf update -y

	if prompt_confirmation "if new kernel was installed, system must be rebooted, reboot now?"
	then
		sudo shutdown -r now
	else
		echo "skipping reboot"
	fi

	if prompt_confirmation "install nvidia drivers: akmod-nvidia?"
	then
		sudo dnf install akmod-nvidia # rhel/centos users can use kmod-nvidia instead
		sudo dnf mark user akmod-nvidia
		sudo modinfo -F version nvidia
	else
		echo "skipping nvidia drivers"
	fi

	if prompt_confirmation "install vulkun libraries?"
	then
		sudo dnf install vulkan
	else
		echo "skipping vulkun libraries"
	fi
	
	if prompt_confirmation "install full ffmpeg?"
	then
		sudo dnf swap ffmpeg-free ffmpeg --allowerasing
		sudo dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
	else
		echo "skipping full ffmpeg"
	fi

	if prompt_confirmation "install nvidia hardware codec?"
	then
		sudo dnf install libva-nvidia-driver
	else
		echo "skipping nvidia hardware codec"
	fi

	if prompt_confirmation "install intel hardware codec?"
	then
		sudo dnf install intel-media-driver
	else
		echo "skipping nvidia hardware codec"
	fi
}
register_opt system_setup_rpm_fusion_packages "Install RPM Fusion packages"

function system_git_install {
	if command -v apt-get
	then
		print_info "installing git"
		sudo apt-get update
		sudo apt-get install git
	elif command -v dnf
	then
		print_info "installing git"
		sudo dnf check-update
		sudo dnf install git
	else
		print_error "package manager not found"
	fi
}
register_opt system_git_install "Install Git"

function system_github_cli_install {
	if command -v apt-get
	then
		print_info "installing github cli"
		(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
			&& sudo mkdir -p -m 755 /etc/apt/keyrings \
			&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
			&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
			&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
			&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
			&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
			&& sudo apt update \
			&& sudo apt install gh -y
	elif command -v dnf
	then
		print_info "installing github cli"
		sudo dnf check-update
		sudo dnf install dnf5-plugins
		sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
		sudo dnf install gh --repo gh-cli
	else
		print_error "package manager not found"
	fi
}
register_opt system_github_cli_install "Install Github CLI"

function system_btrfs_assistant_install {
	if command -v apt-get
	then
		print_info "installing btrfs-assistant"
		sudo apt-get update
		sudo apt-get install btrfs-assistant
	elif command -v dnf
	then
		print_info "installing btrfs-assistant"
		sudo dnf check-update
		sudo dnf install btrfs-assistant
	else
		print_error "package manager not found"
	fi
}
register_opt system_btrfs_assistant_install "Install Btrfs Assistant"

function system_neovim_install {
	if command -v apt-get
	then
		print_info "installing neovim"
		sudo apt-get update
		sudo apt-get install neovim
	elif command -v dnf
	then
		print_info "installing neovim"
		sudo dnf check-update
		sudo dnf install neovim
	else
		print_error "package manager not found"
	fi
}
register_opt system_neovim_install "Install NeoVim"

function system_neovim_reset_conf {
	if [ -d "$HOME/.config/nvim" ]; then
			rm -rf "$HOME/.config/nvim"
	fi
	if [ -d "$HOME/.local/share/nvim" ]; then
			rm -rf "$HOME/.local/share/nvim"
	fi
	if [ -d "$HOME/.local/state/nvim" ]; then
			rm -rf "$HOME/.local/state/nvim"
	fi
}
register_opt system_neovim_reset_conf "Reset NeoVim configuration"

function system_tmux_install {
	if command -v apt-get
	then
		print_info "installing tmux"
		sudo apt-get update
		sudo apt-get install tmux
	elif command -v dnf
	then
		print_info "installing tmux"
		sudo dnf install tmux
	else
		print_error "package manager not found"
	fi
}
register_opt system_tmux_install "Install Tmux"

function system_install_distrobox {
	# https://docs.fedoraproject.org/en-US/quick-docs/dnf-vs-apt/
	if command -v apt-get
	then
		print_info "installing distrobox"
		sudo apt-get update
		sudo apt-get instal distrobox
	elif command -v dnf
	then
		print_info "installing distrobox"
		sudo dnf check-update
		sudo dnf install distrobox
	else
		print_error "package manager not found"
	fi
}
register_opt system_install_distrobox "Install DistroBox"

function system_virt_manager_install {
	if command -v apt-get
	then
		print_info "installing virt-manager packages"
		sudo apt-get update
		sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
		echo "adding $USER to group: kvm"
		sudo usermod -aG kvm $USER
		echo "adding $USER to group: libvirt"
		sudo usermod -aG libvirt $USER
		if prompt_confirmation "enable systemd service: libvirtd?"
		then
			echo "enabling systemd service"
			sudo systemctl enable --now libvirtd
			echo "starting systemd service"
			sudo systemctl start libvirtd
			echo "systemd service status: libvirtd"
			sudo systemctl status libvirtd
		fi
	elif command -v dnf
	then
		print_info "installing virtualization packages"
		sudo dnf check-update
		sudo dnf install @virtualization
		echo "use the following command to start virtualization service: sudo systemctl start libvirtd"
		# echo "adding $USER to group: kvm"
		# sudo usermod -aG kvm $USER
		# echo "adding $USER to group: libvirt"
		# sudo usermod -aG libvirt $USER
		if prompt_confirmation "enable systemd service: libvirtd?"
		then
			echo "enabling systemd service"
			sudo systemctl enable --now libvirtd
			echo "starting systemd service"
			sudo systemctl start libvirtd
			echo "systemd service status: libvirtd"
			sudo systemctl status libvirtd
		fi
	else
		print_error "package manager not found"
	fi
}
register_opt system_virt_manager_install "Install QEMU and Virt Manager"

function system_podman_install {
	if command -v apt-get
	then
		print_info "installing build tools"
		sudo apt-get update
		sudo apt-get install podman
	elif command -v dnf
	then
		print_info "installing build tools"
		sudo dnf check-update
		sudo dnf install podman
	else
		print_error "package manager not found"
	fi
}
register_opt system_podman_install "Install Podman"

function system_uninstall_firefox {
	if command -v apt-get
	then
		sudo apt-get purge firefox*
	elif command -v dnf
	then
		print_info "removing firefox"
		sudo dnf remove firefox
	elif command -v rpm-ostree
	then
		rpm-ostree override remove firefox firefox-langpacks
	else
		print_error "package manager not found"
	fi

	# remove application files
	sudo rm -Rf "/etc/firefox"
	sudo rm -Rf /usr/lib/firefox*
	sudo rm -rf /opt/firefox*
	sudo rm -rf /usr/local/bin/firefox*
	sudo rm -rf /usr/lib/firefox/
	sudo rm -rf /usr/lib/firefox-addons
	rm -rf "$HOME/.mozilla/firefox"
	rm -rf "$HOME/.cache/mozilla/firefox"
}
register_opt system_uninstall_firefox "Uninstall Firefox"

function system_build_tools {
	if command -v apt-get
	then
		print_info "installing build tools"
		sudo apt-get update
		sudo apt-get install build-essential
	elif command -v dnf
	then
		print_info "installing build tools"
		sudo dnf check-update
		sudo dnf install @c-development @development-tools
	else
		print_error "package manager not found"
	fi
}
register_opt system_build_tools "Install build tools"

function system_debian_add_sources {
	local DO_APPEND="false"
	if [ ! -f /etc/apt/sources.list.d/debian.sources ]
	then
		DO_APPEND="true"
	else
		if prompt_confirmation "source file exists, overwrite: /etc/apt/sources.list.d/debian.sources?"
		then
			DO_APPEND="true"
		fi
	fi

	if [ "$DO_APPEND" == "true" ]
	then
		tee "/etc/apt/sources.list.d/debian.sources"> /dev/null <<EOT
Types: deb deb-src
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
## If you want access to contrib and non-free components,
## add " contrib non-free" after "non-free-firmware":
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

EOT
	fi
}
register_opt system_debian_add_sources "Add package sources for Debian Trixie"

####################
# END: System apps #
####################

#######################
# START: Flatpak apps #
#######################

function flatpak_enable_flathub {
	print_info "adding flatpak"
	if command -v flatpak &> /dev/null
	then
		echo "flatpak already installed"
	else
		if command -v apt-get &> /dev/null
		then
			echo "installing flatpak"
			sudo apt-get update
			sudo apt-get install flatpak
			if [ "$XDG_CURRENT_DESKTOP" == "GNOME" ]
			then
				echo "adding gnome plugin"
				sudo apt-get install gnome-software-plugin-flatpak
			elif [ "$XDG_CURRENT_DESKTOP" == "KDE" ]
			then
				echo "adding kde plugin"
				sudo apt-get install plasma-discover-backend-flatpak
			fi
		else
			print_error "package manager not found"
		fi
	fi

	print_info "adding flathub"
	if flatpak remotes | grep -q flathub &> /dev/null
	then
		print_info "flathub exists in the repo list"
		if flatpak remotes --show-disabled | grep -q flathub &> /dev/null
		then
			print_info "flathub was disabled, enabling with no filter"
			flatpak remote-modify --enable --no-filter flathub
		fi
	else
		print_info "adding flathub remote"
		flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	fi
}
register_opt flatpak_enable_flathub "Enable FlatHub"

function flatpak_gnome_extensions_install {
	print_info "installing Gnome Extensions"
	flatpak install flathub org.gnome.Extensions
}
register_opt flatpak_gnome_extensions_install "[Flathub] Install GNOME Extensions"

function flatpak_vscodium_install {
	print_info "installing VSCodium"
	flatpak install flathub com.vscodium.codium

	if prompt_confirmation "install extension: Git Graph?"
	then
		echo "installing extension: Git Graph"
		flatpak run com.vscodium.codium --install-extension mhutchie.git-graph
	fi

	if prompt_confirmation "install extension: Golang?"
	then
		echo "installing extension: Golang"
		flatpak run com.vscodium.codium --install-extension golang.go
	fi

	if prompt_confirmation "install extension: Spell Checker?"
	then
		echo "installing extension: Spell Checker"
		flatpak run com.vscodium.codium --install-extension streetsidesoftware.code-spell-checker
	fi

	if prompt_confirmation "install extension: VIM?"
	then
		echo "installing extension: VIM"
		flatpak run com.vscodium.codium --install-extension vscodevim.vim
	fi

	if prompt_confirmation "install extension: Open Remote - SSH?"
	then
		echo "installing extension: Open Remote - SSH"
		flatpak run com.vscodium.codium --install-extension jeanp413.open-remote-ssh
	fi
}
register_opt flatpak_vscodium_install "[Flathub] Install VSCodium"

function flatpak_podman_desktop_install {	
	print_info "installing Podman Desktop"
	flatpak install flathub io.podman_desktop.PodmanDesktop
}
register_opt flatpak_podman_desktop_install "[Flathub] Install Podman Desktop"

function flatpak_google_chrome_install {
	print_info "installing Google Chrome"
	flatpak install flathub com.google.Chrome
}
register_opt flatpak_google_chrome_install "[Flathub] Install Google Chrome"

function flatpak_brave_browser_install {
	print_info "installing Brave Browser"
	flatpak install flathub com.brave.Browser
}
register_opt flatpak_brave_browser_install "[Flathub] Install Brave Browser"

function flatpak_microsoft_edge_install {
	print_info "installing Microsoft Edger Browser"
	flatpak install flathub com.microsoft.Edge
}
register_opt flatpak_microsoft_edge_install "[Flathub] Install Microsoft Edge"

function flatpak_zen_browser_install {
	print_info "installing Microsoft Edger Browser"
	flatpak install flathub app.zen_browser.zen
}
register_opt flatpak_zen_browser_install "[Flathub] Install Zen Browser"

function flatpak_kid3_install {
	print_info "installing Kid3"
	flatpak install flathub org.kde.kid3
}
register_opt flatpak_kid3_install "[Flathub] Install Kid3 Audio Tagger"

function flatpak_discord_install {
	print_info "installing Discord"
	flatpak install flathub com.discordapp.Discord
}
register_opt flatpak_discord_install "[Flathub] Install Discord"

function flatpak_bleachbit_install {
	print_info "installing BleachBit"
	flatpak install flathub org.bleachbit.BleachBit
}
register_opt flatpak_bleachbit_install "[Flathub] Install BleachBit"

function flatpak_gimp_install {
	print_info "installing GIMP"
	flatpak install flathub org.gimp.GIMP
}
register_opt flatpak_gimp_install "[Flathub] Install GIMP"

function flatpak_vlc_install {
	print_info "installing VLC"
	flatpak install flathub org.videolan.VLC
}
register_opt flatpak_vlc_install "[Flathub] Install VLC Player"

function flatpak_qbittorrent_install {
	print_info "installing qbittorrent"
	flatpak install flathub org.qbittorrent.qBittorrent
}
register_opt flatpak_qbittorrent_install "[Flathub] Install qBittorrent"

function flatpak_thunderbird_install {
	print_info "installing Mozilla ThunderBird"
	flatpak install flathub org.mozilla.Thunderbird
}
register_opt flatpak_thunderbird_install "[Flathub] Install ThunderBird"

function flatpak_bitwarden_install {
	print_info "installing BitWarden"
	flatpak install flathub com.bitwarden.desktop
}
register_opt flatpak_bitwarden_install "[Flathub] Install BitWarden"

function flatpak_cryptomator_install {
	print_info "installing Cryptomator"
	flatpak install flathub org.cryptomator.Cryptomator
}
register_opt flatpak_cryptomator_install "[Flathub] Install Cryptomator"

function flatpak_flatseal_install {
	print_info "installing FlatSeal"
	flatpak install flathub com.github.tchx84.Flatseal
}
register_opt flatpak_flatseal_install "[Flathub] Install FlatSeal"

function flatpak_rclone_ui {
	print_info "installing Rclone-UI"
	flatpak install flathub com.rcloneui.RcloneUI
}
register_opt flatpak_rclone_ui "[Flathub] Install Rclone UI"

function flatpak_localsend {
	print_info "installing LocalSend"
	flatpak install flathub org.localsend.localsend_app
}
register_opt flatpak_localsend "[Flathub] Install LocalSend"

#####################
# END: Flatpak apps #
#####################

# Menu for managing apps installation
register_opt quit "Quit/Exit"
MENU_UI=()
for ((i=0; i<${#REGISTERED_OPT[@]}; i+=2)); do
  MENU_UI+=("${REGISTERED_OPT[i+1]}")
done

while true; do
	SELECTED_OPT=$(gum filter "${MENU_UI[@]}" --limit 1 --height 10 --header "Select Operation")
  for ((i=0; i<${#REGISTERED_OPT[@]}; i+=2)); do
		if [[ "${REGISTERED_OPT[i+1]}" == "$SELECTED_OPT" ]]; then
			SELECTED_CMD="${REGISTERED_OPT[i]}"
			if [[ "$SELECTED_CMD" == "quit" ]]; then exit 0; fi
			$SELECTED_CMD
		fi
	done
done
