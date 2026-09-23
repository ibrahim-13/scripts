#!/usr/bin/env bash
# index.sh — build/refresh the search index used by run list/search/pick and by completion.
#
# Output file: $RUN_ROOT/.cache/index.tsv   (one line per command and per public lib function)
# Columns:     kind  id  summary  tags  roles  file
#              kind  = cmd | fn
#              id    = "vm/mount" for commands, the function name for fn rows
#              tags  = "@tags" for commands, "lib:<topic>" for fn rows
#              roles = "@roles" or "any"
#              file  = path relative to RUN_ROOT
# Staleness:   rebuilt when any cmd/**/*.sh or lib/*.sh is newer than the index, or with --rebuild.
# Fn rows:     a line "name() {" at column 0 is a function. Names starting with "_" (private)
#              or containing "__" (per-distro implementations) are skipped. The summary is the
#              comment line directly above it, only if it starts with "## " or "# name".
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/loader.sh"   # sets RUN_ROOT from its own location
INDEX="$RUN_ROOT/.cache/index.tsv"
shopt -s globstar nullglob

stale() {
  [[ -f $INDEX ]] || return 0
  local f; for f in "$RUN_ROOT"/cmd/**/*.sh "$RUN_ROOT"/lib/*.sh; do [[ $f -nt $INDEX ]] && return 0; done
  return 1
}

build() {
  local f id summary tags roles line prev doc
  mkdir -p "$RUN_ROOT/.cache"
  {
    for f in "$RUN_ROOT"/cmd/**/*.sh; do
      id=${f#"$RUN_ROOT/cmd/"}; id=${id%.sh}
      summary=$(_run_header_field "$f" summary); tags=$(_run_header_field "$f" tags); roles=$(_run_header_field "$f" roles)
      printf 'cmd\t%s\t%s\t%s\t%s\t%s\n' "$id" "$summary" "$tags" "${roles:-any}" "${f#"$RUN_ROOT/"}"
    done
    for f in "$RUN_ROOT"/lib/*.sh; do
      prev=
      while IFS= read -r line; do
        if [[ $line =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ && ${BASH_REMATCH[1]} != _* && ${BASH_REMATCH[1]} != *__* ]]; then
          doc=; [[ $prev == "## "* || $prev == "# ${BASH_REMATCH[1]}"* ]] && doc=${prev#\#}; doc=${doc## }
          printf 'fn\t%s\t%s\t%s\t%s\t%s\n' "${BASH_REMATCH[1]}" "${doc#\# }" "lib:$(basename "${f%.sh}")" any "${f#"$RUN_ROOT/"}"
        fi
        [[ $line == '#'* ]] && prev=$line || prev=
      done < "$f"
    done
  } > "$INDEX.tmp" && mv "$INDEX.tmp" "$INDEX"      # atomic replace: readers never see a half file
}

if [[ ${1:-} == --rebuild ]] || stale; then build; fi
printf '%s\n' "$INDEX"
