# @summary Package management across distros: install/remove/update/refresh/clean/groups
# @needs core os
# Interactive by default (the package manager shows its transaction and asks); RUN_YES=1 adds the
# manager's own "yes" flag; DRY_RUN=1 only prints the command. Public API is the plain name,
# implementations are NAME__<family> (hidden from `run search`). New family: add NAME__<family>
# for each function below and the family itself in lib/os.sh os_detect.

## pkg_install PKG... -> install packages
pkg_install()       { os_dispatch pkg_install "$@"; }
## pkg_remove PKG... -> remove packages
pkg_remove()        { os_dispatch pkg_remove "$@"; }
## pkg_refresh -> refresh package metadata only
pkg_refresh()       { os_dispatch pkg_refresh; }
## pkg_update -> upgrade all installed packages
pkg_update()        { os_dispatch pkg_update; }
## pkg_clean -> drop the package manager's caches
pkg_clean()         { os_dispatch pkg_clean; }
## pkg_group_install GROUP... -> install distro package groups (dnf groups; meta-packages elsewhere)
pkg_group_install() { os_dispatch pkg_group_install "$@"; }
## pkg_install_for FAMILY:PKGS... -> install the list given for this machine's family, e.g. "dnf:a b" "apt:c" "*:d"
pkg_install_for() {
  os_detect; local spec
  for spec in "$@"; do
    # shellcheck disable=SC2086
    if [[ ${spec%%:*} == "$OS_FAMILY" || ${spec%%:*} == '*' ]]; then pkg_install ${spec#*:}; return; fi
  done
  die "no package list for $OS_FAMILY (have: $*)"
}
## pkg_repo_has PATTERN -> 0 if an enabled package repository matches PATTERN (case-insensitive)
pkg_repo_has()      { os_dispatch pkg_repo_has "$@"; }
## dnf_copr_enable USER/PROJECT -> enable a Fedora COPR unless it already is
dnf_copr_enable() {
  if dnf copr list 2>/dev/null | grep -qF -- "$1"; then log "copr $1 already enabled"; else dry sudo dnf copr enable ${RUN_YES:+-y} "$1"; fi
}

pkg_install__dnf()    { dry sudo dnf install ${RUN_YES:+-y} "$@"; }
pkg_install__apt()    { dry sudo apt-get install ${RUN_YES:+-y} "$@"; }
pkg_install__pacman() { dry sudo pacman -S --needed ${RUN_YES:+--noconfirm} "$@"; }
pkg_install__zypper() { dry sudo zypper ${RUN_YES:+--non-interactive} install "$@"; }
pkg_install__apk()    { dry sudo apk add "$@"; }
pkg_install__brew()   { dry brew install "$@"; }

pkg_remove__dnf()     { dry sudo dnf remove ${RUN_YES:+-y} "$@"; }
pkg_remove__apt()     { dry sudo apt-get purge ${RUN_YES:+-y} "$@"; }
pkg_remove__pacman()  { dry sudo pacman -Rs ${RUN_YES:+--noconfirm} "$@"; }
pkg_remove__brew()    { dry brew uninstall "$@"; }

pkg_refresh__dnf()    { dry sudo dnf check-update || true; }     # exit 100 = updates available
pkg_refresh__apt()    { dry sudo apt-get update; }
pkg_refresh__pacman() { dry sudo pacman -Sy; }
pkg_refresh__brew()   { dry brew update; }
pkg_refresh__default(){ :; }

pkg_update__dnf()     { dry sudo dnf upgrade ${RUN_YES:+-y}; }
pkg_update__apt()     { dry sudo apt-get upgrade ${RUN_YES:+-y}; }
pkg_update__pacman()  { dry sudo pacman -Syu ${RUN_YES:+--noconfirm}; }
pkg_update__brew()    { dry brew upgrade; }

pkg_clean__dnf()      { dry sudo dnf clean all; }
pkg_clean__apt()      { dry sudo apt-get clean; }
pkg_clean__pacman()   { dry sudo pacman -Sc ${RUN_YES:+--noconfirm}; }
pkg_clean__default()  { :; }

pkg_repo_has__dnf()     { dnf repolist 2>/dev/null | grep -qi -- "$1"; }
pkg_repo_has__apt()     { grep -rqi -- "$1" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; }
pkg_repo_has__default() { return 1; }

pkg_group_install__dnf()     { dry sudo dnf group install ${RUN_YES:+-y} "$@"; }
pkg_group_install__default() { pkg_install "$@"; }
