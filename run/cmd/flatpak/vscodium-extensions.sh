#!/usr/bin/env bash
# @summary Install VSCodium (flatpak) extensions, each asked separately: Git Graph, Go, spell checker, vim, Open Remote SSH
# @usage run flatpak/vscodium-extensions
# @tags flatpak vscodium extensions editor
# @needs core
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core
main() {
  refuse_root
  local pair
  for pair in "Git Graph:mhutchie.git-graph" "Golang:golang.go" "Spell Checker:streetsidesoftware.code-spell-checker" \
              "VIM:vscodevim.vim" "Open Remote - SSH:jeanp413.open-remote-ssh"; do
    confirm_do "install extension: ${pair%%:*}?" flatpak run com.vscodium.codium --install-extension "${pair#*:}"
  done
}
run_main "$@"
