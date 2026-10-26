param([string]$Python, [switch]$SkipShortcut, [switch]$GraphicalPDF)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
foreach ($command in @('git', 'node', 'npm.cmd', 'g++')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Missing prerequisite: $command. See README.md. No system settings were changed."
    }
}
if (-not $Python) {
    $Python = (Get-Command python.exe -ErrorAction Stop).Source
}
& $Python -c 'import sys; assert sys.version_info >= (3, 10)'
if ($LASTEXITCODE) { throw 'Python 3.10+ required. Pass -Python with an independent Python installation.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (Test-Path -LiteralPath "$root\config") {
    New-Item -ItemType Directory -Force "$root\backup" | Out-Null
    Copy-Item -LiteralPath "$root\config" -Destination "$root\backup\config-$stamp" -Recurse
}
foreach ($folder in @('tools','data','state','cache','evidence','.downloads')) {
    New-Item -ItemType Directory -Force (Join-Path $root $folder) | Out-Null
}
$manifest = @()
function Install-Release($Repository, $Tag, $Pattern, $Folder) {
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repository/releases/$Tag"
    $asset = $release.assets | Where-Object name -Match $Pattern | Select-Object -First 1
    if (-not $asset) { throw "Release asset not found: $Repository" }
    $zip = Join-Path "$root\.downloads" $asset.name
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $asset.digest -or $asset.digest -ne "sha256:$hash") { throw "Missing or mismatched published SHA256: $Repository" }
    Expand-Archive -LiteralPath $zip -DestinationPath "$root\tools\$Folder" -Force
    $script:manifest += @{Repository=$Repository;Version=$release.tag_name;SHA256=$hash;URL=$asset.browser_download_url}
}
Install-Release 'neovim/neovim' 'tags/v0.12.6' '^nvim-win64.zip$' 'neovim'
# Stable 2024 failed on the original setup; use the official nightly channel.
Install-Release 'wezterm/wezterm' 'tags/nightly' '^WezTerm-windows-nightly.zip$' 'wezterm'
Install-Release 'clangd/clangd' 'tags/23.1.0' '^clangd-windows-23.1.0.zip$' 'clangd'
Install-Release 'ryanoasis/nerd-fonts' 'tags/v3.5.1' '^JetBrainsMono.zip$' 'fonts'
$manifest | ConvertTo-Json -Depth 4 | Set-Content "$root\evidence\packages.json"
if (-not (Test-Path -LiteralPath "$root\tools\python\Scripts\python.exe")) {
    & $Python -m venv "$root\tools\python"
    if ($LASTEXITCODE) { throw 'Virtualenv creation failed.' }
}
& "$root\tools\python\Scripts\python.exe" -m pip install 'ruff==0.17.2' 'clang-format==23.1.3' 'debugpy==1.8.22' 'pynvim==0.6.0' 'PyMuPDF==2.0'
if ($LASTEXITCODE) { throw 'Python dependency install failed.' }
if ($GraphicalPDF) {
    & "$root\tools\python\Scripts\python.exe" -m pip install 'pywebview==6.2.1'
    if ($LASTEXITCODE) { throw 'Optional graphical PDF dependency install failed.' }
    Add-Content -LiteralPath "$root\settings.local.ps1" -Value "`n`$env:DESKTOP_IDLE_PDF_GRAPHICS = '1'"
}
& npm.cmd install --prefix "$root\tools\node" 'pyright@1.1.414'
if ($LASTEXITCODE) { throw 'Pyright install failed.' }
. "$root\Environment.ps1"
$lazy = "$root\data\nvim-data\lazy\lazy.nvim"
if (-not (Test-Path -LiteralPath $lazy)) {
    & git clone --filter=blob:none --branch stable https://github.com/folke/lazy.nvim.git $lazy
    if ($LASTEXITCODE) { throw 'lazy.nvim download failed.' }
}
$nvim = "$root\tools\neovim\nvim-win64\bin\nvim.exe"
& $nvim -n -i NONE --headless '+Lazy! restore' +qa
if ($LASTEXITCODE) { throw 'Plugin restore failed.' }
& $nvim -n -i NONE --headless '+TSInstallSync python cpp c lua json' +qa
if ($LASTEXITCODE) { throw 'Treesitter install failed.' }
& $nvim -n -i NONE --headless '+lua assert(vim.fn.maparg("<F8>","n")~=""); print("CONFIG_OK")' +qa
if ($LASTEXITCODE) { throw 'Neovim startup check failed.' }
if (-not $SkipShortcut) {
    $menu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    $target = Join-Path $menu 'Desktop Idle.lnk'
    if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination "$root\backup\Desktop Idle-$stamp.lnk" }
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($target)
    $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -File "' + $root + '\Start-Coding.ps1"'
    $shortcut.WorkingDirectory = "$env:USERPROFILE\Documents"
    $shortcut.IconLocation = (Get-ChildItem "$root\tools\wezterm" -Recurse -Filter wezterm-gui.exe | Select-Object -First 1).FullName + ',0'
    $shortcut.Save()
}
Write-Output 'Installed Desktop Idle. Open it from Start Menu or run Open Coding.cmd.'
