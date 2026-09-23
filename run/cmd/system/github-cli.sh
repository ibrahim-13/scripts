#!/usr/bin/env bash
# @summary Install the GitHub CLI (gh) from GitHub's own apt or dnf repository
# @usage run system/github-cli
# @tags system github gh cli
# @needs core os pkg
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os pkg
main() {
  os_detect
  case $OS_FAMILY in
    apt)
      log "installing github cli (apt repo)"
      have wget || pkg_install wget
      if [[ -n ${DRY_RUN:-} ]]; then log "would add /etc/apt/keyrings/githubcli-archive-keyring.gpg and sources.list.d/github-cli.list"; else
        sudo mkdir -p -m 755 /etc/apt/keyrings
        wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
        sudo mkdir -p -m 755 /etc/apt/sources.list.d
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      fi
      pkg_refresh; RUN_YES=1 pkg_install gh ;;
    dnf)
      log "installing github cli (dnf repo)"
      pkg_refresh; pkg_install dnf5-plugins
      dry sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
      dry sudo dnf install ${RUN_YES:+-y} gh --repo gh-cli ;;
    brew) pkg_install gh ;;
    *) die "no gh install recipe for $OS_FAMILY" ;;
  esac
}
run_main "$@"
