#!/usr/bin/env bash
# @summary Install or update binaries from GitHub releases into ~/apps: lf fzf helium rclone (skips when the recorded tag is current)
# @usage run gh/install NAME...
# @tags github release apps lf fzf helium rclone download
# @needs core dl apps fs
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core dl apps fs
CATALOG=(lf fzf helium rclone)
complete_hook() { printf '%s\n' "${CATALOG[@]}"; }
# Each app: app_update does tag lookup, state check and download; only the install step is specific.
app_lf() {
  app_update lf gokcehan lf "$TMP/lf.tar.gz" "https://github.com/gokcehan/lf/releases/download/{tag}/lf-$(sys_os 1)-$(sys_arch 1).tar.gz" || return 0
  tar -xzf "$TMP/lf.tar.gz" -C "$APPS_DIR" && chmod 755 "$APPS_DIR/lf"; apps_mark lf "$APP_TAG"
}
app_fzf() {
  app_update fzf junegunn fzf "$TMP/fzf.tar.gz" "https://github.com/junegunn/fzf/releases/download/{tag}/fzf-{ver}-$(sys_os 1)_$(sys_arch 1).tar.gz" || return 0
  tar -xzf "$TMP/fzf.tar.gz" -C "$APPS_DIR" && chmod 755 "$APPS_DIR/fzf"; apps_mark fzf "$APP_TAG"
}
app_helium() {                          # state name "helium-browser" as in the old script
  local target=$APPS_DIR/helium-browser-linux.AppImage
  app_update helium-browser imputnet helium-linux "$TMP/helium.AppImage" "https://github.com/imputnet/helium-linux/releases/download/{tag}/helium-{tag}-$(sys_arch 3).AppImage" || return 0
  cp -f "$TMP/helium.AppImage" "$target"; chmod 755 "$target"
  write_file "$APPS_DESKTOP_DIR/helium-browser-linux.desktop" <<DESK
[Desktop Entry]
Name=Helium Browser
Comment=Private, fast, and honest web browser
Exec=$target %F
Terminal=false
Type=Application
Categories=Internet;
Keywords=helium-browser;
Actions=NewWindow;NewIncognitoWindow;

[Desktop Action NewWindow]
Name=New Window
Exec=$target --new-window %F

[Desktop Action NewIncognitoWindow]
Name=New Incognito Window
Exec=$target --incognito %F
DESK
  have update-desktop-database && update-desktop-database "$APPS_DESKTOP_DIR"
  apps_mark helium-browser "$APP_TAG"
}
app_rclone() {                          # system-wide: /usr/bin/rclone + man page
  app_update rclone rclone rclone "$TMP/rclone.zip" "https://github.com/rclone/rclone/releases/download/{tag}/rclone-{tag}-$(sys_os 2)-$(sys_arch 1).zip" || return 0
  have unzip || die "unzip is required"
  unzip -q -o "$TMP/rclone.zip" -d "$TMP/rclone"
  local dir; dir=$(find "$TMP/rclone" -maxdepth 1 -type d -name 'rclone-*' | head -1); [[ -n $dir ]] || die "unexpected archive layout"
  sudo install -o root -g root -m 755 "$dir/rclone" /usr/bin/rclone.new && sudo mv /usr/bin/rclone.new /usr/bin/rclone
  if have mandb; then sudo mkdir -p /usr/local/share/man/man1; sudo cp -f "$dir/rclone.1" /usr/local/share/man/man1/rclone.1; sudo mandb -q
  else warn "mandb not found, man page not installed"; fi
  apps_mark rclone "$APP_TAG"
}
main() {
  refuse_root; (( $# )) || die "usage: run gh/install NAME...   (known: ${CATALOG[*]})"
  apps_init; TMP=$(tmpdir)
  local n; for n in "$@"; do require_known "$n" "${CATALOG[@]}"; log "app: $n"; "app_$n"; done
}
run_main "$@"
