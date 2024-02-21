#!/bin/sh

# Shared Variables
GH_AUTH_TOKEN=""
GH_RESPONSE=""
GH_CREATED_AT=""

# Github Variables
GH_ASSET_NAME="lf-linux-amd64.tar.gz"

# GitHub functions
func_gh_http() {
	GH_RESPONSE="$(wget --header="Accept: application/vnd.github+json" --header="X-GitHub-Api-Version: 2022-11-28" --header="" -qO- https://api.github.com/repos/$1/$2/releases/latest | jq --arg GH_ASSET_NAME $GH_ASSET_NAME '{"created_at":.created_at,"download_url":.assets[] | select(.name | contains($GH_ASSET_NAME)) | .browser_download_url}')"
}

func_gh_cli() {
	GH_RESPONSE="$(gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/$1/$2/releases/latest | jq --arg GH_ASSET_NAME $GH_ASSET_NAME '{"created_at":.created_at,"download_url":.assets[] | select(.name | contains($GH_ASSET_NAME)) | .browser_download_url}')"
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
	func_gh gokcehan lf
	GH_CREATED_AT=$(echo $GH_RESPONSE | jq -r '.created_at')
}

func_install() {
	echo Installing
	echo Release created at: $GH_CREATED_AT
	GH_DL_URL=$(echo $GH_RESPONSE | jq -r '.download_url')

	sudo mkdir /opt/lf
	sudo wget -q --show-progress -O /opt/lf/lf.tar.gz $GH_DL_URL
	sudo chmod 666 /opt/lf/lf.tar.gz
	echo Extracting files:
	sudo tar -xvzf /opt/lf/lf.tar.gz -C /opt/lf
	sudo chmod 755 /opt/lf/lf
	sudo ln -s /opt/lf/lf /bin/lf
	sudo rm /opt/lf/lf.tar.gz
	# Store created_at so that we can compare later for updating the app
	echo $GH_CREATED_AT | sudo tee /opt/lf/created_at
	# Create default config
	if [ ! -d $HOME/.config/lf ]
	then
		mkdir $HOME/.config/lf
	fi
	echo Writing default configuration
	sudo tee $HOME/.config/lf/lfrc > /dev/null <<EOT
# keybindings

map x 'cut'
map d 'delete'

# ui
set hidden
set info size:time
set sortby "name"
EOT
	sudo chmod 666 $HOME/.config/lf/lfrc
	echo Fetching icon config
	sudo wget -q --show-progress -O $HOME/.config/lf/icons https://raw.githubusercontent.com/gokcehan/lf/master/etc/icons.example
	sudo chmod 666 $HOME/.config/lf/icons
	# echo Fetching color config
	# sudo wget -q --show-progress -O $HOME/.config/lf/colors https://raw.githubusercontent.com/gokcehan/lf/master/etc/colors.example
	# sudo chmod 666 $HOME/.config/lf/colors
	echo Done
}

func_update() {
	echo Updating
}

func_uninstall() {
	echo Uninstalling
	sudo rm /bin/lf
	sudo rm -rf /opt/lf
	sudo rm -rf $HOME/.config/lf
	echo Done
}

echo =============
echo = Manage lf =
echo =============

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
	if [ ! -e /opt/lf/created_at ]
	then
		func_install
	else
		TMP_CURRENT_CREATED_AT=$(date +%s -d $GH_CREATED_AT)
		TMP_EXIST_CREATED_AT=$(date +%s -d $(cat /opt/lf/created_at))
		if [ $TMP_CURRENT_CREATED_AT -gt $TMP_EXIST_CREATED_AT ]
		then
			func_update
		else
			echo Already up to date
			func_install
		fi
	fi
elif [ "$INPUT_OPT" = "2" ]
then
	func_uninstall
else
	echo Invalid option!
fi
