#!/usr/bin/env bash
# install.sh — 白蚁协议一键安装/升级脚本
# Termite Protocol one-click install/upgrade script
#
# Usage:
#   bash install.sh [OPTIONS] [TARGET_DIR]
#   curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | bash -s -- [OPTIONS] [TARGET_DIR]
#
# Options:
#   --upgrade   只更新协议核心文件，不动入口文件 / Update protocol files only, skip entry files
#   --force     覆盖所有文件，不创建备份 / Overwrite all files without backup
#   --help      显示帮助 / Show help

set -euo pipefail

# ---------- Constants ----------

VERSION="1.1.1"

# GitHub raw base URL — replace with your fork's URL, or set TERMITE_REPO_URL env var
GITHUB_RAW_BASE="${TERMITE_REPO_URL:-https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/templates}"

# Protocol core files (updated during --upgrade)
PROTOCOL_FILES=(
  TERMITE_PROTOCOL.md
  TERMITE_SEED.md
  UPGRADE_NOTES.md
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
  scripts/field-decompose.sh
  scripts/field-drain.sh
  scripts/field-export-audit.sh
  scripts/field-genesis.sh
  scripts/field-migrate.sh
  scripts/field-pulse.sh
  scripts/termite-db-schema.sql
  scripts/termite-db.sh
  scripts/termite-db-migrate.sh
  scripts/termite-db-export.sh
  scripts/termite-db-reimport.sh
  scripts/field-submit-audit.sh
)

# Git hooks (updated during --upgrade)
HOOK_FILES=(
  scripts/hooks/install.sh
  scripts/hooks/pre-commit
  scripts/hooks/pre-push
  scripts/hooks/prepare-commit-msg
  scripts/hooks/post-commit
)

# Claude Code plugin files (updated during --upgrade)
CLAUDE_PLUGIN_FILES=(
  claude-plugin/plugin.json
  claude-plugin/hooks/hooks.json
  claude-plugin/scripts/termite-hook-lib.sh
  claude-plugin/scripts/hook-session-start.sh
  claude-plugin/scripts/hook-post-edit.sh
  claude-plugin/scripts/hook-stop.sh
  claude-plugin/scripts/hook-pre-compact.sh
  claude-plugin/scripts/hook-user-prompt.sh
  claude-plugin/scripts/hook-pre-bash.sh
  claude-plugin/scripts/hook-post-commit.sh
)

# Entry files (skipped during --upgrade)
ENTRY_FILES=(
  CLAUDE.md
  AGENTS.md
  .termite-telemetry.yaml
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
.birth.*
.field-breath
.pheromone
.commander.events.log
.commander.events.log.1
.commander.log
.termite.db
.termite.db-wal
.termite.db-shm
.termite-upstream-check
.termite-upgrade-report
audit-package-*"

# ---------- Helper Functions ----------

log()  { echo "[termite:install] $*"; }
warn() { echo "[termite:install] WARNING: $*" >&2; }
err()  { echo "[termite:install] ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'HELP'
白蚁协议安装脚本 / Termite Protocol Installer

Usage:
  bash install.sh [OPTIONS] [TARGET_DIR]
  curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | bash -s -- [OPTIONS] [TARGET_DIR]

Options:
  --upgrade   只更新协议核心文件，不动入口文件（CLAUDE.md / AGENTS.md）
              Update protocol core files only, skip entry files
  --force     覆盖所有文件，不创建备份
              Overwrite without creating .backup files
  --help      显示此帮助 / Show this help

TARGET_DIR defaults to the current working directory ($PWD).

Modes:
  Local:  When run from a clone of the protocol source repo (templates/ detected)
  Remote: Downloads protocol templates from GitHub when templates/ is not found
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

# ---------- Install Claude Code Plugin ----------

CLAUDE_PLUGIN_TARGET="${TARGET_DIR}/.claude/plugins/termite-protocol"

install_claude_plugin() {
  mkdir -p "$CLAUDE_PLUGIN_TARGET/hooks" "$CLAUDE_PLUGIN_TARGET/scripts"
  local plugin_copied=0

  for f in "${CLAUDE_PLUGIN_FILES[@]}"; do
    local rel="${f#claude-plugin/}"
    local dst="${CLAUDE_PLUGIN_TARGET}/${rel}"

    if [ "$SOURCE_MODE" = "local" ]; then
      local src="${TEMPLATE_DIR}/${f}"
      if [ ! -f "$src" ]; then
        warn "Claude plugin source not found: ${f}"
        continue
      fi
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    else
      local url="${GITHUB_RAW_BASE}/${f}"
      mkdir -p "$(dirname "$dst")"
      if ! curl -fsSL "$url" -o "$dst" 2>/dev/null; then
        warn "Failed to download: ${f}"
        continue
      fi
    fi

    case "$rel" in
      scripts/*.sh) chmod +x "$dst" ;;
    esac
    plugin_copied=$((plugin_copied + 1))
  done

  if [ "$plugin_copied" -gt 0 ]; then
    log "Claude Code plugin installed: ${CLAUDE_PLUGIN_TARGET} (${plugin_copied} files)"
  fi
}

install_claude_plugin

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

# ---------- Upgrade Summary ----------

# Extract version from TERMITE_PROTOCOL.md first line: <!-- termite-protocol:vX.Y -->
extract_version() {
  local file="$1"
  [ -f "$file" ] || { echo "unknown"; return; }
  head -1 "$file" 2>/dev/null \
    | sed -n 's/.*termite-protocol:\(v[0-9.]*\).*/\1/p' || echo "unknown"
}

if [ "$UPGRADE" = true ]; then
  NEW_VER=$(extract_version "${TARGET_DIR}/TERMITE_PROTOCOL.md")
  OLD_VER="unknown"

  # Try to read old version from backup
  if [ -f "${TARGET_DIR}/TERMITE_PROTOCOL.md.backup" ]; then
    OLD_VER=$(extract_version "${TARGET_DIR}/TERMITE_PROTOCOL.md.backup")
  fi

  UPGRADE_NOTES="${TARGET_DIR}/UPGRADE_NOTES.md"
  UPGRADE_REPORT="${TARGET_DIR}/.termite-upgrade-report"

  if [ -f "$UPGRADE_NOTES" ] && [ "$OLD_VER" != "unknown" ] && [ "$NEW_VER" != "unknown" ] && [ "$OLD_VER" != "$NEW_VER" ]; then
    echo ""
    echo "========================================"
    log "What changed: ${OLD_VER} → ${NEW_VER}"
    echo "========================================"

    # Extract sections between old and new version from UPGRADE_NOTES.md
    # Print all ## vX.Y sections where version > OLD_VER and version <= NEW_VER
    in_range=false
    while IFS= read -r line; do
      if echo "$line" | grep -qE '^## v[0-9]+\.[0-9]'; then
        section_ver=$(echo "$line" | sed 's/^## \(v[0-9.]*\).*/\1/')
        if [ "$section_ver" = "$OLD_VER" ]; then
          in_range=false
        else
          in_range=true
        fi
      fi
      if $in_range; then
        echo "  $line"
      fi
    done < "$UPGRADE_NOTES"

    echo ""

    # Write upgrade report for next agent's field-arrive.sh
    cat > "$UPGRADE_REPORT" <<REOF
upgraded_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
from_version: ${OLD_VER}
to_version: ${NEW_VER}
summary: "See UPGRADE_NOTES.md for full details. Check Action Required sections."
REOF
    log "Upgrade report written to .termite-upgrade-report"
  fi
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
  log "  4. Claude Code plugin installed at .claude/plugins/termite-protocol/"
fi

if [ "$UPGRADE" = true ]; then
  log "Next steps:"
  log "  1. Read UPGRADE_NOTES.md for detailed changes and action items"
  log "  2. Check .termite-upgrade-report for upgrade context"
  log "  3. Run: cd ${TARGET_DIR} && ./scripts/field-arrive.sh"
fi

# ── Migration Hint ───────────────────────────────────────────────────
if [ "$UPGRADE" = true ] && [ -d "${TARGET_DIR}/signals/observations" ]; then
  has_old_signals=false
  for f in "${TARGET_DIR}/signals/observations"/*.yaml; do
    [ -f "$f" ] || continue
    if ! grep -q "^quality_score:" "$f" 2>/dev/null; then
      has_old_signals=true
      break
    fi
  done
  if [ "$has_old_signals" = true ]; then
    echo ""
    log "[MIGRATE] Pre-v5.0 signals detected. Preview migration:"
    log "  cd ${TARGET_DIR} && ./scripts/field-migrate.sh"
    log "Then apply:  ./scripts/field-migrate.sh --apply"
  fi
fi
