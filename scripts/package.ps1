$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$installerScript = Join-Path $projectRoot 'installer\QingTingMusic.iss'
$outputFile = Join-Path $projectRoot 'dist\QingTingMusic-Setup-v0.1.0-x64.exe'
$innoCandidates = @(
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 6\ISCC.exe',
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
)

Set-Location $projectRoot

Get-Process -Name 'qing_ting_music' -ErrorAction SilentlyContinue |
    Stop-Process -Force

Write-Host 'Cleaning previous Windows build...' -ForegroundColor Cyan
flutter clean

Write-Host 'Restoring Flutter dependencies...' -ForegroundColor Cyan
flutter pub get

Write-Host 'Building Windows release...' -ForegroundColor Cyan
flutter build windows --release

$iscc = $innoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw 'Inno Setup 6 is not installed. Install it with: winget install --id JRSoftware.InnoSetup -e'
}

if (-not (Test-Path (Join-Path $releaseDir 'qing_ting_music.exe'))) {
    throw "Windows release executable was not found: $releaseDir"
}

Write-Host 'Building Windows installer...' -ForegroundColor Cyan
& $iscc $installerScript
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $outputFile)) {
    throw "Installer was not found: $outputFile"
}

$hash = (Get-FileHash $outputFile -Algorithm SHA256).Hash
Write-Host "Installer ready: $outputFile" -ForegroundColor Green
Write-Host "SHA256: $hash" -ForegroundColor Green
