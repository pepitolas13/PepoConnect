# Builds the Windows release artifacts from an existing `flutter build windows --release`:
#   dist\PepoConnect-win-x64.exe           single-file launcher (embeds the whole bundle)
#   dist\PepoConnect-win-x64-portable.zip  the raw bundle folder (run pepoconnect.exe in place)
#
# Usage: .\packaging\windows\build-portable.ps1 [-Bundle <dir>] [-OutDir <dir>] [-SkipVcRedist]
#   -Bundle        Flutter release bundle. Default: $env:PEPO_BUNDLE_DIR, else build\windows\x64\runner\Release
#   -OutDir        Output folder. Default: <repo>\dist
#   -SkipVcRedist  Do not copy the VC++ runtime DLLs into the bundle (prepare-bundle.ps1)
# Mirrors the "windows" job of .github/workflows/release.yml.
[CmdletBinding()]
param(
  [string]$Bundle,
  [string]$OutDir,
  [switch]$SkipVcRedist
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

# 1) Check the bundle.
if (-not $Bundle) {
  $Bundle = if ($env:PEPO_BUNDLE_DIR) { $env:PEPO_BUNDLE_DIR } else { Join-Path $root 'build\windows\x64\runner\Release' }
}
if (-not (Test-Path (Join-Path $Bundle 'pepoconnect.exe'))) {
  throw "Bundle not found: $Bundle`nRun 'flutter build windows --release' first or pass -Bundle <dir>."
}
if (-not (Test-Path (Join-Path $Bundle 'data\flutter_assets'))) {
  throw "Incomplete bundle (data\flutter_assets missing): $Bundle"
}
$Bundle = (Resolve-Path $Bundle).Path
Write-Host "bundle: $Bundle"

# 2) VC++ runtime DLLs next to pepoconnect.exe.
if (-not $SkipVcRedist) {
  & (Join-Path $PSScriptRoot 'prepare-bundle.ps1') -Bundle $Bundle
}

# 3) Launcher (build.rs packs the bundle from PEPO_BUNDLE_DIR).
$env:PEPO_BUNDLE_DIR = $Bundle
$manifest = Join-Path $root 'windows-launcher\Cargo.toml'
& cargo build --release --manifest-path $manifest
if ($LASTEXITCODE -ne 0) { throw "cargo build failed (exit $LASTEXITCODE)" }
$launcher = Join-Path $root 'windows-launcher\target\release\PepoConnect.exe'
if (-not (Test-Path $launcher)) { throw "Launcher not produced: $launcher" }

# 4) dist\
if (-not $OutDir) { $OutDir = Join-Path $root 'dist' }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
Copy-Item $launcher (Join-Path $OutDir 'PepoConnect-win-x64.exe') -Force

$zip = Join-Path $OutDir 'PepoConnect-win-x64-portable.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $Bundle '*') -DestinationPath $zip -CompressionLevel Optimal

Write-Host "output: $OutDir"
Get-ChildItem $OutDir -File |
  Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } |
  Format-Table -AutoSize
