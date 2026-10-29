param(
    [string]$GodotPath = "godot",
    [string]$TemplatePath = "",
    [switch]$SkipTests
)
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ProjectRoot
try {
    & python --version
    if ($LASTEXITCODE -ne 0) { throw "Python 3.10+ is required for build tooling." }
    & python -m pip install --requirement scripts/requirements-build.txt
    if ($LASTEXITCODE -ne 0) { throw "Build dependencies failed to install." }
    $BuildArgs = @("scripts/build.py", "--godot", $GodotPath, "--target", "windows", "--package")
    if ($TemplatePath) { $BuildArgs += @("--template", $TemplatePath) }
    if ($SkipTests) { $BuildArgs += "--skip-tests" }
    & python @BuildArgs
    if ($LASTEXITCODE -ne 0) { throw "Windows build failed. Inspect build/logs/." }
    Write-Host "Windows EXE: $ProjectRoot\build\OrbitLaser.exe"
    Write-Host "Download ZIP: $ProjectRoot\releases\OrbitLaser-1.0-Windows-x64.zip"
} finally {
    Pop-Location
}
