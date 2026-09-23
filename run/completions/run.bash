# completions/run.bash — tab completion for `run` and the Ctrl-G live-picker widget.
# Sourced by ~/.bashrc.d/run.sh in interactive shells only (bind needs line editing).
#
# The tree root is captured from THIS file's location when sourced; PATH and cwd play no part.
_RUN_ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
_run_root() { printf '%s\n' "$_RUN_ROOT"; }

# Word 1 (the command): candidates come from the index. Bash cannot display descriptions
# next to candidates, so when there are several matches each candidate is returned as
# "id  - summary" with -o nosort. Readline inserts only the common prefix of all candidates,
# which is the same as the common prefix of the bare ids, so the typed text stays clean; once a
# single candidate remains, the bare id is returned so it gets inserted. CAVEAT: this relies on
# the default `complete` behaviour — with `menu-complete` bound, the whole "id  - summary"
# string would be inserted.
# Word 2+ (arguments): the command itself is asked via `<script> --complete WORDS...`, which
# run_main answers with the "# @complete" words plus complete_hook output (see lib/core.sh).
_run() {
  local cur=${COMP_WORDS[COMP_CWORD]} root; root=$(_run_root)
  local index; index=$("$root/tools/index.sh")
  if (( COMP_CWORD == 1 )); then
    local -a ids=() descs=(); local kind id summary rest
    while IFS=$'\t' read -r kind id summary rest; do
      [[ $kind == cmd && $id == "$cur"* ]] && { ids+=("$id"); descs+=("$summary"); }
    done < "$index"
    local verbs="list search help pick index bundle remote root selftest"
    if (( ${#ids[@]} == 0 )); then mapfile -t COMPREPLY < <(compgen -W "$verbs" -- "$cur"); return; fi
    if (( ${#ids[@]} == 1 )); then COMPREPLY=("${ids[0]}"); return; fi
    compopt -o nosort
    local i pad=0; for id in "${ids[@]}"; do (( ${#id} > pad )) && pad=${#id}; done
    for i in "${!ids[@]}"; do COMPREPLY+=("$(printf '%-*s  - %s' "$pad" "${ids[i]}" "${descs[i]}")"); done
    return
  fi
  local cmd=${COMP_WORDS[1]}; local file="$root/cmd/$cmd.sh"   # two statements: `local a=.. b=$a` would see the OLD $a
  if [[ -f $file ]]; then
    mapfile -t COMPREPLY < <("$file" --complete "${COMP_WORDS[@]:2}" 2>/dev/null | compgen -W "$(cat)" -- "$cur")
  else
    compopt -o default                                            # not a command: fall back to filenames
  fi
}
complete -F _run run

# Ctrl-G: open the picker over the current prompt and insert "run <choice> " at the cursor.
# bind -x hands us READLINE_LINE/READLINE_POINT; changing them edits the line in place.
# The picker draws on /dev/tty and prints only the choice on stdout, so $(...) is safe.
# To use another key, change the sequence in the bind line (e.g. '"\C-x\C-r"').
_run_pick_widget() {
  local root choice; root=$(_run_root)
  choice=$(grep -P '^cmd\t' "$("$root/tools/index.sh")" | cut -f2,3,4 | "$root/tools/pick.sh") || return
  READLINE_LINE="${READLINE_LINE:0:READLINE_POINT}run $choice ${READLINE_LINE:READLINE_POINT}"
  READLINE_POINT=$(( READLINE_POINT + ${#choice} + 5 ))
}
bind -x '"\C-g": _run_pick_widget'
