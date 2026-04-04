# Local Fork Notes

This fork keeps Git-managed code in the `ComfyUI` checkout and moves mutable runtime
state into a sibling runtime root. That separation keeps upstream pulls and merges
clean while preserving the current local setup.

## Runtime Layout

- Code checkout: this repository
- Default runtime root: sibling directory `../ComfyUI-runtime`
- Override runtime root: set `COMFYUI_RUNTIME_DIR=/absolute/path`
- Canonical engine command: `uv run --no-sync --group custom_nodes main.py`
- Canonical convenience launcher: `./run-comfyui.sh`

The public launcher delegates to the internal `.fork` script and runs:

```bash
uv run --no-sync --group custom_nodes main.py \
  --base-directory "$COMFYUI_RUNTIME_DIR" \
  --user-directory "$COMFYUI_RUNTIME_DIR/user" \
  --database-url "sqlite:///$COMFYUI_RUNTIME_DIR/user/comfyui.db"
```

This fork keeps the runtime state outside the Git checkout. The repo-side `user/`
path is bridged back to the runtime user directory so the upgraded ComfyUI database
path does not split state again.

With the launcher flags, ComfyUI reads and writes these runtime directories outside
the Git checkout:

- `models/`
- `custom_nodes/`
- `input/`
- `output/`
- `temp/`
- `user/`

## One-Time Migration

Run this once to move the current local runtime directories into the sibling runtime
root and restore tracked placeholder files in the Git checkout:

```bash
./.fork/migrate-runtime-layout.sh
```

If a previous split left repo-side `user/` data behind, repair it with:

```bash
./.fork/reconcile-runtime-state.sh --apply
```

## UV Workflow

- `requirements.txt` remains the upstream pip reference
- `pyproject.toml` and `uv.lock` are the fork's UV source of truth
- `dependency-groups.custom_nodes` captures the installed runtime custom-node import-time deps
- Python version pin: `.python-version`
- Preferred sync command: `./sync-uv.sh`
- Launch with `./run-comfyui.sh`
- The steady-state launch path is `uv run --no-sync --group custom_nodes main.py`

Helper scripts:

- `./.fork/check-runtime-layout.sh` validates the runtime split and the repo-side compatibility bridge
- `./.fork/check-upstream-deps.sh` verifies that upstream `requirements.txt` is still represented in `pyproject.toml`
- `./.fork/sync-upstream-requirements.py` rewrites the upstream-managed core dependency block in `pyproject.toml`
- `./.fork/sync-custom-node-requirements.py` scans installed runtime custom nodes and rewrites `dependency-groups.custom_nodes`
- `./.fork/check-custom-node-imports.py` validates startup-critical imports from the managed `custom_nodes` group
- `./.fork/check-opencv.py` validates that `cv2` is a real OpenCV install, not a namespace stub
- `./.fork/reconcile-runtime-state.sh [--dry-run|--apply]` merges repo-side user drift back into runtime and re-establishes the `user/` bridge
- `./sync-uv.sh` validates the split, syncs both dependency blocks into `pyproject.toml`, refreshes `uv.lock`, syncs the environment, validates imports/OpenCV, and smoke-tests the canonical UV command
- `./upgrade-from-upstream.sh <latest|tag-or-ref>` creates a new upgrade branch from `master`, merges the requested upstream stable tag/ref, and runs the UV refresh

## Git Remotes

Expected remote layout after fork creation:

- `origin` -> your GitHub fork
- `upstream` -> `https://github.com/comfy-org/ComfyUI.git`

## Upgrade Workflow

Use a short-lived branch for each upstream stable release:

```bash
./upgrade-from-upstream.sh latest
```

Resolve conflicts by keeping upstream behavior in upstream-owned files and preserving
only the fork-owned bridge files under `.fork/` plus any intentional UV-specific
changes that are still required.

## Recovery Sequence

If workflows or settings disappear after a split or manual launch:

```bash
./.fork/reconcile-runtime-state.sh --apply
./sync-uv.sh
./run-comfyui.sh
```

That recovery path keeps pip out of the normal workflow. The goal is for ComfyUI-Manager
and currently installed custom nodes to find their import-time packages in the UV
environment before startup, so they do not need to self-install them.

## Custom Node Inventory

Current top-level custom node inventory is captured in
[`custom_nodes.tsv`](./custom_nodes.tsv).
