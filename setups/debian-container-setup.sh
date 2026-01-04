#!/usr/bin/env bash
sudo apt update

if ! command -v which &> /dev/null; then
  echo "installing which"
  sudo apt install which -y
fi

echo "installing openssh server"
sudo apt install openssh-server -y

# sudo systemctl status ssh
# echo "restarting ssh server"
# sudo systemctl restart ssh

echo "enable the following options in the configuration file: /etc/ssh/sshd_config"
echo "Port 22"
echo "PermitRootLogin yes"
read -p "press any key to edit" TMP
sudo vi /etc/ssh/sshd_config

echo "generating all keys for ssh server"
sudo ssh-keygen -A

if ! command -v passwd &> /dev/null; then
  echo "installing passwd"
  sudo apt update
  sudo apt install which -y
fi

read -p "setting password for root, press any key to continue"
passwd root
