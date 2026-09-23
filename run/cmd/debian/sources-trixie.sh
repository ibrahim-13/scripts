#!/usr/bin/env bash
# @summary Write /etc/apt/sources.list.d/debian.sources for Debian Trixie (main + non-free-firmware, deb-src)
# @usage run debian/sources-trixie
# @tags debian apt sources trixie
# @needs core os fs
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os fs
main() {
  os_require_family apt
  local f=/etc/apt/sources.list.d/debian.sources
  if [[ -f $f ]] && ! confirm "$f exists — overwrite it?"; then log "kept existing $f"; return 0; fi
  write_file "$f" <<'SRCS'
Types: deb deb-src
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
## If you want access to contrib and non-free components,
## add " contrib non-free" after "non-free-firmware":
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
SRCS
}
run_main "$@"
