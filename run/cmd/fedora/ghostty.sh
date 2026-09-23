#!/usr/bin/env bash
# @summary Install the Ghostty terminal from the scottames/ghostty COPR
# @usage run fedora/ghostty
# @tags fedora dnf copr ghostty terminal
# @needs core os pkg
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
main() { os_require_family dnf; dnf_copr_enable scottames/ghostty; pkg_install ghostty; }
run_main "$@"
