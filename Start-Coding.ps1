param([string]$Project = "$env:USERPROFILE\Documents", [switch]$Shell)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Environment.ps1"
$wez = (Get-ChildItem -LiteralPath "$PSScriptRoot\tools\wezterm" -Recurse -Filter wezterm-gui.exe -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if (-not $wez) { throw 'Run Install.ps1 first.' }
$projectPath = (Resolve-Path -LiteralPath $Project).Path
if ($Shell) {
    $arguments = @('--config-file', ('"' + "$PSScriptRoot\config\wezterm.lua" + '"'), 'start', '--always-new-process', '--cwd', ('"' + $projectPath + '"'))
} else {
    $arguments = @('--config-file', ('"' + "$PSScriptRoot\config\wezterm.lua" + '"'), 'start', '--always-new-process', '--cwd', ('"' + $projectPath + '"'), '--', ('"' + "$PSScriptRoot\tools\neovim\nvim-win64\bin\nvim.exe" + '"'), '+NvimTreeOpen')
}
Start-Process -FilePath $wez -ArgumentList $arguments -WindowStyle Normal
