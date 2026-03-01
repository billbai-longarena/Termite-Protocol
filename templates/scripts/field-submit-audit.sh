#!/usr/bin/env bash
# field-submit-audit.sh — Submit audit package to upstream protocol repo via PR
# Requires: gh CLI authenticated. If unavailable, skips silently.
#
# Usage:
#   ./field-submit-audit.sh           # submit if frequency allows
#   ./field-submit-audit.sh --force   # submit regardless of frequency
#   ./field-submit-audit.sh --dry-run # show what would happen

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

DRY_RUN=false
FORCE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --force)   FORCE=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--force] [--dry-run]"
      echo ""
      echo "Submits audit package to upstream protocol repo via PR."
      echo "Requires .termite-telemetry.yaml enabled+accepted and gh CLI."
      exit 0
      ;;
    *) log_error "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Gate 1: Telemetry check ────────────────────────────────────────

if [ ! -f "$TELEMETRY_FILE" ]; then
  log_info "No .termite-telemetry.yaml — skipping audit submission"
  exit 0
fi

enabled=$(yaml_read "$TELEMETRY_FILE" "enabled")
if [ "$enabled" != "true" ]; then
  exit 0  # Silent exit — not opted in
fi

# ── Gate 2: Disclaimer acceptance ──────────────────────────────────

if telemetry_needs_acceptance; then
  echo ""
  echo "================================================================"
  echo "  Termite Protocol — Cross-Colony Feedback Disclaimer"
  echo "================================================================"
  echo ""
  echo "  You are about to enable cross-colony feedback. This means:"
  echo ""
  echo "  [Y] Audit packages contain ONLY protocol artifacts"
  echo "      (signals, rules, handoff chain, caste distribution)"
  echo "  [Y] No source code, business logic, .env, or secrets"
  echo "  [Y] Submitted as PR to upstream protocol repo for Nurse analysis"
  echo "  [Y] You can disable at any time: enabled: false"
  echo "  [Y] anonymize_project: true hides your project name"
  echo ""
  echo "  This is not telemetry. It is pheromone exchange between colonies."
  echo "  Rule 4: every action leaves a trace."
  echo "  Rule 5: weak signals evaporate."
  echo "  Rule 6: strong signals escalate."
  echo ""
  echo "================================================================"
  echo ""

  if [ -t 0 ]; then
    printf "  Type 'accept' to confirm: "
    read -r response
    if [ "$response" = "accept" ]; then
      yaml_write "$TELEMETRY_FILE" "accepted" "true"
      log_info "Disclaimer accepted. Cross-colony feedback enabled."
    else
      log_info "Disclaimer not accepted. Set enabled: false or try again."
      exit 1
    fi
  else
    log_warn "Non-interactive terminal — cannot show disclaimer. Run manually first."
    exit 1
  fi
fi

# ── Gate 3: Frequency check ────────────────────────────────────────

if ! $FORCE && ! telemetry_should_submit; then
  log_info "Submission not due yet (frequency: $(telemetry_submit_frequency))"
  exit 0
fi

# ── Gate 4: gh CLI check ──────────────────────────────────────────

if ! command -v gh >/dev/null 2>&1; then
  log_warn "gh CLI not found — cannot submit audit. Install: https://cli.github.com"
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  log_warn "gh not authenticated — cannot submit audit. Run: gh auth login"
  exit 0
fi

# ── Step 1: Export audit package ──────────────────────────────────

PROJECT_NAME=$(telemetry_project_name)
UPSTREAM=$(telemetry_upstream_repo)
AUDIT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/termite-audit-XXXXXX")
trap 'rm -rf "$AUDIT_DIR"' EXIT

# Sanitize project name for use in git branch names
SAFE_NAME=$(echo "$PROJECT_NAME" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//;s/-$//')

log_info "=== Audit submission starting ==="
log_info "Project: ${PROJECT_NAME}"
log_info "Upstream: ${UPSTREAM}"

if $DRY_RUN; then
  log_info "[dry-run] Would export audit package to ${AUDIT_DIR}"
  log_info "[dry-run] Would fork ${UPSTREAM} and create PR"
  log_info "[dry-run] Would copy to audit-packages/${PROJECT_NAME}/$(today_iso)/"
  exit 0
fi

"${SCRIPT_DIR}/field-export-audit.sh" --project-name "$PROJECT_NAME" --out "$AUDIT_DIR" 2>&1 \
  | while IFS= read -r l; do log_info "  export: $l"; done
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
  log_error "Audit export failed"
  exit 1
fi

# ── Step 2: Determine workflow (fork vs same-owner) ──────────────

GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [ -z "$GH_USER" ]; then
  log_error "Cannot determine GitHub username"
  exit 1
fi

UPSTREAM_OWNER=$(echo "$UPSTREAM" | cut -d'/' -f1)
SAME_OWNER=false
if [ "$GH_USER" = "$UPSTREAM_OWNER" ]; then
  SAME_OWNER=true
  CLONE_REPO="$UPSTREAM"
  log_info "Same-owner mode: pushing directly to ${UPSTREAM}"
else
  log_info "Ensuring fork of ${UPSTREAM}"
  gh repo fork "$UPSTREAM" --clone=false 2>/dev/null || true
  CLONE_REPO="${GH_USER}/$(basename "$UPSTREAM")"
  log_info "Fork: ${CLONE_REPO}"
fi

# ── Step 3: Clone to temp dir ────────────────────────────────────

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR" "$AUDIT_DIR"' EXIT

log_info "Cloning ${CLONE_REPO} (shallow)"
gh repo clone "$CLONE_REPO" "$TEMP_DIR" -- --depth 1 2>/dev/null || {
  log_error "Cannot clone ${CLONE_REPO}"
  exit 1
}

# ── Step 4: Create audit branch + commit ──────────────────────────

BRANCH_NAME="audit/${SAFE_NAME}/$(today_iso)"
cd "$TEMP_DIR"

if [ "$SAME_OWNER" = false ]; then
  # Fork workflow: sync with upstream first
  git remote add upstream "https://github.com/${UPSTREAM}.git" 2>/dev/null || true
  git fetch upstream main --depth 1 2>/dev/null || true
  git checkout -B "$BRANCH_NAME" upstream/main 2>/dev/null || git checkout -B "$BRANCH_NAME"
else
  # Same-owner: branch from origin/main
  git checkout -B "$BRANCH_NAME" origin/main 2>/dev/null || git checkout -B "$BRANCH_NAME"
fi

# Copy audit package
AUDIT_TARGET="audit-packages/${PROJECT_NAME}/$(today_iso)"
mkdir -p "$AUDIT_TARGET"
cp -R "$AUDIT_DIR"/* "$AUDIT_TARGET/"

git add "audit-packages/"
git commit -m "audit(${PROJECT_NAME}): session $(today_iso)" 2>/dev/null || {
  log_info "No changes to commit — audit package identical to previous"
  exit 0
}

# ── Step 5: Push + PR ─────────────────────────────────────────────

log_info "Pushing to ${CLONE_REPO}:${BRANCH_NAME}"
git push origin "$BRANCH_NAME" --force 2>/dev/null || {
  log_error "Push failed"
  exit 1
}

# PR head reference differs for fork vs same-owner
if [ "$SAME_OWNER" = true ]; then
  PR_HEAD="$BRANCH_NAME"
else
  PR_HEAD="${GH_USER}:${BRANCH_NAME}"
fi

# Check if PR already exists
EXISTING_PR=$(gh pr list --repo "$UPSTREAM" --head "$PR_HEAD" --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -n "$EXISTING_PR" ] && [ "$EXISTING_PR" != "null" ]; then
  log_info "PR #${EXISTING_PR} already exists — updated via force push"
else
  # Read metadata for PR body
  META_FILE="${AUDIT_TARGET}/metadata.yaml"
  proto_ver=$(yaml_read "$META_FILE" "protocol_version" 2>/dev/null || echo "unknown")
  kernel_ver=$(yaml_read "$META_FILE" "kernel_version" 2>/dev/null || echo "unknown")
  run_days=$(yaml_read "$META_FILE" "run_duration_days" 2>/dev/null || echo "0")
  signed=$(yaml_read "$META_FILE" "signed_commits" 2>/dev/null || echo "0")
  total=$(yaml_read "$META_FILE" "total_commits" 2>/dev/null || echo "0")
  sig_ratio=$(yaml_read "$META_FILE" "signature_ratio_last_50" 2>/dev/null || echo "0")
  active_sigs=$(yaml_read "$META_FILE" "active_signals" 2>/dev/null || echo "0")
  rules=$(yaml_read "$META_FILE" "active_rules" 2>/dev/null || echo "0")
  obs=$(yaml_read "$META_FILE" "pending_observations" 2>/dev/null || echo "0")

  gh pr create --repo "$UPSTREAM" --head "$PR_HEAD" \
    --title "audit(${PROJECT_NAME}): $(today_iso)" \
    --body "$(cat <<PREOF
## audit(${PROJECT_NAME}): $(today_iso)

### Summary
- Protocol: ${proto_ver}, Kernel: ${kernel_ver}
- Run duration: ${run_days} days, ${signed}/${total} signed commits (${sig_ratio} ratio)
- ${active_sigs} active signals, ${rules} rules, ${obs} observations

### Contents
Protocol artifacts only. No source code.
See \`audit-packages/${PROJECT_NAME}/$(today_iso)/README.md\` for full contents.

---
Submitted by \`field-submit-audit.sh\` via cross-colony feedback loop.
PREOF
)" 2>/dev/null || log_warn "PR creation failed — push succeeded, create PR manually"
fi

cd "$PROJECT_ROOT"

# ── Step 6: Record submission ─────────────────────────────────────

yaml_write "$TELEMETRY_FILE" "last_submitted" "$(today_iso)"
log_info "=== Audit submitted successfully ==="
