#!/bin/bash

gesttings set org.freedesktop.Tracker3.Miner.Files index-recursive-directories @as []
gesttings set org.freedesktop.Tracker3.Miner.Files index-single-directories @as []
gesttings set org.gnome.desktop.interface clock-format '12h'
gesttings set org.gnome.desktop.interface clock-show-weekday true
gesttings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gesttings set org.gnome.desktop.notifications show-in-lock-screen false
gesttings set org.gnome.desktop.privacy old-files-age uint32 7
gesttings set org.gnome.desktop.privacy remember-recent-files false
gesttings set org.gnome.desktop.privacy remove-old-temp-files true
gesttings set org.gnome.desktop.privacy remove-old-trash-files true
gesttings set org.gnome.desktop.search-providers disable-external true
gesttings set org.gnome.desktop.session idle-delay uint32 60
gesttings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gesttings set org.gnome.nautilus.preferences show-delete-permanently true
gesttings set org.gnome.nautilus.preferences show-directory-item-counts 'never'
gesttings set org.gnome.nautilus.preferences show-image-thumbnails 'never'
gesttings set org.gnome.system.location enabled false
gesttings set org.gtk.Settings.FileChooser clock-format '12h'
