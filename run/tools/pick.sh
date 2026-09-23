#!/usr/bin/env bash
# pick.sh — pure-bash live filter (the "fzf" of this toolkit, without fzf).
#
# Input : TSV lines on stdin; the FIRST column is what gets printed when a line is chosen.
# Output: the chosen id on stdout. All drawing goes to the terminal ($PICK_TTY, default
#         /dev/tty), never stdout, so the picker works inside $(...) and inside `bind -x`.
# Args  : $1 = optional initial query.
# Env   : PICK_TTY = terminal device (tests point it elsewhere); PICK_ROWS = max rows (12).
# Exit  : 0 chosen | 1 Enter with no match | 2 cannot open the terminal | 130 cancelled
# Keys  : printable = extend query, Backspace, Ctrl-U clear, Up/Down or Ctrl-P/Ctrl-N move,
#         Enter accept, Esc / Ctrl-C / Ctrl-G cancel. Tab is ignored.
# Match : every whitespace-separated term must occur as a case-insensitive SUBSTRING somewhere
#         in the whole line (id, summary, tags). Fuzzy variant: see README.md "Internals".
set -u
tty=${PICK_TTY:-/dev/tty}
query=${1:-}
max=${PICK_ROWS:-12}

{ : <"$tty"; } 2>/dev/null || { echo "pick: cannot open $tty" >&2; exit 2; }
mapfile -t all                                     # whole list in memory; filtering is a loop
cols=$(stty size <"$tty" 2>/dev/null | { read -r _ c; echo "${c:-80}"; })

sel=0; declare -a hits=()
filter() {
  hits=(); local line l t ok q=${query,,}
  for line in "${all[@]}"; do
    l=${line,,}; ok=1
    for t in $q; do [[ $l == *"$t"* ]] || { ok=0; break; }; done
    ((ok)) && hits+=("$line")
  done
  (( sel >= ${#hits[@]} )) && sel=$(( ${#hits[@]} ? ${#hits[@]}-1 : 0 ))   # keep cursor in range
}

# Redraw strategy: the cursor is always parked on the query line. Each draw writes the
# query line, up to $max result rows and a status line, then moves the cursor back UP by
# the number of lines written so the next draw overwrites in place. "\e[J" erases from the
# cursor to the end of the screen, so a shrinking list leaves no stale rows behind.
# Rows are truncated to the terminal width; the selected row is drawn in reverse video.
# If $max exceeds the terminal height the cursor-up arithmetic breaks — keep PICK_ROWS small.
draw() {
  local i n=${#hits[@]} out=$'\r\e[J' row
  out+=$'\e[1m> \e[0m'"$query"$'\e[K\n'
  for (( i=0; i<n && i<max; i++ )); do
    row="  ${hits[i]//$'\t'/  }"; row=${row:0:cols-1}
    (( i == sel )) && out+=$'\e[7m'"$row"$'\e[0m\n' || out+="$row"$'\n'
  done
  out+=$'\e[2m'"  $n/${#all[@]}"$'\e[0m'
  local lines=$(( (n<max?n:max) + 1 ))
  printf '%s\e[%dA\r' "$out" "$lines" >"$tty"
}

cleanup() { printf '\r\e[J\e[?25h' >"$tty"; }       # clear our lines, show the cursor again
trap cleanup EXIT
trap 'exit 130' INT
printf '\e[?25l' >"$tty"                            # hide the cursor while drawing

filter; draw
# Key reading: `read -rsn1` returns one byte without echo. Arrow keys arrive as ESC [ A/B,
# so after an ESC we wait up to 50 ms for two more bytes; a lone ESC (nothing follows) means
# cancel. Enter shows up as an EMPTY key because newline is read's delimiter. Backspace is
# DEL (0x7f) on most terminals, BS (0x08) on some.
while IFS= read -rsn1 key <"$tty"; do
  if [[ $key == $'\e' ]]; then read -rsn2 -t 0.05 rest <"$tty" || rest=; key+=$rest; fi
  case $key in
    $'\e[A'|$'\x10') (( sel>0 )) && ((sel--)) ;;                     # Up / Ctrl-P
    $'\e[B'|$'\x0e') (( sel < ${#hits[@]}-1 )) && ((sel++)) ;;      # Down / Ctrl-N
    $'\x7f'|$'\b')  query=${query%?}; filter ;;                     # Backspace
    $'\x15')        query=; filter ;;                               # Ctrl-U
    $'\e'|$'\x03'|$'\x07') exit 130 ;;                              # Esc / Ctrl-C / Ctrl-G
    '')             break ;;                                        # Enter
    $'\t')          ;;                                              # Tab: ignored
    *)              query+=$key; filter ;;
  esac
  draw
done
cleanup; trap - EXIT
(( ${#hits[@]} )) || exit 1
printf '%s\n' "${hits[sel]%%$'\t'*}"
