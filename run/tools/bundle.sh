#!/usr/bin/env bash
# bundle.sh — print ONE self-contained script for a command, for `ssh host bash -s < file`.
#
#   tools/bundle.sh vm/setup > setup.sh
#
# Algorithm
#   1. Collect libraries: the command's "# @needs", each library's own "# @needs", depth-first,
#      each once (dependencies before dependents).
#   2. Collect steps (command groups): the command's "# @steps", recursively (a step may itself
#      be a group), each once, inner steps first. Their libraries join the set from 1.
#   3. Emit: shebang, `set -euo pipefail`, a no-op `use()`, _run_header_field (run_main needs
#      it for --complete), every library (shebang removed), every step wrapped as
#          __step_<id>() ( <step file without shebang/loader line/run_main line>; main "$@" )
#      — a SUBSHELL function, so the step's `set -e`, its main() and its variables stay
#      private — and finally the command file with its shebang and loader line removed.
#   run_cmd (lib/core.sh) calls __step_<id> when it exists, so groups work without the tree.
#
# Constraints (README.md "Internals" and "Writing a command"): @needs and @steps must be complete; libraries must
# not read files from the tree at runtime; the loader line must start with `source` and mention
# loader.sh (a trailing `; use ...` on that line is dropped with it, intentionally); the
# `run_main "$@"` line must be on its own line; the remote host needs bash.
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/loader.sh"   # sets RUN_ROOT from its own location
cmd_id=${1:?usage: bundle.sh <ns>/<name>}; cmd_id=${cmd_id%.sh}
cmd="$RUN_ROOT/cmd/$cmd_id.sh"
[[ -f $cmd ]] || { echo "bundle: no such command: $1" >&2; exit 1; }

declare -A seen_lib=() seen_step=(); libs=(); steps=()
add_libs() {
  local lib d; for lib in "$@"; do
    [[ -n ${seen_lib[$lib]:-} ]] && continue; seen_lib[$lib]=1
    [[ -f $RUN_ROOT/lib/$lib.sh ]] || { echo "bundle: @needs names unknown library '$lib'" >&2; exit 1; }
    for d in $(_run_header_field "$RUN_ROOT/lib/$lib.sh" needs); do add_libs "$d"; done
    libs+=("$lib")
  done
}
add_steps() {
  local id f; for id in "$@"; do
    [[ -n ${seen_step[$id]:-} ]] && continue; seen_step[$id]=1     # set first: step cycles terminate
    f="$RUN_ROOT/cmd/$id.sh"
    [[ -f $f ]] || { echo "bundle: @steps names unknown command '$id'" >&2; exit 1; }
    # shellcheck disable=SC2046
    add_libs $(_run_header_field "$f" needs)
    # shellcheck disable=SC2046
    add_steps $(_run_header_field "$f" steps)
    steps+=("$id")
  done
}
# shellcheck disable=SC2046
add_libs $(_run_header_field "$cmd" needs)
# shellcheck disable=SC2046
add_steps $(_run_header_field "$cmd" steps)

body() { grep -v -e '^#!' -e '^[[:space:]]*source .*loader\.sh' "$1"; }   # a command file minus boilerplate

echo '#!/usr/bin/env bash'
echo "# bundled from cmd/$cmd_id.sh on $(date -Is); libs: ${libs[*]}; steps: ${steps[*]:-none}"
echo 'set -euo pipefail'
echo 'use() { :; }   # libraries are inlined below'
echo 'RUN_LIB=/nonexistent RUN_ROOT=/nonexistent RUN_CMD=/nonexistent'
# the confirmation prompt cannot read the header from $0 in a bundle; give it the facts directly
printf 'RUN_BUNDLE_ID=%q RUN_BUNDLE_SUMMARY=%q RUN_BUNDLE_STEPS=%q\n' "$cmd_id" \
  "$(_run_header_field "$cmd" summary)" "$(_run_header_field "$cmd" steps | tr '\n' ' ')"
sed -n '/^_run_header_field()/,/^}/p' "$RUN_ROOT/lib/loader.sh"
for lib in "${libs[@]}"; do
  printf '\n# ---- lib/%s.sh ----\n' "$lib"; grep -v '^#!' "$RUN_ROOT/lib/$lib.sh"
done
for id in "${steps[@]}"; do
  printf '\n# ---- step %s (cmd/%s.sh) ----\n__step_%s() (\n' "$id" "$id" "${id//[^A-Za-z0-9]/_}"
  body "$RUN_ROOT/cmd/$id.sh" | grep -v '^[[:space:]]*run_main[[:space:]]'
  printf '  main "$@"\n)\n'
done
printf '\n# ---- cmd/%s.sh ----\n' "$cmd_id"
body "$cmd"
