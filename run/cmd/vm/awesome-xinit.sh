#!/usr/bin/env bash
# @summary Start awesome wm from ~/.xinitrc (appends the exec line once)
# @usage run vm/awesome-xinit
# @tags vm awesome wm xinit x11
# @needs core fs
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core fs
main() {
  refuse_root
  [[ -f $HOME/.xinitrc ]] || warn "$HOME/.xinitrc did not exist, creating it"
  append_once "exec awesome &> $HOME/awesomewm.log" "$HOME/.xinitrc"
}
run_main "$@"
