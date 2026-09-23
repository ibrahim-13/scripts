#!/usr/bin/env bash
# @summary Print how to add noatime to /etc/fstab during installation (info only)
# @usage run os/noatime-info
# @tags os fstab noatime btrfs info
# @needs core
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core
main() {
  log "instructions to add noatime for the filesystem in /etc/fstab:"
  cat <<'TXT'

After setup has finished and the reboot button is shown, switch to another tty with Ctrl+Alt+F3
and edit the fstab file:

  # In Fedora, also see: /mnt/sysroot/etc/fstab   (use nano or vi)
  -subvol=root,compress-zstd:1
  +subvol=root,noatime,compress-zstd:1

  # alternatively
  -defaults
  +defaults,noatime
TXT
}
run_main "$@"
