#!/usr/bin/env bash
# @summary Dev VM on Fedora, all steps: locale, dnf.conf, upgrade, xorg, awesome wm, autostart, desktop tools, neovim, hugo, xvkbd, build tools, ffmpeg, ghostty
# @usage run vm/setup
# @tags vm setup fedora group
# @roles vm
# @needs core os
# @steps vm/locale-mac fedora/dnf-conf os/upgrade vm/xorg vm/awesome-xinit vm/startx-on-login system/install fedora/ffmpeg fedora/ghostty
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os
main() {
  os_require_role vm; os_require_family dnf
  run_cmd vm/locale-mac
  run_cmd fedora/dnf-conf
  run_cmd os/upgrade
  run_cmd vm/xorg
  run_cmd vm/awesome-xinit
  run_cmd vm/startx-on-login
  run_cmd system/install awesome-desktop neovim hugo xvkbd build-tools
  run_cmd fedora/ffmpeg
  run_cmd fedora/ghostty
  log "to start an xorg session, run: startx"
  log "if startx fails on xauth: set enable_xauth=0 in /usr/local/bin/startx"
}
run_main "$@"
