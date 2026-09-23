#!/usr/bin/env bash
# @summary Clean caches, refresh metadata and upgrade all packages (any distro)
# @usage run os/upgrade
# @tags os packages upgrade update
# @needs core os pkg
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
main() { log "upgrading packages"; pkg_clean; pkg_refresh; pkg_update; }
run_main "$@"
