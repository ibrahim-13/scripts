# @summary Distro / role detection and distro-specific dispatch
# @needs core

## os_detect -> sets OS_ID (fedora, ubuntu, ...), OS_LIKE (ID_LIKE), OS_FAMILY, OS_ROLE; cached after first call
# OS_FAMILY names the package-manager family: dnf | apt | pacman | zypper | apk | brew | unknown.
# OS_ROLE is vm | host | container (RUN_ROLE=... overrides detection).
# TO ADD A FAMILY: add a pattern line to the case below, then write fn__<family> functions
# (e.g. pkg_install__xbps in lib/pkg.sh). Matching is done against " $ID $ID_LIKE " so
# derivatives (Rocky -> rhel, Pop!_OS -> ubuntu debian) map without their own entry.
os_detect() {
  [[ -n ${OS_FAMILY:-} ]] && return 0
  if [[ $(uname -s) == Darwin ]]; then                 # macOS: no os-release, Homebrew, always a host
    OS_ID=macos OS_LIKE= OS_FAMILY=brew OS_ROLE=${RUN_ROLE:-host}; export OS_ID OS_LIKE OS_FAMILY OS_ROLE; return 0
  fi
  local id like
  # /etc/os-release is specified to be sourceable shell; read it in a subshell.
  read -r id like < <( . /etc/os-release 2>/dev/null; printf '%s %s\n' "${ID:-unknown}" "${ID_LIKE:-}" )
  OS_ID=$id OS_LIKE=$like
  case " $id $like " in
    *" fedora "*|*" rhel "*|*" centos "*|*" rocky "*|*" almalinux "*) OS_FAMILY=dnf ;;
    *" debian "*|*" ubuntu "*)                                         OS_FAMILY=apt ;;
    *" arch "*)                                                        OS_FAMILY=pacman ;;
    *" suse "*|*" opensuse "*)                                         OS_FAMILY=zypper ;;
    *" alpine "*)                                                      OS_FAMILY=apk ;;
    *)                                                                 OS_FAMILY=unknown ;;
  esac
  if   [[ -n ${RUN_ROLE:-} ]]; then OS_ROLE=$RUN_ROLE
  elif have systemd-detect-virt; then
    if   systemd-detect-virt -cq; then OS_ROLE=container
    elif systemd-detect-virt -vq; then OS_ROLE=vm
    else                               OS_ROLE=host; fi
  elif grep -qw hypervisor /proc/cpuinfo 2>/dev/null; then OS_ROLE=vm
  else OS_ROLE=host; fi
  export OS_ID OS_LIKE OS_FAMILY OS_ROLE
}

## os_dispatch FN ARGS... -> call the most specific implementation: FN__<OS_ID>, FN__<OS_FAMILY>, FN__default
# Example: pkg_install -> pkg_install__fedora (if defined) else pkg_install__dnf else pkg_install__default.
# No implementation => die with the name of the function you need to write.
os_dispatch() {
  local fn=$1 impl; shift; os_detect
  for impl in "${fn}__${OS_ID}" "${fn}__${OS_FAMILY}" "${fn}__default"; do
    if declare -F "$impl" >/dev/null; then "$impl" "$@"; return; fi
  done
  die "$fn: no implementation for $OS_ID ($OS_FAMILY). Define ${fn}__${OS_FAMILY}()"
}

## os_require_family FAMILY... -> die unless OS_FAMILY is one of FAMILY (dnf apt pacman zypper apk brew); RUN_FORCE=1 warns instead
os_require_family() {
  os_detect
  local f; for f in "$@"; do [[ $OS_FAMILY == "$f" ]] && return 0; done
  [[ -n ${RUN_FORCE:-} ]] && { warn "package family is $OS_FAMILY, wanted: $* (forced)"; return 0; }
  die "this command is for $* systems — detected: $OS_ID ($OS_FAMILY)"
}

## os_require_role ROLE... -> die unless OS_ROLE is one of ROLE (RUN_FORCE=1 downgrades to a warning)
os_require_role() {
  os_detect
  local r; for r in "$@"; do [[ $OS_ROLE == "$r" ]] && return 0; done
  [[ -n ${RUN_FORCE:-} ]] && { warn "role is $OS_ROLE, wanted: $* (forced)"; return 0; }
  die "this command is for role(s): $* — detected: $OS_ROLE (set RUN_FORCE=1 to override)"
}
