#!/usr/bin/env bash
# Task Context Relay — Shell 快捷函数 (Bash/Zsh)
# 多模型 CLI 上下文接力 / Multi-CLI memory coordination
# 用法: 在 ~/.bashrc 或 ~/.zshrc 中加入:  source /path/to/shell-functions.sh
#
# 设计: cc/co/ck 启动「原生交互式」会话并自动携带上下文，而不是一次性 -p 调用。
#   - Claude 支持 --append-system-prompt，上下文作为追加系统提示注入（不改任何文件）
#   - Kimi/Codex 无系统提示参数，但原生读取 AGENTS.md → 把上下文写入其中的受管块
#   - ctx-sync 把上下文同步进 AGENTS.md / CLAUDE.md，之后直接敲裸 claude/kimi/codex 也带上下文

# 上下文文件名（可用环境变量覆盖）
export TASK_CONTEXT_FILE="${TASK_CONTEXT_FILE:-.task-context.md}"

# 受管块标记
_TCR_BEGIN='<!-- task-context-relay:begin (auto-generated — 改 .task-context.md，勿手改本块) -->'
_TCR_END='<!-- task-context-relay:end -->'

# 向上递归查找上下文文件
_find_context_file() {
    local dir="$PWD"
    while [ -n "$dir" ] && [ "$dir" != "/" ]; do
        if [ -f "$dir/$TASK_CONTEXT_FILE" ]; then echo "$dir/$TASK_CONTEXT_FILE"; return 0; fi
        dir="$(dirname "$dir")"
    done
    if [ -f "$HOME/$TASK_CONTEXT_FILE" ]; then echo "$HOME/$TASK_CONTEXT_FILE"; return 0; fi
    return 1
}

# 生成注入到原生记忆文件的块正文
_tcr_context_body() {
    printf '# 当前任务上下文 / Active Task Context\n_(由 task-context-relay 从 %s 同步，请勿手改本块)_\n\n' "$TASK_CONTEXT_FILE"
    cat "$1"
}

# 从 stdin 移除受管块（含标记行），输出到 stdout
_tcr_strip_block() {
    awk -v b="$_TCR_BEGIN" -v e="$_TCR_END" '
        index($0, b) { skip=1 }
        skip { if (index($0, e)) { skip=0 } ; next }
        { print }
    '
}

# 写入/刷新受管块: $1=目标文件, 正文从 stdin
_tcr_set_block() {
    local target="$1"
    local body; body="$(cat)"
    local tmp; tmp="$(mktemp)"
    if [ -f "$target" ]; then
        _tcr_strip_block < "$target" > "$tmp"
        [ -s "$tmp" ] && printf '\n' >> "$tmp"
    fi
    {
        printf '%s\n' "$_TCR_BEGIN"
        printf '%s\n' "$body"
        printf '%s\n' "$_TCR_END"
    } >> "$tmp"
    mv "$tmp" "$target"
}

# 移除受管块: $1=目标文件（移除后若文件全空则删除文件）
_tcr_remove_block() {
    local target="$1"
    [ -f "$target" ] || return 1
    local tmp; tmp="$(mktemp)"
    _tcr_strip_block < "$target" > "$tmp"
    if grep -q '[^[:space:]]' "$tmp"; then mv "$tmp" "$target"; else rm -f "$tmp" "$target"; fi
    return 0
}

# ── 原生交互式启动器 ──────────────────────────────────────────────────

cc() {
    # Claude：原生交互式 + 上下文（追加系统提示，不污染任何文件）
    local f; f="$(_find_context_file)" || f=""
    if [ -z "$f" ]; then
        echo "⚠️ 未找到 $TASK_CONTEXT_FILE，启动无上下文的 Claude" >&2
        claude "$@"; return
    fi
    local ctx; ctx="$(cat "$f")"
    if [ "${#ctx}" -gt 25000 ]; then
        _tcr_context_body "$f" | _tcr_set_block "$PWD/CLAUDE.md"
        echo "📋 Claude ← 上下文较大，已同步至 $PWD/CLAUDE.md（受管块，ctx-unsync 清理）" >&2
        claude "$@"
    else
        echo "📋 Claude ← 上下文: $f" >&2
        claude --append-system-prompt "$ctx" "$@"
    fi
}

ck() {
    # Kimi：原生交互式 + 上下文（Kimi 无系统提示参数 → 同步到 AGENTS.md 受管块）
    local f; f="$(_find_context_file)" || f=""
    if [ -n "$f" ]; then
        _tcr_context_body "$f" | _tcr_set_block "$PWD/AGENTS.md"
        echo "📋 Kimi ← 上下文已同步至 $PWD/AGENTS.md（受管块，ctx-unsync 清理）" >&2
    else
        echo "⚠️ 未找到 $TASK_CONTEXT_FILE，启动无上下文的 Kimi" >&2
    fi
    kimi "$@"
}

co() {
    # Codex：原生交互式 + 上下文（Codex 原生读取 AGENTS.md）
    if ! command -v codex >/dev/null 2>&1; then echo "❌ 未找到 codex（不在 PATH）" >&2; return 1; fi
    local f; f="$(_find_context_file)" || f=""
    if [ -n "$f" ]; then
        _tcr_context_body "$f" | _tcr_set_block "$PWD/AGENTS.md"
        echo "📋 Codex ← 上下文已同步至 $PWD/AGENTS.md（受管块）" >&2
    else
        echo "⚠️ 未找到 $TASK_CONTEXT_FILE，启动无上下文的 Codex" >&2
    fi
    codex "$@"
}

# ── 记忆协调：同步进原生记忆文件，便于直接用裸 CLI ────────────────────

ctx-sync() {
    local f; f="$(_find_context_file)" || f=""
    if [ -z "$f" ]; then echo "❌ 未找到 $TASK_CONTEXT_FILE，先运行 ctx-init" >&2; return 1; fi
    local t
    for t in AGENTS.md CLAUDE.md; do
        _tcr_context_body "$f" | _tcr_set_block "$PWD/$t"
        echo "✅ 已同步 → $PWD/$t" >&2
    done
    echo "现在直接运行 claude / kimi / codex 即自动携带任务上下文。清理：ctx-unsync" >&2
}

ctx-unsync() {
    local t
    for t in AGENTS.md CLAUDE.md; do
        if _tcr_remove_block "$PWD/$t"; then echo "🧹 已清理受管块 → $PWD/$t" >&2; fi
    done
}

# ── 上下文文件管理 ────────────────────────────────────────────────────

ctx() {
    local f; f="$(_find_context_file)" || f=""
    if [ -z "$f" ]; then echo "❌ 未找到 $TASK_CONTEXT_FILE" >&2; return 1; fi
    echo "📄 $f  ($(wc -c < "$f" | tr -d ' ') 字节, $(wc -l < "$f" | tr -d ' ') 行)"
    echo "--- 章节 / Sections ---"
    grep -n '^## ' "$f" | sed 's/^/  /'
    echo "--- 最后更新 / Last Updated ---"
    grep -iE 'last updated:|最后更新:' "$f" | tail -n1 | sed 's/^/  /'
}

_ctx_template() {
    cat <<EOF
# Task Context: [任务名称]

## 目标
[一句话描述最终要达成什么]

## 背景
[相关背景信息]

## 已完成
- [ ]

## 当前卡点
- [ ]

## 约束条件
-

## 相关文件
-

## 关键决策
-

## 待探索
- [ ]

---
最后更新: $(date +%Y-%m-%d\ %H:%M:%S)
EOF
}

ctx-edit() {
    local f; f="$(_find_context_file)" || f=""
    if [ -z "$f" ]; then
        f="$PWD/$TASK_CONTEXT_FILE"
        _ctx_template > "$f"
        echo "📝 已创建: $f" >&2
    fi
    ${EDITOR:-nano} "$f"
}

ctx-init() {
    local target="${1:-$PWD}"
    local f="$target/$TASK_CONTEXT_FILE"
    if [ -f "$f" ]; then
        read -p "文件已存在，是否覆盖? [y/N] " confirm
        [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return 1
    fi
    _ctx_template > "$f"
    echo "✅ 已创建: $f" >&2
}

ctx-clear() {
    local f; f="$(_find_context_file)" || f=""
    if [ -z "$f" ]; then echo "❌ 未找到 $TASK_CONTEXT_FILE" >&2; return 1; fi
    read -p "清空 $f ? 将先自动备份 [y/N] " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        mv "$f" "${f}.bak.$(date +%Y%m%d_%H%M%S)"
        echo "✅ 已备份并清空" >&2
    else
        echo "已取消" >&2
    fi
}

ctx-help() {
    cat <<'EOF'

Task Context Relay — 快捷参考
-----------------------------------------
原生交互式启动器（自动注入上下文）:
  cc [args]   启动 Claude 交互式会话 + 上下文（透传原生参数，如 cc -c / cc -p "q"）
  ck [args]   启动 Kimi  交互式会话 + 上下文（经 AGENTS.md 受管块）
  co [args]   启动 Codex 交互式会话 + 上下文（经 AGENTS.md 受管块）

记忆协调（让裸 CLI 也带上下文）:
  ctx-sync    把上下文写入 AGENTS.md / CLAUDE.md 受管块
  ctx-unsync  清除上述受管块

上下文文件管理:
  ctx         显示上下文摘要（章节 + 最后更新）
  ctx-edit    编辑上下文文件（不存在则创建）
  ctx-init    在当前目录初始化上下文
  ctx-clear   清空上下文（自动备份）
  ctx-help    显示本帮助

环境变量: TASK_CONTEXT_FILE (默认 .task-context.md)
EOF
}
