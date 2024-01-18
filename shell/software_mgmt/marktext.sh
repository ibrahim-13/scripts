#!/bin/sh

# Can not run as root, use `sudo` for system commands
# If the script is running as root, `gh` command can not find the login information of the user
# if [ $(id -u) -ne 0 ]
# then
	# echo "Error! This script requires root priviledges to run"
	# exit 1
# fi

# Shared Variables
GH_RESPONSE=""
GH_CREATED_AT=""
DESKTOP_FILE="[Desktop Entry]\n
Name=MarkText\n
Comment=Next generation markdown editor\n
Exec=marktext %F\n
Terminal=false\n
Type=Application\n
Icon=marktext\n
Categories=Office;TextEditor;Utility;\n
MimeType=text/markdown;\n
Keywords=marktext;\n
StartupWMClass=marktext\n
Actions=NewWindow;\n
\n
[Desktop Action NewWindow]\n
Name=New Window\n
Exec=marktext --new-window %F\n
Icon=marktext\n"

func_init() {
	echo Fetching latest release information from Github
	# Get latest release and store created_at and browser_download_url
	GH_RESPONSE="$(gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/marktext/marktext/releases/latest | jq '{"created_at":.created_at,"download_url":.assets[] | select(.name | contains("AppImage")) | .browser_download_url}')"
	GH_CREATED_AT=$(echo $GH_RESPONSE | jq -r '.created_at')
}

func_after() {
	echo Installing
	echo Release created at: $GH_CREATED_AT
	GH_MARKTEXT_DL_URL=$(echo $GH_RESPONSE | jq -r '.download_url')

	sudo mkdir /opt/marktext
	sudo wget -q --show-progress -O /opt/marktext/marktext.AppImage $GH_MARKTEXT_DL_URL
	sudo chmod 755 /opt/marktext/marktext.AppImage
	# Store created_at so that we can compare later for updating the app
	echo $GH_CREATED_AT | sudo tee /opt/marktext/created_at
	# Create desktop file
	sudo tee /opt/marktext/marktext.desktop > /dev/null <<EOT
[Desktop Entry]
Name=MarkText
Comment=Next generation markdown editor
Exec=marktext %F
Terminal=false
Type=Application
Icon=/opt/marktext/marktext_logo.png
Categories=Office;TextEditor;Utility;
MimeType=text/markdown;
Keywords=marktext;
StartupWMClass=marktext
Actions=NewWindow;

[Desktop Action NewWindow]
Name=New Window
Exec=marktext --new-window %F
Icon=marktext
EOT
	# Download logo
	sudo wget -q --show-progress -O /opt/marktext/marktext_logo.png https://raw.githubusercontent.com/marktext/marktext/develop/static/logo-small.png
	sudo ln -s /opt/marktext/marktext.AppImage /bin/marktext
	sudo ln -s /opt/marktext/marktext.desktop $HOME/.local/share/applications/marktext.desktop
	# Register app to the OS
	update-desktop-database $HOME/.local/share/applications/
	echo Done
}

func_update() {
	echo Updating
}

func_uninstall() {
	echo Uninstalling
	sudo rm /bin/marktext
	sudo rm $HOME/.local/share/applications/marktext.desktop
	sudo rm -rf /opt/marktext
	# Remove app registration from the OS
	update-desktop-database $HOME/.local/share/applications/
}

echo =======================
echo = Installing Marktext =
echo =======================

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
	if [ ! -e /opt/marktext/created_at ]
	then
		func_install
	else
		TMP_CURRENT_CREATED_AT=$(date +%s -d $GH_CREATED_AT)
		TMP_EXIST_CREATED_AT=$(date +%s -d $(cat /opt/marktext/created_at))
		if [ $TMP_CURRENT_CREATED_AT -gt $TMP_EXIST_CREATED_AT ]
		then
			func_update
		else
			echo Already up to date
			func_after_install
		fi
	fi
elif [ "$INPUT_OPT" = "2" ]
then
	func_uninstall
else
	echo Invalid option!
fi
