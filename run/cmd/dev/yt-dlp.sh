#!/usr/bin/env bash
# @summary Install or update yt-dlp nightly into ~/apps
# @usage run dev/yt-dlp
# @tags dev yt-dlp youtube download
# @needs core dl apps
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core dl apps
main() {
  refuse_root; apps_init; apps_migrate yt-dlp "$APPS_DIR/ytdlp.tag"
  local suffix=; [[ $(sys_arch 2) == aarch64 ]] && suffix=_aarch64
  app_update yt-dlp yt-dlp yt-dlp-nightly-builds "$APPS_DIR/yt-dlp" "https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp_$(sys_os 3)$suffix" || return 0
  chmod 755 "$APPS_DIR/yt-dlp"; apps_mark yt-dlp "$APP_TAG"
}
run_main "$@"
