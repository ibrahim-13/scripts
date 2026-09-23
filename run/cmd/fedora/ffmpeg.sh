#!/usr/bin/env bash
# @summary Full ffmpeg from RPM Fusion (enables the repo first, swaps out ffmpeg-free)
# @usage run fedora/ffmpeg
# @tags fedora dnf rpmfusion ffmpeg
# @needs core os pkg
# @steps fedora/rpmfusion-repo
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
main() {
  os_require_family dnf
  run_cmd fedora/rpmfusion-repo
  dry sudo dnf swap ${RUN_YES:+-y} ffmpeg-free ffmpeg --allowerasing
  pkg_install ffmpeg
}
run_main "$@"
