#!/usr/bin/env bash
# @summary Install the Claude Code CLI with its official install script
# @usage run dev/claude-cli
# @tags dev claude cli ai
# @needs core dl
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core dl
main() {
  refuse_root; log "installing claude cli"
  if [[ -n ${DRY_RUN:-} ]]; then log "would run: curl https://claude.ai/install.sh | bash"; return 0; fi
  dl_print https://claude.ai/install.sh | bash
}
run_main "$@"
