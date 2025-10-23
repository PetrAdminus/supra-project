#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Entropy-Foundation/aptos-core"
REV="7d1e62c9a5394a279a73515a150e880200640f06"
FRAMEWORK_PATH="aptos-move/framework"
NEEDED_DIRS=("move-stdlib" "supra-framework" "aptos-stdlib" "supra-stdlib")

MOVE_HOME="${MOVE_HOME:-$HOME/.move}"
CACHE_PREFIX="https___github_com_Entropy-Foundation_aptos-core_git_${REV}"
TARGET_BASE="${MOVE_HOME}/${CACHE_PREFIX}/${FRAMEWORK_PATH}"

log() {
  echo "[bootstrap_move_deps] $*"
}

have_dependencies() {
  for dir in "${NEEDED_DIRS[@]}"; do
    if [ ! -d "${TARGET_BASE}/${dir}" ]; then
      return 1
    fi
  done
  return 0
}

main() {
  if have_dependencies; then
    log "Found cached dependencies in ${TARGET_BASE}."
    exit 0
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT

  local archive="${tmpdir}/aptos-core.tar.gz"
  log "Fetching ${REPO_URL} (${REV})"
  curl -sSL "${REPO_URL}/archive/${REV}.tar.gz" -o "${archive}"

  log "Extracting archive"
  tar -xzf "${archive}" -C "${tmpdir}"
  local source_base="${tmpdir}/aptos-core-${REV}/${FRAMEWORK_PATH}"

  if [ ! -d "${source_base}" ]; then
    log "Expected framework path ${source_base} not found"
    exit 1
  fi

  mkdir -p "${TARGET_BASE}"
  for dir in "${NEEDED_DIRS[@]}"; do
    log "Installing ${dir} -> ${TARGET_BASE}/${dir}"
    rm -rf "${TARGET_BASE}/${dir}"
    cp -R "${source_base}/${dir}" "${TARGET_BASE}/${dir}"
  done

  log "Move dependencies installed."
}

main "$@"
