# @summary Logging, error handling, privilege helpers, script entry point
# (no @needs: this is the root of the dependency graph; every other lib may depend on it)
# Libraries define functions only — no top-level side effects, no `set -e` (the caller decides).

## log MSG... -> blue "::" line on stderr
log()  { printf '\e[1;34m::\e[0m %s\n' "$*" >&2; }
## warn MSG... -> yellow "!!" line on stderr
warn() { printf '\e[1;33m!!\e[0m %s\n' "$*" >&2; }
## die [-c CODE] MSG... -> red "xx" line on stderr, then exit CODE (default 1)
die()  { local code=1; [[ ${1:-} == -c ]] && { code=$2; shift 2; }; printf '\e[1;31mxx\e[0m %s\n' "$*" >&2; exit "$code"; }
## have CMD -> 0 if CMD is an executable/function/builtin
have() { command -v "$1" >/dev/null 2>&1; }
## dry CMD ARGS... -> run CMD, or only print "would run: ..." when DRY_RUN=1
dry() { if [[ -n ${DRY_RUN:-} ]]; then log "would run: $*"; else "$@"; fi; }

## need_root -> re-exec the current script under sudo if not root; keeps args and the RUN_*/DRY_RUN variables
need_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] && return 0
  have sudo || die "need root and sudo is not available"
  log "re-executing as root"
  exec sudo --preserve-env=RUN_FORCE,DRY_RUN,RUN_ROLE,RUN_YES,RUN_CONFIRMED -- "$BASH" "$0" "$@"
}

## confirm QUESTION -> 0 if the user answers y/Y (reads the terminal, not stdin); RUN_YES=1 answers yes
confirm() {
  [[ -n ${RUN_YES:-} ]] && return 0
  local ans; read -r -p "$* [y/N] " ans </dev/tty || return 1; [[ $ans == [yY]* ]]
}
## confirm_do QUESTION CMD ARGS... -> run CMD (through dry) when the user confirms, otherwise log "skipped"
confirm_do() { local q=$1; shift; if confirm "$q"; then dry "$@"; else log "skipped: $*"; fi; }
## require_known VALUE KNOWN... -> die unless VALUE is one of KNOWN
require_known() { local v=$1 k; shift; for k in "$@"; do [[ $v == "$k" ]] && return 0; done; die "unknown '$v' (known: $*)"; }
## ask PROMPT [DEFAULT] -> print the answer typed on the terminal (DEFAULT when empty or when RUN_YES=1)
ask() {
  local ans=; if [[ -z ${RUN_YES:-} ]]; then read -r -p "$1${2:+ [$2]}: " ans </dev/tty || ans=; fi
  printf '%s\n' "${ans:-${2:-}}"
}
## ask_required PROMPT -> like ask, but repeats until something is typed
ask_required() { local ans=; while [[ -z $ans ]]; do read -r -p "$1: " ans </dev/tty || die "no input"; done; printf '%s\n' "$ans"; }
## refuse_root -> die when running as root (for commands that set up the user's own account)
refuse_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] && die "do not run this as root"; return 0; }
## tmpdir -> print a fresh temporary directory that is removed when the script exits
tmpdir() { local d; d=$(mktemp -d); trap 'rm -rf "'"$d"'"' EXIT; printf '%s\n' "$d"; }

## run_cmd <ns>/<name> [ARGS...] -> run another command as a step of this one (command groups)
# Locally the step's file is executed as a child process, so its `set -e`, functions and
# variables stay separate; its exit status is returned (a failing step aborts a `set -e` group).
# In a bundle the bundler defines one __step_<id>() function per "# @steps" entry and this
# function calls that instead. A step that is missing from @steps is caught here with a hint.
# Steps run with RUN_CONFIRMED=1: the group was confirmed as a whole, so the steps' own gate is
# skipped — but their inner confirm/ask questions still work (only RUN_YES silences those).
run_cmd() {
  local id=$1; shift
  local fn="__step_${id//[^A-Za-z0-9]/_}"
  log "step: $id${*:+ $*}"
  if declare -F "$fn" >/dev/null; then RUN_CONFIRMED=1 "$fn" "$@"; return; fi
  [[ -x $RUN_CMD/$id.sh ]] || die "run_cmd: no such command '$id' (in a bundle: add it to '# @steps')"
  RUN_CONFIRMED=1 "$RUN_CMD/$id.sh" "$@"
}

# _run_confirm ARGS... -> "Run <id> ARGS? [y/N]" on the terminal before main(). Skipped when
# RUN_YES=1 (`run -y`: yes to everything), RUN_CONFIRMED=1 (gate already passed: set for steps by
# run_cmd, by `run remote`, and here after a yes so a sudo re-exec does not ask again) or DRY_RUN=1.
# Without a terminal it dies with a hint.
# In a bundle $0 is `bash`, so the bundler injects RUN_BUNDLE_ID/_SUMMARY/_STEPS instead.
_run_confirm() {
  [[ -n ${RUN_YES:-} || -n ${RUN_CONFIRMED:-} || -n ${DRY_RUN:-} ]] && return 0
  local id=${RUN_BUNDLE_ID:-} summary=${RUN_BUNDLE_SUMMARY:-} steps=${RUN_BUNDLE_STEPS:-}
  if [[ -z $id && -f $0 ]]; then
    id=$(readlink -f "$0"); id=${id#"${RUN_CMD:-}/"}; id=${id%.sh}
    summary=$(_run_header_field "$0" summary); steps=$(_run_header_field "$0" steps | tr '\n' ' ')
  fi
  { : </dev/tty; } 2>/dev/null || die "no terminal to confirm '${id:-$0}'; set RUN_YES=1 (or run -y) to run unattended"
  printf '\e[1m%s\e[0m%s\n' "${id:-$0}" "${summary:+ — $summary}" >&2
  [[ -n ${steps// } ]] && printf '  group of: %s\n' "$steps" >&2
  local ans; read -r -p "Run ${id:-$0}${*:+ $*}? [y/N] " ans </dev/tty
  [[ $ans == [yY]* ]] || die -c 130 "cancelled"
  export RUN_CONFIRMED=1
}

## run_main "$@" -> confirm, then call main() only when the script is EXECUTED, not when it is sourced.
# Also implements the `--complete` protocol used by tab completion: prints the words of the
# "# @complete" header field, then the output of complete_hook (if the script defines one).
run_main() {
  local caller=${BASH_SOURCE[1]:-}                     # empty when the script comes from stdin (bash -s)
  [[ -n $caller && $caller != "$0" ]] && return 0      # sourced by another file: define, don't run
  if [[ ${1:-} == --complete ]]; then
    shift
    _run_header_field "$0" complete | tr ' ' '\n'
    declare -F complete_hook >/dev/null && complete_hook "$@"
    exit 0
  fi
  _run_confirm "$@"
  main "$@"
}
