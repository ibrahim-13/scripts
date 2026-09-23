# loader.sh — the ONLY file that scripts source directly. Provides `use`.
#
#   source "<path-relative-to-the-script>/lib/loader.sh"; use core os pkg
#
# Everything is resolved from THIS file's real location: never from the caller's cwd,
# an inherited environment variable, or a hard-coded path. Moving the tree keeps working.
[[ -n ${__RUN_LOADER_LOADED:-} ]] && return 0
__RUN_LOADER_LOADED=1
RUN_LIB=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
RUN_ROOT=${RUN_LIB%/lib}
RUN_CMD=$RUN_ROOT/cmd
export RUN_LIB RUN_ROOT RUN_CMD

# _run_header_field FILE FIELD -> prints the value(s) of "# @FIELD ..." lines in FILE's header.
# The header is the run of comment/blank lines from the top of the file up to the first
# line of code; a field after that line is NOT seen. Leading whitespace is trimmed.
# Used by: use (@needs), run help, tools/index.sh, tools/bundle.sh, run_main (@complete).
_run_header_field() {
  local file=$1 field=$2 line
  while IFS= read -r line || [[ -n $line ]]; do
    case $line in
      '#!'*) ;;                                   # shebang
      '') continue ;;                             # blank lines inside the header are fine
      '#'*) [[ $line == "# @$field "* || $line == "# @$field" ]] &&
              { line=${line#"# @$field"}; printf '%s\n' "${line#"${line%%[![:space:]]*}"}"; } ;;
      *) break ;;                                 # first code line ends the header
    esac
  done < "$file"
}

# use LIB... -> source lib/LIB.sh exactly once, after sourcing its "# @needs" dependencies.
# The guard variable is set BEFORE sourcing, so a dependency cycle (a needs b needs a)
# terminates instead of recursing forever. Unknown library => message on stderr, return 1.
use() {
  local lib guard file deps
  for lib in "$@"; do
    guard="__RUN_LIB_${lib//[^A-Za-z0-9_]/_}"
    [[ -n ${!guard:-} ]] && continue
    file="$RUN_LIB/$lib.sh"
    [[ -r $file ]] || { printf 'use: no such library: %s (%s)\n' "$lib" "$file" >&2; return 1; }
    printf -v "$guard" 1
    deps=$(_run_header_field "$file" needs)
    # shellcheck disable=SC2086
    [[ -n $deps ]] && use $deps
    # shellcheck disable=SC1090
    source "$file"
  done
}
