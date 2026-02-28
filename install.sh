#!/usr/bin/env bash
# install.sh — 白蚁协议一键安装/升级脚本
# Termite Protocol one-click install/upgrade script
#
# Usage:
#   bash install.sh [OPTIONS] [TARGET_DIR]
#   curl -fsSL <url>/install.sh | bash -s -- [OPTIONS] [TARGET_DIR]
#
# Options:
#   --upgrade   只更新协议核心文件，不动入口文件 / Update protocol files only, skip entry files
#   --force     覆盖所有文件，不创建备份 / Overwrite all files without backup
#   --help      显示帮助 / Show help

set -euo pipefail

# ---------- Constants ----------

VERSION="1.0.0"

# GitHub raw base URL — replace with your fork's URL, or set TERMITE_REPO_URL env var
GITHUB_RAW_BASE="${TERMITE_REPO_URL:-https://raw.githubusercontent.com/__GITHUB_RAW_BASE__/main/templates}"

# Protocol core files (updated during --upgrade)
PROTOCOL_FILES=(
  TERMITE_PROTOCOL.md
  TERMITE_SEED.md
  signals/README.md
)

# Scripts (updated during --upgrade)
PROTOCOL_SCRIPTS=(
  scripts/field-lib.sh
  scripts/field-arrive.sh
  scripts/field-claim.sh
  scripts/field-cycle.sh
  scripts/field-decay.sh
  scripts/field-deposit.sh
  scripts/field-drain.sh
  scripts/field-export-audit.sh
  scripts/field-pulse.sh
)

# Git hooks (updated during --upgrade)
HOOK_FILES=(
  scripts/hooks/install.sh
  scripts/hooks/pre-commit
  scripts/hooks/pre-push
  scripts/hooks/prepare-commit-msg
  scripts/hooks/post-commit
)

# Entry files (skipped during --upgrade)
ENTRY_FILES=(
  CLAUDE.md
  AGENTS.md
)

# Signal directories to create
SIGNAL_DIRS=(
  signals/active
  signals/observations
  signals/rules
  signals/claims
  signals/archive
)

# .gitignore rules for termite runtime files
GITIGNORE_MARKER="# Termite Protocol — ephemeral runtime files"
GITIGNORE_RULES=".birth
.field-breath
.pheromone"

# ---------- Helper Functions ----------

log()  { echo "[termite:install] $*"; }
warn() { echo "[termite:install] WARNING: $*" >&2; }
err()  { echo "[termite:install] ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'HELP'
白蚁协议安装脚本 / Termite Protocol Installer

Usage:
  bash install.sh [OPTIONS] [TARGET_DIR]
  curl -fsSL <url>/install.sh | bash -s -- [OPTIONS] [TARGET_DIR]

Options:
  --upgrade   只更新协议核心文件，不动入口文件（CLAUDE.md / AGENTS.md）
              Update protocol core files only, skip entry files
  --force     覆盖所有文件，不创建备份
              Overwrite without creating .backup files
  --help      显示此帮助 / Show this help

TARGET_DIR defaults to the current working directory ($PWD).

Modes:
  Local:  When run from a clone of the 白蚁协议 repo (templates/ detected)
  Remote: Downloads templates from GitHub when templates/ is not found
HELP
  exit 0
}

# Copy a single file from source to target, with backup logic
# Args: $1=relative_path $2=source_base $3=target_base
copy_file() {
  local rel="$1" src_base="$2" dst_base="$3"
  local src="${src_base}/${rel}"
  local dst="${dst_base}/${rel}"

  if [ ! -f "$src" ]; then
    warn "Source not found, skipping: ${rel}"
    skipped=$((skipped + 1))
    return
  fi

  # Create parent directory
  mkdir -p "$(dirname "$dst")"

  # Backup existing file if needed
  if [ -f "$dst" ] && [ "$FORCE" = false ]; then
    cp "$dst" "${dst}.backup"
    backed_up=$((backed_up + 1))
    log "Backed up: ${rel} -> ${rel}.backup"
  fi

  cp "$src" "$dst"
  copied=$((copied + 1))

  # Make scripts executable
  case "$rel" in
    scripts/*.sh|scripts/hooks/*)
      chmod +x "$dst"
      ;;
  esac
}

# Download a single file from GitHub raw URL to target
# Args: $1=relative_path $2=target_base
download_file() {
  local rel="$1" dst_base="$2"
  local url="${GITHUB_RAW_BASE}/${rel}"
  local dst="${dst_base}/${rel}"

  mkdir -p "$(dirname "$dst")"

  # Backup existing file if needed
  if [ -f "$dst" ] && [ "$FORCE" = false ]; then
    cp "$dst" "${dst}.backup"
    backed_up=$((backed_up + 1))
    log "Backed up: ${rel} -> ${rel}.backup"
  fi

  if curl -fsSL "$url" -o "$dst" 2>/dev/null; then
    copied=$((copied + 1))
    case "$rel" in
      scripts/*.sh|scripts/hooks/*)
        chmod +x "$dst"
        ;;
    esac
  else
    warn "Failed to download: ${url}"
    skipped=$((skipped + 1))
  fi
}

# ---------- Parse Arguments ----------

UPGRADE=false
FORCE=false
TARGET_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --upgrade) UPGRADE=true; shift ;;
    --force)   FORCE=true; shift ;;
    --help|-h) usage ;;
    -*)        err "Unknown option: $1 (use --help for usage)" ;;
    *)         TARGET_DIR="$1"; shift ;;
  esac
done

TARGET_DIR="${TARGET_DIR:-$PWD}"
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || err "Target directory not found: ${TARGET_DIR}"

# ---------- Detect Source Mode ----------

SCRIPT_DIR=""
SOURCE_MODE=""
TEMPLATE_DIR=""
TEMP_DIR=""

# Try to find script's own directory (won't work in pipe mode)
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -d "${SCRIPT_DIR}/templates" ]; then
  SOURCE_MODE="local"
  TEMPLATE_DIR="${SCRIPT_DIR}/templates"
  log "Source: local (${TEMPLATE_DIR})"
else
  SOURCE_MODE="remote"
  log "Source: remote (${GITHUB_RAW_BASE})"
  if echo "$GITHUB_RAW_BASE" | grep -q '__GITHUB_RAW_BASE__'; then
    err "Remote mode requires a valid GitHub URL.
Set TERMITE_REPO_URL environment variable, e.g.:
  TERMITE_REPO_URL=https://raw.githubusercontent.com/user/repo/main/templates bash install.sh
Or replace __GITHUB_RAW_BASE__ in the script with your repository path."
  fi
fi

# ---------- Pre-flight Checks ----------

if [ ! -d "$TARGET_DIR" ]; then
  err "Target directory does not exist: ${TARGET_DIR}"
fi

if [ ! -d "${TARGET_DIR}/.git" ]; then
  warn "Target is not a git repository. Git hooks will not be installed."
fi

# Prevent installing into the protocol source repo itself
if [ "$SOURCE_MODE" = "local" ] && [ "$TARGET_DIR" = "$SCRIPT_DIR" ]; then
  err "Cannot install into the protocol source repository itself.
Please specify a different target directory."
fi

# ---------- Install ----------

log "Mode: $([ "$UPGRADE" = true ] && echo 'upgrade' || echo 'install')"
log "Target: ${TARGET_DIR}"
[ "$FORCE" = true ] && log "Force mode: backups disabled"
echo ""

copied=0
skipped=0
backed_up=0

# Function to process a single file
process_file() {
  local rel="$1"
  if [ "$SOURCE_MODE" = "local" ]; then
    copy_file "$rel" "$TEMPLATE_DIR" "$TARGET_DIR"
  else
    download_file "$rel" "$TARGET_DIR"
  fi
}

# Always install protocol core files
for f in "${PROTOCOL_FILES[@]}"; do process_file "$f"; done
for f in "${PROTOCOL_SCRIPTS[@]}"; do process_file "$f"; done
for f in "${HOOK_FILES[@]}"; do process_file "$f"; done

# Install entry files only on fresh install (not --upgrade)
if [ "$UPGRADE" = true ]; then
  log "Upgrade mode: skipping entry files (CLAUDE.md, AGENTS.md)"
else
  for f in "${ENTRY_FILES[@]}"; do process_file "$f"; done
fi

# ---------- Create Signal Directories ----------

for dir in "${SIGNAL_DIRS[@]}"; do
  target="${TARGET_DIR}/${dir}"
  if [ ! -d "$target" ]; then
    mkdir -p "$target"
    log "Created: ${dir}/"
  fi
done

# ---------- Install Git Hooks ----------

if [ -d "${TARGET_DIR}/.git" ]; then
  GIT_HOOKS_DIR="${TARGET_DIR}/.git/hooks"
  mkdir -p "$GIT_HOOKS_DIR"

  HOOKS="pre-commit pre-push prepare-commit-msg post-commit"
  hooks_installed=0

  for hook in $HOOKS; do
    src="${TARGET_DIR}/scripts/hooks/${hook}"
    dst="${GIT_HOOKS_DIR}/${hook}"

    if [ ! -f "$src" ]; then
      continue
    fi

    # Back up existing non-termite hook
    if [ -f "$dst" ] && ! grep -q 'termite' "$dst" 2>/dev/null; then
      if [ "$FORCE" = false ]; then
        cp "$dst" "${dst}.backup"
        log "Backed up existing hook: ${hook} -> ${hook}.backup"
      fi
    fi

    cp "$src" "$dst"
    chmod +x "$dst"
    hooks_installed=$((hooks_installed + 1))
  done

  log "Git hooks installed: ${hooks_installed}"
fi

# ---------- Update .gitignore ----------

GITIGNORE="${TARGET_DIR}/.gitignore"

if [ -f "$GITIGNORE" ]; then
  if ! grep -qF "$GITIGNORE_MARKER" "$GITIGNORE" 2>/dev/null; then
    printf '\n%s\n%s\n' "$GITIGNORE_MARKER" "$GITIGNORE_RULES" >> "$GITIGNORE"
    log "Updated .gitignore with termite runtime rules"
  else
    log ".gitignore already contains termite rules, skipping"
  fi
else
  printf '%s\n%s\n' "$GITIGNORE_MARKER" "$GITIGNORE_RULES" > "$GITIGNORE"
  log "Created .gitignore with termite runtime rules"
fi

# ---------- Cleanup ----------

if [ -n "${TEMP_DIR:-}" ] && [ -d "${TEMP_DIR:-}" ]; then
  rm -rf "$TEMP_DIR"
fi

# ---------- Summary ----------

echo ""
echo "========================================"
if [ "$UPGRADE" = true ]; then
  log "Upgrade complete!"
else
  log "Installation complete!"
fi
echo "========================================"
log "Files copied:    ${copied}"
log "Files backed up: ${backed_up}"
log "Files skipped:   ${skipped}"
log "Target:          ${TARGET_DIR}"
echo ""

if [ "$UPGRADE" = false ]; then
  log "Next steps:"
  log "  1. Edit CLAUDE.md / AGENTS.md — fill in project info"
  log "  2. Run: cd ${TARGET_DIR} && ./scripts/field-arrive.sh"
  log "  3. Start working with your AI agent!"
fi
