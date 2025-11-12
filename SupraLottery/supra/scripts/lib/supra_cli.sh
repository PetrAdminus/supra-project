#!/bin/bash
# Shared helpers for Supra CLI Docker commands.

if [[ -n ${SUPRA_CLI_LIB_LOADED:-} ]]; then
  return
fi
SUPRA_CLI_LIB_LOADED=1

supra_cli_init() {
  local profile=${1:?"Profile name is required"}
  SUPRA_CLI_PROFILE=${profile}
  SUPRA_CLI_ENV_PREFIX=""
  SUPRA_CLI_COPY_CONFIG=""
  if [[ -n ${SUPRA_CONFIG:-} ]]; then
    SUPRA_CLI_ENV_PREFIX="SUPRA_CONFIG=${SUPRA_CONFIG} "
    printf -v SUPRA_CLI_COPY_CONFIG 'mkdir -p /supra/.aptos && cp %q /supra/.aptos/config.yaml && ' "${SUPRA_CONFIG}"
  fi
  if [[ -n ${SUPRA_PROFILE_PASSWORD:-} ]]; then
    SUPRA_CLI_ENV_PREFIX+="SUPRA_PROFILE_PASSWORD=${SUPRA_PROFILE_PASSWORD} "
  fi
}

supra_cli_require_env() {
  local missing=()
  for var in "$@"; do
    if [[ -z ${!var:-} ]]; then
      missing+=("$var")
    fi
  done
  if (( ${#missing[@]} )); then
    printf '[error] Missing required env: %s\n' "${missing[*]}" >&2
    exit 1
  fi
}

supra_cli_compose() {
  local command=${1:?}
  docker compose run --rm --entrypoint bash supra_cli -lc "${SUPRA_CLI_COPY_CONFIG}${SUPRA_CLI_ENV_PREFIX}${command}"
}

supra_cli_move_run() {
  local args=${1:?}
  supra_cli_move_run_profile "${SUPRA_CLI_PROFILE}" "${args}"
}

supra_cli_move_run_profile() {
  local profile=${1:?}
  local args=${2:?}
  supra_cli_compose "/supra/supra move tool run --profile ${profile} --expiration-secs 600 ${args}"
}

supra_cli_move_view() {
  local args=${1:?}
  supra_cli_move_view_profile "${SUPRA_CLI_PROFILE}" "${args}"
}

supra_cli_move_view_profile() {
  local profile=${1:?}
  local args=${2:?}
  supra_cli_compose "/supra/supra move tool view --profile ${profile} ${args}"
}

supra_cli_move_publish() {
  local args=${1:-"--package-dir /supra/move_workspace/lottery"}
  supra_cli_compose "/supra/supra move tool publish --profile ${SUPRA_CLI_PROFILE} ${args}"
}

supra_cli_info() {
  printf '[info] %s\n' "$*"
}

supra_cli_warn() {
  printf '[warn] %s\n' "$*" >&2
}
