$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$exePath = Join-Path $projectRoot 'build\windows\x64\runner\Release\qing_ting_music.exe'

Set-Location $projectRoot

Get-Process -Name 'qing_ting_music' -ErrorAction SilentlyContinue |
    Stop-Process -Force

Write-Host 'Building Windows release...' -ForegroundColor Cyan
flutter build windows

if (-not (Test-Path $exePath)) {
    throw "Build succeeded but executable was not found: $exePath"
}

Write-Host 'Starting QingTingMusic...' -ForegroundColor Green
Start-Process -FilePath $exePath
