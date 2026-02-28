# Claude Code Hook Integration Layer — Design Document

Date: 2026-02-28
Status: Approved
Protocol version: v3.4

## Problem

白蚁协议的核心不变量（到达仪式、安全网、信息素沉淀、代谢循环）目前依赖 LLM "自觉遵守"。
这与协议自身的哲学矛盾——"韧性来自环境设计，不来自个体纪律"。

Claude Code 提供了 hooks 系统（SessionStart/PreToolUse/PostToolUse/Stop/PreCompact/UserPromptSubmit），
可以在环境层面自动执行这些不变量，将协议从"LLM 脑子里的规则"变成"环境自动执行的机制"。

## Decision

采用 **Plugin-First** 架构：

- 核心实现为一个标准 Claude Code plugin（`templates/claude-plugin/`）
- install.sh 安装时自动复制到 `$TARGET/.claude/plugins/termite-protocol/`
- 也可独立通过 `claude plugin add` 或手动复制安装
- plugin 只包含 hooks（无 agents、无 commands），职责单一
- 每个 hook 事件一个独立脚本，通过 `$CLAUDE_PROJECT_DIR` 调用项目已有的 `scripts/field-*.sh`

## Architecture

### File Layout

```
templates/
  claude-plugin/
    plugin.json                       # plugin manifest
    hooks/
      hooks.json                      # 所有 hook 事件注册
    scripts/
      termite-hook-lib.sh             # hook 共享工具库
      hook-session-start.sh           # SessionStart
      hook-post-edit.sh               # PostToolUse(Write|Edit)
      hook-stop.sh                    # Stop
      hook-pre-compact.sh             # PreCompact
      hook-user-prompt.sh             # UserPromptSubmit
      hook-pre-bash.sh                # PreToolUse(Bash)
      hook-post-commit.sh             # PostToolUse(Bash)
```

### Lifecycle Coverage

```
SessionStart ──→ UserPromptSubmit ──→ [PreToolUse → DO → PostToolUse] ──→ PreCompact ──→ Stop
   arrive          触发词检测           S2保护  施工  S3提醒+commit循环       蜕皮保护      信息素沉淀
```

## Hook Specifications

### 1. SessionStart → hook-session-start.sh

- **Purpose**: 自动执行到达仪式（field-arrive.sh → .birth）
- **Behavior**:
  1. 检测 `$CLAUDE_PROJECT_DIR/scripts/field-arrive.sh` 是否存在且可执行
  2. 存在 → 运行 → 生成 `.birth`
  3. 不存在 → 静默退出（exit 0）
  4. 通过 `$CLAUDE_ENV_FILE` 注入 `TERMITE_BIRTH_CONTENT` 环境变量
  5. stdout 输出摘要：`[termite] Arrived. Caste: {caste}. Branch: {branch}. {n} active signals.`
- **Timeout**: 30s
- **Degradation**: field-arrive.sh 失败 → 读已有 .birth → 都失败则静默

### 2. UserPromptSubmit → hook-user-prompt.sh

- **Purpose**: 检测心跳触发词，自动注入 .birth 上下文
- **Behavior**:
  1. 从 stdin 读取 `user_prompt`
  2. 检测是否包含"白蚁协议"或 "termite protocol"（case-insensitive）
  3. 匹配 → systemMessage 注入 .birth 内容
  4. 不匹配 → 静默退出
- **Timeout**: 5s
- **Degradation**: 任何失败静默退出

### 3. PreToolUse(Bash) → hook-pre-bash.sh

- **Purpose**: 安全网 S2 环境强制——禁止删除 .md 文件
- **Behavior**:
  1. 从 stdin 读取 `tool_input.command`
  2. 检测危险模式：
     - `rm` + `.md` 文件 → deny + "安全网 S2: 禁止删除 .md 文件"
     - `rm -rf` + 关键目录（signals/、scripts/） → deny
  3. 无匹配 → allow
- **Timeout**: 5s

### 4. PostToolUse(Write|Edit) → hook-post-edit.sh

- **Purpose**: 安全网 S3 环境检测——未提交行数 ≥50 时提醒
- **Behavior**:
  1. 在 `$CLAUDE_PROJECT_DIR` 运行 `git diff --stat` 获取变更行数
  2. ≥50 行 → exit 2 + stderr: "[termite:S3] 未提交改动已达 {n} 行，建议 commit [WIP]"
  3. <50 行 → 静默退出
- **Timeout**: 10s

### 5. PostToolUse(Bash) → hook-post-commit.sh

- **Purpose**: git commit 后自动触发代谢循环
- **Behavior**:
  1. 从 stdin 读取 `tool_input.command`
  2. 检测是否包含 `git commit`
  3. 匹配 → 后台运行 `field-cycle.sh`（不阻塞）
  4. 不匹配 → 静默退出
- **Timeout**: 10s

### 6. Stop → hook-stop.sh

- **Purpose**: 强制"禁止无声死亡"——检查信息素沉淀
- **Behavior**:
  1. 检查是否是白蚁协议项目（.birth 或 TERMITE_PROTOCOL.md 存在）
  2. 非协议项目 → approve
  3. 协议项目 → 检查：
     - `git diff --stat` 有未提交改动 → block + "请先 commit [WIP] 或运行 field-deposit.sh"
     - `.pheromone` 不比 `.birth` 新 → block + "请运行 field-deposit.sh --pheromone"
  4. 通过 → approve
- **Timeout**: 15s

### 7. PreCompact → hook-pre-compact.sh

- **Purpose**: context 压缩时保留协议状态
- **Behavior**:
  1. 读取 `.birth` 内容
  2. 读取 `.pheromone`（如果有）
  3. systemMessage 输出关键状态供压缩后保留
- **Timeout**: 5s

## Shared Library: termite-hook-lib.sh

核心函数：

| Function | Purpose |
|----------|---------|
| `find_project_root` | 通过 `$CLAUDE_PROJECT_DIR` 或 `git rev-parse` 定位项目根 |
| `find_field_script` | 定位 `scripts/field-*.sh` |
| `read_stdin_json` | 解析 hook stdin JSON（jq → python3 → grep/sed 三级降级） |
| `read_birth` | 读取 `.birth` 内容 |
| `count_uncommitted_lines` | `git diff` 行数统计 |
| `is_termite_project` | 检测是否是白蚁协议项目 |
| `json_get` | 从 JSON 字符串提取字段值 |

## hooks.json

```json
{
  "description": "白蚁协议 Claude Code 集成层",
  "hooks": {
    "SessionStart": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-session-start.sh",
        "timeout": 30
      }]
    }],
    "UserPromptSubmit": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-user-prompt.sh",
        "timeout": 5
      }]
    }],
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-pre-bash.sh",
        "timeout": 5
      }]
    }],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-post-edit.sh",
          "timeout": 10
        }]
      },
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-post-commit.sh",
          "timeout": 10
        }]
      }
    ],
    "PreCompact": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-pre-compact.sh",
        "timeout": 5
      }]
    }],
    "Stop": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-stop.sh",
        "timeout": 15
      }]
    }]
  }
}
```

## install.sh Integration

新增常量：

```bash
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

新增安装步骤（在 git hooks 安装之后）：

```bash
# Install Claude Code plugin
CLAUDE_PLUGIN_TARGET="${TARGET_DIR}/.claude/plugins/termite-protocol"
mkdir -p "$CLAUDE_PLUGIN_TARGET"
for f in "${CLAUDE_PLUGIN_FILES[@]}"; do
  # Map claude-plugin/X → .claude/plugins/termite-protocol/X
  rel="${f#claude-plugin/}"
  process_file_to "$f" "$rel" "$CLAUDE_PLUGIN_TARGET"
done
```

## Dual Distribution

| Channel | Command | When |
|---------|---------|------|
| install.sh | `bash install.sh /project` | 新项目首次安装白蚁协议 |
| install.sh --upgrade | `bash install.sh --upgrade /project` | 升级协议（含 plugin 更新） |
| Manual copy | `cp -r claude-plugin/ /project/.claude/plugins/termite-protocol/` | 项目已有协议，补装 plugin |

## Design Principles

1. **环境强制 > 个体自觉**：安全网（S2/S3）由 hooks 环境层强制，不依赖 LLM 记住规则
2. **静默降级**：每个 hook 在 field 脚本不存在时静默退出，不阻断非协议项目
3. **职责不重复**：hook 只做触发和检测，实际逻辑在 field-*.sh——不重新实现协议
4. **可独立测试**：每个 hook 脚本可通过 stdin JSON 独立测试
5. **零外部依赖**：jq → python3 → grep/sed 三级降级，不假设任何工具存在
