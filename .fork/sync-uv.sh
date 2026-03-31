#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

echo "[1/4] Checking upstream requirements parity"
"${SCRIPT_DIR}/check-upstream-deps.sh"

echo "[2/4] Refreshing uv.lock from pyproject.toml"
uv lock

echo "[3/4] Syncing the UV environment from uv.lock"
echo "This can take a while if native CUDA extensions need to build."
uv sync --locked

echo "[4/4] Smoke testing the ComfyUI launcher"
"${SCRIPT_DIR}/run-comfyui.sh" --help >/dev/null

echo "UV environment is aligned with pyproject.toml and the launcher smoke test passed."
