#!/usr/bin/env bash
# @summary Install nvm (v0.40.4), then Node LTS and the latest npm
# @usage run dev/nvm-node
# @tags dev node nvm npm javascript
# @needs core dl
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core dl
main() {
  refuse_root
  log "installing node version manager"
  if [[ -n ${DRY_RUN:-} ]]; then log "would run the nvm install script and 'nvm install --lts'"; return 0; fi
  dl_print https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
  log "installing node lts and updating npm"
  bash -c 'set +u; export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
           nvm install --lts && nvm use --lts && npm install -g npm@latest' || die "node installation failed"
}
run_main "$@"
