# Local Fork Notes

This fork keeps Git-managed code in the `ComfyUI` checkout and moves mutable runtime
state into a sibling runtime root. That separation keeps upstream pulls and merges
clean while preserving the current local setup.

## Runtime Layout

- Code checkout: this repository
- Default runtime root: sibling directory `../ComfyUI-runtime`
- Override runtime root: set `COMFYUI_RUNTIME_DIR=/absolute/path`
- Canonical launcher: `./.fork/run-comfyui.sh`

The launcher runs:

```bash
uv run --no-sync python main.py --base-directory "$COMFYUI_RUNTIME_DIR"
```

With `--base-directory`, ComfyUI reads and writes these runtime directories outside
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

## UV Workflow

- `requirements.txt` remains the upstream pip reference
- `pyproject.toml` and `uv.lock` are the fork's UV source of truth
- Python version pin: `.python-version`
- Preferred sync command: `./.fork/sync-uv.sh`
- Launch with `./.fork/run-comfyui.sh`

Helper scripts:

- `./.fork/check-upstream-deps.sh` verifies that upstream `requirements.txt` is still represented in `pyproject.toml`
- `./.fork/sync-uv.sh` refreshes `uv.lock`, syncs the environment, and smoke-tests the launcher
- `./.fork/upgrade-from-upstream.sh <tag-or-ref>` creates a new upgrade branch from `master`, merges the requested upstream tag/ref, and runs the UV refresh

## Git Remotes

Expected remote layout after fork creation:

- `origin` -> your GitHub fork
- `upstream` -> `https://github.com/comfy-org/ComfyUI.git`

## Upgrade Workflow

Use a short-lived branch for each upstream stable release:

```bash
./.fork/upgrade-from-upstream.sh v0.18.3
```

Resolve conflicts by keeping upstream behavior in upstream-owned files and preserving
only the fork-owned bridge files under `.fork/` plus any intentional UV-specific
changes that are still required.

## Custom Node Inventory

Current top-level custom node inventory is captured in
[`custom_nodes.tsv`](./custom_nodes.tsv).
