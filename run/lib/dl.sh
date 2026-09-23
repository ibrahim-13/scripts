# @summary Downloads (curl/wget), GitHub latest-release lookups without jq, OS/arch naming styles
# @needs core

## dl_to FILE URL -> download URL to FILE with a progress bar (curl, else wget)
dl_to() {
  if   have curl; then dry curl -fL --progress-bar -o "$1" "$2"
  elif have wget; then dry wget -q --show-progress -O "$1" "$2"
  else die "curl or wget is required"; fi
}
## dl_print URL -> print the body of URL on stdout
dl_print() {
  if   have curl; then curl -fsSL "$1"
  elif have wget; then wget -qO- "$1"
  else die "curl or wget is required"; fi
}

## gh_release_json OWNER REPO -> JSON of the latest release (gh CLI when logged in, else the public API)
gh_release_json() {
  local a='Accept: application/vnd.github+json' v='X-GitHub-Api-Version: 2022-11-28'
  local url="https://api.github.com/repos/$1/$2/releases/latest"
  if   have gh && gh auth token >/dev/null 2>&1; then gh api -H "$a" -H "$v" "/repos/$1/$2/releases/latest"
  elif have curl; then curl -fsSL -H "$a" -H "$v" "$url"
  elif have wget; then wget -qO- --header="$a" --header="$v" "$url"
  else die "curl or wget is required"; fi
}
## gh_json_field JSON KEY -> first string value of "KEY" in JSON (top-level fields; no jq needed)
gh_json_field() { printf '%s\n' "$1" | grep -o "\"$2\": *\"[^\"]*\"" | head -1 | sed 's/^[^:]*: *"\(.*\)"$/\1/'; }
## gh_latest_tag OWNER REPO -> tag_name of the latest release
gh_latest_tag() {
  local j t; j=$(gh_release_json "$1" "$2") || die "github: cannot fetch $1/$2"
  t=$(gh_json_field "$j" tag_name); [[ -n $t ]] || die "github: no tag_name for $1/$2 (rate limited?)"
  printf '%s\n' "$t"
}
## gh_latest_created_at OWNER REPO -> created_at of the latest release
gh_latest_created_at() {
  local j t; j=$(gh_release_json "$1" "$2") || die "github: cannot fetch $1/$2"
  t=$(gh_json_field "$j" created_at); [[ -n $t ]] || die "github: no created_at for $1/$2"
  printf '%s\n' "$t"
}
## gh_asset_url OWNER REPO GLOB -> download URL of the first latest-release asset whose file name matches GLOB
gh_asset_url() {
  local j u; j=$(gh_release_json "$1" "$2") || die "github: cannot fetch $1/$2"
  while read -r u; do
    # shellcheck disable=SC2053
    [[ ${u##*/} == $3 ]] && { printf '%s\n' "$u"; return 0; }
  done < <(printf '%s\n' "$j" | grep -o '"browser_download_url": *"[^"]*"' | sed 's/^[^:]*: *"\(.*\)"$/\1/')
  die "github: no asset matching '$3' in $1/$2"
}

## sys_os STYLE -> this OS as release assets name it: 1 = linux|darwin, 2 = linux|osx, 3 = linux|macos
sys_os() {
  local m; m=$(uname -s)
  case "$m:$1" in
    Linux:*) echo linux ;; Darwin:1) echo darwin ;; Darwin:2) echo osx ;; Darwin:3) echo macos ;;
    CYGWIN*:*) echo cygwin ;; MINGW*:*) echo mingw ;; *) echo "${m,,}" ;;
  esac
}
## sys_arch STYLE -> CPU arch as release assets name it: 1 = amd64|arm64, 2 = x86_64|aarch64, 3 = x86_64|arm64
sys_arch() {
  local a; a=$(uname -m)
  case "$a:$1" in
    x86_64:1|amd64:1) echo amd64 ;; x86_64:*|amd64:*) echo x86_64 ;;
    aarch64:2|arm64:2) echo aarch64 ;; aarch64:*|arm64:*) echo arm64 ;;
    *) echo "$a" ;;
  esac
}
