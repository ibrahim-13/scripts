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
sudo chmod -x /usr/lib/x86_64-linux-gnu/libexec/kactivitymanagerd
sudo chmod -x /usr/lib/x86_64-linux-gnu/qt5/plugins/kactivitymanagerd
KACTIVITY_PID=$(ps -aux | grep kactivitymanage | grep -v grep | awk '$2 ~ /^[0-9]+$/ { print $2 }')
if [ ! "$KACTIVITY_PID" = "" ]
then
    echo killing kactivitymanagerd process id $KACTIVITY_PID
    kill -s 9 $KACTIVITY_PID
fi
rm -rf $HOME/.local/share/kactivitymanagerd
touch $HOME/.local/share/kactivitymanagerd

echo deleting recent documents
rm -rf $HOME/.local/share/RecentDocuments
touch $HOME/.local/share/RecentDocuments

echo deleting thumbnails in cache
rm -rf ~/.cache/thumbnails
touch ~/.cache/thumbnails
