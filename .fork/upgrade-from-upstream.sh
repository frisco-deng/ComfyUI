#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

TARGET_REF="${1:-}"
BASE_BRANCH="${2:-master}"

if [[ -z "${TARGET_REF}" ]]; then
  echo "Usage: $0 <tag-or-ref> [base-branch]" >&2
  echo "Example: $0 v0.18.3" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before upgrading." >&2
  exit 1
fi

UPGRADE_BRANCH="upgrade/${TARGET_REF#refs/tags/}"

echo "[1/5] Fetching origin and upstream refs"
git fetch origin
git fetch upstream --tags

echo "[2/5] Updating base branch ${BASE_BRANCH}"
git checkout "${BASE_BRANCH}"
git pull --ff-only origin "${BASE_BRANCH}"

if git show-ref --verify --quiet "refs/heads/${UPGRADE_BRANCH}"; then
  echo "Branch ${UPGRADE_BRANCH} already exists locally." >&2
  exit 1
fi

echo "[3/5] Creating upgrade branch ${UPGRADE_BRANCH}"
git checkout -b "${UPGRADE_BRANCH}"

echo "[4/5] Merging ${TARGET_REF}"
if ! git merge --no-ff "${TARGET_REF}"; then
  echo "Merge conflicts detected."
  echo "Resolve them, then run ${SCRIPT_DIR}/sync-uv.sh and push ${UPGRADE_BRANCH}."
  exit 1
fi

echo "[5/5] Refreshing the UV environment"
"${SCRIPT_DIR}/sync-uv.sh"

echo "Upgrade branch ready: ${UPGRADE_BRANCH}"
echo "Push it with: git push -u origin ${UPGRADE_BRANCH}"
