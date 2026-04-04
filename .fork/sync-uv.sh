#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

echo "[1/8] Checking runtime layout"
"${SCRIPT_DIR}/check-runtime-layout.sh"

echo "[2/8] Syncing upstream requirements into pyproject.toml"
"${SCRIPT_DIR}/sync-upstream-requirements.py"

echo "[3/8] Syncing custom-node requirements into pyproject.toml"
"${SCRIPT_DIR}/sync-custom-node-requirements.py"

echo "[4/8] Checking upstream requirements parity"
"${SCRIPT_DIR}/check-upstream-deps.sh"

echo "[5/8] Refreshing uv.lock from pyproject.toml"
uv lock

echo "[6/8] Syncing the UV environment from uv.lock"
echo "This can take a while if native CUDA extensions need to build."
uv sync --locked --group custom_nodes

echo "[7/8] Verifying import health and repairing OpenCV if needed"
uv run --no-sync --group custom_nodes "${SCRIPT_DIR}/check-custom-node-imports.py"
if ! uv run --no-sync --group custom_nodes "${SCRIPT_DIR}/check-opencv.py"; then
  echo "OpenCV install looks unhealthy. Reinstalling opencv-contrib-python via uv."
  uv sync --locked --group custom_nodes --reinstall-package opencv-contrib-python
  uv run --no-sync --group custom_nodes "${SCRIPT_DIR}/check-opencv.py"
fi

echo "[8/8] Smoke testing the canonical UV launch command"
uv run --no-sync --group custom_nodes "${REPO_DIR}/main.py" --help >/dev/null

echo "UV environment is aligned with pyproject.toml, custom-node imports are healthy, and the canonical UV launch command passed."
