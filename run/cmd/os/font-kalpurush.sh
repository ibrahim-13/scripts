#!/usr/bin/env bash
# @summary Install the Kalpurush Bangla font (OmicronLab) system-wide
# @usage run os/font-kalpurush
# @tags os fonts bangla kalpurush
# @needs core dl
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core dl
main() {
  local url=https://www.omicronlab.com/download/fonts/kalpurush.ttf tmp; tmp=$(tmpdir)
  log "downloading Kalpurush"; dl_to "$tmp/Kalpurush-OmicronLab.ttf" "$url"
  [[ -n ${DRY_RUN:-} ]] && { log "would copy to /usr/local/share/fonts and run fc-cache"; return 0; }
  [[ -f $tmp/Kalpurush-OmicronLab.ttf ]] || die "failed to download font"
  sudo mkdir -p /usr/local/share/fonts
  sudo cp "$tmp/Kalpurush-OmicronLab.ttf" /usr/local/share/fonts/Kalpurush-OmicronLab.ttf
  log "updating font cache"; fc-cache -fv
}
run_main "$@"
