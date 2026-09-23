#!/usr/bin/env bash
# @summary VM on a Mac host: en_US.UTF8 locale and the German Mac keyboard layout for X11
# @usage run vm/locale-mac
# @tags vm mac locale keyboard x11
# @needs core
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core
main() { dry localectl set-locale "en_US.UTF8"; dry localectl set-x11-keymap de pc105 mac; }
run_main "$@"
