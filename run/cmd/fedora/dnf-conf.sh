#!/usr/bin/env bash
# @summary Write /etc/dnf/dnf.conf: fastest mirror, 10 parallel downloads, keep 3 kernels, no weak deps
# @usage run fedora/dnf-conf
# @tags fedora dnf config
# @needs core os fs
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../lib/loader.sh"; use core os fs
main() {
  os_require_family dnf
  [[ -f /etc/dnf/dnf.conf ]] || { warn "/etc/dnf/dnf.conf not found, skipping"; return 0; }
  write_file /etc/dnf/dnf.conf <<'CONF'
# see `man dnf.conf` for defaults and possible options
[main]

# Use the fastest mirror
fastestmirror=True

# Number of parallel downloads 10
max_parallel_downloads=10

# Ensures DNF always tries to install the highest version of a package
best=1

# Automatically removes orphaned dependencies when a package is uninstalled
clean_requirements_on_remove=True

# Limits the number of old kernels or install-only packages retained to prevent disk space exhaustion
installonly_limit=3

# Removes downloaded package archives after installation to save disk space
keepcache=0

# Ensures DNF verifies package signatures against trusted GPG keys
gpgcheck=1

# Sets the cache expiration to 12 hours (in seconds)
metadata_expire=43200

# Disable installing weak dependencies (such as Recommends or Supplements) when installing a package
install_weak_deps=false
CONF
}
run_main "$@"
