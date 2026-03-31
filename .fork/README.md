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
uv run python main.py --base-directory "$COMFYUI_RUNTIME_DIR"
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

- Python version pin: `.python-version`
- Sync the environment with `uv sync --locked`
- Launch with `./.fork/run-comfyui.sh`

## Git Remotes

Expected remote layout after fork creation:

- `origin` -> your GitHub fork
- `upstream` -> `https://github.com/comfy-org/ComfyUI.git`

## Upgrade Workflow

Use a short-lived branch for each upstream stable release:

```bash
git fetch upstream --tags
git checkout master
git pull --ff-only origin master
git checkout -b upgrade/v0.18.3
git merge --no-ff v0.18.3
```

Resolve conflicts by keeping upstream behavior in upstream-owned files and preserving
only the fork-owned bridge files under `.fork/` plus any intentional UV-specific
changes that are still required.

## Custom Node Inventory

Current top-level custom node inventory is captured in
[`custom_nodes.tsv`](./custom_nodes.tsv).
