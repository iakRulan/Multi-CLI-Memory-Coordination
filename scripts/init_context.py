#!/usr/bin/env python3
"""
Task Context Relay — 上下文文件初始化脚本
用法: python init_context.py [项目路径]
"""

import os
import sys
from datetime import datetime
from pathlib import Path

TEMPLATE = """# Task Context: [任务名称]

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
最后更新: {timestamp}
"""

def find_context_file(start_dir: Path, filename: str = ".task-context.md") -> Path | None:
    """向上递归查找上下文文件"""
    current = start_dir.resolve()
    while current != current.parent:
        candidate = current / filename
        if candidate.exists():
            return candidate
        current = current.parent
    # 全局回退
    global_candidate = Path.home() / filename
    if global_candidate.exists():
        return global_candidate
    return None

def init_context(target_dir: Path) -> Path:
    """初始化上下文文件"""
    ctx_file = target_dir / ".task-context.md"
    
    if ctx_file.exists():
        print(f"⚠️ 上下文文件已存在: {ctx_file}")
        confirm = input("是否覆盖? [y/N] ")
        if confirm.lower() != 'y':
            print("已取消")
            return ctx_file
    
    content = TEMPLATE.format(timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    ctx_file.write_text(content, encoding='utf-8')
    print(f"✅ 已创建上下文文件: {ctx_file}")
    print("📝 请编辑文件，将 [任务名称] 和占位符替换为实际内容")
    return ctx_file

def main():
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    target = target.resolve()
    
    # 检查是否已存在
    existing = find_context_file(target)
    if existing:
        print(f"📄 发现已有上下文文件: {existing}")
        print("   使用 ctx-edit 编辑，或指定其他目录初始化")
        return
    
    init_context(target)

if __name__ == "__main__":
    main()
