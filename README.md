# Task Context Relay

> 多模型 CLI 任务上下文接力工具 —— 换工具不换记忆

在 Codex CLI、Claude CLI、Kimi CLI 等不同 AI 工具间切换时，无需重复解释任务背景。通过一个 `.task-context.md` 文件作为"外部共享记忆"，实现跨工具的上下文无缝延续。

## 问题

每个 AI CLI 工具（Claude、Codex、Kimi）都是独立进程，不共享对话历史。切换工具时你不得不：

- 重复粘贴任务背景
- 重新描述当前进度
- 丢失之前的关键决策和上下文

## 解决方案

在项目中维护一个 `.task-context.md` 文件，记录任务全貌。Shell 快捷函数启动**原生交互式**会话并自动携带上下文（不是一次性 `-p` 调用）：

```
cc            → 启动 Claude 交互式会话，自动带上任务上下文
ck            → 启动 Kimi  交互式会话，自动带上任务上下文
co            → 启动 Codex 交互式会话，自动带上任务上下文
```

注入机制按各 CLI 的原生能力：Claude 用 `--append-system-prompt`（不改任何文件）；Kimi/Codex 原生读取 `AGENTS.md`，故把上下文写入其中一个带标记的「受管块」。原生参数透传，例如 `cc -c` 续接上次会话、`cc -p "快速问题"` 仍可一次性调用。

## 安装

### 1. 克隆仓库

```bash
git clone https://github.com/iakRulan/Multi-CLI-Memory-Coordination.git
cd Multi-CLI-Memory-Coordination
```

### 2. 配置 Shell

**PowerShell（推荐）**

在 `$PROFILE` 中添加：

```powershell
. "C:\path\to\task-context-relay\references\shell-functions.ps1"
```

然后重启终端或执行 `. $PROFILE`。

**Bash / Zsh**

```bash
source /path/to/task-context-relay/references/shell-functions.sh
```

或加到 `~/.bashrc` / `~/.zshrc`。

## 使用

### 快捷函数一览

| 命令 | 作用 |
|------|------|
| `cc [参数]` | 启动 Claude **交互式**会话 + 上下文（透传原生参数，如 `cc -c`、`cc -p "q"`） |
| `co [参数]` | 启动 Codex **交互式**会话 + 上下文（经 `AGENTS.md` 受管块） |
| `ck [参数]` | 启动 Kimi **交互式**会话 + 上下文（经 `AGENTS.md` 受管块） |
| `ctx-sync` | 把上下文写入 `AGENTS.md` / `CLAUDE.md` 受管块，之后直接敲裸 `claude`/`kimi`/`codex` 也带上下文 |
| `ctx-unsync` | 清除上述受管块 |
| `ctx` | 查看当前上下文摘要 |
| `ctx-edit` | 编辑上下文文件（不存在则创建） |
| `ctx-init` | 在当前目录初始化上下文模板 |
| `ctx-clear` | 清空上下文（自动备份） |
| `ctx-help` | 显示帮助 |

### 典型工作流

```powershell
# 1. 进入项目目录
cd my-project

# 2. 初始化上下文
ctx-init

# 3. 编辑上下文（填写任务目标、背景等）
ctx-edit

# 4. 启动 Claude 交互式会话（已带上下文，可自由多轮对话）
cc

# 5. 退出后，手动将关键结论追加到 .task-context.md（或让 AI 帮你更新）

# 6. 切换工具继续，上下文无缝衔接
ck            # 启动 Kimi 交互式会话，读取同一份上下文
```

### 查看上下文状态

```powershell
ctx
```

输出示例：

```
File: C:\Projects\my-project\.task-context.md  (1024 bytes, 42 lines)
--- Sections ---
  ## Goal
  ## Completed
  ## Blockers
  ## Key Decisions
--- Last Updated ---
  Last updated: 2026-06-23 23:00:00
```

## 上下文文件格式

`.task-context.md` 是纯 Markdown，结构如下：

```markdown
# Task Context: [任务名称]

## Goal
[一句话描述最终目标]

## Background
[相关背景信息]

## Completed
- [x] 步骤1 (2026-06-23, Claude)

## Blockers
- [ ] 当前遇到的问题

## Constraints
- 技术约束或限制

## Related Files
- `src/main.py` — 核心模块

## Key Decisions
- 选择方案A，原因是...

## To Explore
- [ ] 待调研的想法

---
Last updated: 2026-06-23 23:00:00
```

## 工作原理

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Claude CLI │     │ .task-context.md  │     │  Codex CLI  │
│             │◄────│   (共享记忆文件)   │────►│             │
└─────────────┘     └──────────────────┘     └─────────────┘
                            ▲
                            │
                     ┌──────┴──────┐
                     │  Kimi CLI   │
                     └─────────────┘

cc/co/ck 命令自动:
1. 向上查找 .task-context.md（找不到则回退到 ~/.task-context.md）
2. 读取文件内容
3. 按各 CLI 原生能力注入上下文:
   - Claude → --append-system-prompt（不改任何文件）
   - Kimi/Codex → 写入 AGENTS.md 受管块（原生读取）
4. 启动对应 CLI 的「交互式」会话（原生参数透传）
```

## 项目结构

```
task-context-relay/
├── README.md                           # 本文件
├── SKILL.md                            # AI Skill 定义（OpenClaw 用）
├── references/
│   ├── context-template.md             # 上下文文件模板
│   ├── shell-functions.ps1             # PowerShell 快捷函数
│   └── shell-functions.sh              # Bash/Zsh 快捷函数
└── scripts/
    ├── init_context.py                 # 初始化上下文脚本
    └── compress_context.py             # 上下文压缩脚本
```

## 设计原则

- **原生优先** — 启动各 CLI 的原生交互式会话，按其原生能力注入上下文（Claude `--append-system-prompt`、Kimi/Codex `AGENTS.md`），原生参数全部透传
- **零依赖** — 不需要额外安装，纯 Shell 函数
- **显式控制 + 可逆** — 用户决定何时更新上下文；写入 `AGENTS.md`/`CLAUDE.md` 的内容均放在带标记的受管块中，`ctx-unsync` 可一键清除，不污染你的手写内容
- **纯文本** — Markdown 文件，Git 友好，可版本控制

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TASK_CONTEXT_FILE` | `.task-context.md` | 上下文文件名 |

## License

MIT
