#!/usr/bin/env bash
# @summary Put ~/apps on PATH via ~/.bashrc.d/apps.sh
# @usage run dev/apps-path
# @tags dev path bashrc apps
# @needs core apps fs
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core apps fs
main() { refuse_root; apps_init; bashrc_add_path apps "$APPS_DIR"; }
run_main "$@"
