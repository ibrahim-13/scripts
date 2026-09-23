#!/usr/bin/env bash
# @summary Install Flathub apps by short name (chrome brave edge zen vscodium discord vlc gimp ...) or by full id
# @usage run flatpak/install NAME|ID...
# @tags flatpak flathub install apps browser
# @needs core
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core
declare -A CATALOG=(
  [gnome-extensions]=org.gnome.Extensions      [vscodium]=com.vscodium.codium
  [podman-desktop]=io.podman_desktop.PodmanDesktop [chrome]=com.google.Chrome
  [brave]=com.brave.Browser                    [edge]=com.microsoft.Edge
  [zen]=app.zen_browser.zen                    [kid3]=org.kde.kid3
  [discord]=com.discordapp.Discord             [bleachbit]=org.bleachbit.BleachBit
  [gimp]=org.gimp.GIMP                         [vlc]=org.videolan.VLC
  [qbittorrent]=org.qbittorrent.qBittorrent    [thunderbird]=org.mozilla.Thunderbird
  [bitwarden]=com.bitwarden.desktop            [cryptomator]=org.cryptomator.Cryptomator
  [flatseal]=com.github.tchx84.Flatseal        [rclone-ui]=com.rcloneui.RcloneUI
  [localsend]=org.localsend.localsend_app
)
complete_hook() { printf '%s\n' "${!CATALOG[@]}" | sort; }
main() {
  refuse_root
  (( $# )) || die "usage: run flatpak/install NAME...   (known: $(complete_hook | tr '\n' ' '))"
  have flatpak || die "flatpak is not installed: run flatpak/flathub first"
  local n id; for n in "$@"; do
    if [[ -n ${CATALOG[$n]:-} ]]; then id=${CATALOG[$n]}; elif [[ $n == *.* ]]; then id=$n; else die "unknown app '$n' (known: $(complete_hook | tr '\n' ' '))"; fi
    log "installing $n ($id)"; dry flatpak install ${RUN_YES:+-y} flathub "$id"
  done
  [[ " $* " == *" vscodium "* ]] && log "hint: run flatpak/vscodium-extensions for Git Graph, Go, spell checker, vim, remote-ssh"; return 0
}
run_main "$@"
