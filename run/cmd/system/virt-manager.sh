#!/usr/bin/env bash
# @summary Install QEMU/KVM, libvirt and virt-manager; optionally enable libvirtd
# @usage run system/virt-manager
# @tags system virtualization qemu kvm libvirt virt-manager
# @needs core os pkg svc
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg svc
main() {
  os_detect; pkg_refresh
  case $OS_FAMILY in
    apt) RUN_YES=1 pkg_install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
         log "adding $USER to groups kvm and libvirt"; dry sudo usermod -aG kvm "$USER"; dry sudo usermod -aG libvirt "$USER" ;;
    dnf) pkg_group_install virtualization ;;
    *)   die "no virtualization recipe for $OS_FAMILY" ;;
  esac
  confirm_do "enable and start systemd service libvirtd?" svc_enable_now libvirtd
}
run_main "$@"
