#!/bin/bash
# Task Context Relay — Shell 快捷函数 (Bash/Zsh)
# 用法: 将以下内容添加到 ~/.bashrc 或 ~/.zshrc，然后 source 或重启终端

# 配置: 上下文文件名（可通过环境变量覆盖）
export TASK_CONTEXT_FILE="${TASK_CONTEXT_FILE:-.task-context.md}"

# 查找上下文文件（向上递归）
_find_context_file() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/$TASK_CONTEXT_FILE" ]]; then
            echo "$dir/$TASK_CONTEXT_FILE"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    # 检查全局回退
    if [[ -f "$HOME/$TASK_CONTEXT_FILE" ]]; then
        echo "$HOME/$TASK_CONTEXT_FILE"
        return 0
    fi
    return 1
}

# 获取上下文内容
_get_context() {
    local ctx_file="$(_find_context_file)"
    if [[ -n "$ctx_file" ]]; then
        cat "$ctx_file"
        return 0
    fi
    return 1
}

# Claude CLI 带上下文注入
cc() {
    local ctx=""
    local ctx_file="$(_find_context_file)"
    
    if [[ -n "$ctx_file" ]]; then
        ctx="$(cat "$ctx_file")"
        local lines=$(wc -l < "$ctx_file" | tr -d ' ')
        echo "📋 已加载任务上下文 ($lines 行) — $ctx_file" >&2
    else
        echo "⚠️ 未找到 $TASK_CONTEXT_FILE，将无上下文运行" >&2
    fi
    
    local user_input="$*"
    if [[ -z "$user_input" ]]; then
        echo "用法: cc <你的指令>" >&2
        return 1
    fi
    
    # 构建提示: 上下文 + 分隔线 + 用户指令
    local prompt=""
    if [[ -n "$ctx" ]]; then
        prompt="${ctx}\n\n---\n\n【用户新指令】\n${user_input}"
    else
        prompt="${user_input}"
    fi
    
    claude "$@" -p "$prompt"
}

# Codex CLI 带上下文注入
co() {
    local ctx=""
    local ctx_file="$(_find_context_file)"
    
    if [[ -n "$ctx_file" ]]; then
        ctx="$(cat "$ctx_file")"
        local lines=$(wc -l < "$ctx_file" | tr -d ' ')
        echo "📋 已加载任务上下文 ($lines 行) — $ctx_file" >&2
    else
        echo "⚠️ 未找到 $TASK_CONTEXT_FILE，将无上下文运行" >&2
    fi
    
    local user_input="$*"
    if [[ -z "$user_input" ]]; then
        echo "用法: co <你的指令>" >&2
        return 1
    fi
    
    local prompt=""
    if [[ -n "$ctx" ]]; then
        prompt="${ctx}\n\n---\n\n【用户新指令】\n${user_input}"
    else
        prompt="${user_input}"
    fi
    
    codex "$@" --prompt "$prompt"
}

# 查看当前上下文摘要
ctx() {
    local ctx_file="$(_find_context_file)"
    if [[ -z "$ctx_file" ]]; then
        echo "❌ 未找到 $TASK_CONTEXT_FILE"
        return 1
    fi
    
    echo "📄 上下文文件: $ctx_file"
    echo "📊 文件大小: $(wc -c < "$ctx_file" | tr -d ' ') 字节, $(wc -l < "$ctx_file" | tr -d ' ') 行"
    echo ""
    
    # 提取关键部分
    echo "🎯 目标:"
    grep -A 2 "^## 目标" "$ctx_file" | tail -n +2 | head -n 3
    echo ""
    
    echo "🚧 当前卡点:"
    grep -A 3 "^## 当前卡点" "$ctx_file" | tail -n +2 | head -n 5
    echo ""
    
    echo "✅ 最近完成:"
    grep "^\- \[x\]" "$ctx_file" | tail -n 3
    echo ""
    
    echo "🕐 最后更新:"
    grep "最后更新:" "$ctx_file" | tail -n 1
}

# 编辑上下文文件
ctx-edit() {
    local ctx_file="$(_find_context_file)"
    if [[ -z "$ctx_file" ]]; then
        # 在当前目录创建
        ctx_file="$PWD/$TASK_CONTEXT_FILE"
        echo "📝 创建新上下文文件: $ctx_file"
        cat > "$ctx_file" << 'EOF'
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
    fi
    
    ${EDITOR:-nano} "$ctx_file"
}

# 初始化上下文文件
ctx-init() {
    local target="${1:-$PWD}"
    local ctx_file="$target/$TASK_CONTEXT_FILE"
    
    if [[ -f "$ctx_file" ]]; then
        echo "⚠️ 上下文文件已存在: $ctx_file"
        read -p "是否覆盖? [y/N] " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 1
    fi
    
    cat > "$ctx_file" << 'EOF'
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
    
    echo "✅ 已创建上下文文件: $ctx_file"
    echo "📝 请编辑文件，将 [任务名称] 和占位符替换为实际内容"
}

# 清空上下文（谨慎使用）
ctx-clear() {
    local ctx_file="$(_find_context_file)"
    if [[ -z "$ctx_file" ]]; then
        echo "❌ 未找到上下文文件"
        return 1
    fi
    
    read -p "⚠️ 确定要清空 $ctx_file 吗? 此操作不可撤销 [y/N] " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        mv "$ctx_file" "${ctx_file}.bak.$(date +%Y%m%d_%H%M%S)"
        echo "✅ 已备份并清空上下文文件"
    else
        echo "已取消"
    fi
}

# 显示帮助
ctx-help() {
    cat << 'EOF'
Task Context Relay — 快捷函数帮助

cc <指令>     — 调用 Claude CLI，自动注入上下文
co <指令>     — 调用 Codex CLI，自动注入上下文
ctx           — 查看当前上下文摘要
ctx-edit      — 编辑上下文文件
ctx-init      — 在当前目录初始化上下文文件
ctx-clear     — 清空上下文（会自动备份）
ctx-help      — 显示此帮助

环境变量:
  TASK_CONTEXT_FILE  — 上下文文件名（默认: .task-context.md）

示例:
  cc "优化这个函数的性能"
  co "为 utils.py 写单元测试"
  ctx
  ctx-edit
EOF
}
