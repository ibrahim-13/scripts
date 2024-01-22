#!/bin/sh

# This script can not run as root, use `sudo` for system commands
# If the script is running as root, `gh` command can not find the login information of the user

# Shared Variables
GH_AUTH_TOKEN=""
GH_RESPONSE=""
GH_CREATED_AT=""

# GitHub functions
func_gh_http() {
	GH_RESPONSE="$(wget --header="Accept: application/vnd.github+json" --header="X-GitHub-Api-Version: 2022-11-28" --header="" -qO- https://api.github.com/repos/$1/$2/releases/latest | jq '{"created_at":.created_at,"download_url":.assets[] | select(.name | contains("Linux_x86_64.tar.gz")) | .browser_download_url}')"
}

func_gh_cli() {
	GH_RESPONSE="$(gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/$1/$2/latest | jq '{"created_at":.created_at,"download_url":.assets[] | select(.name | contains("Linux_x86_64.tar.gz")) | .browser_download_url}')"
}

func_gh() {
	TMP=$(type -p gh >/dev/null || echo "")
	if [ "$TMP" = "" ]
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
	func_gh jesseduffield lazygit
	GH_CREATED_AT=$(echo $GH_RESPONSE | jq -r '.created_at')
}

func_install() {
	echo Installing
	echo Release created at: $GH_CREATED_AT
	GH_MARKTEXT_DL_URL=$(echo $GH_RESPONSE | jq -r '.download_url')

	sudo mkdir /opt/lazygit
	sudo wget -q --show-progress -O /opt/lazygit/lazygit.tar.gz $GH_MARKTEXT_DL_URL
	sudo chmod 666 /opt/lazygit/lazygit.tar.gz
	echo Extracting files:
	sudo tar -xvzf /opt/lazygit/lazygit.tar.gz -C /opt/lazygit
	sudo chmod 755 /opt/lazygit/lazygit
	sudo ln -s /opt/lazygit/lazygit /bin/lazygit
	# Store created_at so that we can compare later for updating the app
	echo $GH_CREATED_AT | sudo tee /opt/lazygit/created_at >/dev/null
	echo Done
}

func_update() {
	echo Updating
}

func_uninstall() {
	echo Uninstalling
	sudo rm /bin/lazygit
	sudo rm -rf /opt/lazygit
	echo Done
}

echo ======================
echo = Manage FuzzyFinder =
echo ======================

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
	if [ ! -e /opt/lazygit/created_at ]
	then
		func_install
	else
		TMP_CURRENT_CREATED_AT=$(date +%s -d $GH_CREATED_AT)
		TMP_EXIST_CREATED_AT=$(date +%s -d $(cat /opt/lazygit/created_at))
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
