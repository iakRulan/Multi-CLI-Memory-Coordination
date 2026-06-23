#!/usr/bin/env python3
"""
Task Context Relay — 上下文文件压缩脚本
当上下文文件过长时，自动压缩历史记录，保留关键决策和当前状态。
用法: python compress_context.py [文件路径]
"""

import re
import sys
from datetime import datetime
from pathlib import Path

def compress_context(filepath: Path) -> str:
    """压缩上下文文件，保留关键信息"""
    content = filepath.read_text(encoding='utf-8')
    
    # 提取各个部分
    sections = {}
    current_section = None
    current_content = []
    
    for line in content.split('\n'):
        if line.startswith('## '):
            if current_section:
                sections[current_section] = '\n'.join(current_content)
            current_section = line[3:].strip()
            current_content = []
        else:
            current_content.append(line)
    
    if current_section:
        sections[current_section] = '\n'.join(current_content)
    
    # 压缩"已完成"：只保留最近5条和关键里程碑
    if '已完成' in sections:
        completed = sections['已完成'].strip().split('\n')
        # 保留所有带 [x] 的行
        done_items = [l for l in completed if l.strip().startswith('- [x]')]
        # 只保留最近5条
        recent_done = done_items[-5:] if len(done_items) > 5 else done_items
        sections['已完成'] = '\n'.join(recent_done) + '\n\n[历史记录已归档，共 {} 条完成项]'.format(len(done_items))
    
    # 压缩"关键决策"：保留所有（通常不多）
    # 压缩"待探索"：保留未完成的
    if '待探索' in sections:
        exploring = sections['待探索'].strip().split('\n')
        pending = [l for l in exploring if l.strip().startswith('- [ ]')]
        sections['待探索'] = '\n'.join(pending) if pending else '- [ ] （暂无）'
    
    # 重建文件
    order = ['目标', '背景', '已完成', '当前卡点', '约束条件', '相关文件', '关键决策', '待探索']
    
    result = [f"# Task Context: [压缩后]\n"]
    for section in order:
        if section in sections:
            result.append(f"## {section}")
            result.append(sections[section].strip())
            result.append("")
    
    result.append(f"---\n最后更新: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    result.append("[注: 此文件已由 compress_context.py 压缩，历史详情见备份]")
    
    return '\n'.join(result)

def main():
    filepath = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.task-context.md')
    
    if not filepath.exists():
        print(f"❌ 文件不存在: {filepath}")
        return
    
    # 备份原文件
    backup = filepath.with_suffix(f'.md.bak_{datetime.now().strftime("%Y%m%d_%H%M%S")}')
    filepath.rename(backup)
    print(f"📦 已备份原文件: {backup}")
    
    # 写入压缩后内容
    compressed = compress_context(backup)
    filepath.write_text(compressed, encoding='utf-8')
    
    original_size = backup.stat().st_size
    new_size = filepath.stat().st_size
    
    print(f"✅ 压缩完成: {filepath}")
    print(f"   原大小: {original_size} 字节")
    print(f"   新大小: {new_size} 字节")
    print(f"   减少: {original_size - new_size} 字节 ({(1 - new_size/original_size)*100:.1f}%)")

if __name__ == "__main__":
    main()
