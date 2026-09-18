# Tags vX.Y.Z and pushes (the tag triggers .github/workflows/release.yml).
#   tool\release.ps1 -Part patch|minor|major   bumps pubspec.yaml, commits, tags
#   tool\release.ps1 -Current                  tags the version already in pubspec.yaml
param(
  [ValidateSet('major', 'minor', 'patch')]$Part = 'patch',
  [switch]$Current
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (git status --porcelain) { throw 'Working tree is dirty' }
flutter analyze --fatal-infos
if ($LASTEXITCODE) { throw 'flutter analyze failed' }
$y = Get-Content pubspec.yaml -Raw
if ($y -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') { throw 'version not found in pubspec.yaml' }
[int]$a = $Matches[1]; [int]$b = $Matches[2]; [int]$c = $Matches[3]; [int]$n = $Matches[4]
if ($Current) {
  $v = "$a.$b.$c"
  if (git tag -l "v$v") { throw "Tag v$v already exists" }
} else {
  switch ($Part) {
    'major' { $a++; $b = 0; $c = 0 }
    'minor' { $b++; $c = 0 }
    'patch' { $c++ }
  }
  $n++
  $v = "$a.$b.$c"
  $updated = $y -replace '(?m)^version:\s*.+$', "version: $v+$n"
  [IO.File]::WriteAllText((Join-Path (Get-Location) 'pubspec.yaml'), $updated, (New-Object Text.UTF8Encoding $false))
  git add pubspec.yaml
  git commit -m "release: v$v"
}
git tag -a "v$v" -m "PepoConnect v$v"
git push origin main --follow-tags
Write-Host "Tagged v$v (build $n). Release workflow triggered."
