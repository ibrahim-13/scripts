#!/usr/bin/env bash
# @summary Install flatpak if missing (with the GNOME/KDE software plugin) and add/enable the Flathub remote
# @usage run flatpak/flathub
# @tags flatpak flathub remote
# @needs core os pkg
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
main() {
  refuse_root; os_detect
  if have flatpak; then log "flatpak already installed"; else
    pkg_refresh; pkg_install flatpak
    case "$OS_FAMILY:${XDG_CURRENT_DESKTOP:-}" in
      apt:GNOME) pkg_install gnome-software-plugin-flatpak ;;
      apt:KDE)   pkg_install plasma-discover-backend-flatpak ;;
    esac
  fi
  [[ -n ${DRY_RUN:-} ]] && { log "would add/enable the flathub remote"; return 0; }
  if flatpak remotes | grep -q flathub; then
    log "flathub is in the remote list"
    if flatpak remotes --show-disabled | grep -q flathub; then log "flathub was disabled, enabling without filter"; flatpak remote-modify --enable --no-filter flathub; fi
  else
    log "adding the flathub remote"; flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}
run_main "$@"
