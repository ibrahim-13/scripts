#!/usr/bin/env bash
# @summary Browse system logs: journal, kernel, services, Xorg, package managers, security (picker, then pager/dump/tail)
# @usage run logs/view [-l|--list]
# @tags logs journal journalctl dmesg systemd view
# @needs core
# @complete -l --list
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core
PAGER_CMD=${PAGER:-less}; [[ $PAGER_CMD == less ]] && PAGER_CMD="less -R +G"     # -R colors, +G start at the end
JCTL="SYSTEMD_COLORS=1 journalctl --no-pager"
CATS=() NAMES=() CMDS=()
add_log()     { CATS+=("$1"); NAMES+=("$2"); CMDS+=("$3"); }
add_service() { systemctl list-unit-files --type=service --no-legend "$2.service" 2>/dev/null | grep -q . && add_log "$1" "$2.service" "$JCTL -u $2.service"; return 0; }
add_file()    { if [[ -r $3 ]]; then add_log "$1" "$2" "cat '$3'"; elif [[ -e $3 ]]; then add_log "$1" "$2" "sudo cat '$3'"; fi; }
registry() {
  add_log "kernel/boot" "kernel log (current boot)"       "$JCTL -k -b 0"
  add_log "kernel/boot" "kernel log (previous boot)"      "$JCTL -k -b -1"
  add_log "kernel/boot" "dmesg (raw kernel ring buffer)"  "sudo dmesg --color=always"
  add_log "kernel/boot" "full journal (current boot)"     "$JCTL -b 0"
  add_log "kernel/boot" "full journal (previous boot)"    "$JCTL -b -1"
  add_log "kernel/boot" "errors and worse (current boot)" "$JCTL -b 0 -p err"
  add_log "kernel/boot" "boot timing (systemd-analyze blame)" "systemd-analyze blame --no-pager"
  add_file "kernel/boot" "boot.log" /var/log/boot.log
  local s
  for s in systemd-journald systemd-logind systemd-udevd systemd-resolved systemd-timesyncd systemd-oomd dbus-broker dbus polkit auditd crond cron chronyd rsyslog; do add_service "system services" "$s"; done
  for s in NetworkManager wpa_supplicant iwd firewalld sshd ssh bluetooth avahi-daemon tailscaled wireguard; do add_service "network" "$s"; done
  for s in gdm sddm lightdm; do add_service "desktop" "$s"; done
  add_file "desktop" "Xorg.0.log (system)"   /var/log/Xorg.0.log
  add_file "desktop" "Xorg.0.log (user)"     "$HOME/.local/share/xorg/Xorg.0.log"
  add_file "desktop" "Xorg.0.log.old (user)" "$HOME/.local/share/xorg/Xorg.0.log.old"
  add_file "desktop" ".xsession-errors"      "$HOME/.xsession-errors"
  add_file "desktop" ".xsession-errors.old"  "$HOME/.xsession-errors.old"
  add_log  "desktop" "gnome-shell (user journal)" "$JCTL --user -b 0 /usr/bin/gnome-shell 2>/dev/null || $JCTL -b 0 _COMM=gnome-shell"
  add_log  "desktop" "user session journal (current boot)" "$JCTL --user -b 0"
  for s in flatpak-system-helper cups upower udisks2 power-profiles-daemon tuned; do add_service "desktop" "$s"; done
  for s in docker containerd podman libvirtd virtqemud; do add_service "virt/containers" "$s"; done
  add_file "packages" "dnf.log" /var/log/dnf.log;  add_file "packages" "dnf.rpm.log" /var/log/dnf.rpm.log
  add_file "packages" "dnf5.log" /var/log/dnf5.log; add_file "packages" "apt history.log" /var/log/apt/history.log
  add_file "packages" "apt term.log" /var/log/apt/term.log; add_file "packages" "pacman.log" /var/log/pacman.log
  add_service "packages" packagekit
  add_file "security" "audit.log" /var/log/audit/audit.log; add_file "security" "secure (auth log)" /var/log/secure
  add_file "security" "auth.log" /var/log/auth.log
  add_log  "security" "failed login attempts" "sudo lastb 2>/dev/null || lastb"
  add_log  "security" "login history" "last"
  add_log  "security" "sudo usage (journal)" "$JCTL _COMM=sudo"
  add_log  "security" "SELinux denials (journal)" "$JCTL -t setroubleshoot -t audit --grep=AVC 2>/dev/null || $JCTL _TRANSPORT=audit"
}
list_all() { local i; for i in "${!NAMES[@]}"; do printf '%3d  %-16s %s\n' "$((i+1))" "${CATS[i]}" "${NAMES[i]}"; done; }
choose() {                                   # -> index, via the toolkit picker when present, else a numbered prompt
  local i pick=$RUN_ROOT/tools/pick.sh
  if [[ -x $pick ]]; then
    local sel; sel=$(for i in "${!NAMES[@]}"; do printf '%s\t%s\t%s\n' "$i" "${NAMES[i]}" "${CATS[i]}"; done | "$pick") || return 1
    printf '%s\n' "$sel"
  else
    list_all >&2; local n; n=$(ask "select (1-${#NAMES[@]}, q = quit)"); [[ $n =~ ^[0-9]+$ && $n -ge 1 && $n -le ${#NAMES[@]} ]] || return 1
    printf '%s\n' "$((n-1))"
  fi
}
view() {
  local name=${NAMES[$1]} cmd=${CMDS[$1]} mode lines
  log "log: $name"
  mode=$(ask "view with [p]ager, [f]ull dump, or last [n] lines" p)
  case $mode in
    f|F) bash -c "$cmd" ;;
    n|N) lines=$(ask "number of lines" 50); bash -c "$cmd" | tail -n "$lines" ;;
    *)   bash -c "$cmd" | $PAGER_CMD ;;
  esac
}
main() {
  registry
  (( ${#NAMES[@]} )) || die "no logs available on this system"
  case ${1:-} in -l|--list) list_all; return 0 ;; -h|--help) echo "usage: run logs/view [-l|--list]"; return 0 ;; esac
  [[ -n ${DRY_RUN:-} ]] && { log "would offer ${#NAMES[@]} logs"; return 0; }
  local idx; while idx=$(choose); do view "$idx"; done
}
run_main "$@"
