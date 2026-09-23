#!/usr/bin/env bash
# @summary Dev tools in a VM, all steps: package upgrade, ~/apps on PATH, yt-dlp nightly, Go, nvm + Node LTS, Claude CLI
# @usage run vm/dev-apps
# @tags vm dev apps group
# @roles vm
# @needs core os
# @steps os/upgrade dev/apps-path dev/yt-dlp dev/golang dev/nvm-node dev/claude-cli
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os
main() {
  os_require_role vm
  run_cmd os/upgrade
  run_cmd dev/apps-path
  run_cmd dev/yt-dlp
  run_cmd dev/golang
  run_cmd dev/nvm-node
  run_cmd dev/claude-cli
}
run_main "$@"
