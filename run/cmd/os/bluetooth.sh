#!/usr/bin/env bash
# @summary Bluetooth audio: start/enable the service and install the pipewire/pulseaudio bluetooth packages
# @usage run os/bluetooth
# @tags os bluetooth audio pipewire
# @needs core os pkg svc
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg svc
main() {
  if ! svc_active bluetooth.service; then warn "bluetooth service is not running"; confirm_do "start bluetooth service?" svc_start bluetooth; fi
  confirm_do "enable bluetooth service at boot?" svc_enable bluetooth
  pkg_refresh
  pkg_install_for "apt:pulseaudio-module-bluetooth pipewire-audio-client-libraries libspa-0.2-bluetooth" \
                  "dnf:pulseaudio-module-bluetooth pipewire-pulseaudio pipewire-alsa pipewire-jack" \
                  "pacman:pulseaudio-bluetooth pipewire pipewire-alsa pipewire-jack"
}
run_main "$@"
