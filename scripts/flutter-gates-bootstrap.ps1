param(
    [string]$InstallDir,
    [ValidateSet("stable", "beta", "main")]
    [string]$Channel = "stable",
    [switch]$SkipIntegration,
    [switch]$UseSystemFlutter
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$gatesScript = Join-Path $scriptDir "v1-gates.ps1"

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = Join-Path $repoRoot ".tooling/flutter"
}

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

if (-not $UseSystemFlutter) {
    Require-Command "git"
    $flutterBat = Join-Path $InstallDir "bin/flutter.bat"
    if (-not (Test-Path $flutterBat)) {
        $parentDir = Split-Path -Parent $InstallDir
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir | Out-Null
        }
        Write-Host "==> Installing Flutter ($Channel) into $InstallDir"
        git clone --depth 1 --branch $Channel https://github.com/flutter/flutter.git $InstallDir
    }
    $safeDirs = @(git config --global --get-all safe.directory 2>$null)
    if (-not ($safeDirs -contains $InstallDir)) {
        git config --global --add safe.directory $InstallDir | Out-Null
    }
    $env:FLUTTER_ROOT = $InstallDir
    $env:PATH = "$(Join-Path $InstallDir 'bin');$env:PATH"
}
else {
    Require-Command "flutter"
}

Write-Host "==> Flutter SDK"
flutter --version

if ($SkipIntegration) {
    & $gatesScript -FlutterOnly -SkipIntegration
}
else {
    & $gatesScript -FlutterOnly
}

if ($LASTEXITCODE -ne 0) {
    throw "Flutter gates failed with exit code $LASTEXITCODE."
}
