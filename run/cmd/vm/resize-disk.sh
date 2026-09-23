#!/usr/bin/env bash
# @summary Grow the LVM root filesystem (xfs) after the virtual disk was enlarged; every command is offered separately
# @usage run vm/resize-disk
# @tags vm disk resize lvm xfs storage
# @roles vm
# @needs core os
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os
# offer CMD... -> ask, then run CMD (eval'd so pipes/globs in the string work). No = skip, return 1.
offer() {
  if ! confirm ">>> run: $*?"; then log "skipped: $*"; return 1; fi
  [[ -n ${DRY_RUN:-} ]] && { log "would run: $*"; return 0; }
  eval "$*" || { warn "command failed (exit $?)"; return 1; }
}
check() { echo; echo "=== size check: $* ==="; [[ -n ${DRY_RUN:-} ]] || eval "$*"; echo "==============="; echo; }
main() {
  os_require_role vm
  cat <<'TXT'
###############################################################################
# STEP 0 — run this MANUALLY on the HOST (this command will NOT run it), then
# reboot the VM so the guest sees the extended disk:
#     sudo qemu-img resize /path/to/vm.qcow2 +20G
###############################################################################
TXT
  log "parsing live system info to find the devices backing /"
  local root_src root_real pv_part lv_path= path
  root_src=$(findmnt -no SOURCE /) || die "could not determine the source device of / (findmnt)"
  root_real=$(readlink -f "$root_src")
  pv_part=$(lsblk -rno NAME,TYPE,MOUNTPOINT,PKNAME | awk '$2 == "lvm" && $3 == "/" { print $4; exit }')
  [[ -n $pv_part ]] || die "could not find an LVM volume mounted at / in lsblk output"
  while read -r path; do [[ $(readlink -f "$path") == "$root_real" ]] && { lv_path=$path; break; }; done < <(sudo lvdisplay 2>/dev/null | awk '/LV Path/ { print $3 }')
  [[ -n $lv_path ]] || die "could not match any 'LV Path' from lvdisplay to $root_src"
  cat <<TXT

Figured-out parameters:
  root source (findmnt /)  : $root_src
  PV partition (from lsblk): /dev/$pv_part
  LV path (from lvdisplay) : $lv_path

Commands that will be offered:
  sudo pvresize /dev/$pv_part
  sudo lvextend -l +100%FREE $lv_path
  sudo xfs_growfs /

TXT
  confirm ">>> do these parameters look correct?" || die "aborting: parameters not confirmed"
  offer "lsblk" || true
  offer "sudo pvresize /dev/$pv_part" && check "sudo pvs; sudo vgs"
  offer "sudo lvdisplay" || true
  offer "sudo lvextend -l +100%FREE $lv_path" && check "sudo lvs"
  offer "sudo xfs_growfs /" && check "df -h /"
  offer "lsblk" || true
  log "done"
}
run_main "$@"
