#!/usr/bin/env bash
# @summary Delete the NeoVim configuration, data and state directories of this user
# @usage run system/neovim-reset
# @tags system neovim reset config
# @needs core
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core
main() {
  refuse_root
  local d; for d in "$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim"; do
    [[ -d $d ]] && dry rm -rf "$d" || log "not present: $d"
  done; return 0
}
run_main "$@"
