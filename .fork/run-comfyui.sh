#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_RUNTIME_DIR="$(cd "${REPO_DIR}/.." && pwd)/ComfyUI-runtime"
RUNTIME_DIR="${COMFYUI_RUNTIME_DIR:-${DEFAULT_RUNTIME_DIR}}"
RUNTIME_USER_DIR="${RUNTIME_DIR}/user"
DATABASE_PATH="${RUNTIME_USER_DIR}/comfyui.db"

mkdir -p \
  "${RUNTIME_DIR}" \
  "${RUNTIME_DIR}/custom_nodes" \
  "${RUNTIME_DIR}/input" \
  "${RUNTIME_DIR}/models" \
  "${RUNTIME_DIR}/output" \
  "${RUNTIME_DIR}/temp" \
  "${RUNTIME_USER_DIR}/default/workflows"

exec uv run --no-sync --group custom_nodes "${REPO_DIR}/main.py" \
  "$@" \
  --base-directory "${RUNTIME_DIR}" \
  --user-directory "${RUNTIME_USER_DIR}" \
  --database-url "sqlite:///${DATABASE_PATH}"
