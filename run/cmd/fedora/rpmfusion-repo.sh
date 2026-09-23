#!/usr/bin/env bash
# @summary Enable the RPM Fusion free + nonfree repositories and Cisco OpenH264 (Fedora)
# @usage run fedora/rpmfusion-repo
# @tags fedora dnf rpmfusion repository codecs
# @needs core os pkg
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
main() {
  os_require_family dnf
  if pkg_repo_has rpmfusion; then log "rpm fusion repositories already present"; else
    local rel; rel=$(rpm -E %fedora)
    pkg_install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$rel.noarch.rpm" \
                "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$rel.noarch.rpm"
  fi
  dry sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
}
run_main "$@"
