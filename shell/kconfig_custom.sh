#!/bin/sh

echo disabling activity tracking in settings
kwriteconfig5 --file kactivitymanagerdrc --group Plugins --key org.kde.ActivityManager.ResourceScoringEnabled --type bool false # disable recent activity

echo disable certain KRunner searching sources
kwriteconfig5 --file krunnerrc --group Plugins --key "PIM Contacts Search RunnerEnabled" --type bool false
kwriteconfig5 --file krunnerrc --group Plugins --key appstreamEnabled --type bool false
kwriteconfig5 --file krunnerrc --group Plugins --key baloosearchEnabled --type bool false
kwriteconfig5 --file krunnerrc --group Plugins --key browserhistoryEnabled --type bool false
kwriteconfig5 --file krunnerrc --group Plugins --key locationsEnabled --type bool false
kwriteconfig5 --file krunnerrc --group Plugins --key recentdocumentsEnabled --type bool false
kwriteconfig5 --file krunnerrc --group Plugins --key webshortcutsEnabled --type bool false

echo enable Night Color
kwriteconfig5 --file kwinrc --group NightColor --key Active --type bool true # Enable night color
kwriteconfig5 --file kwinrc --group NightColor --key Mode Times # set mode custom time
kwriteconfig5 --file kwinrc --group NightColor --key MorningBeginFixed 0800 # set start of morning
kwriteconfig5 --file kwinrc --group NightColor --key EveningBeginFixed 1700 # set start of evening
kwriteconfig5 --file kwinrc --group NightColor --key NightTemperature 5100 # set night temparature

echo disabling kactivitymanagerd
rm -rf $HOME/.local/share/kactivitymanagerd
touch $HOME/.local/share/kactivitymanagerd

echo disabling gnome/gtk recent files
gsettings set org.gnome.desktop.privacy remember-recent-files false

echo deleting recent documents
rm -rf $HOME/.local/share/RecentDocuments
touch $HOME/.local/share/RecentDocuments
rm $HOME/.local/share/recently-used.xbel
touch $HOME/.local/share/recently-used.xbel
sudo chattr +i $HOME/.local/share/recently-used.xbel

echo deleting user places
rm $HOME/.local/share/user-places.xbel
touch $HOME/.local/share/user-places.xbel
sudo chattr +i $HOME/.local/share/user-places.xbel


echo deleting thumbnails in cache
rm -rf ~/.cache/thumbnails
touch ~/.cache/thumbnails
