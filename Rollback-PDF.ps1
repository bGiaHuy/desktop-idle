$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is required.' }
$baseline = & git -C $root show 'before-pdf-webview-20261027:config/nvim/lua/pdf_reader.lua'
if ($LASTEXITCODE) { throw 'Rollback tag not available. Fetch tags from origin first.' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
New-Item -ItemType Directory -Force "$root\backup" | Out-Null
Copy-Item "$root\config" "$root\backup\before-pdf-rollback-$stamp" -Recurse
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText("$root\config\nvim\lua\pdf_reader.lua", ($baseline -join "`n") + "`n", $utf8)
$init = [IO.File]::ReadAllText("$root\config\nvim\init.lua")
$init = $init.Replace("require('pdf_graphics').setup()", '')
[IO.File]::WriteAllText("$root\config\nvim\init.lua", $init, $utf8)
Write-Output 'Text PDF restored. Restart Desktop Idle. New files/dependencies were preserved.'
