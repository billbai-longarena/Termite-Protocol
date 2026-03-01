# Cross-Colony Feedback Loop Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable host projects using the Termite Protocol to submit audit packages to the protocol source repo via PR, detect protocol updates, and support opt-in/opt-out with disclaimer.

**Architecture:** Three new scripts (`field-submit-audit.sh`, telemetry helpers in `field-lib.sh`, version check in `field-arrive.sh`), one config template (`.termite-telemetry.yaml`), and modifications to `install.sh`. All gated behind `.termite-telemetry.yaml` `enabled: true + accepted: true`.

**Tech Stack:** Bash, `gh` CLI, `sqlite3`, `curl` (fallback), YAML (flat key:value via existing `yaml_read`/`yaml_write`)

**Design doc:** `docs/plans/2026-02-28-cross-colony-feedback-loop-design.md`

---

### Task 1: Create `.termite-telemetry.yaml` template

**Files:**
- Create: `templates/.termite-telemetry.yaml`

**Step 1: Write the template file**

```yaml
# Termite Protocol — Cross-Colony Feedback Configuration
# Controls whether this project participates in the protocol optimization loop.
#
# What gets shared: protocol artifacts ONLY (signals, rules, handoff chain,
# caste distribution). No source code, business logic, .env, or secrets.
#
# Set enabled: true and run field-submit-audit.sh to activate.
# Set enabled: false at any time to stop.

enabled: false
accepted: false
upstream_repo: "billbai-longarena/Termite-Protocol"
anonymize_project: false
submit_frequency: "session-end"
last_submitted: ""
```

**Step 2: Verify YAML is parseable by existing `yaml_read`**

Run: `source templates/scripts/field-lib.sh && yaml_read templates/.termite-telemetry.yaml "enabled"`
Expected: `false`

**Step 3: Commit**

```bash
git add templates/.termite-telemetry.yaml
git commit -m "feat(telemetry): add .termite-telemetry.yaml template"
```

---

### Task 2: Add telemetry helper functions to `field-lib.sh`

**Files:**
- Modify: `templates/scripts/field-lib.sh` (append after `yaml_read_list` function, ~line 135)

**Step 1: Write telemetry helper functions**

Add after the `yaml_read_list()` function block:

```bash
# ── Telemetry Configuration ──────────────────────────────────────────

TELEMETRY_FILE="${PROJECT_ROOT}/.termite-telemetry.yaml"
UPSTREAM_CACHE="${PROJECT_ROOT}/.termite-upstream-check"

telemetry_enabled() {
  # Returns 0 if telemetry is fully opted-in (enabled + accepted)
  [ -f "$TELEMETRY_FILE" ] || return 1
  local enabled accepted
  enabled=$(yaml_read "$TELEMETRY_FILE" "enabled")
  accepted=$(yaml_read "$TELEMETRY_FILE" "accepted")
  [ "$enabled" = "true" ] && [ "$accepted" = "true" ]
}

telemetry_needs_acceptance() {
  # Returns 0 if enabled but not yet accepted
  [ -f "$TELEMETRY_FILE" ] || return 1
  local enabled accepted
  enabled=$(yaml_read "$TELEMETRY_FILE" "enabled")
  accepted=$(yaml_read "$TELEMETRY_FILE" "accepted")
  [ "$enabled" = "true" ] && [ "$accepted" != "true" ]
}

telemetry_upstream_repo() {
  yaml_read "$TELEMETRY_FILE" "upstream_repo" 2>/dev/null || echo "billbai-longarena/Termite-Protocol"
}

telemetry_project_name() {
  local name
  name=$(basename "$PROJECT_ROOT")
  local anon
  anon=$(yaml_read "$TELEMETRY_FILE" "anonymize_project" 2>/dev/null || echo "false")
  if [ "$anon" = "true" ]; then
    echo "$name" | shasum -a 256 | cut -c1-8
  else
    echo "$name"
  fi
}

telemetry_submit_frequency() {
  yaml_read "$TELEMETRY_FILE" "submit_frequency" 2>/dev/null || echo "session-end"
}

telemetry_should_submit() {
  # Check if submission is due based on frequency setting
  telemetry_enabled || return 1
  local freq
  freq=$(telemetry_submit_frequency)
  case "$freq" in
    session-end) return 0 ;;
    manual) return 1 ;;
    weekly)
      local last
      last=$(yaml_read "$TELEMETRY_FILE" "last_submitted" 2>/dev/null || echo "")
      [ -z "$last" ] && return 0
      local age
      age=$(days_since "$last")
      [ "$age" -ge 7 ]
      ;;
    *) return 1 ;;
  esac
}

local_protocol_version() {
  # Extract version from TERMITE_PROTOCOL.md
  local proto_file="${PROJECT_ROOT}/TERMITE_PROTOCOL.md"
  [ -f "$proto_file" ] || { echo "unknown"; return; }
  grep -m1 'termite-protocol:v' "$proto_file" 2>/dev/null \
    | sed 's/.*termite-protocol:\(v[0-9.]*\).*/\1/' || echo "unknown"
}

upstream_protocol_version() {
  # Check upstream version with 24h cache
  # Returns version string or "unknown"
  if [ -f "$UPSTREAM_CACHE" ]; then
    local cache_time
    cache_time=$(yaml_read "$UPSTREAM_CACHE" "checked_at" 2>/dev/null || echo "")
    if [ -n "$cache_time" ]; then
      local cache_age
      cache_age=$(days_since "$cache_time" 2>/dev/null || echo "999")
      if [ "$cache_age" -eq 0 ]; then
        # Checked today, use cache
        yaml_read "$UPSTREAM_CACHE" "upstream_version" 2>/dev/null || echo "unknown"
        return
      fi
    fi
  fi

  # Fetch upstream version
  local upstream
  upstream=$(telemetry_upstream_repo)
  local version="unknown"

  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    # Try gh api for latest release tag
    version=$(gh api "repos/${upstream}/releases/latest" --jq '.tag_name' 2>/dev/null || echo "")
    # Fallback: read raw TERMITE_PROTOCOL.md first line
    if [ -z "$version" ] || [ "$version" = "null" ]; then
      version=$(gh api "repos/${upstream}/contents/templates/TERMITE_PROTOCOL.md" \
        --jq '.content' 2>/dev/null \
        | base64 -d 2>/dev/null \
        | head -1 \
        | sed 's/.*termite-protocol:\(v[0-9.]*\).*/\1/' || echo "unknown")
    fi
  elif command -v curl >/dev/null 2>&1; then
    version=$(curl -fsSL "https://raw.githubusercontent.com/${upstream}/main/templates/TERMITE_PROTOCOL.md" 2>/dev/null \
      | head -1 \
      | sed 's/.*termite-protocol:\(v[0-9.]*\).*/\1/' || echo "unknown")
  fi

  # Write cache
  cat > "$UPSTREAM_CACHE" <<CEOF
checked_at: $(today_iso)
upstream_version: ${version}
CEOF

  echo "$version"
}
```

**Step 2: Verify syntax**

Run: `bash -n templates/scripts/field-lib.sh`
Expected: no output (success)

**Step 3: Commit**

```bash
git add templates/scripts/field-lib.sh
git commit -m "feat(telemetry): add telemetry helper functions to field-lib.sh"
```

---

### Task 3: Create `field-submit-audit.sh`

**Files:**
- Create: `templates/scripts/field-submit-audit.sh`

**Step 1: Write the script**

```bash
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
AUDIT_DIR="${PROJECT_ROOT}/audit-package-$(today_iso)"

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
  | while IFS= read -r l; do log_info "  export: $l"; done || {
    log_error "Audit export failed"
    exit 1
  }

# ── Step 2: Fork upstream (idempotent) ────────────────────────────

log_info "Ensuring fork of ${UPSTREAM}"
gh repo fork "$UPSTREAM" --clone=false 2>/dev/null || true

# Get fork name (owner/repo)
GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
if [ -z "$GH_USER" ]; then
  log_error "Cannot determine GitHub username"
  rm -rf "$AUDIT_DIR"
  exit 1
fi

FORK_REPO="${GH_USER}/$(basename "$UPSTREAM")"
log_info "Fork: ${FORK_REPO}"

# ── Step 3: Clone fork to temp dir ────────────────────────────────

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR" "$AUDIT_DIR"' EXIT

log_info "Cloning fork (shallow)"
gh repo clone "$FORK_REPO" "$TEMP_DIR" -- --depth 1 2>/dev/null || {
  log_error "Cannot clone fork ${FORK_REPO}"
  exit 1
}

# ── Step 4: Create audit branch + commit ──────────────────────────

BRANCH_NAME="audit/${PROJECT_NAME}/$(today_iso)"
cd "$TEMP_DIR"

# Sync fork with upstream first
git remote add upstream "https://github.com/${UPSTREAM}.git" 2>/dev/null || true
git fetch upstream main --depth 1 2>/dev/null || true
git checkout -B "$BRANCH_NAME" upstream/main 2>/dev/null || git checkout -B "$BRANCH_NAME"

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

log_info "Pushing to ${FORK_REPO}:${BRANCH_NAME}"
git push origin "$BRANCH_NAME" --force 2>/dev/null || {
  log_error "Push failed"
  exit 1
}

# Check if PR already exists
EXISTING_PR=$(gh pr list --repo "$UPSTREAM" --head "${GH_USER}:${BRANCH_NAME}" --json number --jq '.[0].number' 2>/dev/null || echo "")

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

  gh pr create --repo "$UPSTREAM" \
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
```

**Step 2: Make executable**

Run: `chmod +x templates/scripts/field-submit-audit.sh`

**Step 3: Verify syntax**

Run: `bash -n templates/scripts/field-submit-audit.sh`
Expected: no output (success)

**Step 4: Commit**

```bash
git add templates/scripts/field-submit-audit.sh
git commit -m "feat(telemetry): add field-submit-audit.sh for cross-colony PR submission"
```

---

### Task 4: Add protocol version detection to `field-arrive.sh`

**Files:**
- Modify: `templates/scripts/field-arrive.sh` (insert after Step 3.5 genesis block, before Step 4 caste determination)

**Step 1: Add version detection step**

Insert after line 107 (`fi` closing genesis block), before line 109 (`# ── Step 4:`):

```bash
# ── Step 3.7: Protocol version detection ─────────────────────────────

if telemetry_enabled; then
  local_ver=$(local_protocol_version)
  upstream_ver=$(upstream_protocol_version)
  if [ "$upstream_ver" != "unknown" ] && [ "$local_ver" != "unknown" ] && [ "$upstream_ver" != "$local_ver" ]; then
    log_info "Protocol update available: ${local_ver} → ${upstream_ver}"
    # Create HOLE signal if one doesn't already exist for this version
    update_signal_exists=false
    if has_db; then
      existing=$(db_signal_count "module='termite-protocol' AND title LIKE '%${upstream_ver}%' AND status NOT IN ('archived','done')" 2>/dev/null || echo "0")
      [ "${existing:-0}" -gt 0 ] && update_signal_exists=true
    fi
    if ! $update_signal_exists; then
      if has_db; then
        update_id=$(db_next_signal_id "S")
        db_signal_create "$update_id" "HOLE" \
          "Protocol update available: ${local_ver} → ${upstream_ver}" \
          "open" "35" "14" "$(today_iso)" "$(today_iso)" "unassigned" \
          "termite-protocol" "[]" \
          "Scout: read UPGRADE_NOTES.md for changes and action items, then decide whether to run install.sh --upgrade" \
          "0" "autonomous"
        log_info "Created signal ${update_id} for protocol update"
      else
        ensure_signal_dirs
        update_id=$(next_signal_id S)
        cat > "${ACTIVE_DIR}/${update_id}.yaml" <<SIGEOF
id: ${update_id}
type: HOLE
title: "Protocol update available: ${local_ver} → ${upstream_ver}"
status: open
weight: 35
ttl_days: 14
created: $(today_iso)
last_touched: $(today_iso)
owner: unassigned
module: "termite-protocol"
tags: []
next: "Scout: read UPGRADE_NOTES.md for changes and action items, then decide whether to run install.sh --upgrade"
touch_count: 0
source: autonomous
SIGEOF
        log_info "Created signal ${update_id} for protocol update"
      fi
    fi
  fi
fi
```

**Step 2: Verify syntax**

Run: `bash -n templates/scripts/field-arrive.sh`
Expected: no output (success)

**Step 3: Commit**

```bash
git add templates/scripts/field-arrive.sh
git commit -m "feat(telemetry): add protocol version detection to field-arrive.sh"
```

---

### Task 5: Update `install.sh` — telemetry config + script registration

**Files:**
- Modify: `install.sh`

**Step 1: Add `.termite-telemetry.yaml` to PROTOCOL_FILES array**

In the `PROTOCOL_FILES` array (around line 20), add after `TERMITE_SEED.md`:

```bash
  .termite-telemetry.yaml
```

**Step 2: Add `field-submit-audit.sh` to PROTOCOL_SCRIPTS array**

In the `PROTOCOL_SCRIPTS` array (around line 31), add after `termite-db-reimport.sh`:

```bash
  scripts/field-submit-audit.sh
```

**Step 3: Add `.termite-telemetry.yaml` to GITIGNORE_RULES**

**Do NOT add it.** The telemetry config should be committed to git so team members can see/modify it. No change needed here.

**Step 4: Add telemetry skip logic for `--upgrade`**

After the entry files section (around line 283), the `.termite-telemetry.yaml` is a PROTOCOL_FILE so it will be installed normally on fresh install. For `--upgrade`, it's already handled — `process_file` creates `.backup` for existing files. But we want `--upgrade` to NOT overwrite an existing telemetry config. Add `.termite-telemetry.yaml` to a skip list.

In the `process_file` function area, or more simply: add a guard in the copy logic. The cleanest approach: move `.termite-telemetry.yaml` from `PROTOCOL_FILES` to `ENTRY_FILES` array, since entry files are skipped during `--upgrade`. This is exactly the right semantic.

So actually: add `.termite-telemetry.yaml` to `ENTRY_FILES` (not `PROTOCOL_FILES`):

```bash
ENTRY_FILES=(
  CLAUDE.md
  AGENTS.md
  .termite-telemetry.yaml
)
```

**Step 5: Verify syntax**

Run: `bash -n install.sh`
Expected: no output (success)

**Step 6: Commit**

```bash
git add install.sh
git commit -m "feat(telemetry): register telemetry config and submit script in install.sh"
```

---

### Task 6: Add `.termite-upstream-check` to `.gitignore` rules

**Files:**
- Modify: `install.sh` (GITIGNORE_RULES variable)

**Step 1: Add cache file to gitignore rules**

In the `GITIGNORE_RULES` variable (around line 89), add:

```
.termite-upstream-check
```

So the full block becomes:

```bash
GITIGNORE_RULES=".birth
.birth.*
.field-breath
.pheromone
.termite.db
.termite.db-wal
.termite.db-shm
.termite-upstream-check"
```

**Step 2: Verify syntax**

Run: `bash -n install.sh`
Expected: no output (success)

**Step 3: Commit**

```bash
git add install.sh
git commit -m "chore: add .termite-upstream-check to gitignore rules"
```

---

### Task 7: Create protocol repo directory structure

**Files:**
- Create: `audit-packages/.gitkeep`
- Create: `audit-analysis/.gitkeep`
- Create: `audit-analysis/optimization-proposals/.gitkeep`

**Step 1: Create directories with .gitkeep**

```bash
mkdir -p audit-packages audit-analysis/optimization-proposals
touch audit-packages/.gitkeep audit-analysis/.gitkeep audit-analysis/optimization-proposals/.gitkeep
```

**Step 2: Commit**

```bash
git add audit-packages/ audit-analysis/
git commit -m "feat(telemetry): create audit-packages/ and audit-analysis/ directories"
```

---

### Task 8: Update TERMITE_PROTOCOL.md — document the feedback loop

**Files:**
- Modify: `templates/TERMITE_PROTOCOL.md` (insert after "跨蚁丘信号交换" section, ~line 843)

**Step 1: Add cross-colony feedback loop section**

Insert after the "种子版本追踪" section (after line 843):

```markdown
### 跨蚁丘反馈闭环

当多个蚁丘使用白蚁协议时，可通过审计提交形成协议优化闭环：

```
项目蚁丘 ──(field-submit-audit.sh)──▶ 协议仓库 audit-packages/
                                              │
                                      Protocol Nurse 分析
                                              │
                                      优化提案 → merge
                                              │
项目蚁丘 ◀──(field-arrive.sh 检测版本)──────────┘
```

**参与方式**：通过 `.termite-telemetry.yaml` 控制（默认关闭）。

```yaml
enabled: true       # 启用跨蚁丘反馈
accepted: true      # 已确认免责声明
upstream_repo: "billbai-longarena/Termite-Protocol"
anonymize_project: false
submit_frequency: "session-end"  # session-end | weekly | manual
```

**工作机制**：

1. **审计提交**：`./scripts/field-submit-audit.sh` 导出审计包 → fork 上游 → 创建 PR
2. **版本检测**：`field-arrive.sh` 到达时检查上游协议版本（24h 缓存），有更新则生成 HOLE 信号
3. **半自主升级**：Scout 审查 `UPGRADE_NOTES.md` 后决定是否执行 `install.sh --upgrade`

**免责声明**：首次启用时强制展示。审计包只含协议产物（参见"协议审计导出"），不含项目源码。

**不参与的蚁丘**：`enabled: false`（默认）时，一切照旧。不联网、不导出、不 fork。
等价于自给自足的蚁丘——独立运行，不与外部交换信息素。完全合法的生存方式。
```

**Step 2: Verify markdown renders correctly**

Visually inspect the section for proper formatting.

**Step 3: Commit**

```bash
git add templates/TERMITE_PROTOCOL.md
git commit -m "docs: add cross-colony feedback loop section to TERMITE_PROTOCOL.md"
```

---

### Task 9: Integration test — full dry-run cycle

**Step 1: Verify all scripts pass syntax check**

```bash
bash -n templates/scripts/field-lib.sh && \
bash -n templates/scripts/field-arrive.sh && \
bash -n templates/scripts/field-submit-audit.sh && \
bash -n templates/scripts/field-cycle.sh && \
bash -n templates/scripts/field-export-audit.sh && \
bash -n install.sh && \
echo "ALL OK"
```

Expected: `ALL OK`

**Step 2: Test telemetry helpers in isolation**

```bash
cd templates
PROJECT_ROOT="$(pwd)"
source scripts/field-lib.sh

# Test with default config (disabled)
echo "enabled=$(yaml_read .termite-telemetry.yaml 'enabled')"   # → false
telemetry_enabled && echo "BUG" || echo "correctly disabled"     # → correctly disabled

# Test project name
echo "project=$(telemetry_project_name)"                         # → templates (or dir name)

# Test local version
echo "local_ver=$(local_protocol_version)"                       # → v3.4
```

**Step 3: Test field-submit-audit.sh gates**

```bash
# With disabled telemetry — should exit silently
./scripts/field-submit-audit.sh --dry-run
# Expected: "No .termite-telemetry.yaml" or silent exit

# With enabled but not accepted — should show disclaimer
# (only in interactive terminal)
```

**Step 4: Final commit with version bump note**

```bash
git add -A
git status  # verify nothing unexpected
# If clean, no commit needed. If leftover changes:
git commit -m "chore: integration verification cleanup"
```

---

## Task Dependency Map

```
Task 1 (template)
  └─▶ Task 2 (helpers) ──▶ Task 3 (submit script)
                          ──▶ Task 4 (arrive detection)
  └─▶ Task 5 (install.sh)
      └─▶ Task 6 (gitignore)
Task 7 (directories) — independent
Task 8 (docs) — independent
Task 9 (integration test) — depends on all above
```

Tasks 1, 7, 8 can run in parallel.
Tasks 2 depends on 1.
Tasks 3, 4 depend on 2.
Tasks 5, 6 depend on 1.
Task 9 depends on all.
