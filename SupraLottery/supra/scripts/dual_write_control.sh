#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
WORKSPACE_DIR="${PROJECT_ROOT}/SupraLottery/supra/move_workspace"
PODMAN_IMAGE_DEFAULT="asia-docker.pkg.dev/supra-devnet-misc/supra-testnet/validator-node:v9.0.12"

usage() {
  cat <<'USAGE'
Использование: dual_write_control.sh [опции] <команда> [аргументы]

Команды:
  init <abort_on_mismatch> <abort_on_missing>      — инициализировать мост dual-write
  update-flags <enabled> <abort_on_mismatch> <abort_on_missing>
                                                — обновить флаги dual-write
  set <lottery_id> <expected_hash_hex>             — записать ожидаемый хэш сводки
  clear <lottery_id>                               — удалить ожидаемый хэш
  enable-mirror                                    — включить запись в legacy архив
  disable-mirror                                   — отключить запись в legacy архив
  mirror <lottery_id>                              — вручную зеркалировать сводку
  status <lottery_id>                              — показать статус конкретной лотереи
  flags                                            — вывести текущие флаги dual-write
  pending                                          — вывести список лотерей с ожидаемым хэшем

Опции:
  --profile <имя>        Профиль Supra CLI (например, default)
  --config <путь>        Конфиг Supra CLI (например, /supra/configs/devnet.yaml)
  --backend <тип>        Явно указать backend: local | docker | docker-compose | podman
  --podman-image <образ> Образ контейнера Supra CLI для режима podman
  -h, --help             Показать эту справку
USAGE
}

PROFILE=""
CONFIG=""
BACKEND_OVERRIDE=""
PODMAN_IMAGE="${PODMAN_IMAGE_DEFAULT}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE=${2:?"Значение для --profile не указано"}
      shift 2
      ;;
    --config)
      CONFIG=${2:?"Значение для --config не указано"}
      shift 2
      ;;
    --backend)
      BACKEND_OVERRIDE=${2:?"Значение для --backend не указано"}
      shift 2
      ;;
    --podman-image)
      PODMAN_IMAGE=${2:?"Значение для --podman-image не указано"}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

COMMAND=$1
shift

COMPOSE_CMD=( )

choose_compose() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
    return 0
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
    return 0
  fi
  return 1
}

BACKEND=""

choose_backend() {
  if [[ -n "$BACKEND_OVERRIDE" ]]; then
    case "$BACKEND_OVERRIDE" in
      local)
        if ! command -v supra >/dev/null 2>&1; then
          echo "[dual_write_control] Бинарь supra не найден для backend=local" >&2
          exit 1
        fi
        BACKEND="local"
        return
        ;;
      docker|docker-compose)
        if ! choose_compose; then
          echo "[dual_write_control] Docker Compose недоступен" >&2
          exit 1
        fi
        BACKEND="docker_compose"
        return
        ;;
      podman)
        if ! command -v podman >/dev/null 2>&1; then
          echo "[dual_write_control] Podman недоступен" >&2
          exit 1
        fi
        BACKEND="podman"
        return
        ;;
      *)
        echo "[dual_write_control] Неизвестный backend: $BACKEND_OVERRIDE" >&2
        exit 1
        ;;
    esac
  fi

  if command -v supra >/dev/null 2>&1; then
    BACKEND="local"
    return
  fi
  if choose_compose; then
    BACKEND="docker_compose"
    return
  fi
  if command -v podman >/dev/null 2>&1; then
    BACKEND="podman"
    return
  fi

  echo "[dual_write_control] Не удалось определить среду запуска Supra CLI" >&2
  exit 1
}

invoke_supra() {
  local -a args=("$@")
  case "$BACKEND" in
    local)
      supra "${args[@]}"
      ;;
    docker_compose)
      "${COMPOSE_CMD[@]}" run --rm supra_cli supra "${args[@]}"
      ;;
    podman)
      local volume_suffix="${PODMAN_VOLUME_SUFFIX:-}";
      local -a podman_args
      if [[ -n "${PODMAN_EXTRA_ARGS:-}" ]]; then
        read -r -a podman_args <<<"${PODMAN_EXTRA_ARGS}"
      else
        podman_args=("--rm")
      fi
      local workspace_volume="${ROOT_DIR}/move_workspace:/supra/move_workspace${volume_suffix}"
      local -a volumes=("-v" "${workspace_volume}")
      if [[ -d "${ROOT_DIR}/configs" ]]; then
        local config_volume="${ROOT_DIR}/configs:/supra/configs${volume_suffix}"
        volumes+=("-v" "${config_volume}")
      fi
      podman run "${podman_args[@]}" \
        -e SUPRA_HOME=/supra/configs \
        "${volumes[@]}" \
        "${PODMAN_IMAGE}" \
        /supra/supra "${args[@]}"
      ;;
    *)
      echo "[dual_write_control] Backend не выбран" >&2
      exit 1
      ;;
  esac
}

build_run_command() {
  local function_name=$1
  shift
  local -a cmd=(move run)
  if [[ -n "$PROFILE" ]]; then
    cmd+=(--profile "$PROFILE")
  fi
  if [[ -n "$CONFIG" ]]; then
    cmd+=(--config "$CONFIG")
  fi
  cmd+=(--function "$function_name")
  if [[ $# -gt 0 ]]; then
    cmd+=(--args)
    while [[ $# -gt 0 ]]; do
      cmd+=("$1")
      shift
    done
  fi
  printf '%s\0' "${cmd[@]}"
}

build_view_command() {
  local function_name=$1
  shift
  local -a cmd=(move view)
  if [[ -n "$CONFIG" ]]; then
    cmd+=(--config "$CONFIG")
  fi
  cmd+=(--function "$function_name")
  if [[ $# -gt 0 ]]; then
    cmd+=(--args)
    while [[ $# -gt 0 ]]; do
      cmd+=("$1")
      shift
    done
  fi
  printf '%s\0' "${cmd[@]}"
}

run_move() {
  local -a cmd
  IFS=$'\0' read -r -d '' -a cmd < <(build_run_command "$@")
  invoke_supra "${cmd[@]}"
}

view_move() {
  local -a cmd
  IFS=$'\0' read -r -d '' -a cmd < <(build_view_command "$@")
  invoke_supra "${cmd[@]}"
}

normalize_bool() {
  case "$1" in
    true|false)
      printf '%s' "$1"
      ;;
    1)
      printf 'true'
      ;;
    0)
      printf 'false'
      ;;
    *)
      echo "[dual_write_control] Ожидается булево значение (true/false/1/0), получено: $1" >&2
      exit 1
      ;;
  esac
}

normalize_hex() {
  local value="$1"
  value=${value#0x}
  value=${value#0X}
  if [[ -z "$value" ]]; then
    echo "[dual_write_control] Пустой хэш" >&2
    exit 1
  fi
  printf '0x%s' "${value,,}"
}

choose_backend

case "$COMMAND" in
  init)
    if [[ $# -ne 2 ]]; then
      echo "[dual_write_control] Требуется 2 аргумента: abort_on_mismatch abort_on_missing" >&2
      exit 1
    fi
    local local_abort_mismatch
    local local_abort_missing
    local_abort_mismatch=$(normalize_bool "$1")
    local_abort_missing=$(normalize_bool "$2")
    run_move "lottery_multi::legacy_bridge::init_dual_write" "bool:${local_abort_mismatch}" "bool:${local_abort_missing}"
    ;;
  update-flags)
    if [[ $# -ne 3 ]]; then
      echo "[dual_write_control] Требуется 3 аргумента: enabled abort_on_mismatch abort_on_missing" >&2
      exit 1
    fi
    local local_enabled
    local local_abort_mismatch
    local local_abort_missing
    local_enabled=$(normalize_bool "$1")
    local_abort_mismatch=$(normalize_bool "$2")
    local_abort_missing=$(normalize_bool "$3")
    run_move "lottery_multi::legacy_bridge::update_flags" \
      "bool:${local_enabled}" "bool:${local_abort_mismatch}" "bool:${local_abort_missing}"
    ;;
  set)
    if [[ $# -ne 2 ]]; then
      echo "[dual_write_control] Требуется 2 аргумента: lottery_id expected_hash_hex" >&2
      exit 1
    fi
    local normalized_hash
    normalized_hash=$(normalize_hex "$2")
    run_move "lottery_multi::legacy_bridge::set_expected_hash" "u64:$1" "hex:${normalized_hash}"
    ;;
  clear)
    if [[ $# -ne 1 ]]; then
      echo "[dual_write_control] Требуется 1 аргумент: lottery_id" >&2
      exit 1
    fi
    run_move "lottery_multi::legacy_bridge::clear_expected_hash" "u64:$1"
    ;;
  enable-mirror)
    if [[ $# -ne 0 ]]; then
      echo "[dual_write_control] Команда enable-mirror не принимает аргументы" >&2
      exit 1
    fi
    run_move "lottery_multi::legacy_bridge::enable_legacy_mirror"
    ;;
  disable-mirror)
    if [[ $# -ne 0 ]]; then
      echo "[dual_write_control] Команда disable-mirror не принимает аргументы" >&2
      exit 1
    fi
    run_move "lottery_multi::legacy_bridge::disable_legacy_mirror"
    ;;
  mirror)
    if [[ $# -ne 1 ]]; then
      echo "[dual_write_control] Требуется 1 аргумент: lottery_id" >&2
      exit 1
    fi
    run_move "lottery_multi::history::mirror_summary_admin" "u64:$1"
    ;;
  status)
    if [[ $# -ne 1 ]]; then
      echo "[dual_write_control] Требуется 1 аргумент: lottery_id" >&2
      exit 1
    fi
    view_move "lottery_multi::legacy_bridge::dual_write_status" "u64:$1"
    ;;
  flags)
    view_move "lottery_multi::legacy_bridge::dual_write_flags"
    ;;
  pending)
    view_move "lottery_multi::legacy_bridge::pending_expected_hashes"
    ;;
  *)
    echo "[dual_write_control] Неизвестная команда: $COMMAND" >&2
    usage
    exit 1
    ;;
esac

