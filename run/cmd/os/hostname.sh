#!/usr/bin/env bash
# @summary Set the machine hostname with hostnamectl (asks when no name is given)
# @usage run os/hostname [NAME]
# @tags os hostname
# @needs core
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core
main() {
  local name=${1:-}; [[ -n $name ]] || name=$(ask "hostname")
  [[ -n $name ]] || { warn "empty input, hostname will not be changed"; return 0; }
  dry sudo hostnamectl set-hostname "$name"
}
run_main "$@"
