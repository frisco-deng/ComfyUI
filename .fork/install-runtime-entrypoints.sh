#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_RUNTIME_DIR="$(cd "${REPO_DIR}/.." && pwd)/ComfyUI-runtime"
RUNTIME_DIR="${COMFYUI_RUNTIME_DIR:-${DEFAULT_RUNTIME_DIR}}"
RUNTIME_USER_DIR="${RUNTIME_DIR}/user"
RUNTIME_MAIN="${RUNTIME_DIR}/main.py"
RUNTIME_RUN="${RUNTIME_DIR}/run-comfyui.sh"

mkdir -p \
  "${RUNTIME_DIR}" \
  "${RUNTIME_DIR}/custom_nodes" \
  "${RUNTIME_DIR}/input" \
  "${RUNTIME_DIR}/models" \
  "${RUNTIME_DIR}/output" \
  "${RUNTIME_DIR}/temp" \
  "${RUNTIME_USER_DIR}/default/workflows"

cat > "${RUNTIME_MAIN}" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations

import os
import pathlib
import shutil
import sys


def main() -> int:
    runtime_dir = pathlib.Path(__file__).resolve().parent
    repo_dir = pathlib.Path(os.environ.get("COMFYUI_REPO_DIR", runtime_dir.parent / "ComfyUI")).resolve()
    repo_main = repo_dir / "main.py"
    runtime_user_dir = runtime_dir / "user"
    database_url = f"sqlite:///{runtime_user_dir / 'comfyui.db'}"

    if not repo_main.is_file():
        raise SystemExit(f"ComfyUI main.py not found: {repo_main}")

    if shutil.which("uv") is None:
        raise SystemExit("uv is required in PATH to launch ComfyUI from the runtime directory")

    argv = [
        "uv",
        "run",
        "--project",
        str(repo_dir),
        "--no-sync",
        "--group",
        "custom_nodes",
        str(repo_main),
        *sys.argv[1:],
        "--base-directory",
        str(runtime_dir),
        "--user-directory",
        str(runtime_user_dir),
        "--database-url",
        database_url,
    ]
    os.execvp("uv", argv)


if __name__ == "__main__":
    raise SystemExit(main())
PY

cat > "${RUNTIME_RUN}" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec uv run "${SCRIPT_DIR}/main.py" "$@"
SH

chmod +x "${RUNTIME_MAIN}" "${RUNTIME_RUN}"

echo "Installed runtime entrypoints:"
echo " - ${RUNTIME_MAIN}"
echo " - ${RUNTIME_RUN}"
