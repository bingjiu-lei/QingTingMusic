param(
    [switch]$FullTests,
    [switch]$SkipBuild,
    [int]$FullTestTimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    Write-Host $Title -ForegroundColor Cyan
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Title failed with exit code $LASTEXITCODE"
    }
}

function Invoke-CheckedCommandWithTimeout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    Write-Host $Title -ForegroundColor Cyan
    $job = Start-Job -ScriptBlock {
        param($WorkingDirectory, $Executable, [string[]]$CommandArguments)
        Set-Location $WorkingDirectory
        & $Executable @CommandArguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Executable failed with exit code $LASTEXITCODE"
        }
    } -ArgumentList $projectRoot, $FilePath, $Arguments

    if (-not (Wait-Job $job -Timeout $TimeoutSeconds)) {
        Stop-Job $job
        Remove-Job $job
        throw "$Title timed out after $TimeoutSeconds seconds"
    }
    Receive-Job $job
    Remove-Job $job
}

Invoke-CheckedCommand 'Formatting Dart files...' dart format lib test
Invoke-CheckedCommand 'Running Flutter analyze...' flutter analyze

if ($FullTests) {
    Invoke-CheckedCommandWithTimeout 'Running all Flutter tests...' flutter $FullTestTimeoutSeconds test
} else {
    Invoke-CheckedCommand 'Running player controller tests...' flutter test test\player_controller_test.dart
    Invoke-CheckedCommand 'Running storage tests...' flutter test test\storage_test.dart
    Write-Host 'Skipped full widget suite. Use .\scripts\verify.ps1 -FullTests when UI tests are required.' -ForegroundColor DarkYellow
}

if (-not $SkipBuild) {
    Invoke-CheckedCommand 'Building Windows release...' flutter build windows
    $exePath = Join-Path $projectRoot 'build\windows\x64\runner\Release\qing_ting_music.exe'
    Write-Host "Verification passed: $exePath" -ForegroundColor Green
} else {
    Write-Host 'Verification passed without Windows build.' -ForegroundColor Green
}
