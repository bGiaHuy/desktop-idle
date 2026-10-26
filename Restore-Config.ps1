param([string]$Snapshot)
$ErrorActionPreference = 'Stop'
if (-not $Snapshot) {
    $Snapshot = (Get-ChildItem -LiteralPath "$PSScriptRoot\backup" -Directory -Filter 'config-*' | Sort-Object Name -Descending | Select-Object -First 1).FullName
}
if (-not $Snapshot) { throw 'No config snapshot found.' }
$resolved = (Resolve-Path -LiteralPath $Snapshot).Path
$backupRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\backup").Path + '\'
if (-not $resolved.StartsWith($backupRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Snapshot must be inside this environment backup folder.' }
if (-not (Test-Path -LiteralPath "$resolved\nvim\init.lua")) { throw 'Invalid snapshot.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Move-Item -LiteralPath "$PSScriptRoot\config" -Destination "$PSScriptRoot\backup\before-restore-$stamp"
Copy-Item -LiteralPath $resolved -Destination "$PSScriptRoot\config" -Recurse
Write-Output 'Configuration restored. Restart the coding environment.'
