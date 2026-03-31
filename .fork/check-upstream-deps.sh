#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=(python3)
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=(python)
elif command -v uv >/dev/null 2>&1; then
  PYTHON_BIN=(uv run --no-sync python)
else
  echo "Python is required to compare requirements.txt and pyproject.toml." >&2
  exit 1
fi

"${PYTHON_BIN[@]}" - <<'PY'
from __future__ import annotations

import pathlib
import re
import sys
import tomllib


def canonicalize(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def extract_name(spec: str) -> str:
    cleaned = spec.split(";", 1)[0].strip()
    match = re.match(r"([A-Za-z0-9_.-]+)", cleaned)
    if not match:
        raise ValueError(f"Unable to parse dependency name from: {spec!r}")
    return match.group(1)


repo_dir = pathlib.Path.cwd()
requirements_path = repo_dir / "requirements.txt"
pyproject_path = repo_dir / "pyproject.toml"

requirements = []
for raw_line in requirements_path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    requirements.append((line, canonicalize(extract_name(line))))

pyproject = tomllib.loads(pyproject_path.read_text(encoding="utf-8"))
project_dependencies = pyproject.get("project", {}).get("dependencies", [])
pyproject_specs = {}
for spec in project_dependencies:
    name = canonicalize(extract_name(spec))
    pyproject_specs[name] = spec

missing = [line for line, name in requirements if name not in pyproject_specs]
if missing:
    print("requirements.txt has entries that are missing from pyproject.toml:", file=sys.stderr)
    for line in missing:
        print(f" - {line}", file=sys.stderr)
    sys.exit(1)

requirement_names = {name for _, name in requirements}
fork_only = [
    spec
    for name, spec in sorted(pyproject_specs.items())
    if name not in requirement_names
]

print("requirements.txt packages are represented in pyproject.toml.")
if fork_only:
    print("Fork-only pyproject additions:")
    for spec in fork_only:
        print(f" - {spec}")
PY
