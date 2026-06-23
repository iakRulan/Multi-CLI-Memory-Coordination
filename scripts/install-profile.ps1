$profilePath = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$sourceLine = '. "C:\Users\86198\.qclaw\skills\task-context-relay\references\shell-functions.ps1"'

if (-not (Test-Path $profilePath)) {
    New-Item -Path $profilePath -ItemType File -Force | Out-Null
}

$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

if ($profileContent -notmatch [regex]::Escape($sourceLine)) {
    Add-Content -Path $profilePath -Value "`n# Task Context Relay`n$sourceLine`n" -Encoding UTF8
    Write-Host "✅ 已添加到 PowerShell profile" -ForegroundColor Green
} else {
    Write-Host "ℹ️ 已存在于 profile 中" -ForegroundColor Cyan
}

Write-Host "`n📄 Profile 路径: $profilePath" -ForegroundColor Gray
