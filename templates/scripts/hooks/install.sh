#!/usr/bin/env bash
# install.sh — One-click git hooks installation for Termite Protocol
# Copies hook scripts to .git/hooks/ and sets permissions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GIT_HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"

# Verify git repo
if [ ! -d "${PROJECT_ROOT}/.git" ]; then
  echo "[termite:install] ERROR: Not a git repository: ${PROJECT_ROOT}"
  exit 1
fi

# Ensure hooks directory exists
mkdir -p "$GIT_HOOKS_DIR"

# Hooks to install
HOOKS="pre-commit pre-push prepare-commit-msg post-commit"

installed=0
skipped=0

for hook in $HOOKS; do
  src="${SCRIPT_DIR}/${hook}"
  dst="${GIT_HOOKS_DIR}/${hook}"

  if [ ! -f "$src" ]; then
    echo "[termite:install] SKIP: ${hook} (source not found)"
    skipped=$((skipped + 1))
    continue
  fi

  # Back up existing hook if it's not ours
  if [ -f "$dst" ] && ! grep -q 'termite' "$dst" 2>/dev/null; then
    echo "[termite:install] Backing up existing ${hook} → ${hook}.backup"
    cp "$dst" "${dst}.backup"
  fi

  cp "$src" "$dst"
  chmod +x "$dst"
  installed=$((installed + 1))
  echo "[termite:install] Installed: ${hook}"
done

echo ""
echo "[termite:install] Done: ${installed} hooks installed, ${skipped} skipped."
echo "[termite:install] Hooks directory: ${GIT_HOOKS_DIR}"
