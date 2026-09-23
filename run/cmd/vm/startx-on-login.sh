#!/usr/bin/env bash
# @summary Start X automatically when logging in on tty1 (appends a startx guard to ~/.bashrc)
# @usage run vm/startx-on-login
# @tags vm startx x11 login bashrc
# @needs core fs
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core fs
main() {
  refuse_root
  local awesome="exec awesome &> $HOME/awesomewm.log"
  local startx='if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then exec startx; fi'
  have startx || { warn "startx not found, xorg autostart skipped"; return 0; }
  [[ -f $HOME/.bashrc ]] || { warn "$HOME/.bashrc not found, xorg autostart not configured"; return 0; }
  line_exists "$awesome" "$HOME/.xinitrc" || { warn "xinit is not configured yet (run vm/awesome-xinit first)"; return 0; }
  append_once "$startx" "$HOME/.bashrc"
}
run_main "$@"
