#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Entropy-Foundation/aptos-core"
REV="dev"
FRAMEWORK_PATH="aptos-move/framework"
NEEDED_DIRS=("move-stdlib" "supra-framework" "aptos-stdlib" "supra-stdlib")

MOVE_HOME="${MOVE_HOME:-$HOME/.move}"
CACHE_PREFIX="https___github_com_Entropy-Foundation_aptos-core_git_${REV}"
TARGET_BASE="${MOVE_HOME}/${CACHE_PREFIX}/${FRAMEWORK_PATH}"

log() {
  echo "[bootstrap_move_deps] $*"
}

ensure_dependencies() {
  local missing=0
  for dir in "${NEEDED_DIRS[@]}"; do
    if [ ! -d "${TARGET_BASE}/${dir}" ]; then
      missing=1
      break
    fi
  done
  return ${missing}
}

main() {
  if ensure_dependencies; then
    log "Все зависимости уже установлены в ${TARGET_BASE}."
    exit 0
  fi

  local tmpdir="$(mktemp -d)"
  trap 'if [ -n "${tmpdir:-}" ]; then rm -rf "${tmpdir}"; fi' EXIT

  local archive="${tmpdir}/aptos-core.tar.gz"
  log "Скачиваю ${REPO_URL} (${REV})…"
  curl -sSL "${REPO_URL}/archive/refs/heads/${REV}.tar.gz" -o "${archive}"

  log "Распаковываю архив…"
  tar -xzf "${archive}" -C "${tmpdir}"
  local source_base="${tmpdir}/aptos-core-${REV}/${FRAMEWORK_PATH}"

  mkdir -p "${TARGET_BASE}"
  for dir in "${NEEDED_DIRS[@]}"; do
    log "Копирую ${dir} → ${TARGET_BASE}/${dir}"
    rm -rf "${TARGET_BASE}/${dir}"
    cp -R "${source_base}/${dir}" "${TARGET_BASE}/${dir}"
  done

  log "Готово. Git-зависимости Move теперь доступны локально."
}

main "$@"
