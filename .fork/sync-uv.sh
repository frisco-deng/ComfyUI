#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

echo "[1/5] Checking runtime layout"
"${SCRIPT_DIR}/check-runtime-layout.sh"

echo "[2/5] Checking upstream requirements parity"
"${SCRIPT_DIR}/check-upstream-deps.sh"

echo "[3/5] Refreshing uv.lock from pyproject.toml"
uv lock

echo "[4/5] Syncing the UV environment from uv.lock"
echo "This can take a while if native CUDA extensions need to build."
uv sync --locked

echo "[5/5] Smoke testing the ComfyUI launcher"
"${REPO_DIR}/run-comfyui.sh" --help >/dev/null

echo "UV environment is aligned with pyproject.toml and the launcher smoke test passed."
