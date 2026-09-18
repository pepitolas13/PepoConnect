# Copies the VC++ runtime DLLs into the Flutter Windows release bundle so the app runs on clean machines.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$bundle = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path $bundle)) { throw "Bundle not found: $bundle (run 'flutter build windows --release' first)" }
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$crt = & $vswhere -latest -products * -find 'VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT' | Sort-Object | Select-Object -Last 1
if (-not $crt) { throw 'Microsoft.VC143.CRT redistributable folder not found' }
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item (Join-Path $crt $dll) $bundle -Force
  Write-Host "copied $dll from $crt"
}
Get-ChildItem $bundle | Select-Object Name, Length | Format-Table -AutoSize
