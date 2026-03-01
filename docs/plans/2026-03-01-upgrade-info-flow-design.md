# F-008: Upgrade Information Flow Fix — Design Document

**Date**: 2026-03-01
**Finding**: F-008 (REGISTRY.yaml)
**Author**: Nurse self-check session 3

## Problem Statement

When the protocol source repo publishes updates (template fixes, protocol evolution), host project agents have three broken links in the upgrade information chain:

1. **HOLE signal → "review changelog"** — but no changelog exists
2. **install.sh --upgrade → file counts only** — no semantic summary of what changed
3. **Post-upgrade → silence** — no mechanism to tell the colony whether action is needed

## Design Decisions

### D-1: UPGRADE_NOTES.md as the single source of upgrade truth

**Create `templates/UPGRADE_NOTES.md`** — a structured, machine-parseable changelog that gets installed into host projects. This file serves both human developers and AI agents.

Format: version-delimited sections with structured subsections.

```markdown
<!-- upgrade-notes:v1.0 -->
# Termite Protocol — Upgrade Notes

## v3.4 (2026-03-01)

### Changes
- **field-cycle.sh**: Now auto-invokes field-submit-audit.sh at end of metabolism cycle (TF-003)
- **field-export-audit.sh**: Fixed cp -R nesting bug that doubled audit package size (TF-002)
- ...

### Action Required
- To enable automatic audit submission: set `enabled: true` in `.termite-telemetry.yaml`
- No action needed for bug fixes — they take effect automatically on next heartbeat

### Action Optional
- (none for this version)

## v3.3 (2026-02-28)
### Changes
- ...
### Action Required
- (none)
```

**Why this format:**
- `## vX.Y` headers are trivially parseable by sed/grep (no yq/jq needed, consistent with field-lib.sh philosophy)
- `### Action Required` vs `### Action Optional` gives agents a clear decision framework
- The file accumulates history — agents upgrading from v3.2 to v3.4 can see both v3.3 and v3.4 changes

### D-2: install.sh --upgrade prints relevant changes

After copying files, install.sh:
1. Reads old version from the `.backup` of TERMITE_PROTOCOL.md (or current if no backup)
2. Reads new version from the freshly installed TERMITE_PROTOCOL.md
3. Extracts all sections between old and new version from UPGRADE_NOTES.md
4. Prints them to stdout
5. Writes a `.termite-upgrade-report` file with the same content (for agents arriving later)

The `.termite-upgrade-report` is ephemeral (added to .gitignore) — it's consumed by the next agent's field-arrive.sh and then can be cleared.

### D-3: field-arrive.sh reads .termite-upgrade-report

Add a step between 3.7 (version detection) and step 4 (caste determination):
- If `.termite-upgrade-report` exists → inject its content into `.birth` situation summary
- Agent immediately knows what changed and what to do

### D-4: HOLE signal next field updated

Change from:
```
"Scout: review changelog at https://github.com/..., decide whether to install.sh --upgrade"
```
To:
```
"Scout: read UPGRADE_NOTES.md for changes and action items, then decide whether to run install.sh --upgrade"
```

### D-5: Protocol spec references updated

In TERMITE_PROTOCOL.md line 885:
```
- Old: "Scout 审查 changelog 后决定是否执行 install.sh --upgrade"
+ New: "Scout 审查 UPGRADE_NOTES.md 后决定是否执行 install.sh --upgrade"
```

### D-6: Entry file templates updated (both CLAUDE.md and AGENTS.md)

Add `UPGRADE_NOTES.md` to the lookup index in both templates:

**CLAUDE.md** (Claude Code):
```markdown
| 协议升级变更 | `UPGRADE_NOTES.md` |
```

**AGENTS.md** (Codex / Gemini):
```markdown
| 协议升级变更 | `UPGRADE_NOTES.md` |
```

## Files Changed

| File | Change |
|------|--------|
| `templates/UPGRADE_NOTES.md` | **NEW** — structured changelog with per-version changes and action items |
| `install.sh` | Add upgrade summary logic: detect old/new version, extract/print relevant changes, write `.termite-upgrade-report` |
| `templates/scripts/field-arrive.sh` | Add Step 3.8: read `.termite-upgrade-report` if present, inject into .birth |
| `templates/scripts/field-lib.sh` | Add `UPGRADE_REPORT` constant, add `extract_upgrade_notes()` helper |
| `templates/TERMITE_PROTOCOL.md` | Update "review changelog" → "review UPGRADE_NOTES.md" (line 885) |
| `templates/CLAUDE.md` | Add UPGRADE_NOTES.md to lookup index |
| `templates/AGENTS.md` | Add UPGRADE_NOTES.md to lookup index |
| `.gitignore` (protocol source repo) | No change needed — .termite-upgrade-report is already covered by host project .gitignore template |

## Install Flow

### PROTOCOL_FILES update

Add `UPGRADE_NOTES.md` to the `PROTOCOL_FILES` array in `install.sh` so it gets installed and updated during `--upgrade`.

## Upgrade Report Format

`.termite-upgrade-report` written by install.sh:

```yaml
upgraded_at: 2026-03-01T15:30:00Z
from_version: v3.3
to_version: v3.4
changes: |
  ## v3.4 (2026-03-01)
  ### Changes
  - field-cycle.sh: Now auto-invokes field-submit-audit.sh ...
  ### Action Required
  - To enable automatic audit submission: set enabled: true in .termite-telemetry.yaml
```

## Information Flow After Fix

```
协议源仓库发布新版本
         ↓
field-arrive.sh Step 3.7: 检测到版本不一致
         ↓
创建 HOLE 信号: "Protocol update available: v3.3 → v3.4"
  next: "Scout: read UPGRADE_NOTES.md for changes and action items, then decide whether to run install.sh --upgrade"
         ↓
Scout 读本地 UPGRADE_NOTES.md (上次安装的版本)
  → 看不到新版本的内容 (尚未升级)
  → 但信号存在 = 知道有更新 → 决定升级
         ↓
运行 install.sh --upgrade
         ↓
install.sh:
  1. 检测旧版本 (从 .backup 或当前 TERMITE_PROTOCOL.md)
  2. 安装新文件 (包括新的 UPGRADE_NOTES.md)
  3. 读新 UPGRADE_NOTES.md，提取 v3.3→v3.4 之间的所有变更
  4. 打印到 stdout: "=== What changed === ..."
  5. 写入 .termite-upgrade-report
         ↓
当前 Scout 直接在 stdout 看到变更摘要
         ↓
下一只白蚁到达 → field-arrive.sh Step 3.8
  → 检测到 .termite-upgrade-report → 注入 .birth
  → 代理知道刚刚发生了升级，知道需要什么行动
  → 完成行动后清除 .termite-upgrade-report
```

## Version Impact

- **Protocol spec version**: No bump needed (this is tooling/DX, not protocol semantics)
- **Field lib version**: Bump to v20.1 (new helper function)
- **Entry kernel version**: No bump (lookup index is informational, not behavioral)
- **install.sh version**: Bump to v1.1.0
