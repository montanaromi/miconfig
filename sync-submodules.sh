#!/usr/bin/env bash
# sync-submodules.sh
# Temporarily rewrites .gitmodules to use SSH URLs, syncs all submodules,
# then restores the original HTTPS URLs.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
GITMODULES="$REPO_ROOT/.gitmodules"
BACKUP="$GITMODULES.bak"

cleanup() {
  if [[ -f "$BACKUP" ]]; then
    echo "Restoring original .gitmodules..."
    mv "$BACKUP" "$GITMODULES"
    git -C "$REPO_ROOT" submodule sync --quiet
    echo "Restored."
  fi
}

trap cleanup EXIT INT TERM

echo "Backing up .gitmodules..."
cp "$GITMODULES" "$BACKUP"

echo "Rewriting URLs: https://github.com/ → git@github.com:..."
sed -i 's|url = https://github.com/|url = git@github.com:|g' "$GITMODULES"

echo "Running git submodule sync..."
git -C "$REPO_ROOT" submodule sync --recursive

echo "Updating submodules (remote tracking, parallel)..."
git -C "$REPO_ROOT" submodule update \
  --init \
  --recursive \
  --remote \
  --merge \
  --jobs "$(nproc 2>/dev/null || echo 4)"

echo "All submodules synced successfully."
# cleanup() runs automatically on EXIT and restores .gitmodules
