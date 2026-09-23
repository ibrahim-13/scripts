#!/usr/bin/env bash
# @summary Install tools by name on any distro: git tmux neovim podman distrobox btrfs-assistant build-tools hugo xvkbd jq awesome-desktop
# @usage run system/install NAME...
# @tags system packages install tools git tmux neovim podman distrobox btrfs hugo jq
# @needs core os pkg
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
CATALOG=(git tmux neovim podman distrobox btrfs-assistant build-tools hugo xvkbd jq awesome-desktop)
complete_hook() { printf '%s\n' "${CATALOG[@]}"; }
install_one() {
  require_known "$1" "${CATALOG[@]}"
  case $1 in
    build-tools)     if [[ $OS_FAMILY == dnf ]]; then pkg_group_install c-development development-tools
                     else pkg_install_for "apt:build-essential" "pacman:base-devel" "brew:gcc make"; fi ;;
    neovim)          pkg_install neovim ripgrep xsel ;;
    awesome-desktop) pkg_install_for "dnf:thunar thunar-archive-plugin engrampa xdg-user-dirs awesome desktop-file-utils git wget curl xclip xinput xset rsync" ;;
    *)               pkg_install "$1" ;;
  esac
}
main() {
  (( $# )) || die "usage: run system/install NAME...   (known: ${CATALOG[*]})"
  os_detect; pkg_refresh
  local n; for n in "$@"; do log "installing $n"; install_one "$n"; done
}
run_main "$@"
