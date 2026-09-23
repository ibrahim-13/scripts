#!/usr/bin/env bash
# @summary Install or update Go into /usr/local/go from go.dev (PATH via ~/.bashrc.d/golang.sh)
# @usage run dev/golang
# @tags dev golang go
# @needs core dl apps fs
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core dl apps fs
main() {
  refuse_root; apps_init; apps_migrate golang "$APPS_DIR/golang.tag"
  local pattern file; pattern="go.*.$(sys_os 1)-$(sys_arch 1).tar.gz"
  file=$(dl_print "https://go.dev/dl/?mode=json" | grep -o "$pattern" | head -n 1 | tr -d '\r\n')
  [[ -n $file ]] || die "could not find a Go archive matching $pattern"
  apps_current golang "$file" && { log "go already at $file"; return 0; }
  log "golang: installing $file"; dl_to "$APPS_DIR/$file" "https://go.dev/dl/$file"
  if [[ -n ${DRY_RUN:-} ]]; then log "would replace /usr/local/go"; else
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "$APPS_DIR/$file"; rm -f "$APPS_DIR/$file"; apps_mark golang "$file"; fi
  bashrc_add_path golang /usr/local/go/bin
}
run_main "$@"
