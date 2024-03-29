#!/usr/bin/env bash
#
function func_config_os {
	echo "applying kde configs"
	if command -v kwriteconfig5
	then
		echo "configuring with: kwriteconfig5"
		echo "-------------------------------"
		echo "disabling activity tracking in settings"
		kwriteconfig5 --file kactivitymanagerdrc --group Plugins --key org.kde.ActivityManager.ResourceScoringEnabled --type bool false

		echo "disable certain KRunner searching sources"
		kwriteconfig5 --file krunnerrc --group Plugins --key appstreamEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key CharacterRunnerEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key baloosearchEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key bookmarksEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key browserhistoryEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key browsertabsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key calculatorEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key desktopsessionsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key DictionaryEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key helprunnerEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key katesessionsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key konsoleprofilesEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key krunner_spellcheckEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key kwinEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key locationsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key org.kde.activities2Enabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key org.kde.datetimeEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key org.kde.windowedwidgetsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key "PIM Contacts Search RunnerEnabled" --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key placesEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key plasma-desktopEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key recentdocumentsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key shellEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key unitconverterEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key webshortcutsEnabled --type bool false
		kwriteconfig5 --file krunnerrc --group Plugins --key windowsEnabled --type bool false

		echo "enable Night Color"
		kwriteconfig5 --file kwinrc --group NightColor --key Active --type bool true # Enable night color
		kwriteconfig5 --file kwinrc --group NightColor --key Mode Times # set mode custom time
		kwriteconfig5 --file kwinrc --group NightColor --key MorningBeginFixed 0800 # set start of morning
		kwriteconfig5 --file kwinrc --group NightColor --key EveningBeginFixed 1700 # set start of evening
		kwriteconfig5 --file kwinrc --group NightColor --key NightTemperature 5100 # set night temparature
	elif command -v gsettings
	then
		echo "configuring with: gsettings"
		echo "---------------------------"
		echo "disabling directory search indexes"
		gesttings set org.freedesktop.Tracker3.Miner.Files index-recursive-directories []
		gesttings set org.freedesktop.Tracker3.Miner.Files index-single-directories []
		echo "setting 12h clock format"
		gesttings set org.gnome.desktop.interface clock-format '12h'
		gesttings set org.gtk.Settings.FileChooser clock-format '12h'
		echo "setting weekday display"
		gesttings set org.gnome.desktop.interface clock-show-weekday true
		echo "setting darkmode"
		gesttings set org.gnome.desktop.interface color-scheme 'prefer-dark'
		echo "disabling lockscreen notification"
		gesttings set org.gnome.desktop.notifications show-in-lock-screen false
		echo "disabling recent files"
		gesttings set org.gnome.desktop.privacy remember-recent-files false
		gsettings set org.gnome.desktop.privacy remember-app-usage false
		gsettings set org.gnome.desktop.privacy recent-files-max-age 0
		echo "disabling app usage"
		gsettings set org.gnome.desktop.privacy remember-app-usage false
		echo "disabling technical problem reporting and software usage"
		gsettings set org.gnome.desktop.privacy report-technical-problems false
		gsettings set org.gnome.desktop.privacy send-software-usage-stats false
		echo "configuring auto removal of temp files"
		gesttings set org.gnome.desktop.privacy remove-old-temp-files true
		echo "configuring auto removal of trash files"
		gesttings set org.gnome.desktop.privacy remove-old-trash-files true
		echo "configuring auto removal time for temp and trash files"
		gesttings set org.gnome.desktop.privacy old-files-age 7
		echo "disabling external search providers"
		gesttings set org.gnome.desktop.search-providers disable-external true
		echo "setting desktop idle delay time"
		gesttings set org.gnome.desktop.session idle-delay 60
		echo "configuring nautilus"
		gesttings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
		gesttings set org.gnome.nautilus.preferences show-delete-permanently true
		gesttings set org.gnome.nautilus.preferences show-directory-item-counts 'never'
		gesttings set org.gnome.nautilus.preferences show-image-thumbnails 'never'
		echo "disabling location"
		gesttings set org.gnome.system.location enabled false
		echo "disabling update notification and auto update download"
		gesttings set org.gnome.software download-updates false
		gesttings set org.gnome.software download-updates-notify false
		echo "other configs"
		gesttings set org.gtk.Settings.FileChooser sort-directories-first true
		echo "configuring night time"
		echo "TODO"
	fi

	local DIR_KACTIVITYMANAGERD="$HOME/.local/share/kactivitymanagerd"
	if [[ -d "$DIR_KACTIVITYMANAGERD" ]]
	then
		echo "disabling kactivitymanagerd"
		rm -rf "$DIR_KACTIVITYMANAGERD"
		touch "$DIR_KACTIVITYMANAGERD"
	else
		echo "directory not found: $DIR_KACTIVITYMANAGERD"
	fi

	local DIR_RECENTDOCUMENTS="$HOME/.local/share/RecentDocuments"
	if [[ -d "$DIR_RECENTDOCUMENTS" ]]
	then
		echo "deleting recent documents"
		rm -rf "$DIR_RECENTDOCUMENTS"
		touch "$DIR_RECENTDOCUMENTS"
	else
		echo "directory not found: $DIR_RECENTDOCUMENTS"
	fi

	local FILE_RECENTDOCUMENTSXBEL="$HOME/.local/share/recently-used.xbel"
	if [[ -f "$FILE_RECENTDOCUMENTSXBEL" ]]
	then
		echo "deleting recently used history database"
		rm "$FILE_RECENTDOCUMENTSXBEL"
		mkdir "$FILE_RECENTDOCUMENTSXBEL"
	else
		echo "file not found: $FILE_RECENTDOCUMENTSXBEL"
	fi

	local FILE_USERPLACESXBEL="$HOME/.local/share/user-places.xbel"
	if [[ -f "$FILE_USERPLACESXBEL" ]]
	then
		echo "deleting user places history database"
		rm "$FILE_USERPLACESXBEL"
	else
		echo "file not found: $FILE_USERPLACESXBEL"
	fi


	local DIR_THUMBNAILSCACHE="$HOME/.cache/thumbnails"
	if [[ -d "$DIR_THUMBNAILSCACHE" ]]
	then
		echo "deleting thumbnails in cache"
		rm -rf "$DIR_THUMBNAILSCACHE"
		touch "$DIR_THUMBNAILSCACHE"
	else
		echo "directory not found: $DIR_THUMBNAILSCACHE"
	fi
}

echo "=================================="
echo "= operating system configuration ="
echo "=================================="
echo ""
func_config_os
