# Launches two independent PepoConnect instances on this PC (profiles "a" and "b")
# so pairing and transfers can be tested without a phone. Build first:
#   flutter build windows --release
param([string]$Exe = (Join-Path $PSScriptRoot '..\..\build\windows\x64\runner\Release\pepoconnect.exe'))
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Exe)) { throw "Not built: $Exe (run 'flutter build windows --release')" }
$dir = Split-Path $Exe
Start-Process -FilePath $Exe -ArgumentList '--profile=a' -WorkingDirectory $dir
Start-Sleep -Milliseconds 800
Start-Process -FilePath $Exe -ArgumentList '--profile=b' -WorkingDirectory $dir
Write-Host 'Two instances started: "a" and "b". Pair them with Ajustes > Añadir dispositivo > Usar código.'
