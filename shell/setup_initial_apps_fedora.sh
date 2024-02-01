#!/bin/sh

echo "============================="
echo "= Initial Application Setup ="
echo "============================="
echo
echo

# If not running as ROOT, then exit
# This script required root priviledges to function.
if [ $(id -u) -ne 0 ]
then
	echo "Error! This script requires root priviledges to run"
	exit 1
fi

echo =============================
echo = Configure Package Sources =
echo =============================

# https://rpmfusion.org/
# echo ---------------------------
# echo Add RPM Fusion repositories
# echo ---------------------------
# dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
# dnf install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

echo ----------------------------
echo Enable fedora-cisco-openh264
echo ----------------------------
dnf config-manager --enable fedora-cisco-openh264

echo -----------------------------
echo Visual Studio Code repository
echo -----------------------------
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

# echo ------------------
# echo Add Flathub Remote
# echo ------------------
# flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Add backend for Discover (KDE)
# sudo dnf install plasma-discover-backend-flatpak
# sudo dnf install plasma-discover-flatpak

echo --------------
echo Update Package
echo --------------
dnf check-update

echo =======================
echo = Git Version Manager =
echo =======================
dnf install git

echo ===========
echo = ripgrep =
echo ===========
dnf install ripgrep

echo ==============
echo = GitHub Cli =
echo ==============
dnf install 'dnf-command(config-manager)'
dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
dnf install gh

echo ===============
echo = Cryptomator =
echo ===============
flatpak install flathub org.cryptomator.Cryptomator

echo ==============================
echo = Bitwarden Password Manager =
echo ==============================
flatpak install flathub com.bitwarden.desktop

echo ==============
echo = VLC Player =
echo ==============
dnf install vlc

echo ============================
echo = Thunderbird Email Client =
echo ============================
flatpak install flathub org.mozilla.Thunderbird

echo ========
echo = Gimp =
echo ========
flatpak install flathub org.gimp.GIMP

echo ======================
echo = Visual Studio Code =
echo ======================
dnf install code # or code-insiders
echo --------------------
echo Extension: Git Graph
echo --------------------
code --install-extension mhutchie.git-graph # Git Graph
echo -----------------
echo Extension: Golang
echo -----------------
code --install-extension golang.go # Golang
echo ----------------------
echo Extension: VS Code Vim
echo ----------------------
code --install-extension vscodevim.vim # VS Vim

echo ===================================
echo = Node Version Manager nvm-0.39.7 =
echo ===================================
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
command -v nvm
nvm install --reinstall-packages-from=current 'lts/*'

echo ===============================
echo = Bleachbit 4.6 for Fedora 28 =
echo ===============================
dnf install https://download.bleachbit.org/bleachbit-4.6.0-1.1.fc38.noarch.rpm

echo ===========
echo = Discord =
echo ===========
flatpak install flathub com.discordapp.Discord

echo =====================
echo = Kid3 Audio Tagger =
echo =====================
flatpak install flathub org.kde.kid3

# Configure hostname, default is `fedora`
echo ===========================
echo = Set hostname ibrahim-pc =
echo ===========================
sudo hostnamectl set-hostname ibrahim-pc

# In case of dual-boot with Windows, this is important to avoid system time conflict.
# Because, Windows stores system time in local format but Fedora stores system time in UTC format.
echo ====================================
echo = Adjust how system time is stored =
echo ====================================
timedatectl set-local-rtc 1 --adjust-system-clock

echo ========================
echo = Configure Multimedia =
echo ========================
# Refer to RMP Fusion for more info

echo ------------------------
echo Switching to full ffmpeg
echo ------------------------
dnf swap ffmpeg-free ffmpeg --allowerasing

echo -----------------
echo Additional Codecs
echo -----------------
dnf groupupdate multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

echo ---------------
echo Sound and Video
echo ---------------
dnf groupupdate sound-and-video

echo ---------------------------------
echo Hardware Accelerated Codec: Intel
echo ---------------------------------
dnf install intel-media-driver

# echo -------------------------------
# echo Hardware Accelerated Codec: AMD
# echo -------------------------------
# sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld
# sudo dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
#
echo ----------------------------------
echo Hardware Accelerated Codec: NVIDIA
echo ----------------------------------
sudo dnf install nvidia-vaapi-driver
