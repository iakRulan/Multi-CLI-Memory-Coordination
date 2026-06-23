---
name: task-context-relay
description: |
  多模型 CLI 任务上下文接力工具。解决 Codex CLI、Claude CLI 等独立进程间不共享对话历史导致的上下文断裂问题。
  通过 .task-context.md 文件作为"外部共享记忆"，实现换工具不换记忆。
  触发词：task context、上下文接力、cc 快捷函数、co 快捷函数、.task-context.md、多模型接力、Codex Claude 切换、任务记忆、上下文文件。
  当用户需要：
  1. 在 Codex/Claude 等不同 CLI 工具间切换时保持任务上下文
  2. 创建或更新 .task-context.md 文件
  3. 设置 Shell 快捷函数（cc/co）
  4. 查询当前任务上下文状态
  5. 初始化任务上下文工作流
  使用此 skill。
---

# Task Context Relay — 多模型 CLI 上下文接力

## 概述

本 skill 提供一套完整的"文件接力法"工作流，让用户在 Codex CLI、Claude CLI、OpenClaw 等不同 AI 工具间切换时，无需重复解释任务背景。

核心机制：在项目中维护一个 `.task-context.md` 文件，记录任务目标、背景、已完成事项、当前卡点、约束条件和相关文件。通过 Shell 快捷函数自动将上下文内容注入新工具，实现"换工具不换记忆"。

## 快速开始

### 1. 初始化上下文文件

在项目根目录创建 `.task-context.md`：

```bash
# 使用本 skill 的初始化脚本
python ~/.qclaw/skills/task-context-relay/scripts/init_context.py
```

或手动创建，参考模板见 `references/context-template.md`。

### 2. 配置 Shell 快捷函数

不必手抄函数，直接在 profile 中引用本 skill 的完整版脚本即可。

**PowerShell（推荐）** — 在 `$PROFILE` 中加入，然后重开终端或执行 `. $PROFILE`：

```powershell
. "$HOME\.qclaw\skills\task-context-relay\references\shell-functions.ps1"
```

**Bash / Zsh** — 在 `~/.bashrc` / `~/.zshrc` 中加入，然后重开终端或 `source`：

```bash
. "$HOME/.qclaw/skills/task-context-relay/references/shell-functions.sh"
```

> 这些脚本提供 `cc`/`ck`/`co`（启动**原生交互式**会话并自动注入上下文）以及 `ctx*` 管理命令。
>
> **注入机制**（按各 CLI 原生能力，保持交互）：
> - **Claude** → `claude --append-system-prompt <上下文>`，上下文作为追加系统提示，不改任何文件
> - **Kimi / Codex** → 它们无系统提示参数，但原生读取 `AGENTS.md`，故把上下文写入其中带标记的「受管块」；`ctx-unsync` 可一键清除，不动你的手写内容
>
> **原生参数透传**：`cc -c` 续接上次会话、`cc -p "快速问题"` 仍可一次性调用、`cc --model ...` 等同样可用。
>
> ⚠️ PowerShell 脚本须以 **UTF-8 (带 BOM)** 保存，否则 Windows PowerShell 5.1 会按 GBK 解析导致中文乱码或语法报错。

### 3. 使用流程

```
1. 开始任务 → 创建/更新 .task-context.md（ctx-init / ctx-edit）
2. 运行 cc  → 启动 Claude 交互式会话，已带上下文，自由多轮对话
3. 运行 ck  → 启动 Kimi 交互式会话，读取同一份上下文
4. 退出后，将关键结论追加回 .task-context.md（手动或让 AI 帮你更新）
5. 切换工具时，新进程自动读取同一文件，上下文无缝延续
```

## 上下文文件规范

### 文件位置
- 优先：项目根目录 `./.task-context.md`
- 向上查找：若当前目录不存在，递归向上查找至根目录
- 全局回退：`~/.task-context.md`（通用任务）

### 文件结构

```markdown
# Task Context: [任务名称]

## 目标
[一句话描述最终要达成什么]

## 背景
[为什么做这件事，相关背景信息]

## 已完成
- [x] 步骤1: [描述] ([日期], [工具])
- [x] 步骤2: [描述] ([日期], [工具])

## 当前卡点
- [ ] [描述当前遇到的问题或阻塞]

## 约束条件
- [技术约束, 如: 必须使用 Python 3.11]
- [业务约束, 如: 不能修改数据库 schema]

## 相关文件
- `./src/main.py` — [作用描述]
- `./config.yaml` — [作用描述]

## 关键决策
- [决策1]: [描述及原因] ([日期])

## 待探索
- [ ] [想法1]
- [ ] [想法2]

---
最后更新: [ISO 8601 日期时间]
```

### 更新规则

1. **每次交互后追加**：关键结论、新发现、修复的问题
2. **卡点变化时更新**：当前卡点解决后，记录解决方案，写入新卡点
3. **决策记录**：任何重要决策必须记录原因，避免重复讨论
4. **工具标记**：记录每条进展使用的工具（Claude/Codex/其他），便于追溯

## 快捷函数参考

| 函数 | 作用 | 示例 |
|------|------|------|
| `cc [参数]` | 启动 Claude **交互式**会话 + 上下文（原生参数透传） | `cc` / `cc -c` / `cc -p "q"` |
| `ck [参数]` | 启动 Kimi **交互式**会话 + 上下文（经 `AGENTS.md`） | `ck` |
| `co [参数]` | 启动 Codex **交互式**会话 + 上下文（经 `AGENTS.md`） | `co` |
| `ctx-sync` | 把上下文写入 `AGENTS.md`/`CLAUDE.md` 受管块，裸 CLI 也带上下文 | `ctx-sync` |
| `ctx-unsync` | 清除上述受管块 | `ctx-unsync` |
| `ctx` | 查看当前上下文摘要 | `ctx` |
| `ctx-edit` | 编辑上下文文件 | `ctx-edit` |
| `ctx-clear` | 清空当前任务上下文 | `ctx-clear` |

## 高级用法

### 多任务并行
为不同任务维护多个上下文文件：
```bash
.task-context.md          # 默认主任务
.task-context-feature-x.md # 功能X开发
.task-context-bug-123.md   # Bug修复
```
通过环境变量切换：
```bash
export TASK_CONTEXT=.task-context-feature-x.md
cc "继续开发"
```

### 上下文压缩
当文件过长时，自动压缩历史记录：
```bash
python ~/.qclaw/skills/task-context-relay/scripts/compress_context.py
```
保留关键决策和当前状态，归档已完成细节。

### 与 Git 集成
```bash
# .gitignore 中排除上下文文件（可选）
echo ".task-context.md" >> .gitignore

# 或提交到仓库，让协作者共享上下文
git add .task-context.md
git commit -m "docs: update task context"
```

## 故障排查

| 问题 | 原因 | 解决 |
|------|------|------|
| 快捷函数未找到 | Shell 未重新加载 | `source ~/.bashrc` 或重启终端 |
| 上下文未加载 | 文件不在当前目录 | 确认 `.task-context.md` 存在，或使用 `ctx-init` |
| 工具报文太长 | 上下文文件过大 | 运行压缩脚本或手动精简 |
| 中文乱码 | 编码问题 | 确保文件保存为 UTF-8 |

## 设计原则

1. **零成本**：不更换现有工具，不依赖外部服务
2. **原生优先**：启动各 CLI 原生交互式会话，按其原生能力注入上下文（Claude `--append-system-prompt`、Kimi/Codex `AGENTS.md`），原生参数全部透传
3. **显式控制 + 可逆**：用户决定何时更新上下文；写入 `AGENTS.md`/`CLAUDE.md` 的内容均在带标记的受管块中，`ctx-unsync` 可一键清除
4. **可审计**：纯文本文件，版本控制友好，随时可查历史

## 参考文件

- `references/context-template.md` — 上下文文件完整模板
- `references/shell-functions.sh` — Bash/Zsh 快捷函数完整版
- `references/shell-functions.ps1` — PowerShell 快捷函数完整版
