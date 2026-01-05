#!/usr/bin/env bash

# Debugging
# ---------
# set -x : print out every line as it executes, with variables expanded
#		putting it at top of the script will enable this for the whole
#		script, or before a block of commands and end it with:
#		{ set +x; } 2>/dev/null
#
# bash -x script.sh : same as putting set -x at the top of script
# trap read DEBUG : stop before every line, can be put at the top
# trap '(read -p "[$BASE_SOURCE:$lineno] $bash_command")' DEBUG

# print error msg and exit
# $1 : error msg
function errexit {
	echo "[ error ] $1" >&2
	exit 1
}

# gitHub functions

# get lastest release asset url from github with http api
# $1 : github username
# $2 : github repo
# $3 : jq selector for asset name
function func_gh_http {
	local GH_URL
	local HEADER_ACCEPT
	local HEADER_VERSION
	local JSON_QUERY
	local GH_RESPONSE
	GH_URL="https://api.github.com/repos/$1/$2/releases/latest"
	HEADER_ACCEPT="Accept: application/vnd.github+json"
	HEADER_VERSION="X-GitHub-Api-Version: 2022-11-28"
	JSON_QUERY="{\"created_at\":.created_at,\"download_url\":.assets[] | $3 | .browser_download_url,\"source\":\"http\",\"msg\":\"$4\"}"
	GH_RESPONSE="$(wget --header="$HEADER_ACCEPT" \
		--header="$HEADER_VERSION" \
		-qO- "$GH_URL" | \
		jq "$JSON_QUERY")"
	echo "$GH_RESPONSE"
	}

# get lastest release asset url from github with gh cli
# $1 : github username
# $2 : github repo
# $3 : jq selector for asset name
function func_gh_cli {
	local GH_URL
	local HEADER_ACCEPT
	local HEADER_VERSION
	local JSON_QUERY
	local GH_RESPONSE
	GH_URL="/repos/$1/$2/releases/latest"
	HEADER_ACCEPT="Accept: application/vnd.github+json"
	HEADER_VERSION="X-GitHub-Api-Version: 2022-11-28"
	JSON_QUERY="{\"created_at\":.created_at,\"download_url\":.assets[] | $3 | .browser_download_url,\"source\":\"http\",\"msg\":\"$4\"}"
	GH_RESPONSE="$(gh api -H "$HEADER_ACCEPT" \
		-H "$HEADER_VERSION" \
		"$GH_URL" | \
		jq "$JSON_QUERY")"
	echo "$GH_RESPONSE"
}

# get lastest release asset url from github
#	use gh cli if installed and loggedin,
#	use http api otherwise
# $1 : github username
# $2 : github repo
# $3 : jq selector for asset name
function func_github_asset {
	if ! command -v gh &> /dev/null
	then
		func_gh_http "$1" "$2" "$3" "gh: command not found, using http api"
	else
		local GH_AUTH_TOKEN
		GH_AUTH_TOKEN=$(gh auth token)
		if [ "$GH_AUTH_TOKEN" = "" ]
		then
			func_gh_http "$1" "$2" "$3" "gh: auth token not found, you may be not logged in, using http api"
		else
			func_gh_cli "$1" "$2" "$3" "gh: using gh cli"
		fi
	fi
}

# $1 : github response
function func_ghutil_get_downloadurl {
	local GH_DL_URL
	GH_DL_URL=$(echo "$1" | jq -r '.download_url')
	echo "$GH_DL_URL"
}

# $1 : github response
function func_ghutil_get_created_at {
	local GH_CREATED_AT
	GH_CREATED_AT=$(echo "$1" | jq -r '.created_at')
	echo "$GH_CREATED_AT"
}

# $1 : github response
function func_ghutil_get_source {
	local GH_SOURCE
	GH_SOURCE=$(echo "$1" | jq -r '.source')
	echo "$GH_SOURCE"
}

# $1 : github response
function func_ghutil_get_msg {
	local GH_MSG
	GH_MSG=$(echo "$1" | jq -r '.msg')
	echo "$GH_MSG"
}

# check if json is valid
# $1 : json string
function func_ghutil_check_valid_json {
	if [ "$(echo "$1" | jq empty > /dev/null 2>&1; echo $?)" -eq 0 ]
	then
		return 0
	else
		return 1
	fi
}

########
# MAIN #
########

function usage() {
    if [ -n "$1" ]; then
        echo -e "[ error ] $1\n";
    fi
    echo "Download or update binaries from Github releases"
    echo "State file stores the information required to check for updates"
    echo ""
    echo "Usage: $(basename "$0") [-upd|--update] [-d|--download] FILE_PATH [-u|--user] GITHUB_USER_NAME"
    echo "                       [-r|--repo] GITHUB_REPO_NAME [-p|--pattern] PATTERN [-s|--state] STATE_FILE_PATH"
    echo ""
    echo "  -upd, --update     download only if there is an update based on state file, otherwise exit with code 255"
    echo "                                   note: [-s|--state] param is required to detect update"
    echo "  -d, --download     download asset from github release"
    echo "  -u, --user         user name of the github repository"
    echo "  -r, --repo         repository name"
    echo "  -p, --pattern      jq pattern to find unique asset file, must be in single quote"
    echo "  -s, --state        state file location to store release information"
    echo ""
    exit 1
}

if [ $# -eq 0 ]; then
    usage  "no arguments provided."
fi

# parse params
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ "$#" > 0 ]]; do case $1 in
    -upd|--update) ARG_UPDATE=1; shift;;
    -d|--download) ARG_DOWNLOAD=1; ARG_DOWNLOAD_PATH="$2"; shift; shift;;
    -u|--user) ARG_USER="$2"; shift; shift;;
    -r|--repo) ARG_REPO="$2"; shift; shift;;
    -p|--pattern) ARG_PATTERN="$2"; shift; shift;;
    -s|--state) ARG_STATE_FILE="$2"; shift; shift;;
    *) usage "invalid arguments";;
esac; done

# verify params
if [ -z "$ARG_DOWNLOAD" ]; then usage "download option is required"; fi;
if [[ "$ARG_DOWNLOAD" == "1" ]]; then
    if [ -z "$ARG_DOWNLOAD_PATH" ]; then usage "download file path is required"; fi;
fi
if [[ "$ARG_UPDATE" == "1" ]]; then
    if [ -z "$ARG_STATE_FILE" ]; then usage "state file is required for update"; fi;
fi
if [ -z "$ARG_USER" ]; then usage "user is required"; fi;
if [ -z "$ARG_REPO" ]; then usage "repo is required"; fi;
if [ -z "$ARG_PATTERN" ]; then usage "pattern for asset name is required"; fi;

GH_RESPONSE=$(func_github_asset "$ARG_USER" "$ARG_REPO" "$ARG_PATTERN")
if [[ -z "$GH_RESPONSE" ]]; then errexit "error fetching github response"; fi;

GH_CREATED_AT=$(func_ghutil_get_created_at "$GH_RESPONSE")
if [[ -z "$GH_CREATED_AT" ]]; then errexit "error getting created_at from github response"; fi;

GH_DL_URL=$(func_ghutil_get_downloadurl "$GH_RESPONSE")
if [[ -z "$GH_DL_URL" ]]; then errexit "error getting download_url from github response"; fi;

GH_SOURCE=$(func_ghutil_get_source "$GH_RESPONSE")
if [[ -z "$GH_SOURCE" ]]; then errexit "error getting source from github response"; fi;

GH_MSG=$(func_ghutil_get_msg "$GH_RESPONSE")

FILE_CREATED_AT="$ARG_STATE_FILE"

echo "response msg: $GH_MSG"
echo "response source: $GH_SOURCE"

if [ "$ARG_UPDATE" == "1" ]; then
	# If installed and created_at date is before the current release create_at date, then update
	if [[ -e "$FILE_CREATED_AT" ]]
	then
		TMP_CURRENT_CREATED_AT=$(date +%s -d "$GH_CREATED_AT")
		TMP_EXIST_CREATED_AT=$(date +%s -d "$(cat "$FILE_CREATED_AT")")
		if [[ ! "$TMP_CURRENT_CREATED_AT" -gt "$TMP_EXIST_CREATED_AT" ]]
		then
			echo "up to date"
			exit 255
		fi
	fi
fi

echo "latest release: $GH_CREATED_AT"

if [[ "$ARG_DOWNLOAD" == "1" ]]; then
    wget -q --show-progress -O "$ARG_DOWNLOAD_PATH" "$GH_DL_URL" || errexit "error downloading archive"
	echo "download done"
fi


# Store created_at so that we can compare later for updating the app
echo "$GH_CREATED_AT" | tee "$FILE_CREATED_AT"
