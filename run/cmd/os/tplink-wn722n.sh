#!/usr/bin/env bash
# @summary Load the right kernel module for the TP-Link TL-WN722N USB wifi adapter (rtl8xxxu instead of rtl8192cu)
# @usage run os/tplink-wn722n
# @tags os kernel module wifi usb tplink
# @needs core fs
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core fs
main() {
  log "removing PCI module rtl8192cu"
  if ! dry sudo modprobe -r rtl8192cu; then
    warn "modprobe -r failed, blacklisting rtl8192cu instead"
    write_file /etc/modprobe.d/blacklist-rtl8192cu.conf <<<'blacklist rtl8192cu'
  fi
  log "loading USB module rtl8xxxu"; dry sudo modprobe rtl8xxxu
  confirm_do "update initramfs so the change applies on boot?" sudo update-initramfs -uk all
  if confirm "trigger a USB device probe?"; then
    dry sudo udevadm trigger; dry sudo partprobe
    cat <<'TXT'
alternatively:
  1. usbreset: run lsusb, find the device id, then   sudo usbreset XXXX:XXXX
  2. unbind/bind: run lsusb, find the bus number, then
       echo '2-1' | sudo tee /sys/bus/usb/drivers/usb/unbind
       echo '2-1' | sudo tee /sys/bus/usb/drivers/usb/bind
note: an already-initialised device may ignore the probe; power the machine fully off and on.
TXT
  else log "device probe not triggered"; fi
}
run_main "$@"
