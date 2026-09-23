#!/usr/bin/env bash
# @summary Install the Xorg display server (Fedora group base-x)
# @usage run vm/xorg
# @tags vm xorg x11 display
# @needs core os pkg
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
main() { os_require_family dnf; pkg_group_install base-x; log "xorg display server installed"; }
run_main "$@"
