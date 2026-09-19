# Runs the real packaged app while retaining the legacy updater's app/ cwd.
# The fixture uses isolated portable data and never touches the user's install.
param([string]$Launcher = "$PSScriptRoot/../windows-launcher/target/release/PepoConnect.exe")
$ErrorActionPreference = 'Stop'
$Launcher = (Resolve-Path -LiteralPath $Launcher).Path
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('pepo-launcher-upgrade-' + [guid]::NewGuid().ToString('N'))
$app = Join-Path $fixture 'app'
$work = Join-Path $fixture '.pepoconnect-update-test'
[IO.Directory]::CreateDirectory($app) | Out-Null
[IO.Directory]::CreateDirectory($work) | Out-Null
[IO.File]::WriteAllText((Join-Path $fixture 'portable.txt'), '')
[IO.File]::WriteAllText((Join-Path $app 'pepoconnect.exe'), 'previous runner')
[IO.File]::WriteAllText((Join-Path $app '.bundle-id'), 'previous version')
[IO.File]::WriteAllText((Join-Path $app 'personal.txt'), 'preserve me')
$target = Join-Path $fixture 'PepoConnect.exe'
Copy-Item -LiteralPath $Launcher -Destination $target
$originalDirectory = [Environment]::CurrentDirectory
$originalHealth = $env:PEPOCONNECT_UPDATE_HEALTH
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$originalAutostart = (Get-ItemProperty -LiteralPath $runKey -Name PepoConnect -ErrorAction SilentlyContinue).PepoConnect
$started = Get-Date
try {
    # This handle caused the 0.4.x updater to fail despite Flutter having exited.
    [Environment]::CurrentDirectory = $app
    $env:PEPOCONNECT_UPDATE_HEALTH = Join-Path $work 'health'
    $launcherProcess = Start-Process -FilePath $target -WorkingDirectory $fixture -WindowStyle Hidden -ArgumentList @('--profile=launcher-update-test', '--port=0', '--minimized') -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while (-not (Test-Path -LiteralPath $env:PEPOCONNECT_UPDATE_HEALTH)) {
        $launcherProcess.Refresh()
        if ($launcherProcess.HasExited -and $launcherProcess.ExitCode -ne 0) { throw 'Launcher failed before startup confirmation' }
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Updated Flutter app did not confirm startup' }
        Start-Sleep -Milliseconds 100
    }
    if ((Get-Content -LiteralPath $env:PEPOCONNECT_UPDATE_HEALTH -Raw) -ne 'healthy') { throw 'Invalid startup confirmation' }
    if ((Get-Content -LiteralPath (Join-Path $app '.bundle-id') -Raw) -eq 'previous version') { throw 'Bundle was not replaced' }
    if ((Get-Content -LiteralPath (Join-Path $app 'personal.txt') -Raw) -ne 'preserve me') { throw 'Personal file was lost' }
    Write-Output 'PASS: legacy working-directory lock, real Flutter startup, and personal-file preservation'
} finally {
    [Environment]::CurrentDirectory = $originalDirectory
    $env:PEPOCONNECT_UPDATE_HEALTH = $originalHealth
    # Stop only the isolated runner created by this test; retain the fixture.
    Get-Process -Name pepoconnect -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -eq (Join-Path $app 'pepoconnect.exe') -and $_.StartTime -ge $started } catch { $false }
    } | Stop-Process -Force
    if ($launcherProcess -and -not $launcherProcess.HasExited) { Stop-Process -Id $launcherProcess.Id -Force }
    # The real app refreshes an existing autostart registration on boot.
    $currentAutostart = (Get-ItemProperty -LiteralPath $runKey -Name PepoConnect -ErrorAction SilentlyContinue).PepoConnect
    if ($currentAutostart -and $currentAutostart.Contains($fixture)) {
        if ($null -ne $originalAutostart) { Set-ItemProperty -LiteralPath $runKey -Name PepoConnect -Value $originalAutostart }
        else { Remove-ItemProperty -LiteralPath $runKey -Name PepoConnect }
    }
}
