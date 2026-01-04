#!/usr/bin/env bash

# exit immediately if any errors encountered
set -e

if ! command -v jq &> /dev/null
then
  if command -v dnf &> /dev/null
      then
          echo "[ dnf ] installing jq"
          sudo dnf check-update
          sudo dnf install jq
      elif command -v apt-get &> /dev/null
      then
          echo "[ apt-get ] installing jq"
          sudo apt-get update
          sudo apt-get install -y jq
      else
          errexit "could not detect package manager"
      fi
fi

# https://github.com/charmbracelet/gum
if ! command -v gum &> /dev/null
then
  if command -v yum &> /dev/null
  then
    echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
    sudo rpm --import https://repo.charm.sh/yum/gpg.key
    sudo yum install gum
  elif command -v apt &> /dev/null
  then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install gum
  elif command -v brew &> /dev/null
  then
    brew install gum
  fi
fi