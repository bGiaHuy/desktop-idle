$env:TRANSPARENT_CODING_ROOT = $PSScriptRoot
$env:XDG_CONFIG_HOME = "$PSScriptRoot\config"
$env:XDG_DATA_HOME = "$PSScriptRoot\data"
$env:XDG_STATE_HOME = "$PSScriptRoot\state"
$env:XDG_CACHE_HOME = "$PSScriptRoot\cache"
$env:NVIM_APPNAME = 'nvim'
$env:WEZTERM_CONFIG_FILE = "$PSScriptRoot\config\wezterm.lua"
$env:CODING_PYTHON = "$PSScriptRoot\tools\python\Scripts\python.exe"
$env:CODING_SHELL = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$clangd = Get-ChildItem -LiteralPath "$PSScriptRoot\tools\clangd" -Recurse -Filter clangd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$env:PATH = "$PSScriptRoot\bin;$PSScriptRoot\tools\neovim\nvim-win64\bin;$PSScriptRoot\tools\python\Scripts;$PSScriptRoot\tools\node\node_modules\.bin;$($clangd.DirectoryName);$env:PATH"
if (Test-Path -LiteralPath "$PSScriptRoot\settings.local.ps1") { . "$PSScriptRoot\settings.local.ps1" }
