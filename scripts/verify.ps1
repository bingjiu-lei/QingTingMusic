$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host 'Formatting Dart files...' -ForegroundColor Cyan
dart format lib test
if ($LASTEXITCODE -ne 0) {
    throw "Dart formatting failed with exit code $LASTEXITCODE"
}

Write-Host 'Running Flutter analyze...' -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) {
    throw "Flutter analyze failed with exit code $LASTEXITCODE"
}

Write-Host 'Running Flutter tests...' -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) {
    throw "Flutter tests failed with exit code $LASTEXITCODE"
}

Write-Host 'Building Windows release...' -ForegroundColor Cyan
flutter build windows
if ($LASTEXITCODE -ne 0) {
    throw "Windows release build failed with exit code $LASTEXITCODE"
}

$exePath = Join-Path $projectRoot 'build\windows\x64\runner\Release\qing_ting_music.exe'
Write-Host "Verification passed: $exePath" -ForegroundColor Green
