# 白蚁协议快速上手指南 (Quick Start)

本文档介绍如何在全新的项目中安装并初始化白蚁协议（Termite Protocol）。

## 1. 安装 (Installation)

在你的项目根目录下，运行以下命令进行一键安装。这将下载协议的核心脚本和模板文件。

```bash
# 设置协议模板仓库地址
# 注意：请确保使用正确的 raw.githubusercontent.com 地址
export TERMITE_REPO_URL=https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/templates

# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | bash
```

或者使用单行命令：

```bash
curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | \
TERMITE_REPO_URL=https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/templates bash
```

### 安装选项

- `bash -s -- --upgrade`：升级模式，只更新核心协议文件，保留你的配置文件（如 `CLAUDE.md`, `AGENTS.md`）。
- `bash -s -- --force`：强制模式，覆盖文件时不创建备份。

## 2. 创世 (Genesis)

“创世”是白蚁协议在全新环境下的自动初始化过程。它会自动探测你的项目类型（语言、构建工具），并生成初始的上下文文件。

### 如何触发创世

安装完成后，只需运行“到达”脚本：

```bash
./scripts/field-arrive.sh
```

### 创世过程详解

当你第一次运行 `field-arrive.sh` 时，如果系统中没有 `BLACKBOARD.md` 和活跃信号，脚本会自动执行 `scripts/field-genesis.sh`，完成以下工作：

1.  **环境探测**：自动识别项目语言（如 Python, Node, Go, Rust 等）和构建工具（如 npm, cargo, pip 等）。
2.  **生成黑板 (Blackboard)**：在根目录创建 `BLACKBOARD.md`，填入探测到的项目信息和基本骨架。
3.  **生成初始信号**：创建一个 `EXPLORE` 类型的信号（通常是 `S-001`），任务是“探索项目结构、验证构建环境、完善黑板”。

### 验证成功

创世完成后，你应该能看到：
- 根目录下生成了 `BLACKBOARD.md` 文件。
- `signals/active/` 目录下出现了一个新的 `.yaml` 信号文件（例如 `S-001.yaml`）。

## 3. 下一步

1.  **编辑配置**：打开 `CLAUDE.md` 和 `AGENTS.md`，根据你的项目需求填写相关信息。
2.  **开始工作**：启动你的 AI Agent，让它根据 S-001 信号的指示开始工作。
