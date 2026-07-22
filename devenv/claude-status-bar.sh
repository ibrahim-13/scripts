#!/usr/bin/env bash
# =============================================================================
#  Claude Code custom status bar
# =============================================================================
#
#  WHAT IT SHOWS  (each segment is hidden when it has no value)
#    dir   : current directory name
#    git   : git branch — if inside a git repo (read straight from .git/HEAD)
#    vim   : vim mode (NORMAL / INSERT / VISUAL / VISUAL LINE) — only if enabled
#    model : model name + reasoning effort level, e.g. "Opus 4.8 (high)"
#    cost  : total session cost in USD
#    diff  : lines added/removed this session, e.g. "+156 / -23"
#    ctx   : context window used %
#    rate  : rate-limit usage + time until reset, e.g. "5h 30% 1h 1m / 7d
#            41% 1d 2h" (Claude Pro/Max only)
#    wt    : worktree path — only when inside a --worktree session
#
#  Segments are joined with " | ". Lines wrap onto multiple lines once they
#  exceed $LINE_WIDTH_PERCENT of $COLUMNS — the slack absorbs the statusLine
#  "padding" setting so the terminal doesn't hard-crop the line.
#
#  Tunable constants (thresholds, wrap width) live at the top of the script,
#  right below `set -uo pipefail`.
#
#  DEPENDENCIES: bash + GNU coreutils. `git` is OPTIONAL.
#    - The JSON payload is parsed with pure bash (no jq, grep, sed or awk).
#    - The git BRANCH is read directly from .git/HEAD (no git binary needed).
#    - The git DIRTY marker ("*") needs the `git` binary. It is added only when
#      BOTH a .git is found AND `git` is on PATH; otherwise it is silently
#      skipped and just the branch is shown.
#    - The only always-used external command is `cat` (coreutils) for stdin.
#
# -----------------------------------------------------------------------------
#  INSTALL
#    1. Save this file somewhere stable, e.g. ~/.claude/status-bar.sh
#    2. Make it executable:        chmod +x ~/.claude/status-bar.sh
#    3. Add to ~/.claude/settings.json (use an ABSOLUTE path):
#
#         {
#           "statusLine": {
#             "type": "command",
#             "command": "/home/USER/.claude/status-bar.sh",
#             "padding": 1,
#             "hideVimModeIndicator": true
#           }
#         }
#
#       - "hideVimModeIndicator": true  -> hides the built-in "-- INSERT --"
#         text since this script draws the vim mode itself.
#       - "padding"                     -> optional left/right spacing.
#       - "refreshInterval": 5          -> add only if you want timed refreshes
#         (not needed here; the bar updates on every message/event).
#
#  ENABLE  /  DISABLE  (without deleting the file)
#    - DISABLE: remove (or rename) the "statusLine" key in settings.json.
#               e.g. rename it to "_statusLine" to keep it parked.
#    - ENABLE : restore the "statusLine" key shown above.
#    Changes take effect on the next interaction (a settings edit alone does
#    not refresh the bar until something else triggers an update).
#
#  REVERT TO THE ORIGINAL / DEFAULT STATUS BAR
#    Claude Code's built-in status bar is simply "no statusLine configured".
#    Delete the entire "statusLine" block from settings.json and the default
#    returns. (No reinstall needed.)
#
#  UNINSTALL (completely)
#    1. Delete the "statusLine" block from ~/.claude/settings.json
#    2. Delete this file:  rm ~/.claude/status-bar.sh
#
# -----------------------------------------------------------------------------
#  VIM MODE for the Claude CLI (controls whether the "vim" segment appears)
#    ENABLE / DISABLE:  run  /config  ->  toggle "Editor mode" to vim / normal
#                       (there is no settings.json key for this — UI only).
#    When enabled you start in INSERT mode; press Esc for NORMAL mode.
#    Quick keys: i/a insert, hjkl move, dd delete line, yy yank, p paste, u undo.
#    While vim mode is OFF, the "vim:" segment is automatically hidden here.
# =============================================================================

set -uo pipefail

# =============================================================================
#  Tunable constants
# =============================================================================
LINE_WIDTH_PERCENT=90   # wrap lines once they exceed this % of $COLUMNS
LINE_WIDTH_MIN=20       # never wrap narrower than this many columns
RATE_RED_PCT=80         # rate-limit % at/above which the value turns red
RATE_YELLOW_PCT=50      # rate-limit % at/above which the value turns yellow

# Read the whole JSON payload Claude Code sends on stdin (cat = coreutils).
input=$(cat)

# =============================================================================
#  Minimal pure-bash JSON reader (no jq / grep / sed / awk)
# =============================================================================

# json_balanced REST
#   REST starts with '{' or '['. Echoes the balanced {...} or [...] substring,
#   correctly skipping braces/brackets that appear inside string literals.
json_balanced() {
  local rest=$1 open close ch out='' depth=0 instr=0 esc=0 i n
  open=${rest:0:1}
  [[ $open == '{' ]] && close='}' || close=']'
  n=${#rest}
  for (( i=0; i<n; i++ )); do
    ch=${rest:i:1}
    out+=$ch
    if (( instr )); then
      if   (( esc ));            then esc=0
      elif [[ $ch == '\' ]];     then esc=1
      elif [[ $ch == '"' ]];     then instr=0
      fi
    else
      if   [[ $ch == '"' ]];     then instr=1
      elif [[ $ch == "$open" ]]; then (( depth++ ))
      elif [[ $ch == "$close" ]]; then (( depth-- )); (( depth == 0 )) && break
      fi
    fi
  done
  printf '%s' "$out"
  return 0
}

# json_raw JSON KEY
#   Echoes the raw value for KEY at the top level of the JSON object string:
#   string -> inner text (escapes left intact); object/array -> the {...}/[...]
#   substring; number/bool/null -> the literal token. Empty if KEY not found.
json_raw() {
  local s=$1 key=$2 rest c out='' re
  re="\"${key}\"[[:space:]]*:[[:space:]]*"
  if [[ $s =~ $re ]]; then
    rest=${s#*"${BASH_REMATCH[0]}"}
    c=${rest:0:1}
    if [[ $c == '"' ]]; then
      [[ $rest =~ ^\"(([^\"\\]|\\.)*)\" ]] && out=${BASH_REMATCH[1]}
    elif [[ $c == '{' || $c == '[' ]]; then
      out=$(json_balanced "$rest")
    else
      [[ $rest =~ ^([^],}[:space:]]+) ]] && out=${BASH_REMATCH[1]}
    fi
  fi
  printf '%s' "$out"
  return 0
}

# jget JSON KEY [KEY ...]
#   Follows a path of keys into nested objects and returns the leaf value,
#   with common string escapes unescaped and JSON null treated as empty.
jget() {
  local cur=$1; shift
  local k
  for k in "$@"; do
    cur=$(json_raw "$cur" "$k")
    if [[ -z $cur ]]; then printf ''; return 0; fi
  done
  cur=${cur//\\\//\/}    # \/  -> /
  cur=${cur//\\\"/\"}    # \"  -> "
  cur=${cur//\\\\/\\}    # \\  -> \
  [[ $cur == null ]] && cur=''
  printf '%s' "$cur"
  return 0
}

# =============================================================================
#  Extract fields
# =============================================================================
cur_dir=$(jget "$input" workspace current_dir)
[ -n "$cur_dir" ] || cur_dir=$(jget "$input" cwd)
dir_name=${cur_dir##*/}
[ -n "$dir_name" ] || dir_name=${cur_dir:-?}

vim_mode=$(jget "$input" vim mode)

model=$(jget "$input" model display_name); [ -n "$model" ] || model="?"
effort=$(jget "$input" effort level)
[ -n "$effort" ] && model="$model ($effort)"

cost=$(jget "$input" cost total_cost_usd); [ -n "$cost" ] || cost="0"
cost_fmt=$(printf '%.2f' "$cost" 2>/dev/null || printf '%s' "$cost")

lines_add=$(jget "$input" cost total_lines_added); [ -n "$lines_add" ] || lines_add=0
lines_del=$(jget "$input" cost total_lines_removed); [ -n "$lines_del" ] || lines_del=0

ctx_used=$(jget "$input" context_window used_percentage)

rate_5h=$(jget "$input" rate_limits five_hour used_percentage)
rate_7d=$(jget "$input" rate_limits seven_day used_percentage)
[ -n "$rate_5h" ] && rate_5h=$(printf '%.0f' "$rate_5h" 2>/dev/null || printf '%s' "$rate_5h")
[ -n "$rate_7d" ] && rate_7d=$(printf '%.0f' "$rate_7d" 2>/dev/null || printf '%s' "$rate_7d")

# Reset times (unix epoch seconds); may be independently absent.
rate_5h_reset=$(jget "$input" rate_limits five_hour resets_at)
rate_7d_reset=$(jget "$input" rate_limits seven_day resets_at)

# fmt_reset EPOCH
#   Echoes the time remaining until EPOCH, e.g. "1h 1m" (< 1 day) or "1d 1h"
#   (>= 1 day). Zero-valued units are dropped, and minutes are omitted once
#   the reset is a day or more away. Under a minute shows "<1m". Empty when
#   EPOCH is missing, invalid, or already past.
#   Uses bash's $EPOCHSECONDS (bash 5+) with a `date` fallback.
fmt_reset() {
  local at=${1%%.*} now rem d h m out=''
  [[ $at =~ ^[0-9]+$ ]] || return 0
  now=${EPOCHSECONDS:-$(date +%s)}
  rem=$(( at - now ))
  (( rem > 0 )) || return 0
  d=$(( rem / 86400 )); h=$(( rem % 86400 / 3600 )); m=$(( rem % 3600 / 60 ))
  if (( d > 0 )); then
    out="${d}d"; (( h > 0 )) && out+=" ${h}h"
  else
    (( h > 0 )) && out="${h}h"
    (( m > 0 )) && out+="${out:+ }${m}m"
    [ -n "$out" ] || out="<1m"
  fi
  printf '%s' "$out"
  return 0
}

wt_path=$(jget "$input" worktree path)

# ---- git branch + dirty flag ---------------------------------------------
# Branch is read straight from .git/HEAD (no git binary). The dirty "*" is
# added only when a .git is found AND the git binary is available.
git_branch=""; git_dirty=""; git_root=""
d=$cur_dir
while [ -n "$d" ]; do
  if [ -e "$d/.git" ]; then                   # .git folder OR file exists here
    git_root=$d
    gitdir="$d/.git"
    if [ -f "$gitdir" ]; then                 # ".git" file (worktree/submodule)
      ref_line=$(<"$gitdir")                   # "gitdir: <path>"
      gitdir=${ref_line#gitdir: }
      [ "${gitdir#/}" = "$gitdir" ] && gitdir="$d/$gitdir"   # resolve relative
    fi
    if [ -f "$gitdir/HEAD" ]; then
      head=$(<"$gitdir/HEAD")
      if [ "${head#ref: refs/heads/}" != "$head" ]; then
        git_branch=${head#ref: refs/heads/}    # on a branch
      else
        git_branch=${head:0:7}                 # detached HEAD -> short hash
      fi
    fi
    break
  fi
  [ "$d" = "/" ] && break
  d=${d%/*}; [ -n "$d" ] || d=/
done

# Dirty marker: requires the optional git binary. Checks both conditions.
if [ -n "$git_root" ] && command -v git >/dev/null 2>&1; then
  if [ -n "$(git -C "$git_root" status --porcelain 2>/dev/null)" ]; then
    git_dirty="*"
  fi
fi

# =============================================================================
#  ANSI colors
# =============================================================================
R=$'\033[0m'; DIM=$'\033[2m'
BLUE=$'\033[34m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'
YELLOW=$'\033[33m'; MAGENTA=$'\033[35m'; RED=$'\033[31m'

# =============================================================================
#  Build segments  (two parallel arrays: plain for width math, color for output)
# =============================================================================
seg_plain=(); seg_color=()
add() { seg_plain+=("$1"); seg_color+=("$2"); }

# dir
add "dir: $dir_name" "${DIM}dir:${R} ${CYAN}${dir_name}${R}"

# git (hidden if not a repo); "*" appended when the work tree is dirty
if [ -n "$git_branch" ]; then
  add "git: ${git_branch}${git_dirty}" "${DIM}git:${R} ${GREEN}⎇ ${git_branch}${R}${YELLOW}${git_dirty}${R}"
fi

# vim (hidden if mode empty)
if [ -n "$vim_mode" ]; then
  case "$vim_mode" in
    NORMAL) vc=$GREEN ;;
    INSERT) vc=$YELLOW ;;
    *)      vc=$MAGENTA ;;   # VISUAL / VISUAL LINE
  esac
  add "vim: $vim_mode" "${DIM}vim:${R} ${vc}${vim_mode}${R}"
fi

# model (+ effort)
add "model: $model" "${DIM}model:${R} ${BLUE}${model}${R}"

# cost
add "cost: \$$cost_fmt" "${DIM}cost:${R} \$${cost_fmt}"

# diff (hidden if no lines changed)
if [ "$lines_add" != "0" ] || [ "$lines_del" != "0" ]; then
  add "diff: +${lines_add} / -${lines_del}" "${DIM}diff:${R} ${GREEN}+${lines_add}${R} ${DIM}/${R} ${RED}-${lines_del}${R}"
fi

# ctx (hidden if empty)
if [ -n "$ctx_used" ]; then
  add "ctx: ${ctx_used}% used" "${DIM}ctx:${R} ${YELLOW}${ctx_used}%${R} ${DIM}used${R}"
fi

# rate (hidden if no rate-limit data; Pro/Max only)
# Each window shows "<used>% <time to reset>", e.g. "30% 1h 1m" / "30% 1d 1h".
if [ -n "$rate_5h" ] || [ -n "$rate_7d" ]; then
  rate_color() { if [ "${1:-0}" -ge "$RATE_RED_PCT" ] 2>/dev/null; then printf '%s' "$RED"; elif [ "${1:-0}" -ge "$RATE_YELLOW_PCT" ] 2>/dev/null; then printf '%s' "$YELLOW"; else printf '%s' "$GREEN"; fi; }
  h=${rate_5h:-?}; d2=${rate_7d:-?}
  hc=$(rate_color "$rate_5h"); dc=$(rate_color "$rate_7d")
  hr=$(fmt_reset "$rate_5h_reset"); dr=$(fmt_reset "$rate_7d_reset")
  [ -n "$hr" ] && hr=" $hr"
  [ -n "$dr" ] && dr=" $dr"
  add "rate: 5h ${h}%${hr} / 7d ${d2}%${dr}" "${DIM}rate:${R} ${DIM}5h${R} ${hc}${h}%${R}${DIM}${hr}${R} ${DIM}/ 7d${R} ${dc}${d2}%${R}${DIM}${dr}${R}"
fi

# wt (hidden if no worktree)
if [ -n "$wt_path" ]; then
  add "wt: $wt_path" "${DIM}wt:${R} ${MAGENTA}${wt_path}${R}"
fi

# =============================================================================
#  Wrap into multiple lines if wider than the terminal
# =============================================================================
# Wrap at $LINE_WIDTH_PERCENT of the terminal width — the slack absorbs the
# statusLine "padding" setting (not part of the stdin payload) so lines don't
# get hard-cropped by the terminal.
width=$(( ${COLUMNS:-80} * LINE_WIDTH_PERCENT / 100 ))
[ "$width" -lt "$LINE_WIDTH_MIN" ] && width=$LINE_WIDTH_MIN
sep_plain=" | "
sep_color="${DIM} | ${R}"

line_plain=""; line_color=""
flush() { [ -n "$line_color" ] && printf '%b\n' "$line_color"; return 0; }

for i in "${!seg_plain[@]}"; do
  p=${seg_plain[$i]}; c=${seg_color[$i]}
  if [ -z "$line_plain" ]; then
    line_plain=$p; line_color=$c
  elif [ $(( ${#line_plain} + ${#sep_plain} + ${#p} )) -le "$width" ]; then
    line_plain+="$sep_plain$p"; line_color+="$sep_color$c"
  else
    flush
    line_plain=$p; line_color=$c
  fi
done
flush
