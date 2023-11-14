#!/bin/sh

echo "=================="
echo "= Golang Updater ="
echo "=================="
echo

# If not running as ROOT, then exit
# This script required root priviledges to function.
if [ $(id -u) -ne 0 ]
then
	echo "Error! This script requires root priviledges to run"
	exit 1
fi

# Golang updater function
golang_upd()
{
	if [ "$MACHINE" = "x86_64" ]
	then
    		MACHINE="amd64"
	fi

	GO_FILE_NAME="$1.$ARCH-amd64.tar.gz"
	GO_DL_URL="https://go.dev/dl/$GO_FILE_NAME"
	GO_TMP_ARCHIVE="/tmp/$GO_FILE_NAME"

	echo "Downloading archive..."

	# If previous updating attempt failed or abruptly exited
	# without cleaning up the archive file, then remove the
	# previous archive file and start over.
	if [ -e $GO_TMP_ARCHIVE ]
	then
		echo "Cleaning up previously downloaded archive..."
		rm $GO_TMP_ARCHIVE
	fi

	echo
	# Download Golang binary archive in temporary folder
	wget -O $GO_TMP_ARCHIVE $GO_DL_URL

	# In case Golang is not installed, this directory will not exist
	if [ -d "/usr/local/go" ]
	then
		rm -rf /usr/local/go
	fi
	tar -C /usr/local -xzf $GO_TMP_ARCHIVE

	echo "Checking if Golang binaries exist in PATH env"
	PROF_STR_START="# START:Golang"
	PROF_STR_END="# END:Golang"
	if grep -Fxq "$PROF_STR_END" /etc/profile && grep -Fxq "$PROF_STR_START" /etc/profile
	then
		echo "Path of Golang binaries already added to PATH env"
	else
		echo "Adding path of Golang binaries to PATH env"
		echo >> /etc/profile
		echo "$PROF_STR_START" >> /etc/profile
		echo "export GOPATH=\$HOME/go" >> /etc/profile
		echo "export PATH=\$PATH:/usr/local/go/bin:\$GOPATH/bin" >> /etc/profile
		echo "$PROF_STR_END" >> /etc/profile
	fi

	# Clean up archive file
	rm $GO_TMP_ARCHIVE
}

if [ -e "/usr/local/go/VERSION" ]
then
	GO_VER_INSTALLED=$(cat /usr/local/go/VERSION | head --lines 1)
fi
GO_VER=$(wget -qO- https://go.dev/VERSION?m=text | head --lines 1)
ARCH=$(uname -s | tr '[:upper:]' '[:lower:]')
MACHINE=$(uname -m)

echo "Installed Golang : $GO_VER_INSTALLED"
echo "New Golang       : $GO_VER"
echo

if [ "$GO_VER_INSTALLED" = "$GO_VER" ]
then
	echo "Binaries up to date"
	read -p "Reinstall? (y/N): " REINSTALL_GOLANG
	echo "$REINSTALL_GOLANG"
	if [ "$REINSTALL_GOLANG" = "Y" ] || [ "$REINSTALL_GOLANG" = "y" ]
	then
		echo "Reinstalling Golang binaries..."
		echo
		exit
		golang_upd $GO_VER
	fi
else
	echo "Updating Golang binaries..."
	echo
	golang_upd $GO_VER
fi
