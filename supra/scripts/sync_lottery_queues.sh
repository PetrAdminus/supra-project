#!/usr/bin/env bash
# Usage: ./sync_lottery_queues.sh <PROFILE> [history_limit] [purchase_limit]
# Synchronizes draw history and purchase queues between lottery_core and the
# support/rewards packages. Limits default to 0 (process all pending records).
set -euo pipefail

PROFILE=${1:?"Supra CLI profile is required"}
HISTORY_LIMIT=${2:-0}
PURCHASE_LIMIT=${3:-0}
CONFIG=${SUPRA_CONFIG:-}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PODMAN_IMAGE_DEFAULT="asia-docker.pkg.dev/supra-devnet-misc/supra-testnet/validator-node:v9.0.12"

choose_compose() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return 0
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return 0
  fi

  return 1
}

COMPOSE_CMD="${SUPRA_COMPOSE_CMD:-}"
if [ -z "$COMPOSE_CMD" ]; then
  if COMPOSE_CMD=$(choose_compose); then
    :
  else
    COMPOSE_CMD=""
  fi
fi

SUPRA_BIN_PATH="${SUPRA_BIN:-}"
if [ -z "$SUPRA_BIN_PATH" ] && command -v supra >/dev/null 2>&1; then
  SUPRA_BIN_PATH="$(command -v supra)"
fi

RUNNER=""
if [ -n "${SUPRA_USE_PODMAN:-}" ] && [ "${SUPRA_USE_PODMAN}" != "0" ]; then
  RUNNER="podman"
elif [ -n "$SUPRA_BIN_PATH" ]; then
  RUNNER="local"
elif [ -n "$COMPOSE_CMD" ]; then
  RUNNER="compose"
elif command -v podman >/dev/null 2>&1; then
  RUNNER="podman"
else
  cat >&2 <<'MSG'
[sync_lottery_queues] Не удалось найти Supra CLI. Установите `supra` в PATH,
задайте SUPRA_BIN или включите один из контейнерных способов запуска
(Docker Compose или Podman).
MSG
  exit 1
fi

run_with_local_cli() {
  local function_id="$1"
  local limit="$2"
  local -a args=(move tool run --profile "$PROFILE" --function-id "$function_id")
  if [ -n "$limit" ]; then
    args+=(--args "u64:${limit}")
  fi
  if [ -n "$CONFIG" ]; then
    SUPRA_CONFIG="$CONFIG" "$SUPRA_BIN_PATH" "${args[@]}"
  else
    "$SUPRA_BIN_PATH" "${args[@]}"
  fi
}

run_with_compose() {
  local command="$1"
  local -a compose_parts
  IFS=' ' read -r -a compose_parts <<<"$COMPOSE_CMD"
  local -a env_args=()
  if [ -n "$CONFIG" ]; then
    env_args=(-e "SUPRA_CONFIG=$CONFIG")
  fi
  "${compose_parts[@]}" run --rm "${env_args[@]}" --entrypoint bash supra_cli -lc "$command"
}

run_with_podman() {
  local command="$1"
  local image="${PODMAN_IMAGE:-$PODMAN_IMAGE_DEFAULT}"
  local podman_bin="${PODMAN_BIN:-podman}"
  local volume_suffix="${PODMAN_VOLUME_SUFFIX:-}"
  local -a podman_args
  if [ -n "${PODMAN_EXTRA_ARGS:-}" ]; then
    IFS=' ' read -r -a podman_args <<<"${PODMAN_EXTRA_ARGS}"
  else
    podman_args=(--rm)
  fi

  local -a env_vars=(-e SUPRA_HOME=/supra/configs)
  if [ -n "$CONFIG" ]; then
    env_vars+=(-e "SUPRA_CONFIG=$CONFIG")
  fi

  local -a volumes=(-v "${PROJECT_ROOT}/move_workspace:/supra/move_workspace${volume_suffix}")
  if [ -d "${PROJECT_ROOT}/configs" ]; then
    volumes+=(-v "${PROJECT_ROOT}/configs:/supra/configs${volume_suffix}")
  fi
  if [ -d "${REPO_ROOT}/SupraLottery" ]; then
    volumes+=(-v "${REPO_ROOT}/SupraLottery:/supra/SupraLottery${volume_suffix}")
  fi

  "$podman_bin" run "${podman_args[@]}" "${env_vars[@]}" "${volumes[@]}" \
    "$image" /bin/bash -lc "$command"
}

build_command() {
  local function_id="$1"
  local limit="$2"
  local extra=""
  if [ -n "$limit" ]; then
    extra=" --args u64:${limit}"
  fi
  echo "/supra/supra move tool run --profile ${PROFILE} --function-id ${function_id}${extra}"
}

execute() {
  local function_id="$1"
  local limit="$2"
  case "$RUNNER" in
    local)
      run_with_local_cli "$function_id" "$limit"
      ;;
    compose)
      run_with_compose "$(build_command "$function_id" "$limit")"
      ;;
    podman)
      run_with_podman "$(build_command "$function_id" "$limit")"
      ;;
  esac
}

if [ "${HISTORY_LIMIT,,}" != "skip" ]; then
  echo "[info] Синхронизация очереди розыгрышей (limit=${HISTORY_LIMIT})"
  execute "lottery_support::history::sync_draws_from_rounds" "$HISTORY_LIMIT"
else
  echo "[info] Пропуск синхронизации истории (skip)"
fi

if [ "${PURCHASE_LIMIT,,}" != "skip" ]; then
  echo "[info] Синхронизация очереди покупок (limit=${PURCHASE_LIMIT})"
  execute "lottery_rewards::rounds_sync::sync_purchases_from_rounds" "$PURCHASE_LIMIT"
else
  echo "[info] Пропуск синхронизации покупок (skip)"
fi
