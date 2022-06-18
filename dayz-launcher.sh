#!/usr/bin/env bash
set -eo pipefail

SELF=$(basename "$(readlink -f "${0}")")

DAYZ_ID=221100

DEFAULT_GAMEPORT=2302
DEFAULT_QUERYPORT=27016

FLATPAK_STEAM="com.valvesoftware.Steam"
FLATPAK_PARAMS=(
  --branch=stable
  --arch=x86_64
  --command=/app/bin/steam-wrapper
)

API_URL="https://dayzsalauncher.com/api/v1/query/@ADDRESS@/@PORT@"
API_PARAMS=(
  -sSL
  -m 10
  -H "User-Agent: dayz-linux-cli-launcher"
)

WORKSHOP_URL="https://steamcommunity.com/sharedfiles/filedetails/?id=@ID@"


DEBUG=0
LAUNCH=0
STEAM=""
SERVER=""
PORT="${DEFAULT_QUERYPORT}"
NAME=""
INPUT=()
MODS=()
PARAMS=()

declare -A DEPS=(
  [gawk]="required for parsing the mod metadata"
  [curl]="required for querying the server API"
  [jq]="required for parsing the server API's JSON response"
)


print_help() {
  cat <<EOF
Usage: ${SELF} [OPTION]... [MODID]... [-- [GAME-PARAM]...]

Automatically set up mods for DayZ, launch the game and connect to a server,
or print the game's -mod command line argument for custom configuration.

Command line options:

  -h
  --help
    Print this help text.

  -d
  --debug
    Print debug messages to output.

  --steam <"" | flatpak | /path/to/steam/executable>
    If set to flatpak, use the flatpak version of Steam (${FLATPAK_STEAM}).
    Steam needs to already be running in the flatpak container.
    Default is: "" (automatic detection - prefers flatpak if available)

  -l
  --launch
    Launch DayZ after resolving and setting up mods instead of
    printing the game's -mod command line argument.
    Any custom game parameters that come after the first double-dash (--) will
    be appended to the overall launch command line. This implies --launch.

  -n <name>
  --name <name>
    Set the profile name when launching the game via --launch.
    Some community servers require a profile name when trying to connect.

  -s <address[:port]>
  --server <address[:port]>
    Retrieve a server's mod list and add it to the remaining input.
    Uses the dayzsalauncher.com DayZ server JSON API.
    If --launch is set, it will automatically connect to the server.
    The optional port is the server's game port. Default is: ${DEFAULT_GAMEPORT}

  -p <port>
  --port <port>
    The server's query port, not to be confused with the server's game port.
    Default is: ${DEFAULT_QUERYPORT}

Environment variables:

  STEAM_ROOT
    Set a custom path to Steam's root directory. Default is:
    \${XDG_DATA_HOME:-\${HOME}/.local/share}/Steam
    which defaults to ~/.local/share/Steam

    If the flatpak package is being used, then the default is:
    ~/.var/app/${FLATPAK_STEAM}/data/Steam

    If the game is stored in a different Steam library directory, then this
    environment variable needs to be set/changed.

    For example, if the game has been installed in the game library located in
      /media/games/SteamLibrary/steamapps/common/DayZ
    then the STEAM_ROOT env var needs to be set like this:
      STEAM_ROOT=/media/games/SteamLibrary
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
    --steam)
      STEAM="${2}"
      shift
      ;;
    -l|--launch)
      LAUNCH=1
      ;;
    -s|--server)
      SERVER="${2}"
      [[ "${SERVER}" = *:* ]] || SERVER="${SERVER}:${DEFAULT_GAMEPORT}"
      shift
      ;;
    -p|--port)
      PORT="${2}"
      shift
      ;;
    -n|--name)
      NAME="${2}"
      shift
      ;;
    --)
      shift
      PARAMS+=("${@}")
      LAUNCH=1
      break
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
  if [[ ${DEBUG} == 1 ]]; then
    echo "[${SELF}][debug] ${@}"
  fi
}

check_dir() {
  debug "Checking directory: ${1}"
  [[ -d "${1}" ]] || err "Invalid/missing directory: ${1}"
}

check_dep() {
  command -v "${1}" >/dev/null 2>&1
}

check_deps() {
  for dep in "${!DEPS[@]}"; do
    check_dep "${dep}" || err "'${dep}' is missing (${DEPS["${dep}"]}). Aborting."
  done
}

check_flatpak() {
  check_dep flatpak \
    && flatpak info "${FLATPAK_STEAM}" >/dev/null 2>&1 \
    && { flatpak ps | grep "${FLATPAK_STEAM}"; } >/dev/null 2>&1
}

dec2base64() {
  echo "$1" \
    | LC_ALL=C gawk '
      {
        do {
          printf "%c", and($1, 255)
          $1 = rshift($1, 8)
        } while ($1 > 0)
      }
    ' \
    | base64 \
    | sed 's|/|-|g; s|+|_|g; s|=||g'
}


# ----


resolve_steam() {
  if [[ "${STEAM}" == flatpak ]]; then
    check_flatpak || err "Could not find a running instance of the '${FLATPAK_STEAM}' flatpak package"
  elif [[ -n "${STEAM}" ]]; then
    check_dep "${STEAM}" || err "Could not find the '${STEAM}' executable"
  else
    msg "Resolving steam"
    if check_flatpak; then
      STEAM=flatpak
    elif check_dep steam; then
      STEAM=steam
    else
      err "Could not find a running instance of the '${FLATPAK_STEAM}' flatpak package or the 'steam' executable"
    fi
  fi
}

query_server_api() {
  [[ -z "${SERVER}" ]] && return

  local query
  local response
  msg "Querying API for server: ${SERVER%:*}:${PORT}"
  query="$(sed -e "s/@ADDRESS@/${SERVER%:*}/" -e "s/@PORT@/${PORT}/" <<< "${API_URL}")"
  debug "Querying ${query}"
  response="$(curl "${API_PARAMS[@]}" "${query}")"
  debug "Parsing API response"
  jq -e '.result.mods | select(type == "array")' >/dev/null 2>&1 <<< "${response}" || err "Missing mods data from API response"
  jq -e '.result.mods[]' >/dev/null 2>&1 <<< "${response}" || { msg "This server is unmodded"; return; }

  INPUT+=( $(jq -r ".result.mods[] | .steamWorkshopId" <<< "${response}") )
}

setup_mods() {
  local dir_dayz="${1}"
  local dir_workshop="${2}"
  local missing=0

  for modid in "${INPUT[@]}"; do
    local modpath="${dir_workshop}/${modid}"
    if ! [[ -d "${modpath}" ]]; then
      missing=1
      msg "Missing mod directory for: ${modid}"
      msg "Subscribe the mod here: $(sed -e "s/@ID@/${modid}/" <<< "${WORKSHOP_URL}")"
      continue
    fi

    local modmeta="${modpath}/meta.cpp"
    [[ -f "${modmeta}" ]] || err "Missing mod metadata for: ${modid}"

    local modname="$(gawk 'match($0,/name\s*=\s*"(.+)"/,m){print m[1];exit}' "${modmeta}")"
    [[ -n "${modname}" ]] || err "Missing mod name for: ${modid}"
    debug "Mod ${modid} found: ${modname}"
    local modlink="@$(dec2base64 "${modid}")"

    if ! [[ -L "${dir_dayz}/${modlink}" ]]; then
      msg "Creating mod symlink for: ${modname} (${modlink})"
      ln -sr "${modpath}" "${dir_dayz}/${modlink}"
    fi

    MODS+=("${modlink}")
  done

  return ${missing}
}

run_steam() {
  if [[ "${STEAM}" == flatpak ]]; then
    ( set -x; flatpak run "${FLATPAK_PARAMS[@]}" "${FLATPAK_STEAM}" "${@}"; )
  else
    ( set -x; steam "${@}"; )
  fi
}


main() {
  check_deps
  resolve_steam

  if [[ "${STEAM}" == flatpak ]]; then
    msg "Using flatpak mode"
  else
    msg "Using non-flatpak mode: ${STEAM}"
  fi

  if [[ -z "${STEAM_ROOT}" ]]; then
    if [[ "${STEAM}" == flatpak ]]; then
      STEAM_ROOT="${HOME}/.var/app/${FLATPAK_STEAM}/data/Steam"
    else
      STEAM_ROOT="${XDG_DATA_HOME:-${HOME}/.local/share}/Steam"
    fi
  fi
  STEAM_ROOT="${STEAM_ROOT}/steamapps"

  local dir_dayz="${STEAM_ROOT}/common/DayZ"
  local dir_workshop="${STEAM_ROOT}/workshop/content/${DAYZ_ID}"
  check_dir "${dir_dayz}"
  check_dir "${dir_workshop}"

  query_server_api
  setup_mods "${dir_dayz}" "${dir_workshop}" || exit 1

  local mods="$(IFS=";"; echo "${MODS[*]}")"

  if [[ "${LAUNCH}" == 1 ]]; then
    local cmdline=()
    [[ -n "${mods}" ]] && cmdline+=("-mod=${mods}")
    [[ -n "${SERVER}" ]] && cmdline+=("-connect=${SERVER}" -nolauncher -world=empty)
    [[ -n "${NAME}" ]] && cmdline+=("-name=${NAME}")
    msg "Launching DayZ"
    run_steam -applaunch "${DAYZ_ID}" "${cmdline[@]}" "${PARAMS[@]}"
  elif [[ -n "${mods}" ]]; then
    msg "Add this to your game's launch options, including the quotes:"
    echo "\"-mod=${mods}\""
  else
    msg "Nothing to do..."
    msg "No mod-ID list, --server address, or --launch parameter set."
    msg "See --help for all the available options."
  fi
}

main
