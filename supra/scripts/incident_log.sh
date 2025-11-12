#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LOG_ARG_PRESENT=false
for arg in "$@"; do
    if [[ "$arg" == "--log" ]]; then
        LOG_ARG_PRESENT=true
        break
    fi
done

ARGS=("$@")
if [[ "${LOG_ARG_PRESENT}" == false ]]; then
    ARGS+=("--log" "${PROJECT_ROOT}/docs/handbook/operations/incident_log.md")
fi

PYTHONPATH="${PROJECT_ROOT}" python -m supra.tools.incident_log "${ARGS[@]}"
