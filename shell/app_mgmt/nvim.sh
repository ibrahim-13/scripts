#!/bin/sh

# This script can not run as root, use `sudo` for system commands
# If the script is running as root, `gh` command can not find the login information of the user

# Shared Variables
GH_AUTH_TOKEN=""
GH_RESPONSE=""
GH_CREATED_AT=""

# Github Variables
GH_ASSET_NAME="nvim.appimage"

# GitHub functions
func_gh_http() {
	GH_RESPONSE="$(wget --header="Accept: application/vnd.github+json" --header="X-GitHub-Api-Version: 2022-11-28" --header="" -qO- https://api.github.com/repos/$1/$2/releases/latest | jq --arg GH_ASSET_NAME $GH_ASSET_NAME '{"created_at":.created_at,"download_url":.assets[] | select(.name == $GH_ASSET_NAME) | .browser_download_url}')"
}

func_gh_cli() {
	GH_RESPONSE="$(gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/$1/$2/releases/latest | jq --arg GH_ASSET_NAME $GH_ASSET_NAME '{"created_at":.created_at,"download_url":.assets[] | select(.name == $GH_ASSET_NAME) | .browser_download_url}')"
}

func_gh() {
	if ! [ -x "$(command -v gh)" ]
	then
		echo gh: command not found, using http api
		func_gh_http $1 $2
	else
		echo gh: command found, using gh cli
		GH_AUTH_TOKEN=$(gh auth token)
		if [ "$GH_AUTH_TOKEN" = "" ]
		then
			echo "gh: auth token not found, you may be not logged in, using http api"
			func_gh_http $1 $2
		else
			echo "gh: auth token found"
			func_gh_cli $1 $2
		fi
	fi
}

func_init() {
	echo Fetching latest release information from Github
	# Get latest release and store created_at and browser_download_url
	func_gh neovim neovim
	GH_CREATED_AT=$(echo $GH_RESPONSE | jq -r '.created_at')
}

func_install() {
	echo Installing
	echo Release created at: $GH_CREATED_AT
	GH_DL_URL=$(echo $GH_RESPONSE | jq -r '.download_url')

	TMP_CURRENT_DIR=$PWD
	sudo mkdir /opt/neovim
	sudo wget -q --show-progress -O /opt/neovim/neovim.AppImage $GH_DL_URL
	sudo chmod 755 /opt/neovim/neovim.AppImage
	sudo ln -s /opt/neovim/neovim.AppImage /bin/nvim
	type -p libfuse2 || {
		echo libfuse2 not found, extracting AppImage;
		cd /opt/neovim
		echo extracting AppImage contents
		sudo ./neovim.AppImage --appimage-extract >/dev/null
		sudo rm /bin/nvim
		sudo ln -s /opt/neovim/squashfs-root/AppRun /bin/nvim
		sudo rm neovim.AppImage
	}
	# Copy configuration
	if [ ! -d $HOME/.config ]
	then
		mkdir $HOME/.config
	fi
	if [ ! -d $HOM/.config/nvim ]
	then
		mkdir $HOME/.config/nvim
	fi
	echo $PWD
	if [ -f $TMP_CURRENT_DIR/nvim_config.lua ]
	then
		echo found: nvim_config.lua
		echo copying config file...
		sudo cp $TMP_CURRENT_DIR/nvim_config.lua $HOME/.config/nvim/init.lua
	fi
	# Store created_at so that we can compare later for updating the app
	echo $GH_CREATED_AT | sudo tee /opt/neovim/created_at
	echo Done
}

func_update() {
	echo Updating
}

func_uninstall() {
	echo Uninstalling
	sudo rm /bin/nvim
	sudo rm -rf /opt/neovim
	echo Removing configurations
	sudo rm -rf $HOME/.config/nvim
	sudo rm -rf $HOME/.local/share/nvim
	sudo rm -rf $HOME/.local/state/nvim
	echo Done
}

echo =================
echo = Manage NeoVim =
echo =================

echo "1) Install/Update"
echo "2) Uninstall"
INPUT_OPT=""
read -p "Choose: " INPUT_OPT

if [ "$INPUT_OPT" = "1" ]
then
	# Get data from Github
	func_init
	# Check if already installed
	# If installed and created_at date is before the current release create_at date, then update
	if [ ! -e /opt/neovim/created_at ]
	then
		func_install
	else
		TMP_CURRENT_CREATED_AT=$(date +%s -d $GH_CREATED_AT)
		TMP_EXIST_CREATED_AT=$(date +%s -d $(cat /opt/neovim/created_at))
		if [ $TMP_CURRENT_CREATED_AT -gt $TMP_EXIST_CREATED_AT ]
		then
			func_update
		else
			echo Already up to date
			func_nstall
		fi
	fi
elif [ "$INPUT_OPT" = "2" ]
then
	func_uninstall
else
	echo Invalid option!
fi
