#!/usr/bin/env bash
# @summary Remove Firefox (package and leftover files, including this user's profile)
# @usage run system/firefox-uninstall
# @tags system firefox uninstall remove
# @needs core os pkg
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
main() {
  os_detect
  case $OS_FAMILY in
    apt) pkg_remove 'firefox*' ;;
    dnf) if have rpm-ostree; then dry rpm-ostree override remove firefox firefox-langpacks; else pkg_remove firefox; fi ;;
    *)   warn "no package recipe for $OS_FAMILY, removing files only" ;;
  esac
  log "removing application files"
  local p; for p in /etc/firefox /usr/lib/firefox /usr/lib/firefox-addons; do [[ -e $p ]] && dry sudo rm -rf "$p"; done
  if [[ -n ${DRY_RUN:-} ]]; then log "would remove /usr/lib/firefox* /opt/firefox* /usr/local/bin/firefox*"; else
    sudo rm -rf /usr/lib/firefox* /opt/firefox* /usr/local/bin/firefox*; fi
  dry rm -rf "$HOME/.mozilla/firefox" "$HOME/.cache/mozilla/firefox"
}
run_main "$@"
