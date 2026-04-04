#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

resolve_latest_stable_tag() {
  python3 - <<'PY'
from __future__ import annotations

import re
import subprocess
import sys

stable_tags = []
for tag in subprocess.check_output(["git", "tag", "-l", "v*"], text=True).splitlines():
    match = re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)", tag)
    if match:
        stable_tags.append((tuple(int(part) for part in match.groups()), tag))

if not stable_tags:
    sys.exit("No stable upstream tags were found.")

stable_tags.sort()
print(stable_tags[-1][1])
PY
}

TARGET_REF="${1:-}"
BASE_BRANCH="${2:-master}"

if [[ -z "${TARGET_REF}" ]]; then
  echo "Usage: $0 <latest|tag-or-ref> [base-branch]" >&2
  echo "Example: $0 latest" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before upgrading." >&2
  exit 1
fi

echo "[1/7] Fetching origin and upstream refs"
git fetch origin --tags
git fetch upstream --tags

if [[ "${TARGET_REF}" == "latest" ]]; then
  TARGET_REF="$(resolve_latest_stable_tag)"
  echo "Resolved latest stable upstream tag to ${TARGET_REF}"
fi

UPGRADE_BRANCH="upgrade/${TARGET_REF#refs/tags/}"

echo "[2/7] Checking runtime layout"
"${SCRIPT_DIR}/check-runtime-layout.sh"

echo "[3/7] Refreshing managed dependency blocks on the current base"
"${SCRIPT_DIR}/sync-upstream-requirements.py"
"${SCRIPT_DIR}/sync-custom-node-requirements.py"
"${SCRIPT_DIR}/check-upstream-deps.sh"

echo "[4/7] Updating base branch ${BASE_BRANCH}"
git checkout "${BASE_BRANCH}"
git pull --ff-only origin "${BASE_BRANCH}"

if git show-ref --verify --quiet "refs/heads/${UPGRADE_BRANCH}"; then
  echo "Branch ${UPGRADE_BRANCH} already exists locally." >&2
  exit 1
fi

echo "[5/7] Creating upgrade branch ${UPGRADE_BRANCH}"
git checkout -b "${UPGRADE_BRANCH}"

echo "[6/7] Merging ${TARGET_REF}"
if ! git merge --no-ff "${TARGET_REF}"; then
  echo "Merge conflicts detected."
  echo "Resolve them, then run ./sync-uv.sh and push ${UPGRADE_BRANCH}."
  exit 1
fi

echo "[7/7] Refreshing managed dependency blocks and the UV environment"
"${SCRIPT_DIR}/sync-upstream-requirements.py"
"${SCRIPT_DIR}/sync-custom-node-requirements.py"
"${REPO_DIR}/sync-uv.sh"

echo "Upgrade branch ready: ${UPGRADE_BRANCH}"
echo "Push it with: git push -u origin ${UPGRADE_BRANCH}"
