# @summary File and mount helpers: append-once, write with sudo, fstab, mount checks, ~ expansion
# @needs core

## line_exists LINE FILE -> 0 if FILE contains exactly LINE
line_exists() { [[ -f $2 ]] && grep -qFx -- "$1" "$2"; }

_fs_writable() { [[ -w $1 || ( ! -e $1 && -w $(dirname "$1") ) ]]; }

## append_once LINE FILE -> append LINE to FILE unless already there (sudo when not writable)
append_once() {
  local line=$1 file=$2
  if line_exists "$line" "$file"; then log "already in $file: $line"; return 0; fi
  if [[ -n ${DRY_RUN:-} ]]; then log "would append to $file: $line"; return 0; fi
  if _fs_writable "$file"; then printf '%s\n' "$line" >>"$file"; else printf '%s\n' "$line" | sudo tee -a "$file" >/dev/null; fi
  log "appended to $file: $line"
}

## write_file FILE <<EOF ... -> replace FILE with stdin (sudo when not writable; DRY_RUN shows the content)
write_file() {
  local file=$1
  if [[ -n ${DRY_RUN:-} ]]; then log "would write $file:"; sed 's/^/    | /' >&2; return 0; fi
  if _fs_writable "$file"; then cat >"$file"; else sudo tee "$file" >/dev/null; fi
  log "wrote $file"
}

## bashrc_add_path NAME DIR -> write ~/.bashrc.d/NAME.sh that appends DIR to PATH (Fedora's .bashrc sources that dir)
bashrc_add_path() { mkdir -p "$HOME/.bashrc.d"; write_file "$HOME/.bashrc.d/$1.sh" <<<"export PATH=\"\$PATH:$2\""; }

## fstab_add LINE -> append LINE to /etc/fstab unless present
fstab_add() { append_once "$1" /etc/fstab; }

## mount_exists DIR -> 0 if DIR is a mount point right now
mount_exists() { grep -q "[[:space:]]$1[[:space:]]" /proc/mounts; }

## ensure_unmounted DIR -> unmount DIR if mounted; die if it is busy
ensure_unmounted() {
  mount_exists "$1" || return 0
  warn "already mounted, unmounting: $1"
  dry sudo umount "$1" || die "mount is busy, refusing to force: $1"
}

## expand_path PATH -> expand a leading ~ and $VARS; command substitution is rejected
expand_path() {
  local p=$1
  [[ $p == *'`'* || $p == *'$('* ]] && die "unsafe characters in path: $p"
  case $p in '~') p=$HOME ;; '~/'*) p=$HOME/${p#\~/} ;; esac
  eval "printf '%s\n' \"$p\""
}
