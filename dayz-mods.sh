#!/usr/bin/env bash
set -eo pipefail

SELF=$(basename "$(readlink -f "${0}")")

[[ -z "${STEAM_ROOT}" ]] && STEAM_ROOT="${XDG_DATA_HOME:-${HOME}/.local/share}/Steam"
STEAM_ROOT="${STEAM_ROOT}/steamapps"

DAYZ_ID=221100
DIR_WORKSHOP="${STEAM_ROOT}/workshop/content/${DAYZ_ID}"
DIR_DAYZ="${STEAM_ROOT}/common/DayZ"

API_URL="https://api.daemonforge.dev/server/@ADDRESS@/@PORT@/full"
API_PARAMS=(
  -sSL
  -m 10
  -H "Referer: https://daemonforge.dev/"
  -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36"
)

WORKSHOP_URL="https://steamcommunity.com/sharedfiles/filedetails/?id=@ID@"

DEBUG=0
LAUNCH=0
SERVER=""
PORT="27016"
INPUT=()

declare -A DEPS=(
  [gawk]=gawk
  [curl]=curl
  [jq]=jq
  [steam]=steam
)


print_help() {
  cat <<EOF
Usage: ${SELF} [OPTION]... [MODID]...

Automatically set up mods for the DayZ client
and print the game's -mod command line argument.

Command line options:

  -h
  --help
    Print this help text.

  -d
  --debug
    Print debug messages to output.

  -l
  --launch
    Launch DayZ after resolving and setting up mods
    instead of printing the game's -mod command line argument.

  -s <address[:port]>
  --server <address[:port]>
    Retrieve a server's mod list and add it to the remaining input.
    Uses the daemonforge.dev DayZ server JSON API.
    If --launch is set, it will automatically connect to the server.

  -p <port>
  --port <port>
    The server's query port (not to be confused with the server's game port).
    Default is: 27016

Environment variables:

  STEAM_ROOT
    Set a custom path to Steam's root directory. Default is:
    \${XDG_DATA_HOME:-\${HOME}/.local/share}/Steam
    which defaults to ~/.local/share/Steam

    If the game is stored in a different Steam library directory, then this
    environment variable needs to be set/changed.
EOF
}


while (( "$#" )); do
  case "${1}" in
    -h|--help)
      print_help
      exit
      ;;
    -d|--debug)
      DEBUG=1
      ;;
    -l|--launch)
      LAUNCH=1
      ;;
    -s|--server)
      SERVER="${2}"
      shift
      ;;
    -p|--port)
      PORT="${2}"
      shift
      ;;
    *)
      INPUT+=("${1}")
      ;;
  esac
  shift
done


# ----


err() {
  echo >&2 "[${SELF}][error] ${@}"
  exit 1
}

msg() {
  echo "[${SELF}][info] ${@}"
}

debug() {
  [[ ${DEBUG} == 1 ]] && echo "[${SELF}][debug] ${@}"
}

check_dir() {
  [[ -d "${1}" ]] || err "Invalid/missing directory: ${1}"
}


# ----


for dep in "${!DEPS[@]}"; do
  command -v "${dep}" 2>&1 >/dev/null || err "${DEPS["${dep}"]} is missing. Aborting."
done

check_dir "${DIR_DAYZ}"
check_dir "${DIR_WORKSHOP}"

if [[ -n "${SERVER}" ]]; then
  msg "Querying API for server: ${SERVER%:*}:${PORT}"
  query="$(sed -e "s/@ADDRESS@/${SERVER%:*}/" -e "s/@PORT@/${PORT}/" <<< "${API_URL}")"
  debug "Querying ${query}"
  response="$(curl "${API_PARAMS[@]}" "${query}")"
  [[ $? > 0 ]] && err "Error while querying API"
  debug "Parsing API response"
  jq -e ".mods[]" 2>&1 >/dev/null <<< "${response}" || err "Missing mods data from API response"
  INPUT+=( $(jq -r ".mods[] | select(.app_id == ${DAYZ_ID}) | .id" <<< "${response}") )
fi

missing=0
mods=()
for modid in "${INPUT[@]}"; do
  modpath="${DIR_WORKSHOP}/${modid}"
  if ! [[ -d "${modpath}" ]]; then
    missing=1
    msg "Missing mod directory for: ${modid}"
    msg "Subscribe the mod here: $(sed -e "s/@ID@/${modid}/" <<< "${WORKSHOP_URL}")"
    continue
  fi

  modmeta="${modpath}/meta.cpp"
  [[ -f "${modmeta}" ]] || err "Missing mod metadata for: ${modid}"

  modname="$(gawk 'match($0,/name\s*=\s*"(.+)"/,m){print m[1];exit}' "${modmeta}")"
  [[ -n "${modname}" ]] || err "Missing mod name for: ${modid}"
  debug "Mod ${modid} found: ${modname}"
  modname="${modname//\'/}"

  if ! [[ -L "${DIR_DAYZ}/@${modname}" ]]; then
    msg "Creating mod symlink for: ${modname}"
    ln -sr "${modpath}" "${DIR_DAYZ}/@${modname}"
  fi

  mods+=("@${modname}")
done
[[ "${missing}" == 1 ]] && exit 1

cmdline=()
if [[ "${#mods[@]}" -gt 0 ]]; then
  cmdline+=("\"-mod=$(IFS=";"; echo "${mods[*]}")\"")
fi
if [[ "${LAUNCH}" == 1 ]] && [[ -n "${SERVER}" ]]; then
  cmdline+=("-connect=${SERVER}")
fi

if [[ "${LAUNCH}" == 1 ]]; then
  set -x
  steam -applaunch "${DAYZ_ID}" "${cmdline[@]}"
else
  echo "${cmdline[@]}"
fi
