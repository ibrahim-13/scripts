#!/usr/bin/env bash
# @summary macOS: mount a .dmg (file or URL) and install the .app into /Applications or run its .pkg
# @usage run mac/dmg-install -f FILE | -u URL
# @tags mac macos dmg install
# @needs core os dl
# @complete -f -u
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os dl
main() {
  os_detect; [[ $OS_ID == macos ]] || die "macOS only"
  local file= url=
  while (( $# )); do case $1 in -f|--file) file=$2; shift 2 ;; -u|--url) url=$2; shift 2 ;; *) die "usage: run mac/dmg-install -f FILE | -u URL" ;; esac; done
  [[ -n $file || -n $url ]] || die "usage: run mac/dmg-install -f FILE | -u URL"
  if [[ -z $file ]]; then file=$(tmpdir)/pkg.dmg; dl_to "$file" "$url"; fi
  [[ -n ${DRY_RUN:-} ]] && { log "would attach $file and install its .app/.pkg"; return 0; }
  local volume; volume=$(hdiutil attach "$file" -nobrowse | grep Volumes | cut -f 3)
  [[ -n $volume ]] || die "could not mount $file"
  if compgen -G "$volume/*.app" >/dev/null; then sudo cp -rf "$volume"/*.app /Applications
  elif compgen -G "$volume/*.pkg" >/dev/null; then sudo installer -pkg "$(ls -1 "$volume"/*.pkg | head -1)" -target /
  else warn "no .app or .pkg found in $volume"; fi
  hdiutil detach "$volume"
}
run_main "$@"
