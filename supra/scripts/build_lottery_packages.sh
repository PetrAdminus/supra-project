#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_PACKAGES=("lottery_core" "lottery_support" "lottery_rewards")

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

main() {
  local runner=""

  if command -v supra >/dev/null 2>&1; then
    runner=run_with_local_cli
  elif [ -n "$COMPOSE_CMD" ]; then
    runner=run_in_compose
  else
    cat >&2 <<'MSG'
[build_lottery_packages] Не удалось найти бинарь `supra` или Docker Compose.
Установите CLI Supra или Docker (для запуска контейнера `supra_cli`).
MSG
    exit 1
  fi

  for pkg in "${PACKAGES[@]}"; do
    echo "==> Сборка пакета ${pkg}"
    "${runner}" "${pkg}"
  done
}

main "$@"
