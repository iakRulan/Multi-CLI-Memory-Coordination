<#
  Task Context Relay - PowerShell Quick Functions
  Add to $PROFILE: . "C:\Users\86198\.qclaw\skills\task-context-relay\references\shell-functions.ps1"
#>

$env:TASK_CONTEXT_FILE = if ($env:TASK_CONTEXT_FILE) { $env:TASK_CONTEXT_FILE } else { ".task-context.md" }

function _Find-ContextFile {
    $dir = Get-Location
    while ($dir -and $dir.Path -ne $dir.Root) {
        $cand = Join-Path $dir.Path $env:TASK_CONTEXT_FILE
        if (Test-Path $cand) { return $cand }
        $dir = $dir.Parent
    }
    $g = Join-Path $HOME $env:TASK_CONTEXT_FILE
    if (Test-Path $g) { return $g }
    return $null
}

function cc {
    $f = _Find-ContextFile
    $ctx = ""
    if ($f) {
        $ctx = Get-Content $f -Raw
        $n = (Get-Content $f).Count
        Write-Host "Loaded context ($n lines) - $f" -ForegroundColor Cyan
    } else {
        Write-Host "No .task-context.md found" -ForegroundColor Yellow
    }
    $inp = $args -join " "
    if (-not $inp) { Write-Host "Usage: cc <command>" -ForegroundColor Red; return }
    $p = if ($ctx) { "$ctx`n`n---`n`n[New Instruction]`n$inp" } else { $inp }
    claude $args -p $p
}

function co {
    $f = _Find-ContextFile
    $ctx = ""
    if ($f) {
        $ctx = Get-Content $f -Raw
        $n = (Get-Content $f).Count
        Write-Host "Loaded context ($n lines) - $f" -ForegroundColor Cyan
    } else {
        Write-Host "No .task-context.md found" -ForegroundColor Yellow
    }
    $inp = $args -join " "
    if (-not $inp) { Write-Host "Usage: co <command>" -ForegroundColor Red; return }
    $p = if ($ctx) { "$ctx`n`n---`n`n[New Instruction]`n$inp" } else { $inp }
    codex $args --prompt $p
}

function ctx {
    $f = _Find-ContextFile
    if (-not $f) { Write-Host "No .task-context.md found" -ForegroundColor Red; return }
    $bytes = (Get-Item $f).Length
    $lines = (Get-Content $f).Count
    Write-Host "File: $f  ($bytes bytes, $lines lines)"
    Write-Host "--- Sections ---" -ForegroundColor Green
    Get-Content $f | Select-String "^## " | ForEach-Object { Write-Host "  $_" }
    Write-Host "--- Last Updated ---" -ForegroundColor Gray
    Get-Content $f | Select-String "Last updated:" | Select-Object -Last 1 | ForEach-Object { Write-Host "  $_" }
}

function ctx-edit {
    $f = _Find-ContextFile
    if (-not $f) {
        $f = Join-Path (Get-Location) $env:TASK_CONTEXT_FILE
        $d = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $tpl = "# Task Context`n`n## Goal`n[describe goal]`n`n## Completed`n- `n`n## Blockers`n- `n`n## Key Decisions`n- `n`n---`nLast updated: $d"
        [System.IO.File]::WriteAllText($f, $tpl, [System.Text.Encoding]::UTF8)
        Write-Host "Created: $f" -ForegroundColor Cyan
    }
    notepad $f
}

function ctx-init {
    $target = if ($args.Count -gt 0) { $args[0] } else { (Get-Location).Path }
    $f = Join-Path $target $env:TASK_CONTEXT_FILE
    if (Test-Path $f) {
        $c = Read-Host "File exists. Overwrite? [y/N]"
        if ($c -ne "y" -and $c -ne "Y") { return }
    }
    $d = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tpl = "# Task Context`n`n## Goal`n[describe goal]`n`n## Completed`n- `n`n## Blockers`n- `n`n## Key Decisions`n- `n`n---`nLast updated: $d"
    [System.IO.File]::WriteAllText($f, $tpl, [System.Text.Encoding]::UTF8)
    Write-Host "Created: $f" -ForegroundColor Green
}

function ctx-clear {
    $f = _Find-ContextFile
    if (-not $f) { Write-Host "No .task-context.md found" -ForegroundColor Red; return }
    $c = Read-Host "Clear $f ? This cannot be undone [y/N]"
    if ($c -eq "y" -or $c -eq "Y") {
        $bak = "$f.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Move-Item $f $bak
        Write-Host "Backed up to $bak" -ForegroundColor Green
    }
}

function ctx-help {
    Write-Host @"

Task Context Relay - Quick Reference
-------------------------------------
cc <command>   Call Claude CLI with context injection
co <command>   Call Codex CLI with context injection
ck <command>   Call Kimi CLI with context injection
ctx            Show context summary
ctx-edit       Edit context file
ctx-init       Initialize context file in current directory
ctx-clear      Clear context (auto-backup)
ctx-help       Show this help

Env: TASK_CONTEXT_FILE = $env:TASK_CONTEXT_FILE
"@ -ForegroundColor Cyan
}

function ck {
    $f = _Find-ContextFile
    $ctx = ""
    if ($f) {
        $ctx = Get-Content $f -Raw
        $n = (Get-Content $f).Count
        Write-Host "Loaded context ($n lines) - $f" -ForegroundColor Cyan
    } else {
        Write-Host "No .task-context.md found" -ForegroundColor Yellow
    }
    $inp = $args -join " "
    if (-not $inp) { Write-Host "Usage: ck <command>" -ForegroundColor Red; return }
    $p = if ($ctx) { "$ctx`n`n---`n`n[New Instruction]`n$inp" } else { $inp }
    kimi $args -p $p
}

Set-Alias -Name tcr -Value ctx-help
