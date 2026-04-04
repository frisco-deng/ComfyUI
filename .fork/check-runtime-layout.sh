#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_RUNTIME_DIR="$(cd "${REPO_DIR}/.." && pwd)/ComfyUI-runtime"
RUNTIME_DIR="${COMFYUI_RUNTIME_DIR:-${DEFAULT_RUNTIME_DIR}}"
REPO_USER_DIR="${REPO_DIR}/user"
RUNTIME_USER_DIR="${RUNTIME_DIR}/user"
RUNTIME_DB="${RUNTIME_USER_DIR}/comfyui.db"
RUNTIME_MAIN="${RUNTIME_DIR}/main.py"
RUNTIME_RUN="${RUNTIME_DIR}/run-comfyui.sh"

failures=()

for name in custom_nodes input models output user; do
  if [[ ! -d "${RUNTIME_DIR}/${name}" ]]; then
    failures+=("Missing runtime directory: ${RUNTIME_DIR}/${name}")
  fi
done

if [[ ! -d "${RUNTIME_USER_DIR}/default/workflows" ]]; then
  failures+=("Missing workflows directory: ${RUNTIME_USER_DIR}/default/workflows")
fi

if [[ ! -f "${RUNTIME_MAIN}" ]]; then
  failures+=("Missing runtime launcher shim: ${RUNTIME_MAIN}")
fi

if [[ ! -x "${RUNTIME_RUN}" ]]; then
  failures+=("Missing runtime launcher wrapper: ${RUNTIME_RUN}")
fi

if [[ ! -L "${REPO_USER_DIR}" ]]; then
  failures+=("Repo user path is not a compatibility symlink: ${REPO_USER_DIR}")
else
  repo_user_real="$(readlink -f "${REPO_USER_DIR}")"
  runtime_user_real="$(readlink -f "${RUNTIME_USER_DIR}")"
  if [[ "${repo_user_real}" != "${runtime_user_real}" ]]; then
    failures+=("Repo user symlink does not point at runtime user: ${REPO_USER_DIR} -> ${repo_user_real}")
  fi
fi

if [[ ! -f "${RUNTIME_DB}" ]]; then
  failures+=("Missing runtime database: ${RUNTIME_DB}")
elif [[ ! -s "${RUNTIME_DB}" ]]; then
  failures+=("Runtime database is empty: ${RUNTIME_DB}")
fi

if (( ${#failures[@]} > 0 )); then
  echo "Runtime layout check failed." >&2
  for failure in "${failures[@]}"; do
    echo " - ${failure}" >&2
  done
  echo "Run ./.fork/install-runtime-entrypoints.sh to refresh the runtime-side shims." >&2
  echo "Run ./.fork/reconcile-runtime-state.sh --apply to repair the runtime bridge." >&2
  exit 1
fi

echo "Runtime layout looks healthy."
echo "Runtime root: ${RUNTIME_DIR}"
echo "Runtime database: ${RUNTIME_DB}"
