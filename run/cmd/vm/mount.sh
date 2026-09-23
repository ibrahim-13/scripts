#!/usr/bin/env bash
# @summary Mount a virtio shared folder (virtiofs, or 9p with optional bindfs uid/gid remap), optionally persisted in /etc/fstab
# @usage run vm/mount -l LABEL -m MOUNT_DIR [-mm MAP_DIR] [-t virtiofs|9p] [--fstab] [-i]
# @tags vm mount virtiofs 9p bindfs fstab share qemu utm
# @roles vm
# @needs core os pkg fs
# @complete -l -m -mm -t --fstab -i --map-mount --label --mount-dir --type --interactive
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg fs
usage() {
  [[ -n ${1:-} ]] && warn "$1"
  cat <<'TXT'
Mount a virtio shared folder (virtiofs or virtio-9p) inside a VM.

  run vm/mount -l LABEL -m MOUNT_DIR [options]
  -l, --label        virtio device label/tag (required)
  -m, --mount-dir    base mount directory (required)
  -mm, --map-mount   bindfs remapped directory (optional; forces 9p)
  -t, --type         force transport: virtiofs | 9p (optional; default: try virtiofs, fall back to 9p)
      --fstab        persist entries to /etc/fstab and reload systemd
  -i, --interactive  prompt for any parameter not given
  (RUN_YES=1 / run -y answers every question with yes)

  run vm/mount -l share -m /mnt/shared
  run vm/mount -l share -m /mnt/shared -mm "$HOME/shared" --fstab
TXT
  exit 1
}
interactive() {
  log "interactive mode: prompting for missing parameters"
  [[ -n $label ]] || label=$(ask_required "virtio device label/tag")
  [[ -n $mnt ]]   || mnt=$(expand_path "$(ask_required "base mount directory")")
  if [[ -z $map && $type != virtiofs ]]; then local m; m=$(ask "bindfs remap directory (blank = none)"); [[ -n $m ]] && map=$(expand_path "$m"); fi
  if [[ -z $type && -z $map ]]; then
    case $(ask "transport: 1 = auto (virtiofs, fall back to 9p), 2 = virtiofs, 3 = 9p" 1) in 2) type=virtiofs ;; 3) type=9p ;; esac
  fi
  [[ $fstab == true ]] || { confirm "persist to /etc/fstab?" && fstab=true; }
  return 0
}
main() {
  os_require_role vm
  local label= mnt= map= type= fstab=false inter=false
  (( $# )) || usage "no arguments provided"
  while (( $# )); do case $1 in
    -l|--label) label=${2:-}; shift 2 ;;  -m|--mount-dir) mnt=${2:-}; shift 2 ;;
    -mm|--map-mount) map=${2:-}; shift 2 ;;  -t|--type) type=${2:-}; shift 2 ;;
    --fstab) fstab=true; shift ;;  -i|--interactive) inter=true; shift ;;
    -y) export RUN_YES=1; shift ;;  -h|--help) usage ;;  *) usage "invalid argument: $1" ;;
  esac; done
  [[ $inter == true ]] && interactive
  [[ -n $label ]] || usage "label is required";  [[ -n $mnt ]] || usage "mount directory is required"
  [[ -z $type || $type == virtiofs || $type == 9p ]] || usage "invalid type: $type (virtiofs or 9p)"
  [[ -n $map && $type == virtiofs ]] && die "--type virtiofs cannot be combined with --map-mount (bindfs remapping is 9p-only)"
  log "note: macOS/UTM hosts use the fixed label 'share'; host uid/gid differ from the guest (hence the bindfs remap)"
  local mtype fallback=false
  if   [[ -n $type ]]; then mtype=$type
  elif [[ -n $map ]];  then mtype=9p
  else mtype=virtiofs; fallback=true; fi
  if [[ $inter == true ]]; then
    printf '\n  label      : %s\n  mount-dir  : %s\n  type       : %s\n  map-mount  : %s\n  fstab      : %s\n\n' \
      "$label" "$mnt" "$([[ $fallback == true ]] && echo 'auto (virtiofs, fall back to 9p)' || echo "$mtype")" "${map:-none}" "$fstab"
    confirm "proceed?" || die "aborted by user"
  fi
  ensure_unmounted "$mnt"; [[ -n $map ]] && ensure_unmounted "$map"
  if [[ -n $map ]] && ! have bindfs; then
    confirm "bindfs is not installed; install fuse and bindfs?" || die "bindfs is required for --map-mount"
    pkg_install fuse bindfs
  fi
  dry sudo mkdir -p "$mnt"; [[ -n $map ]] && dry sudo mkdir -p "$map"
  mount_virtiofs() { dry sudo mount -t virtiofs "$label" "$mnt"; }
  mount_9p()       { dry sudo mount -t 9p -o trans=virtio,version=9p2000.L,rw "$label" "$mnt"; }
  log "mounting '$label' at '$mnt'"      # https://wiki.qemu.org/Documentation/9psetup
  if [[ $mtype == virtiofs ]]; then
    if [[ $fallback == true ]]; then
      if mount_virtiofs; then mtype=virtiofs; else warn "virtiofs failed, trying virtio-9p"; mount_9p || die "failed to mount as virtio-9p"; mtype=9p; fi
    else mount_virtiofs || die "failed to mount as virtiofs"; fi
  else mount_9p || die "failed to mount as virtio-9p"; fi
  log "mounted as $mtype"
  local fstab_mount fstab_map=
  if [[ $mtype == virtiofs ]]; then fstab_mount="$label $mnt virtiofs defaults,rw,nofail,noatime,nodiratime 0 0"
  else fstab_mount="$label $mnt 9p trans=virtio,version=9p2000.L,rw,_netdev,nofail,auto 0 0"; fi
  if [[ -n $map ]]; then
    local uid gid spec
    if [[ -n ${DRY_RUN:-} ]]; then uid=HOSTUID gid=HOSTGID; else
      uid=$(stat -c %u "$mnt"); gid=$(stat -c %g "$mnt"); [[ -n $uid && -n $gid ]] || die "unable to read uid/gid of $mnt"; fi
    spec="$uid/$(id -u):@$gid/@$(id -g)"
    log "setting up bindfs remap ($spec): $map"
    dry sudo bindfs "--map=$spec" "$mnt" "$map" || die "failed to set up bindfs mount"
    fstab_map="$mnt $map fuse.bindfs map=$spec,x-systemd.requires=$mnt,_netdev,nofail,auto 0 0"
  fi
  if [[ $fstab == true ]]; then
    fstab_add "$fstab_mount"; [[ -n $fstab_map ]] && fstab_add "$fstab_map"
    if confirm "live-mount from /etc/fstab now (unmount current mounts, daemon-reload, restart the fs target)?"; then
      [[ -n $map ]] && mount_exists "$map" && { dry sudo umount "$map" || warn "could not unmount $map"; }
      mount_exists "$mnt" && { dry sudo umount "$mnt" || warn "could not unmount $mnt"; }
      dry sudo systemctl daemon-reload          # regenerates .mount units from fstab; mounts nothing itself
      dry sudo systemctl restart network-fs.target 2>/dev/null || dry sudo systemctl restart remote-fs.target || die "failed to restart network-fs.target / remote-fs.target"
    fi
  fi
  log "done"
}
run_main "$@"
