#!/usr/bin/env bash
# @summary Update every GitHub-release app that is already installed (has a state file)
# @usage run gh/update
# @tags github release apps update
# @needs core apps
# @steps gh/install
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core apps
main() {
  local n names=()
  for n in lf fzf helium rclone; do
    if apps_installed "${n/helium/helium-browser}"; then names+=("$n"); else warn "$n not installed, skipping"; fi
  done
  (( ${#names[@]} )) || { log "nothing installed yet"; return 0; }
  run_cmd gh/install "${names[@]}"
}
run_main "$@"
