#!/usr/bin/env bash
# @summary macOS: install or update the LuLu firewall from its GitHub release (state by release date)
# @usage run mac/lulu
# @tags mac macos lulu firewall github
# @needs core os dl apps
# @steps mac/dmg-install
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os dl apps
main() {
  os_detect; [[ $OS_ID == macos ]] || die "macOS only"
  refuse_root; apps_init
  local created url f; created=$(gh_latest_created_at objective-see LuLu)
  apps_current lulu "$created" && { log "LuLu is up to date ($created)"; return 0; }
  url=$(gh_asset_url objective-see LuLu 'LuLu_*.dmg'); f=$(tmpdir)/LuLu.dmg
  dl_to "$f" "$url"
  run_cmd mac/dmg-install -f "$f"
  apps_mark lulu "$created"
}
run_main "$@"
