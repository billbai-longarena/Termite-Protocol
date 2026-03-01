# Claude Code Hook Integration Layer — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Claude Code plugin that automatically enforces Termite Protocol invariants (arrival, safety nets, pheromone deposit, metabolism) via hooks, and integrate it into install.sh for dual-channel distribution.

**Architecture:** Plugin-First — 7 independent hook scripts sharing a common library (`termite-hook-lib.sh`), each calling existing `field-*.sh` scripts via `$CLAUDE_PROJECT_DIR`. Plugin lives in `templates/claude-plugin/` and gets copied to host projects' `.claude/plugins/termite-protocol/`.

**Tech Stack:** Bash (POSIX-compatible), jq (optional, with python3 and grep/sed fallbacks), Claude Code hooks API.

---

### Task 1: Create plugin.json and hooks.json

**Files:**
- Create: `templates/claude-plugin/plugin.json`
- Create: `templates/claude-plugin/hooks/hooks.json`

**Step 1: Create directory structure**

Run: `mkdir -p templates/claude-plugin/hooks templates/claude-plugin/scripts`

**Step 2: Write plugin.json**

Create `templates/claude-plugin/plugin.json`:
```json
{
  "name": "termite-protocol",
  "description": "白蚁协议 Claude Code 集成层 — 自动执行到达仪式、安全网强制、信息素沉淀、代谢循环",
  "version": "1.0.0"
}
```

**Step 3: Write hooks.json**

Create `templates/claude-plugin/hooks/hooks.json`:
```json
{
  "description": "白蚁协议 Claude Code 集成层 — 环境强制协议不变量",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-session-start.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-user-prompt.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-pre-bash.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-post-edit.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-post-commit.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-pre-compact.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-stop.sh",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

**Step 4: Commit**

```bash
git add templates/claude-plugin/plugin.json templates/claude-plugin/hooks/hooks.json
git commit -m "feat(hooks): add plugin manifest and hook event registry

[termite:2026-02-28:worker]"
```

---

### Task 2: Create termite-hook-lib.sh (shared library)

**Files:**
- Create: `templates/claude-plugin/scripts/termite-hook-lib.sh`

**Step 1: Write the shared library**

Create `templates/claude-plugin/scripts/termite-hook-lib.sh`:

```bash
#!/usr/bin/env bash
# termite-hook-lib.sh — Shared utilities for Termite Protocol Claude Code hooks
# Source this from all hook-*.sh scripts.
# Zero external dependencies: jq → python3 → grep/sed fallback chain.

set -euo pipefail

# ── Project Root ────────────────────────────────────────────────────

find_project_root() {
  # $CLAUDE_PROJECT_DIR is set by Claude Code hooks runtime
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    echo "$CLAUDE_PROJECT_DIR"
    return 0
  fi
  # Fallback: git rev-parse
  git rev-parse --show-toplevel 2>/dev/null || echo ""
}

PROJECT_ROOT="$(find_project_root)"

# ── Termite Project Detection ───────────────────────────────────────

is_termite_project() {
  [ -n "$PROJECT_ROOT" ] && {
    [ -f "${PROJECT_ROOT}/.birth" ] ||
    [ -f "${PROJECT_ROOT}/TERMITE_PROTOCOL.md" ] ||
    [ -f "${PROJECT_ROOT}/CLAUDE.md" ] && grep -q "termite-kernel" "${PROJECT_ROOT}/CLAUDE.md" 2>/dev/null
  }
}

# ── Field Script Location ──────────────────────────────────────────

find_field_script() {
  local script_name="$1"
  local path="${PROJECT_ROOT}/scripts/${script_name}"
  if [ -x "$path" ]; then
    echo "$path"
    return 0
  fi
  return 1
}

# ── JSON Parsing (3-tier fallback) ─────────────────────────────────

json_get() {
  # Usage: json_get "$json_string" "field_name"
  # Extracts a top-level string value from flat JSON.
  local json="$1" field="$2"

  # Tier 1: jq
  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r ".${field} // empty" 2>/dev/null && return 0
  fi

  # Tier 2: python3
  if command -v python3 >/dev/null 2>&1; then
    echo "$json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    keys = '${field}'.split('.')
    v = d
    for k in keys:
        v = v[k]
    print(v if v is not None else '')
except: pass
" 2>/dev/null && return 0
  fi

  # Tier 3: grep/sed (flat keys only)
  echo "$json" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" 2>/dev/null \
    | sed "s/\"${field}\"[[:space:]]*:[[:space:]]*\"//" | sed 's/"$//' && return 0

  echo ""
}

read_stdin_json() {
  # Read all of stdin into a variable. Call once per hook.
  cat
}

# ── .birth Reading ─────────────────────────────────────────────────

read_birth() {
  local birth_file="${PROJECT_ROOT}/.birth"
  if [ -f "$birth_file" ]; then
    cat "$birth_file"
  else
    echo ""
  fi
}

birth_field() {
  # Extract a field from .birth (flat YAML: "key: value")
  local field="$1"
  local birth_file="${PROJECT_ROOT}/.birth"
  if [ -f "$birth_file" ]; then
    grep -m1 "^${field}:" "$birth_file" 2>/dev/null \
      | sed "s/^${field}:[[:space:]]*//"
  fi
}

# ── Git Utilities ──────────────────────────────────────────────────

count_uncommitted_lines() {
  # Count total inserted+deleted lines in unstaged+staged changes
  if [ -z "$PROJECT_ROOT" ] || [ ! -d "${PROJECT_ROOT}/.git" ]; then
    echo "0"
    return
  fi
  local staged unstaged total
  staged=$(git -C "$PROJECT_ROOT" diff --cached --numstat 2>/dev/null \
    | awk '{s+=$1+$2} END {print s+0}')
  unstaged=$(git -C "$PROJECT_ROOT" diff --numstat 2>/dev/null \
    | awk '{s+=$1+$2} END {print s+0}')
  total=$((staged + unstaged))
  echo "$total"
}

has_uncommitted_changes() {
  [ -n "$PROJECT_ROOT" ] && [ -d "${PROJECT_ROOT}/.git" ] && \
    ! git -C "$PROJECT_ROOT" diff --quiet 2>/dev/null || \
    ! git -C "$PROJECT_ROOT" diff --cached --quiet 2>/dev/null
}

# ── File Freshness ─────────────────────────────────────────────────

is_newer_than() {
  # Usage: is_newer_than fileA fileB → 0 if fileA is newer than fileB
  local file_a="$1" file_b="$2"
  if [ ! -f "$file_a" ] || [ ! -f "$file_b" ]; then
    return 1
  fi
  # Use stat to compare modification times
  local mod_a mod_b
  mod_a=$(stat -f "%m" "$file_a" 2>/dev/null || stat -c "%Y" "$file_a" 2>/dev/null || echo 0)
  mod_b=$(stat -f "%m" "$file_b" 2>/dev/null || stat -c "%Y" "$file_b" 2>/dev/null || echo 0)
  [ "$mod_a" -gt "$mod_b" ]
}

# ── Output Helpers ─────────────────────────────────────────────────

hook_approve() {
  echo '{"decision":"approve"}'
}

hook_block() {
  local reason="$1"
  local msg="${2:-$reason}"
  cat <<HOOKEOF
{"decision":"block","reason":"${reason}","systemMessage":"${msg}"}
HOOKEOF
}

hook_allow() {
  local json='{"hookSpecificOutput":{"permissionDecision":"allow"}}'
  echo "$json"
}

hook_deny() {
  local reason="$1"
  cat <<HOOKEOF
{"hookSpecificOutput":{"permissionDecision":"deny"},"systemMessage":"${reason}"}
HOOKEOF
}

hook_system_message() {
  local msg="$1"
  echo "{\"systemMessage\":$(echo "$msg" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))' 2>/dev/null || echo "\"${msg}\"")}"
}
```

**Step 2: Make executable and commit**

```bash
chmod +x templates/claude-plugin/scripts/termite-hook-lib.sh
git add templates/claude-plugin/scripts/termite-hook-lib.sh
git commit -m "feat(hooks): add shared hook library with JSON parsing and project detection

Three-tier JSON fallback (jq → python3 → grep/sed), .birth reader,
git change counting, hook output helpers.

[termite:2026-02-28:worker]"
```

---

### Task 3: Create hook-session-start.sh

**Files:**
- Create: `templates/claude-plugin/scripts/hook-session-start.sh`

**Step 1: Write the hook script**

Create `templates/claude-plugin/scripts/hook-session-start.sh`:

```bash
#!/usr/bin/env bash
# hook-session-start.sh — SessionStart hook
# Runs field-arrive.sh to generate .birth, injects summary into session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Consume stdin (required by hook protocol even if unused)
cat > /dev/null

# Skip if not a termite project
if ! is_termite_project; then
  exit 0
fi

# Try to run field-arrive.sh
arrive_script=""
arrive_script=$(find_field_script "field-arrive.sh") || true

if [ -n "$arrive_script" ]; then
  # Run arrive, capture stderr for logging, allow failure
  "$arrive_script" 2>/dev/null || true
fi

# Read .birth for summary
birth_content="$(read_birth)"
if [ -z "$birth_content" ]; then
  exit 0
fi

# Inject birth content as environment variable (persists across session)
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  # Encode multiline content as base64 for safe env var storage
  birth_b64=$(echo "$birth_content" | base64 | tr -d '\n')
  echo "export TERMITE_BIRTH_B64=\"${birth_b64}\"" >> "$CLAUDE_ENV_FILE"
fi

# Extract summary fields from .birth
caste=$(birth_field "caste")
branch=$(birth_field "branch")
health=$(birth_field "health")

echo "[termite] Arrived. Caste: ${caste:-unknown}. Branch: ${branch:-unknown}. ${health:-no health data}."
```

**Step 2: Make executable and commit**

```bash
chmod +x templates/claude-plugin/scripts/hook-session-start.sh
git add templates/claude-plugin/scripts/hook-session-start.sh
git commit -m "feat(hooks): add SessionStart hook — auto-run field-arrive.sh

Generates .birth on session start, injects summary into transcript,
stores birth content in CLAUDE_ENV_FILE for session persistence.

[termite:2026-02-28:worker]"
```

---

### Task 4: Create hook-user-prompt.sh

**Files:**
- Create: `templates/claude-plugin/scripts/hook-user-prompt.sh`

**Step 1: Write the hook script**

Create `templates/claude-plugin/scripts/hook-user-prompt.sh`:

```bash
#!/usr/bin/env bash
# hook-user-prompt.sh — UserPromptSubmit hook
# Detects "白蚁协议" / "termite protocol" trigger and injects .birth context.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Skip if not a termite project
if ! is_termite_project; then
  cat > /dev/null
  exit 0
fi

# Read hook input
INPUT="$(read_stdin_json)"

# Extract user prompt
user_prompt=$(json_get "$INPUT" "user_prompt")

# Check for trigger words (case-insensitive)
trigger_found=false
prompt_lower=$(echo "$user_prompt" | tr '[:upper:]' '[:lower:]')

case "$prompt_lower" in
  *白蚁协议*|*termite\ protocol*|*termite-protocol*)
    trigger_found=true
    ;;
esac

if [ "$trigger_found" = "false" ]; then
  exit 0
fi

# Trigger detected — inject .birth content as system message
birth_content="$(read_birth)"

if [ -z "$birth_content" ]; then
  # No .birth yet — try to generate one
  arrive_script=""
  arrive_script=$(find_field_script "field-arrive.sh") || true
  if [ -n "$arrive_script" ]; then
    "$arrive_script" 2>/dev/null || true
    birth_content="$(read_birth)"
  fi
fi

if [ -n "$birth_content" ]; then
  hook_system_message "[termite:heartbeat] 白蚁协议心跳触发。以下是你的 .birth 出生证明，按此行动：

${birth_content}"
fi
```

**Step 2: Make executable and commit**

```bash
chmod +x templates/claude-plugin/scripts/hook-user-prompt.sh
git add templates/claude-plugin/scripts/hook-user-prompt.sh
git commit -m "feat(hooks): add UserPromptSubmit hook — detect trigger word, inject .birth

Listens for '白蚁协议' or 'termite protocol' in user prompts,
injects .birth content as system message to activate protocol.

[termite:2026-02-28:worker]"
```

---

### Task 5: Create hook-pre-bash.sh

**Files:**
- Create: `templates/claude-plugin/scripts/hook-pre-bash.sh`

**Step 1: Write the hook script**

Create `templates/claude-plugin/scripts/hook-pre-bash.sh`:

```bash
#!/usr/bin/env bash
# hook-pre-bash.sh — PreToolUse(Bash) hook
# Safety net S2: prevent deletion of .md files and critical directories.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Skip if not a termite project
if ! is_termite_project; then
  cat > /dev/null
  exit 0
fi

# Read hook input
INPUT="$(read_stdin_json)"

# Extract command
command_str=$(json_get "$INPUT" "tool_input.command")

if [ -z "$command_str" ]; then
  exit 0
fi

# Check for dangerous patterns
#
# Pattern 1: rm + .md file
# Matches: rm foo.md, rm -f CLAUDE.md, rm -rf dir/BLACKBOARD.md
if echo "$command_str" | grep -qE '\brm\b.*\.md\b'; then
  hook_deny "[termite:S2] 安全网 S2: 禁止删除 .md 文件。白蚁协议保护 .md 文件不被删除。如果确实需要删除，请人类手动操作。"
  exit 0
fi

# Pattern 2: rm -rf on critical directories
if echo "$command_str" | grep -qE '\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|(-[a-zA-Z]*f[a-zA-Z]*r))\b.*(signals/|scripts/|\.claude/)'; then
  hook_deny "[termite:S2] 安全网 S2: 禁止递归删除协议关键目录 (signals/, scripts/, .claude/)。"
  exit 0
fi

# No dangerous pattern — allow
exit 0
```

**Step 2: Make executable and commit**

```bash
chmod +x templates/claude-plugin/scripts/hook-pre-bash.sh
git add templates/claude-plugin/scripts/hook-pre-bash.sh
git commit -m "feat(hooks): add PreToolUse(Bash) hook — safety net S2 enforcement

Blocks rm commands targeting .md files and recursive deletion of
protocol-critical directories (signals/, scripts/, .claude/).

[termite:2026-02-28:worker]"
```

---

### Task 6: Create hook-post-edit.sh

**Files:**
- Create: `templates/claude-plugin/scripts/hook-post-edit.sh`

**Step 1: Write the hook script**

Create `templates/claude-plugin/scripts/hook-post-edit.sh`:

```bash
#!/usr/bin/env bash
# hook-post-edit.sh — PostToolUse(Write|Edit) hook
# Safety net S3: warn when uncommitted changes exceed 50 lines.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Consume stdin
cat > /dev/null

# Skip if not a termite project
if ! is_termite_project; then
  exit 0
fi

# Count uncommitted lines
lines=$(count_uncommitted_lines)

if [ "$lines" -ge 50 ]; then
  echo "[termite:S3] 未提交改动已达 ${lines} 行（阈值 50）。建议立即 git commit -m '[WIP] ...' 防止丢失。" >&2
  exit 2
fi

exit 0
```

**Step 2: Make executable and commit**

```bash
chmod +x templates/claude-plugin/scripts/hook-post-edit.sh
git add templates/claude-plugin/scripts/hook-post-edit.sh
git commit -m "feat(hooks): add PostToolUse(Write|Edit) hook — safety net S3 enforcement

Counts uncommitted changed lines after each edit, warns via stderr
when threshold (50 lines) is exceeded.

[termite:2026-02-28:worker]"
```

---

### Task 7: Create hook-post-commit.sh

**Files:**
- Create: `templates/claude-plugin/scripts/hook-post-commit.sh`

**Step 1: Write the hook script**

Create `templates/claude-plugin/scripts/hook-post-commit.sh`:

```bash
#!/usr/bin/env bash
# hook-post-commit.sh — PostToolUse(Bash) hook
# Triggers field-cycle.sh (metabolism) after git commit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Read hook input
INPUT="$(read_stdin_json)"

# Skip if not a termite project
if ! is_termite_project; then
  exit 0
fi

# Extract command
command_str=$(json_get "$INPUT" "tool_input.command")

if [ -z "$command_str" ]; then
  exit 0
fi

# Check if this was a git commit command
if ! echo "$command_str" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

# Run metabolism cycle in background (don't block the hook)
cycle_script=""
cycle_script=$(find_field_script "field-cycle.sh") || true

if [ -n "$cycle_script" ]; then
  "$cycle_script" >/dev/null 2>&1 &
  disown 2>/dev/null || true
  echo "[termite] Metabolism cycle triggered (background)."
fi

exit 0
```

**Step 2: Make executable and commit**

```bash
chmod +x templates/claude-plugin/scripts/hook-post-commit.sh
git add templates/claude-plugin/scripts/hook-post-commit.sh
git commit -m "feat(hooks): add PostToolUse(Bash) hook — auto metabolism after commit

Detects git commit commands, triggers field-cycle.sh in background
for decay, drain, pulse, promotion, and rule archival.

[termite:2026-02-28:worker]"
```

---

### Task 8: Create hook-stop.sh

**Files:**
- Create: `templates/claude-plugin/scripts/hook-stop.sh`

**Step 1: Write the hook script**

Create `templates/claude-plugin/scripts/hook-stop.sh`:

```bash
#!/usr/bin/env bash
# hook-stop.sh — Stop hook
# Enforces "no silent death" — blocks stop until pheromone is deposited.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Consume stdin
cat > /dev/null

# Skip if not a termite project — approve immediately
if ! is_termite_project; then
  hook_approve
  exit 0
fi

# Check 1: Uncommitted changes
if has_uncommitted_changes; then
  lines=$(count_uncommitted_lines)
  if [ "$lines" -gt 0 ]; then
    hook_block \
      "[termite] 有 ${lines} 行未提交改动。请先 commit [WIP] 或运行 ./scripts/field-deposit.sh --pheromone 再结束。" \
      "[termite:S3] 禁止无声死亡。有 ${lines} 行未提交改动。请 commit [WIP] 或运行 ./scripts/field-deposit.sh --pheromone 留下信息素。"
    exit 0
  fi
fi

# Check 2: Pheromone freshness
# .pheromone should be newer than .birth (written during this session)
pheromone_file="${PROJECT_ROOT}/.pheromone"
birth_file="${PROJECT_ROOT}/.birth"

if [ -f "$birth_file" ]; then
  if [ ! -f "$pheromone_file" ] || ! is_newer_than "$pheromone_file" "$birth_file"; then
    hook_block \
      "[termite] 本次会话尚未沉淀信息素。请运行 ./scripts/field-deposit.sh --pheromone 再结束。" \
      "[termite] 禁止无声死亡。请运行: ./scripts/field-deposit.sh --pheromone --caste <your_caste> --completed '已完成的工作' --unresolved '未解决的问题' --predecessor-useful true"
    exit 0
  fi
fi

# All checks passed
hook_approve
```

**Step 2: Make executable and commit**

```bash
chmod +x templates/claude-plugin/scripts/hook-stop.sh
git add templates/claude-plugin/scripts/hook-stop.sh
git commit -m "feat(hooks): add Stop hook — enforce no-silent-death invariant

Blocks session stop until uncommitted changes are committed and
pheromone is deposited, ensuring cross-session handoff continuity.

[termite:2026-02-28:worker]"
```

---

### Task 9: Create hook-pre-compact.sh

**Files:**
- Create: `templates/claude-plugin/scripts/hook-pre-compact.sh`

**Step 1: Write the hook script**

Create `templates/claude-plugin/scripts/hook-pre-compact.sh`:

```bash
#!/usr/bin/env bash
# hook-pre-compact.sh — PreCompact hook
# Injects .birth and .pheromone into context before compaction to preserve protocol state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/termite-hook-lib.sh"

# Consume stdin
cat > /dev/null

# Skip if not a termite project
if ! is_termite_project; then
  exit 0
fi

# Build preserved context
preserved=""

# Include .birth
birth_content="$(read_birth)"
if [ -n "$birth_content" ]; then
  preserved="${preserved}## 白蚁协议 .birth（当前种姓与态势）
${birth_content}
"
fi

# Include .pheromone if it exists
pheromone_file="${PROJECT_ROOT}/.pheromone"
if [ -f "$pheromone_file" ]; then
  pheromone_content=$(cat "$pheromone_file")
  preserved="${preserved}
## 白蚁协议 .pheromone（交接状态）
${pheromone_content}
"
fi

if [ -n "$preserved" ]; then
  hook_system_message "[termite:PreCompact] 以下是压缩前必须保留的协议状态：

${preserved}
请在压缩后继续按以上种姓和态势工作。"
fi
```

**Step 2: Make executable and commit**

```bash
chmod +x templates/claude-plugin/scripts/hook-pre-compact.sh
git add templates/claude-plugin/scripts/hook-pre-compact.sh
git commit -m "feat(hooks): add PreCompact hook — preserve protocol state across compaction

Injects .birth and .pheromone content into context before compaction
so LLM retains caste, signals, and handoff state after summarization.

[termite:2026-02-28:worker]"
```

---

### Task 10: Integrate plugin into install.sh

**Files:**
- Modify: `install.sh`

**Step 1: Add CLAUDE_PLUGIN_FILES array after existing arrays (~line 54)**

Add after the `HOOK_FILES` array:

```bash
# Claude Code plugin files
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
```

**Step 2: Add plugin install section after git hooks install (~line 311)**

Add new section between git hooks install and .gitignore update:

```bash
# ---------- Install Claude Code Plugin ----------

CLAUDE_PLUGIN_TARGET="${TARGET_DIR}/.claude/plugins/termite-protocol"

install_claude_plugin() {
  mkdir -p "$CLAUDE_PLUGIN_TARGET/hooks" "$CLAUDE_PLUGIN_TARGET/scripts"

  for f in "${CLAUDE_PLUGIN_FILES[@]}"; do
    local rel="${f#claude-plugin/}"
    local src dst

    if [ "$SOURCE_MODE" = "local" ]; then
      src="${TEMPLATE_DIR}/${f}"
      dst="${CLAUDE_PLUGIN_TARGET}/${rel}"
      if [ ! -f "$src" ]; then
        warn "Claude plugin source not found: ${f}"
        continue
      fi
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    else
      local url="${GITHUB_RAW_BASE}/${f}"
      dst="${CLAUDE_PLUGIN_TARGET}/${rel}"
      mkdir -p "$(dirname "$dst")"
      curl -fsSL "$url" -o "$dst" 2>/dev/null || { warn "Failed to download: ${f}"; continue; }
    fi

    case "$rel" in
      scripts/*.sh) chmod +x "$dst" ;;
    esac
  done

  log "Claude Code plugin installed: ${CLAUDE_PLUGIN_TARGET}"
}

install_claude_plugin
```

**Step 3: Update summary section to mention plugin**

Update the "Next steps" log output to include:

```bash
log "  4. Claude Code plugin installed at .claude/plugins/termite-protocol/"
```

**Step 4: Commit**

```bash
git add install.sh
git commit -m "feat(install): integrate Claude Code plugin into install.sh

Adds CLAUDE_PLUGIN_FILES array and install_claude_plugin() function.
Plugin is copied to .claude/plugins/termite-protocol/ in host project
alongside existing git hooks and field scripts.

[termite:2026-02-28:worker]"
```

---

### Task 11: Test hook scripts manually

**Step 1: Test hook-pre-bash.sh with dangerous command**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"rm -f CLAUDE.md"}}' | \
  bash templates/claude-plugin/scripts/hook-pre-bash.sh
```

Expected output: JSON with `permissionDecision: deny` and S2 message.

**Step 2: Test hook-pre-bash.sh with safe command**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | \
  bash templates/claude-plugin/scripts/hook-pre-bash.sh
```

Expected: no output, exit 0.

**Step 3: Test hook-user-prompt.sh with trigger word**

```bash
CLAUDE_PROJECT_DIR="$(pwd)" \
  echo '{"user_prompt":"白蚁协议 修复登录bug"}' | \
  bash templates/claude-plugin/scripts/hook-user-prompt.sh
```

Expected: JSON systemMessage containing .birth content (if .birth exists) or empty (if no .birth).

**Step 4: Test hook-post-edit.sh line counting**

```bash
CLAUDE_PROJECT_DIR="$(pwd)" \
  echo '{}' | \
  bash templates/claude-plugin/scripts/hook-post-edit.sh
```

Expected: exit 0 if uncommitted lines < 50, exit 2 with warning if >= 50.

**Step 5: Test hook-stop.sh approval**

```bash
CLAUDE_PROJECT_DIR="$(pwd)" \
  echo '{}' | \
  bash templates/claude-plugin/scripts/hook-stop.sh
```

Expected: `{"decision":"approve"}` if clean, or block JSON if dirty.

**Step 6: Commit test results (if any fixes needed)**

Fix any issues found, then:
```bash
git add -A templates/claude-plugin/
git commit -m "fix(hooks): address issues found during manual testing

[termite:2026-02-28:worker]"
```

---

### Task 12: Final commit — update TERMITE_PROTOCOL.md reference

**Files:**
- Modify: `templates/TERMITE_PROTOCOL.md`

**Step 1: Add Claude Code hook integration note**

In Part II, after the Platform Detection table, add a new section:

```markdown
## Claude Code Hook 集成 (Claude Code Hook Integration)

> v3.4+ 提供 Claude Code plugin，在环境层面自动执行协议不变量。

### 安装

```
# 方式 1: install.sh 一键安装（推荐）
bash install.sh /path/to/project

# 方式 2: 手动安装 plugin（项目已有协议基础设施）
cp -r templates/claude-plugin/ /path/to/project/.claude/plugins/termite-protocol/
```

### Hook 事件映射

| Hook 事件 | 触发时机 | 协议行为 |
|-----------|---------|---------|
| SessionStart | 会话启动 | 运行 field-arrive.sh → 生成 .birth |
| UserPromptSubmit | 用户提交 | 检测"白蚁协议"触发词 → 注入 .birth |
| PreToolUse(Bash) | Bash 调用前 | 安全网 S2: 阻止删除 .md 文件 |
| PostToolUse(Write/Edit) | 编辑后 | 安全网 S3: 检查未提交行数 |
| PostToolUse(Bash) | Bash 调用后 | 检测 git commit → 触发 field-cycle.sh |
| PreCompact | Context 压缩前 | 注入 .birth + .pheromone 到压缩上下文 |
| Stop | 会话结束前 | 检查未提交改动和信息素沉淀 |

### 设计原则

- 环境强制 > 个体自觉：安全网由 hook 强制，不依赖 LLM 记住规则
- 静默降级：非协议项目中所有 hook 静默退出
- 职责不重复：hook 只做触发和检测，逻辑在 field-*.sh
```

**Step 2: Commit**

```bash
git add templates/TERMITE_PROTOCOL.md
git commit -m "docs: add Claude Code hook integration section to protocol

Documents hook event mapping, installation methods, and design
principles for the new Claude Code plugin integration layer.

[termite:2026-02-28:worker]"
```
