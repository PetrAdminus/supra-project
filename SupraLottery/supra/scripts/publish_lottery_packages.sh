#!/usr/bin/env bash
# Usage: ./publish_lottery_packages.sh <PROFILE> [package...]
# Publishes lottery_core, lottery_support and lottery_rewards sequentially using Supra CLI.
set -euo pipefail

if [ "$#" -lt 1 ]; then
  cat >&2 <<'MSG'
Usage: publish_lottery_packages.sh <PROFILE> [package...]
If no packages are provided, the default order is lottery_core, lottery_support, lottery_rewards.
MSG
  exit 1
fi

PROFILE="$1"
shift

if [ "$#" -gt 0 ]; then
  PACKAGES=("$@")
else
  PACKAGES=("lottery_core" "lottery_support" "lottery_rewards")
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LOCAL_WORKSPACE="${REPO_ROOT}/SupraLottery/supra/move_workspace"
CONTAINER_WORKSPACE="/supra/move_workspace"
CONFIG="${SUPRA_CONFIG:-}"
ASSUME_YES="${SUPRA_PUBLISH_ASSUME_YES:-1}"
DEFAULT_ARGS=(--included-artifacts none --skip-fetch-latest-git-deps)
EXTRA_ARGS=()
if [ -n "${SUPRA_PUBLISH_EXTRA_ARGS:-}" ]; then
  IFS=' ' read -r -a EXTRA_ARGS <<<"${SUPRA_PUBLISH_EXTRA_ARGS}"
fi

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
[publish_lottery_packages] Не удалось найти Supra CLI. Установите бинарь `supra`,
укажите путь через SUPRA_BIN или используйте Docker Compose / Podman (SUPRA_COMPOSE_CMD,
SUPRA_USE_PODMAN).
MSG
  exit 1
fi

log_mode() {
  case "$RUNNER" in
    local)
      echo "[publish_lottery_packages] Используется локальный Supra CLI (${SUPRA_BIN_PATH})."
      ;;
    compose)
      echo "[publish_lottery_packages] Используется Docker Compose (${COMPOSE_CMD})."
      ;;
    podman)
      local image="${PODMAN_IMAGE:-asia-docker.pkg.dev/supra-devnet-misc/supra-testnet/validator-node:v9.0.12}"
      local podman_bin="${PODMAN_BIN:-podman}"
      echo "[publish_lottery_packages] Используется Podman (${podman_bin}) с образом ${image}."
      ;;
  esac
}

run_with_local_cli() {
  local pkg="$1"
  local package_dir="${LOCAL_WORKSPACE}/${pkg}"
  if [ ! -d "$package_dir" ]; then
    echo "[publish_lottery_packages] Не найден пакет ${package_dir}" >&2
    return 1
  fi
  local -a args=(move tool publish --profile "$PROFILE" --package-dir "$package_dir")
  args+=("${DEFAULT_ARGS[@]}")
  if [ "$ASSUME_YES" != "0" ]; then
    args+=(--assume-yes)
  fi
  if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
    args+=("${EXTRA_ARGS[@]}")
  fi
  if [ -n "$CONFIG" ]; then
    SUPRA_CONFIG="$CONFIG" "$SUPRA_BIN_PATH" "${args[@]}"
  else
    "$SUPRA_BIN_PATH" "${args[@]}"
  fi
}

build_compose_command() {
  local pkg="$1"
  local package_dir="${CONTAINER_WORKSPACE}/${pkg}"
  local cmd="/supra/supra move tool publish --profile ${PROFILE} --package-dir ${package_dir}"
  for arg in "${DEFAULT_ARGS[@]}"; do
    cmd+=" ${arg}"
  done
  if [ "$ASSUME_YES" != "0" ]; then
    cmd+=" --assume-yes"
  fi
  if [ ${#EXTRA_ARGS[@]} -gt 0 ]; then
    for arg in "${EXTRA_ARGS[@]}"; do
      cmd+=" ${arg}"
    done
  fi
  echo "$cmd"
}

run_with_compose() {
  local pkg="$1"
  local -a compose_parts
  IFS=' ' read -r -a compose_parts <<<"$COMPOSE_CMD"
  local -a env_args=()
  if [ -n "$CONFIG" ]; then
    env_args=(-e "SUPRA_CONFIG=$CONFIG")
  fi
  "${compose_parts[@]}" run --rm "${env_args[@]}" --entrypoint bash supra_cli -lc "$(build_compose_command "$pkg")"
}

run_with_podman() {
  local pkg="$1"
  local image="${PODMAN_IMAGE:-asia-docker.pkg.dev/supra-devnet-misc/supra-testnet/validator-node:v9.0.12}"
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
    "$image" /bin/bash -lc "$(build_compose_command "$pkg")"
}

publish_package() {
  local pkg="$1"
  echo "==> Публикация пакета ${pkg}"
  case "$RUNNER" in
    local)
      run_with_local_cli "$pkg"
      ;;
    compose)
      run_with_compose "$pkg"
      ;;
    podman)
      run_with_podman "$pkg"
      ;;
  esac
}

log_mode

for pkg in "${PACKAGES[@]}"; do
  publish_package "$pkg"
  echo
  echo "[publish_lottery_packages] Завершена публикация ${pkg}."
  echo
  if [ -n "${SUPRA_PUBLISH_PAUSE:-}" ]; then
    echo "[publish_lottery_packages] Пауза ${SUPRA_PUBLISH_PAUSE} секунд перед следующим пакетом."
    sleep "${SUPRA_PUBLISH_PAUSE}"
  fi

done
