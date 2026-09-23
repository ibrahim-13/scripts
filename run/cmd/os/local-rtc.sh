#!/usr/bin/env bash
# @summary Keep the hardware clock in local time (avoids clock drift when dual-booting Windows)
# @usage run os/local-rtc
# @tags os time rtc windows dual-boot
# @needs core
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core
main() { log "setting local RTC as system time"; dry sudo timedatectl set-local-rtc 1 --adjust-system-clock; }
run_main "$@"
