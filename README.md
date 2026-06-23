# Task Context Relay

> 多模型 CLI 任务上下文接力工具 —— 换工具不换记忆

在 Codex CLI、Claude CLI、Kimi CLI 等不同 AI 工具间切换时，无需重复解释任务背景。通过一个 `.task-context.md` 文件作为"外部共享记忆"，实现跨工具的上下文无缝延续。

## 问题

每个 AI CLI 工具（Claude、Codex、Kimi）都是独立进程，不共享对话历史。切换工具时你不得不：

- 重复粘贴任务背景
- 重新描述当前进度
- 丢失之前的关键决策和上下文

## 解决方案

在项目中维护一个 `.task-context.md` 文件，记录任务全貌。Shell 快捷函数在调用工具时自动注入上下文：

```
cc "优化这个函数"   → Claude 读取上下文 + 执行
co "写单元测试"     → Codex 读取同一上下文 + 执行
ck "看看这段代码"   → Kimi 读取同一上下文 + 执行
```

## 安装

### 1. 克隆仓库

```bash
git clone https://github.com/iakRulan/task-context-relay.git
cd task-context-relay
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
| `cc <指令>` | 调用 Claude CLI，自动注入上下文 |
| `co <指令>` | 调用 Codex CLI，自动注入上下文 |
| `ck <指令>` | 调用 Kimi CLI，自动注入上下文 |
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

# 4. 使用某个 AI 工具
cc "帮我优化这个函数的性能"

# 5. 手动将关键结论追加到 .task-context.md

# 6. 切换工具继续，上下文无缝衔接
co "为优化后的函数写单元测试"
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
1. 向上查找 .task-context.md
2. 读取文件内容
3. 拼接到用户指令前面
4. 调用对应 CLI 工具
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

- **零依赖** — 不需要额外安装，纯 Shell 函数
- **显式控制** — 用户决定何时更新上下文，没有自动同步的副作用
- **工具无关** — 任何支持 `-p` / `--prompt` 参数的 CLI 工具都可接入
- **纯文本** — Markdown 文件，Git 友好，可版本控制

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `TASK_CONTEXT_FILE` | `.task-context.md` | 上下文文件名 |

## License

MIT
