#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_RUNTIME_DIR="$(cd "${REPO_DIR}/.." && pwd)/ComfyUI-runtime"
RUNTIME_DIR="${COMFYUI_RUNTIME_DIR:-${DEFAULT_RUNTIME_DIR}}"

mkdir -p "${RUNTIME_DIR}"

for name in custom_nodes input output user models temp; do
  src="${REPO_DIR}/${name}"
  dst="${RUNTIME_DIR}/${name}"

  if [[ ! -e "${src}" ]]; then
    continue
  fi

  if [[ -e "${dst}" ]]; then
    echo "Refusing to overwrite existing runtime path: ${dst}" >&2
    exit 1
  fi

  mv "${src}" "${dst}"
  echo "Moved ${src} -> ${dst}"
done

git -C "${REPO_DIR}" restore --source=HEAD --staged --worktree -- custom_nodes input output models

mkdir -p "${RUNTIME_DIR}/user"

if [[ -e "${REPO_DIR}/user" || -L "${REPO_DIR}/user" ]]; then
  rm -rf "${REPO_DIR}/user"
fi
ln -s "${RUNTIME_DIR}/user" "${REPO_DIR}/user"

echo "Runtime migration complete."
echo "Launcher: ${REPO_DIR}/run-comfyui.sh"
echo "Runtime root: ${RUNTIME_DIR}"
