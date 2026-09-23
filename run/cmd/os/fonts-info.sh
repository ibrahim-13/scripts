#!/usr/bin/env bash
# @summary Print where to get the Nerd font and the Bangla (Kalpurush) font (info only)
# @usage run os/fonts-info
# @tags os fonts nerd-font bangla info
# @needs core
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core
main() {
  log "nerd font: required for icons in the terminal"
  cat <<'TXT'
    1. go to https://github.com/ryanoasis/nerd-fonts/releases
    2. download any (e.g. Mononoki) nerd font from the release assets
    3. install by double-clicking or through the system font manager
TXT
  log "bangla font: required for complex characters (or: run os/font-kalpurush)"
  cat <<'TXT'
    1. go to https://www.omicronlab.com/bangla-fonts.html
    2. download the Kalpurush font
    3. install by double-clicking or through the system font manager
TXT
}
run_main "$@"
