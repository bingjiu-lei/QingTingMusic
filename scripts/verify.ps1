$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host 'Formatting Dart files...' -ForegroundColor Cyan
dart format lib test

Write-Host 'Running Flutter analyze...' -ForegroundColor Cyan
flutter analyze

Write-Host 'Running Flutter tests...' -ForegroundColor Cyan
flutter test

Write-Host 'Building Windows release...' -ForegroundColor Cyan
flutter build windows

$exePath = Join-Path $projectRoot 'build\windows\x64\runner\Release\qing_ting_music.exe'
Write-Host "Verification passed: $exePath" -ForegroundColor Green
