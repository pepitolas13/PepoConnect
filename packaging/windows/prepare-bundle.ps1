# Copies the VC++ runtime DLLs into the Flutter Windows release bundle so the app runs on clean machines.
# Usage: prepare-bundle.ps1 [-Bundle <dir>]
#   Default bundle: $env:PEPO_BUNDLE_DIR, else build\windows\x64\runner\Release.
[CmdletBinding()]
param([string]$Bundle)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $Bundle) {
  $Bundle = if ($env:PEPO_BUNDLE_DIR) { $env:PEPO_BUNDLE_DIR } else { Join-Path $root 'build\windows\x64\runner\Release' }
}
if (-not (Test-Path (Join-Path $Bundle 'pepoconnect.exe'))) {
  throw "Bundle not found: $Bundle (run 'flutter build windows --release' first or pass -Bundle)"
}
$Bundle = (Resolve-Path $Bundle).Path

$dlls = 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll'
$crt = $null

# 1) A "Developer PowerShell" / vcvars shell exports VCToolsRedistDir.
if ($env:VCToolsRedistDir) {
  $candidate = Join-Path $env:VCToolsRedistDir 'x64\Microsoft.VC143.CRT'
  if (Test-Path $candidate) { $crt = $candidate }
}

# 2) Otherwise ask vswhere for every VS / Build Tools instance and take the newest redist.
if (-not $crt) {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (-not (Test-Path $vswhere)) {
    throw "vswhere.exe not found ($vswhere). Install Visual Studio Build Tools with the 'Desktop development with C++' workload."
  }
  $found = @(& $vswhere -products '*' -find 'VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT' | Where-Object { $_ })
  $crt = $found |
    Sort-Object { [version](Split-Path (Split-Path (Split-Path $_ -Parent) -Parent) -Leaf) } |
    Select-Object -Last 1
}
if (-not $crt) {
  throw 'Microsoft.VC143.CRT redistributable folder not found (install the "C++ Redistributable" / MSVC build tools component).'
}

foreach ($dll in $dlls) {
  $src = Join-Path $crt $dll
  if (-not (Test-Path $src)) { throw "Missing $src" }
  Copy-Item $src $Bundle -Force
  Write-Host "copied $dll from $crt"
}
Get-ChildItem $Bundle | Select-Object Name, Length | Format-Table -AutoSize
