#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_RUNTIME_DIR="$(cd "${REPO_DIR}/.." && pwd)/ComfyUI-runtime"
RUNTIME_DIR="${COMFYUI_RUNTIME_DIR:-${DEFAULT_RUNTIME_DIR}}"
MODE="${1:---dry-run}"

case "${MODE}" in
  --dry-run|--apply)
    ;;
  *)
    echo "Usage: $0 [--dry-run|--apply]" >&2
    exit 1
    ;;
esac

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=(python3)
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN=(python)
elif command -v uv >/dev/null 2>&1; then
  PYTHON_BIN=(uv run --no-sync python)
else
  echo "Python is required to reconcile runtime state." >&2
  exit 1
fi

export REPO_DIR
export RUNTIME_DIR
export MODE

"${PYTHON_BIN[@]}" - <<'PY'
from __future__ import annotations

import json
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path


REPO_DIR = Path(os.environ["REPO_DIR"]).resolve()
RUNTIME_DIR = Path(os.environ["RUNTIME_DIR"]).resolve()
MODE = os.environ["MODE"]
APPLY = MODE == "--apply"
TIMESTAMP = datetime.now().strftime("%Y%m%d-%H%M%S")
RECOVERY_DIR = RUNTIME_DIR / "recovery" / f"reconcile-{TIMESTAMP}"
REPO_USER_DIR = REPO_DIR / "user"
RUNTIME_USER_DIR = RUNTIME_DIR / "user"
REPO_WORKFLOWS_DIR = REPO_USER_DIR / "default" / "workflows"
RUNTIME_WORKFLOWS_DIR = RUNTIME_USER_DIR / "default" / "workflows"


def log(message: str) -> None:
    print(message)


def relative_to_repo(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_DIR))
    except ValueError:
        return str(path)


def relative_to_runtime(path: Path) -> str:
    try:
        return str(path.relative_to(RUNTIME_DIR))
    except ValueError:
        return str(path)


def ensure_dir(path: Path) -> None:
    if APPLY:
        path.mkdir(parents=True, exist_ok=True)


def copy_path(src: Path, dst: Path) -> None:
    if src.is_symlink():
        dst.symlink_to(os.readlink(src))
    elif src.is_dir():
        shutil.copytree(src, dst)
    else:
        shutil.copy2(src, dst)


def backup_path(src: Path, dst: Path) -> None:
    if not src.exists() and not src.is_symlink():
        return
    log(f"Backing up {src} -> {dst}")
    if APPLY:
        ensure_dir(dst.parent)
        if dst.exists() or dst.is_symlink():
            if dst.is_dir() and not dst.is_symlink():
                shutil.rmtree(dst)
            else:
                dst.unlink()
        copy_path(src, dst)


def write_json(path: Path, payload: dict[str, object]) -> None:
    rendered = json.dumps(payload, indent=4, sort_keys=True) + "\n"
    if APPLY:
        ensure_dir(path.parent)
        path.write_text(rendered, encoding="utf-8")


def load_json(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return data


def file_bytes(path: Path) -> bytes:
    return path.read_bytes()


def repo_user_is_bridged() -> bool:
    if not REPO_USER_DIR.is_symlink():
        return False
    try:
        return REPO_USER_DIR.resolve() == RUNTIME_USER_DIR.resolve()
    except FileNotFoundError:
        return False


ensure_dir(RUNTIME_DIR)
for name in ("custom_nodes", "input", "models", "output", "temp", "user"):
    ensure_dir(RUNTIME_DIR / name)
ensure_dir(RUNTIME_WORKFLOWS_DIR)

log(f"Mode: {'apply' if APPLY else 'dry-run'}")
log(f"Repo root: {REPO_DIR}")
log(f"Runtime root: {RUNTIME_DIR}")
log(f"Recovery backup dir: {RECOVERY_DIR}")

bridged = repo_user_is_bridged()

if not bridged and REPO_WORKFLOWS_DIR.is_dir():
    for src in sorted(path for path in REPO_WORKFLOWS_DIR.rglob("*") if path.is_file()):
        rel = src.relative_to(REPO_WORKFLOWS_DIR)
        dst = RUNTIME_WORKFLOWS_DIR / rel
        ensure_dir(dst.parent)
        if not dst.exists():
            log(f"Copying workflow into runtime: {relative_to_repo(src)} -> {relative_to_runtime(dst)}")
            if APPLY:
                shutil.copy2(src, dst)
            continue

        if file_bytes(src) == file_bytes(dst):
            log(f"Workflow already present in runtime: {relative_to_runtime(dst)}")
            continue

        conflict_dst = RECOVERY_DIR / "workflow_conflicts" / rel
        backup_path(src, conflict_dst)
        log(f"Keeping runtime workflow on name conflict: {relative_to_runtime(dst)}")

repo_settings = REPO_USER_DIR / "default" / "comfy.settings.json"
runtime_settings = RUNTIME_USER_DIR / "default" / "comfy.settings.json"
if not bridged and (repo_settings.exists() or runtime_settings.exists()):
    repo_payload = load_json(repo_settings)
    runtime_payload = load_json(runtime_settings)
    merged_payload = dict(repo_payload)
    merged_payload.update(runtime_payload)
    if merged_payload != runtime_payload:
        backup_path(runtime_settings, RECOVERY_DIR / "runtime-user" / "default" / "comfy.settings.json")
        backup_path(repo_settings, RECOVERY_DIR / "repo-user" / "default" / "comfy.settings.json")
        log("Merging repo settings into runtime settings with runtime values winning conflicts.")
        write_json(runtime_settings, merged_payload)

repo_users = REPO_USER_DIR / "users.json"
runtime_users = RUNTIME_USER_DIR / "users.json"
if not bridged and (repo_users.exists() or runtime_users.exists()):
    repo_payload = load_json(repo_users)
    runtime_payload = load_json(runtime_users)
    merged_payload = dict(runtime_payload)
    changed = False
    for key, value in repo_payload.items():
        if key not in merged_payload:
            merged_payload[key] = value
            changed = True
    if changed:
        backup_path(runtime_users, RECOVERY_DIR / "runtime-user" / "users.json")
        backup_path(repo_users, RECOVERY_DIR / "repo-user" / "users.json")
        log("Merging missing repo users into runtime users.json.")
        write_json(runtime_users, merged_payload)

repo_db = REPO_USER_DIR / "comfyui.db"
runtime_db = RUNTIME_USER_DIR / "comfyui.db"
repo_db_size = repo_db.stat().st_size if repo_db.exists() else 0
runtime_db_size = runtime_db.stat().st_size if runtime_db.exists() else 0

if not bridged and (repo_db.exists() or runtime_db.exists()):
    backup_path(repo_db, RECOVERY_DIR / "repo-user" / "comfyui.db")
    backup_path(runtime_db, RECOVERY_DIR / "runtime-user" / "comfyui.db")
    repo_lock = REPO_USER_DIR / "comfyui.db.lock"
    runtime_lock = RUNTIME_USER_DIR / "comfyui.db.lock"
    backup_path(repo_lock, RECOVERY_DIR / "repo-user" / "comfyui.db.lock")
    backup_path(runtime_lock, RECOVERY_DIR / "runtime-user" / "comfyui.db.lock")

    if runtime_db_size == 0 and repo_db_size > 0:
        log("Promoting repo database into runtime because the runtime database is empty.")
        if APPLY:
            ensure_dir(runtime_db.parent)
            shutil.copy2(repo_db, runtime_db)
    elif runtime_db_size > 0 and repo_db_size > 0:
        log("Keeping runtime database as canonical and preserving both originals in recovery.")
    elif runtime_db_size == 0 and repo_db_size == 0:
        log("Both repo and runtime databases are empty.")

if bridged:
    log("Repo user path already points at the runtime user directory.")
else:
    if REPO_USER_DIR.exists() or REPO_USER_DIR.is_symlink():
        backup_path(REPO_USER_DIR, RECOVERY_DIR / "repo-user-before-bridge")
        log(f"Replacing {REPO_USER_DIR} with a symlink to {RUNTIME_USER_DIR}")
        if APPLY:
            if REPO_USER_DIR.is_symlink() or REPO_USER_DIR.is_file():
                REPO_USER_DIR.unlink()
            elif REPO_USER_DIR.is_dir():
                shutil.rmtree(REPO_USER_DIR)
            REPO_USER_DIR.symlink_to(RUNTIME_USER_DIR)
    else:
        log(f"Creating repo user bridge: {REPO_USER_DIR} -> {RUNTIME_USER_DIR}")
        if APPLY:
            REPO_USER_DIR.symlink_to(RUNTIME_USER_DIR)

if APPLY:
    log("Runtime reconciliation applied.")
else:
    log("Dry run complete. Re-run with --apply to make these changes.")
PY
