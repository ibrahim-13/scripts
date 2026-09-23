#!/usr/bin/env bash
# @summary RPM Fusion extras, each asked separately: nvidia driver, vulkan, full ffmpeg, nvidia/intel hardware codecs
# @usage run fedora/rpmfusion-packages
# @tags fedora dnf rpmfusion nvidia vulkan ffmpeg codecs
# @needs core os pkg
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
main() {
  os_require_family dnf
  log "updating system packages"; RUN_YES=1 pkg_update
  confirm_do "if a new kernel was installed the system must reboot — reboot now?" sudo shutdown -r now
  if confirm "install nvidia drivers (akmod-nvidia)?"; then
    pkg_install akmod-nvidia; dry sudo dnf mark user akmod-nvidia; [[ -n ${DRY_RUN:-} ]] || sudo modinfo -F version nvidia || true
  fi
  confirm_do "install vulkan libraries?" pkg_install vulkan
  if confirm "install full ffmpeg (swap ffmpeg-free)?"; then
    dry sudo dnf swap ${RUN_YES:+-y} ffmpeg-free ffmpeg --allowerasing
    dry sudo dnf update ${RUN_YES:+-y} @multimedia --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin
  fi
  confirm_do "install nvidia hardware codec (libva-nvidia-driver)?" pkg_install libva-nvidia-driver
  confirm_do "install intel hardware codec (intel-media-driver)?" pkg_install intel-media-driver
}
run_main "$@"
