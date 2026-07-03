param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [ValidateRange(1, 2147483647)]
    [int]$BuildNumber = 1
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$installerScript = Join-Path $projectRoot 'installer\QingTingMusic.iss'
$pubspecFile = Join-Path $projectRoot 'pubspec.yaml'
$outputFile = Join-Path $projectRoot "dist\QingTingMusic-Setup-v$Version-x64.exe"
$innoCandidates = @(
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 6\ISCC.exe',
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
)

Set-Location $projectRoot

Get-Process -Name 'qing_ting_music' -ErrorAction SilentlyContinue |
    Stop-Process -Force

$pubspec = [System.IO.File]::ReadAllText($pubspecFile)
$updatedPubspec = [regex]::Replace(
    $pubspec,
    '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$',
    "version: $Version+$BuildNumber"
)
if ($updatedPubspec -eq $pubspec -and $pubspec -notmatch "(?m)^version:\s*$Version\+$BuildNumber\s*$") {
    throw 'Could not update the version field in pubspec.yaml'
}
[System.IO.File]::WriteAllText(
    $pubspecFile,
    $updatedPubspec,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host 'Cleaning previous Windows build...' -ForegroundColor Cyan
flutter clean

Write-Host 'Restoring Flutter dependencies...' -ForegroundColor Cyan
flutter pub get

Write-Host "Building Windows release v$Version+$BuildNumber..." -ForegroundColor Cyan
flutter build windows --release --build-name $Version --build-number $BuildNumber

$iscc = $innoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw 'Inno Setup 6 is not installed. Install it with: winget install --id JRSoftware.InnoSetup -e'
}

if (-not (Test-Path (Join-Path $releaseDir 'qing_ting_music.exe'))) {
    throw "Windows release executable was not found: $releaseDir"
}

Write-Host 'Building Windows installer...' -ForegroundColor Cyan
& $iscc "/DMyAppVersion=$Version" $installerScript
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $outputFile)) {
    throw "Installer was not found: $outputFile"
}

$hash = (Get-FileHash $outputFile -Algorithm SHA256).Hash
$hashFile = "$outputFile.sha256"
$hashLine = "$hash  $(Split-Path -Leaf $outputFile)"
[System.IO.File]::WriteAllText(
    $hashFile,
    $hashLine,
    [System.Text.UTF8Encoding]::new($false)
)
Write-Host "Installer ready: $outputFile" -ForegroundColor Green
Write-Host "SHA256: $hash" -ForegroundColor Green
Write-Host "SHA256 file: $hashFile" -ForegroundColor Green
