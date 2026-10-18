# Refresh the cloud repo from Studio and the local docs, then commit and push.
#
# Before running: open Roblox Studio on the SPELLSHOT place, with Assistant > ... > Manage MCP Servers >
# "Enable Studio as MCP server" switched on. Edit mode is best (Play mode reads the server side only).
#
#   powershell -ExecutionPolicy Bypass -File tools\refresh.ps1                # export, copy, commit, push
#   powershell -ExecutionPolicy Bypass -File tools\refresh.ps1 -NoPush        # stop after the local commit
#   powershell -ExecutionPolicy Bypass -File tools\refresh.ps1 -Source "E:\Spellshot - Atharv"
#
# It never force-pushes. If the push is rejected because the remote has new commits, it stops and says so.
param(
    [string]$Source = "D:\Spellshot - Atharv",
    [switch]$NoPush
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

$uv = (Get-Command uv -ErrorAction SilentlyContinue).Source
if (-not $uv) {
    $uv = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe\uv.exe"
}
if (-not (Test-Path $uv)) { throw "uv not found; install it (winget install astral-sh.uv) and re-run" }

function Step($label, [scriptblock]$body) {
    Write-Host "== $label"
    & $body
    if ($LASTEXITCODE -ne 0) { throw "$label failed (exit $LASTEXITCODE)" }
}

Step "export game tree from Studio" { & $uv run --no-project python (Join-Path $PSScriptRoot "export_game_tree.py") $repo }
Step "copy docs" { & $uv run --no-project python (Join-Path $PSScriptRoot "copy_docs.py") $repo $Source }
Step "copy sims" { & $uv run --no-project python (Join-Path $PSScriptRoot "copy_sims.py") $repo $Source }

Set-Location $repo
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host "Nothing changed since the last refresh."; exit 0 }
git diff --cached --stat | Select-Object -Last 1
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -q -m "Refresh from Studio and local docs, $stamp"
if ($LASTEXITCODE -ne 0) { throw "git commit failed" }

if ($NoPush) { Write-Host "Committed locally (-NoPush)."; exit 0 }
if (-not (git remote)) { Write-Host "Committed locally. No remote is set yet, so nothing was pushed."; exit 0 }
git push
if ($LASTEXITCODE -ne 0) {
    Write-Host "Push rejected. The remote has commits this copy lacks: run 'git pull --rebase', check the result, then 'git push'. Never force-push."
    exit 1
}
Write-Host "Pushed."
