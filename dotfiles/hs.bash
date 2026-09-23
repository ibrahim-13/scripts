# hs.bash — `hs`: live-filtering shell history search, no external programs.
#
# Source it from your rc file:   source /path/to/hs.bash
# Works with bash >= 3.2 (stock macOS bash and every Linux distro) and with zsh (the macOS
# default shell); needs only shell builtins, awk and stty, which both BSD and GNU userlands
# ship. Unlike a `bind -x` widget it does not need READLINE_LINE, so it does not require bash 4.
#
# Use :  hs [QUERY]      open the picker, optionally with a starting query
#        hs -n [QUERY]   recall only: the choice is appended to history and printed, not run
#                        (press Up, then Enter to run it after editing)
# Keys:  type to filter (every space-separated term must appear, case-insensitive),
#        Backspace, Ctrl-U clear, Up/Down or Ctrl-P/Ctrl-N move, Enter accept,
#        Esc / Ctrl-C / Ctrl-G cancel.
# Env :  HS_ROWS    max rows shown (default 12; keep below the terminal height)
#        HS_PROMPT  text before the query (default "search: ")
#        HS_TTY   terminal device (default /dev/tty; tests point it elsewhere)

hs() {
  local run=1
  [[ ${1:-} == -n ]] && { run=0; shift; }
  local choice
  # fc -ln: history without numbers; awk trims, flattens tabs, newest first, no duplicates.
  choice=$(fc -ln 1 2>/dev/null | awk '
      { sub(/^[ \t]+/, ""); gsub(/\t/, " "); if ($0 != "") l[++n] = $0 }
      END { for (i = n; i > 0; i--) if (!seen[l[i]]++) print l[i] }' \
    | _hs_pick "$*") || return 0
  [[ -n $choice ]] || return 0
  # so Up brings it back and it is saved
  if [[ -n ${ZSH_VERSION:-} ]]; then print -s -- "$choice"; else history -s -- "$choice"; fi
  if (( run )); then
    printf '\033[2m$ %s\033[0m\n' "$choice" >&2
    eval " $choice"                              # leading space: never parsed as an option
  else
    printf '%s\n' "$choice"
  fi
}

# _hs_pick QUERY  <lines  ->  chosen line on stdout; draws on $HS_TTY only.
# Exit: 0 chosen | 1 Enter with no match | 2 no terminal | 130 cancelled.
_hs_pick() {
  # zsh: 0-based arrays and split $query on spaces, both local to this function.
  [[ -n ${ZSH_VERSION:-} ]] && setopt localoptions ksharrays shwordsplit
  local tty=${HS_TTY:-/dev/tty} query=${1:-} max=${HS_ROWS:-12} prompt=${HS_PROMPT-search: }
  # How long to wait for the rest of an escape sequence: a lone Esc cancels after this.
  # bash 3.2 accepts only whole seconds for read -t; zsh and bash >= 4 take fractions.
  local esc_wait=1
  [[ -n ${ZSH_VERSION:-} || ${BASH_VERSINFO[0]:-0} -ge 4 ]] && esc_wait=0.05
  { : <"$tty"; } 2>/dev/null || { echo "hs: cannot open $tty" >&2; return 2; }
  local -a all=() hits=()
  local line
  while IFS= read -r line || [[ -n $line ]]; do all+=("$line"); done   # bash 3.2: no mapfile
  local cols; cols=$(stty size <"$tty" 2>/dev/null | { read -r rows c; echo "${c:-0}"; }); (( cols > 0 )) || cols=80
  local sel=0 key rest ok t i n row out lines rc=0 w=$(( cols - 1 ))
  # Raw keys: no line buffering, no echo, and Ctrl-C arrives as a byte instead of a signal
  # (intr undef, because bash's read -n switches signals back on by itself).
  local saved; saved=$(stty -g <"$tty" 2>/dev/null)
  # Safety net for a SIGINT from elsewhere in bash: cancel instead of leaving the terminal raw.
  local oldtrap=; [[ -n ${ZSH_VERSION:-} ]] || { oldtrap=$(trap -p INT); trap 'rc=130' INT; }

  # _hs_match LINE TERM: case-insensitive substring test.
  local nocase=0
  if [[ -n ${ZSH_VERSION:-} ]]; then
    # eval hides zsh-only syntax from bash: (#i) = ignore case, ${(b)2} = quote pattern characters
    eval '_hs_match() { setopt localoptions extendedglob; [[ $1 == (#i)*${(b)2}* ]]; }'
  else
    shopt -q nocasematch && nocase=1; shopt -s nocasematch
    _hs_match() { [[ $1 == *"$2"* ]]; }
  fi
  _hs_filter() {
    hits=(); for line in "${all[@]}"; do
      ok=1; for t in $query; do _hs_match "$line" "$t" || { ok=0; break; }; done
      (( ok )) && hits+=("$line")
    done
    (( sel >= ${#hits[@]} )) && sel=$(( ${#hits[@]} ? ${#hits[@]} - 1 : 0 ))
  }
  _hs_draw() {
    n=${#hits[@]}; out=$'\r\e[J'$'\e[1m'"$prompt"$'\e[0m'"$query"$'\e[K\n'
    for (( i = 0; i < n && i < max; i++ )); do
      row="  ${hits[i]}"; row=${row:0:$w}   # zsh needs a plain width here
      if (( i == sel )); then out+=$'\e[7m'"$row"$'\e[0m\n'; else out+="$row"$'\n'; fi
    done
    out+=$'\e[2m'"  $n/${#all[@]}"$'\e[0m'
    lines=$(( (n < max ? n : max) + 1 ))
    printf '%s\e[%dA\r' "$out" "$lines" >"$tty"
  }
  _hs_cleanup() {
    printf '\r\e[J\e[?25h' >"$tty"
    [[ -n $saved ]] && stty "$saved" <"$tty"
    [[ -n ${ZSH_VERSION:-} ]] || eval "${oldtrap:-trap - INT}"
    [[ -n ${ZSH_VERSION:-} ]] || (( nocase )) || shopt -u nocasematch
  }
  # _hs_getc VAR COUNT [TIMEOUT]: read COUNT raw characters from the terminal into VAR.
  _hs_getc() {
    local -a o=(-r -s)
    if [[ -n ${ZSH_VERSION:-} ]]; then o+=(-u 0 -k "$2"); else o+=(-n "$2"); fi
    [[ -n ${3:-} ]] && o+=(-t "$3")
    eval "$1="                                   # an interrupted read leaves the old value behind
    IFS= read "${o[@]}" "$1" <"$tty"
  }

  printf '\e[?25l' >"$tty"
  [[ -n $saved ]] && stty -icanon -echo -isig intr undef min 1 time 0 <"$tty"
  _hs_filter; _hs_draw
  while _hs_getc key 1; do
    (( rc )) && break
    # Esc alone cancels; Esc [ A/B is an arrow key, whose bytes arrive together.
    if [[ $key == $'\e' ]]; then _hs_getc rest 2 "$esc_wait" || rest=; key+=$rest; fi
    case $key in
      $'\e[A'|$'\x10') (( sel > 0 )) && (( sel-- )) ;;
      $'\e[B'|$'\x0e') (( sel < ${#hits[@]} - 1 )) && (( sel++ )) ;;
      $'\x7f'|$'\b')   query=${query%?}; _hs_filter ;;
      $'\x15')         query=; _hs_filter ;;
      $'\e'|$'\x03'|$'\x07') rc=130; break ;;
      ''|$'\n'|$'\r')  break ;;
      $'\t')           ;;
      *)               query+=$key; _hs_filter ;;
    esac
    _hs_draw
  done
  _hs_cleanup
  (( rc )) && return $rc
  (( ${#hits[@]} )) || return 1
  printf '%s\n' "${hits[sel]}"
}
