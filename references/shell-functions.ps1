<#
  Task Context Relay — PowerShell 快捷函数
  多模型 CLI 上下文接力 / Multi-CLI memory coordination

  在 $PROFILE 中加入:
    . "C:\Users\86198\.qclaw\skills\task-context-relay\references\shell-functions.ps1"
  然后重开 PowerShell，或执行:  . $PROFILE

  注意: 本文件须以 UTF-8 (带 BOM) 保存，否则 Windows PowerShell 5.1 会按 GBK 解析导致乱码/报错。

  设计：cc/co/ck 启动「原生交互式」会话并自动携带上下文，而不是一次性 -p 调用。
    - Claude 支持 --append-system-prompt，上下文作为追加系统提示注入（不改任何文件）
    - Kimi/Codex 无系统提示参数，但原生读取 AGENTS.md → 把上下文写入其中的受管块
    - ctx-sync 把上下文同步进 AGENTS.md / CLAUDE.md，之后直接敲裸 claude/kimi/codex 也带上下文
#>

# 上下文文件名（可用环境变量覆盖）
$env:TASK_CONTEXT_FILE = if ($env:TASK_CONTEXT_FILE) { $env:TASK_CONTEXT_FILE } else { ".task-context.md" }

# 注入到原生记忆文件 (AGENTS.md / CLAUDE.md) 的受管块标记
$script:TcrBegin = '<!-- task-context-relay:begin (auto-generated — 改 .task-context.md，勿手改本块) -->'
$script:TcrEnd   = '<!-- task-context-relay:end -->'

# 统一以 UTF-8 读写，避免 PS5.1 默认 GBK 导致的乱码与匹配失败
function _Read-Utf8 {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return "" }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function _Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function _Find-ContextFile {
    $dir = Get-Location
    while ($dir -and $dir.Path -ne $dir.Root) {
        $cand = Join-Path $dir.Path $env:TASK_CONTEXT_FILE
        if (Test-Path $cand) { return (Resolve-Path $cand).Path }
        $dir = $dir.Parent
    }
    $g = Join-Path $HOME $env:TASK_CONTEXT_FILE
    if (Test-Path $g) { return $g }
    return $null
}

function _Context-Body {
    param([string]$ContextFile)
    $ctx = _Read-Utf8 $ContextFile
    return "# 当前任务上下文 / Active Task Context`n_(由 task-context-relay 从 $env:TASK_CONTEXT_FILE 同步，请勿手改本块)_`n`n$ctx"
}

function _Set-ManagedBlock {
    # 在原生记忆文件中写入/刷新受管上下文块，保留文件其余内容
    param([string]$TargetFile, [string]$Body)
    $block = "$script:TcrBegin`n$Body`n$script:TcrEnd"
    $cur = _Read-Utf8 $TargetFile
    $bi = $cur.IndexOf($script:TcrBegin)
    $ei = $cur.IndexOf($script:TcrEnd)
    if ($bi -ge 0 -and $ei -gt $bi) {
        $new = $cur.Substring(0, $bi) + $block + $cur.Substring($ei + $script:TcrEnd.Length)
    } elseif ($cur.Trim().Length -eq 0) {
        $new = $block + "`n"
    } else {
        $new = $cur.TrimEnd() + "`n`n" + $block + "`n"
    }
    _Write-Utf8NoBom -Path $TargetFile -Text $new
}

function _Remove-ManagedBlock {
    param([string]$TargetFile)
    if (-not (Test-Path $TargetFile)) { return $false }
    $cur = _Read-Utf8 $TargetFile
    $bi = $cur.IndexOf($script:TcrBegin)
    $ei = $cur.IndexOf($script:TcrEnd)
    if ($bi -lt 0 -or $ei -le $bi) { return $false }
    $new = ($cur.Substring(0, $bi) + $cur.Substring($ei + $script:TcrEnd.Length)).Trim()
    if ($new.Length -eq 0) { Remove-Item $TargetFile }
    else { _Write-Utf8NoBom -Path $TargetFile -Text ($new + "`n") }
    return $true
}

# ── 原生交互式启动器 ──────────────────────────────────────────────────

function cc {
    # Claude：原生交互式 + 上下文（作为追加系统提示，不污染任何文件）
    $f = _Find-ContextFile
    if (-not $f) {
        Write-Host "⚠️ 未找到 $env:TASK_CONTEXT_FILE，启动无上下文的 Claude" -ForegroundColor Yellow
        claude @args
        return
    }
    $ctx = _Read-Utf8 $f
    if ($ctx.Length -gt 25000) {
        # 上下文过大，命令行参数可能超限 → 改用 CLAUDE.md 受管块
        $cmd = Join-Path (Get-Location).Path "CLAUDE.md"
        _Set-ManagedBlock -TargetFile $cmd -Body (_Context-Body $f)
        Write-Host "📋 Claude ← 上下文较大，已同步至 $cmd（受管块，ctx-unsync 清理）" -ForegroundColor Cyan
        claude @args
    } else {
        Write-Host "📋 Claude ← 上下文: $f" -ForegroundColor Cyan
        claude --append-system-prompt $ctx @args
    }
}

function ck {
    # Kimi：原生交互式 + 上下文（Kimi 无系统提示参数 → 同步到 AGENTS.md 受管块）
    $f = _Find-ContextFile
    if ($f) {
        $agents = Join-Path (Get-Location).Path "AGENTS.md"
        _Set-ManagedBlock -TargetFile $agents -Body (_Context-Body $f)
        Write-Host "📋 Kimi ← 上下文已同步至 $agents（受管块，ctx-unsync 清理）" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️ 未找到 $env:TASK_CONTEXT_FILE，启动无上下文的 Kimi" -ForegroundColor Yellow
    }
    kimi @args
}

function co {
    # Codex：原生交互式 + 上下文（Codex 原生读取 AGENTS.md）
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        Write-Host "❌ 未找到 codex（不在 PATH）" -ForegroundColor Red; return
    }
    $f = _Find-ContextFile
    if ($f) {
        $agents = Join-Path (Get-Location).Path "AGENTS.md"
        _Set-ManagedBlock -TargetFile $agents -Body (_Context-Body $f)
        Write-Host "📋 Codex ← 上下文已同步至 $agents（受管块）" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️ 未找到 $env:TASK_CONTEXT_FILE，启动无上下文的 Codex" -ForegroundColor Yellow
    }
    codex @args
}

# ── 记忆协调：同步进原生记忆文件，便于直接用裸 CLI ────────────────────

function ctx-sync {
    # 写入 AGENTS.md (Kimi/Codex) 和 CLAUDE.md (Claude)，之后直接敲 claude/kimi/codex 即带上下文
    $f = _Find-ContextFile
    if (-not $f) { Write-Host "❌ 未找到 $env:TASK_CONTEXT_FILE，先运行 ctx-init" -ForegroundColor Red; return }
    $body = _Context-Body $f
    foreach ($t in @("AGENTS.md", "CLAUDE.md")) {
        $tp = Join-Path (Get-Location).Path $t
        _Set-ManagedBlock -TargetFile $tp -Body $body
        Write-Host "✅ 已同步 → $tp" -ForegroundColor Green
    }
    Write-Host "现在直接运行 claude / kimi / codex 即自动携带任务上下文。清理：ctx-unsync" -ForegroundColor Cyan
}

function ctx-unsync {
    foreach ($t in @("AGENTS.md", "CLAUDE.md")) {
        $tp = Join-Path (Get-Location).Path $t
        if (_Remove-ManagedBlock -TargetFile $tp) { Write-Host "🧹 已清理受管块 → $tp" -ForegroundColor Gray }
    }
}

# ── 上下文文件管理 ────────────────────────────────────────────────────

function ctx {
    $f = _Find-ContextFile
    if (-not $f) { Write-Host "❌ 未找到 $env:TASK_CONTEXT_FILE" -ForegroundColor Red; return }
    $text = _Read-Utf8 $f
    $lines = $text -split "`r?`n"
    Write-Host "📄 $f  ($((Get-Item $f).Length) bytes, $($lines.Count) lines)"
    Write-Host "--- 章节 / Sections ---" -ForegroundColor Green
    $lines | Where-Object { $_ -match '^## ' } | ForEach-Object { Write-Host "  $($_.TrimEnd())" }
    Write-Host "--- 最后更新 / Last Updated ---" -ForegroundColor Gray
    $lines | Where-Object { $_ -match '(?i)last updated:|最后更新:' } | Select-Object -Last 1 | ForEach-Object { Write-Host "  $($_.Trim())" }
}

$script:CtxTemplate = "# Task Context`n`n## Goal`n[describe goal]`n`n## Completed`n- `n`n## Blockers`n- `n`n## Key Decisions`n- `n`n---`nLast updated: {0}"

function ctx-edit {
    $f = _Find-ContextFile
    if (-not $f) {
        $f = Join-Path (Get-Location).Path $env:TASK_CONTEXT_FILE
        $d = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        _Write-Utf8NoBom -Path $f -Text ($script:CtxTemplate -f $d)
        Write-Host "📝 已创建: $f" -ForegroundColor Cyan
    }
    notepad $f
}

function ctx-init {
    $target = if ($args.Count -gt 0) { $args[0] } else { (Get-Location).Path }
    $f = Join-Path $target $env:TASK_CONTEXT_FILE
    if (Test-Path $f) {
        $c = Read-Host "文件已存在，是否覆盖? [y/N]"
        if ($c -ne "y" -and $c -ne "Y") { return }
    }
    $d = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    _Write-Utf8NoBom -Path $f -Text ($script:CtxTemplate -f $d)
    Write-Host "✅ 已创建: $f" -ForegroundColor Green
}

function ctx-clear {
    $f = _Find-ContextFile
    if (-not $f) { Write-Host "❌ 未找到 $env:TASK_CONTEXT_FILE" -ForegroundColor Red; return }
    $c = Read-Host "清空 $f ? 将先自动备份 [y/N]"
    if ($c -eq "y" -or $c -eq "Y") {
        $bak = "$f.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Move-Item $f $bak
        Write-Host "✅ 已备份到 $bak" -ForegroundColor Green
    }
}

function ctx-help {
    Write-Host @"

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

环境变量: TASK_CONTEXT_FILE = $env:TASK_CONTEXT_FILE
"@ -ForegroundColor Cyan
}

Set-Alias -Name tcr -Value ctx-help
