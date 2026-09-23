# @summary ~/apps: user-installed binaries and the state files that record installed versions
# @needs core dl
# Paths are kept exactly as the old scripts used them, so existing installs are recognised:
#   ~/apps/<binary>, ~/apps/state/<name>.gh.state (GitHub tag or release date), ~/apps/*.tag
APPS_DIR=${APPS_DIR:-$HOME/apps}
APPS_STATE_DIR=$APPS_DIR/state
APPS_DESKTOP_DIR=$HOME/.local/share/applications

## apps_init -> create ~/apps, ~/apps/state and ~/.local/share/applications
apps_init() { mkdir -p "$APPS_DIR" "$APPS_STATE_DIR" "$APPS_DESKTOP_DIR"; }
## apps_state_file NAME -> ~/apps/state/NAME.gh.state
apps_state_file() { printf '%s\n' "$APPS_STATE_DIR/$1.gh.state"; }
## apps_installed NAME -> 0 if NAME has a state file
apps_installed() { [[ -f $(apps_state_file "$1") ]]; }
## apps_current NAME VALUE -> 0 if NAME's state file holds VALUE (nothing to do)
apps_current() { local f; f=$(apps_state_file "$1"); [[ -f $f && $(<"$f") == "$2" ]]; }
## apps_mark NAME VALUE -> record VALUE as NAME's installed version (skipped under DRY_RUN)
apps_mark() { [[ -n ${DRY_RUN:-} ]] && return 0; apps_init; printf '%s\n' "$2" >"$(apps_state_file "$1")"; }
## apps_migrate NAME OLDFILE -> adopt an old ~/apps/*.tag file as NAME's state file (one-time, keeps old installs recognised)
apps_migrate() { local f; f=$(apps_state_file "$1"); if [[ -f $2 && ! -f $f ]]; then apps_init; mv "$2" "$f"; log "migrated $2 -> $f"; fi; return 0; }
## app_update NAME OWNER REPO FILE URL_TEMPLATE -> the shared "install from a GitHub release if newer" flow:
# sets APP_TAG to the latest tag; returns 1 when NAME's state already records it (nothing to do);
# otherwise downloads URL_TEMPLATE to FILE, with {tag} replaced by the tag and {ver} by the tag minus
# its first character (v1.2 -> 1.2). Under DRY_RUN the download is only printed and 1 is returned,
# so callers write:   app_update lf gokcehan lf "$f" URL || return 0; <install>; apps_mark lf "$APP_TAG"
app_update() {
  local name=$1 owner=$2 repo=$3 file=$4 url=$5
  APP_TAG=$(gh_latest_tag "$owner" "$repo")
  if apps_current "$name" "$APP_TAG"; then log "$name $APP_TAG already installed"; return 1; fi
  url=${url//\{tag\}/$APP_TAG}; url=${url//\{ver\}/${APP_TAG#?}}
  log "$name: installing $APP_TAG"; dl_to "$file" "$url"
  [[ -z ${DRY_RUN:-} ]]
}
