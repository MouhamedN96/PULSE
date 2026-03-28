param(
    [switch]$RustOnly,
    [switch]$FlutterOnly,
    [switch]$SkipIntegration
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($RustOnly -and $FlutterOnly) {
    throw "--rust-only and --flutter-only cannot be used together."
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$rustDir = Join-Path $repoRoot "rust_core"
$flutterDir = Join-Path $repoRoot "flutter_app"

function Require-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Run-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "==> $Name"
    Push-Location $WorkingDirectory
    try {
        & $Command
        if ($LASTEXITCODE -ne 0) {
            throw "$Name failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

if (-not $FlutterOnly) {
    Require-Command "cargo"
    Run-Step -Name "cargo fmt --check" -WorkingDirectory $rustDir -Command { cargo fmt --check }
    Run-Step -Name "cargo clippy -- -D warnings" -WorkingDirectory $rustDir -Command { cargo clippy -- -D warnings }
    Run-Step -Name "cargo test" -WorkingDirectory $rustDir -Command { cargo test }
}

if (-not $RustOnly) {
    Require-Command "flutter"
    $localFlutterDir = Join-Path $repoRoot ".tooling/flutter"
    if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $localFlutterDir ".git"))) {
        $safeDirs = @(git config --global --get-all safe.directory 2>$null)
        if (-not ($safeDirs -contains $localFlutterDir)) {
            git config --global --add safe.directory $localFlutterDir | Out-Null
        }
        $env:FLUTTER_ROOT = $localFlutterDir
        $env:PATH = "$(Join-Path $localFlutterDir 'bin');$env:PATH"
    }
    Run-Step -Name "flutter pub get" -WorkingDirectory $flutterDir -Command { flutter pub get }
    Run-Step -Name "flutter analyze" -WorkingDirectory $flutterDir -Command { flutter analyze }
    Run-Step -Name "flutter test" -WorkingDirectory $flutterDir -Command { flutter test }
    if (-not $SkipIntegration) {
        Run-Step -Name "flutter test integration_test" -WorkingDirectory $flutterDir -Command { flutter test integration_test }
    }
}

Write-Host "V1 gates passed."
