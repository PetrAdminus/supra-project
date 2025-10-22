#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
WORKSPACE_DIR="${PROJECT_ROOT}/SupraLottery/supra/move_workspace"
PYTHON_BIN="${PYTHON_BIN:-python3}"
DEFAULT_PACKAGES=("lottery_core" "lottery_support" "lottery_rewards")
PODMAN_IMAGE_DEFAULT="asia-docker.pkg.dev/supra-devnet-misc/supra-testnet/validator-node:v9.0.12"

if [ "$#" -eq 0 ]; then
  PACKAGES=("${DEFAULT_PACKAGES[@]}")
else
  PACKAGES=("$@")
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

  echo "" >&2
  return 1
}

COMPOSE_CMD=""
if ! COMPOSE_CMD=$(choose_compose); then
  COMPOSE_CMD=""
fi

if [ -z "${PODMAN_BIN:-}" ] && command -v podman >/dev/null 2>&1; then
  PODMAN_BIN="podman"
fi

run_in_compose() {
  local pkg="$1"
  local compose_cmd=( )
  IFS=' ' read -r -a compose_cmd <<<"$COMPOSE_CMD"
  "${compose_cmd[@]}" run --rm supra_cli \
    supra move tool sandbox build --package-dir "/supra/move_workspace/${pkg}"
}

run_with_local_cli() {
  local pkg="$1"
  supra move tool sandbox build --package-dir "${ROOT_DIR}/move_workspace/${pkg}"
}

run_with_podman() {
  local pkg="$1"
  local image="${PODMAN_IMAGE:-$PODMAN_IMAGE_DEFAULT}"
  local volume_suffix="${PODMAN_VOLUME_SUFFIX:-}"
  local podman_args=( )

  if [ -n "${PODMAN_EXTRA_ARGS:-}" ]; then
    IFS=' ' read -r -a podman_args <<<"${PODMAN_EXTRA_ARGS}"
  else
    podman_args=("--rm")
  fi

  local workspace_volume="${ROOT_DIR}/move_workspace:/supra/move_workspace${volume_suffix}"
  local -a volumes=("-v" "${workspace_volume}")

  if [ -d "${ROOT_DIR}/configs" ]; then
    local config_volume="${ROOT_DIR}/configs:/supra/configs${volume_suffix}"
    volumes+=("-v" "${config_volume}")
  fi

  "${PODMAN_BIN}" run "${podman_args[@]}" \
    -e SUPRA_HOME=/supra/configs \
    "${volumes[@]}" \
    "${image}" \
    /supra/supra move tool sandbox build --package-dir "/supra/move_workspace/${pkg}"
}

run_with_move_cli() {
  local pkg="$1"
  local cli_path=""

  if [ -n "${MOVE_CLI:-}" ]; then
    cli_path="${MOVE_CLI}"
  elif command -v aptos >/dev/null 2>&1; then
    cli_path="$(command -v aptos)"
  fi

  if [ -z "${cli_path}" ]; then
    cat >&2 <<'MSG'
[build_lottery_packages] Не удалось найти Supra CLI и контейнеры. Установите Aptos CLI
(`MOVE_CLI=/path/to/aptos`) или добавьте его в PATH, чтобы использовать Python-обёртку
`supra.scripts.cli move-test` для локальной проверки пакетов.
MSG
    return 1
  fi

  local python_path="${PYTHONPATH_OVERRIDE:-${PROJECT_ROOT}/SupraLottery}"
  PYTHONPATH="${python_path}" \
    "${PYTHON_BIN}" -m supra.scripts.cli move-test \
    --workspace "${WORKSPACE_DIR}" \
    --package "${pkg}" \
    --mode check \
    --cli "${cli_path}" \
    --report-json - \
    --report-junit - \
    --report-log -
}

main() {
  local runner=""

  if command -v supra >/dev/null 2>&1; then
    runner=run_with_local_cli
  elif [ -n "${MOVE_CLI:-}" ]; then
    runner=run_with_move_cli
  elif [ -n "$COMPOSE_CMD" ]; then
    runner=run_in_compose
  elif [ -n "${PODMAN_BIN:-}" ]; then
    runner=run_with_podman
  elif command -v aptos >/dev/null 2>&1; then
    runner=run_with_move_cli
  else
    cat >&2 <<'MSG'
[build_lottery_packages] Не удалось найти бинарь `supra`, Docker Compose, Podman или Aptos CLI.
Установите Supra CLI (либо настройте Docker/Podman), либо скачайте бинарь Aptos CLI и укажите
его через переменную `MOVE_CLI`, чтобы воспользоваться Python-обёрткой `supra.scripts.cli`.
MSG
    exit 1
  fi

  if [ "$runner" = run_in_compose ]; then
    echo "[build_lottery_packages] Используется Docker Compose (${COMPOSE_CMD})."
  elif [ "$runner" = run_with_podman ]; then
    local image="${PODMAN_IMAGE:-$PODMAN_IMAGE_DEFAULT}"
    echo "[build_lottery_packages] Используется Podman (${PODMAN_BIN}) с образом ${image}."
  elif [ "$runner" = run_with_move_cli ]; then
    local cli_display="${MOVE_CLI:-$(command -v aptos 2>/dev/null || echo "aptos")}" 
    echo "[build_lottery_packages] Используется Python-обёртка supra.scripts.cli (CLI: ${cli_display})."
  fi

  for pkg in "${PACKAGES[@]}"; do
    echo "==> Сборка пакета ${pkg}"
    "${runner}" "${pkg}"
  done
}

main "$@"
