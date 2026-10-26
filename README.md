# Desktop Idle

A transparent Windows coding desktop built with WezTerm and Neovim. Catppuccin/Tokyo Night, Python and C++ tooling, familiar editing shortcuts, and an optional Codex CLI sidebar.

## Install on Windows 11

1. Install **Git**, **Node.js**, **Python 3.10+** (independent installation with venv/pip), and an existing **GCC/G++ toolchain** on PATH. Do not install a second compiler if one already works. MSYS2 UCRT64 is supported. This installer does not install or modify these prerequisites.
2. Clone/download this repository into a permanent folder. Open PowerShell there and run:

```powershell
.\Install.ps1 -Python 'C:\Path\To\Python\python.exe'
```

The script downloads official Neovim 0.12.6, WezTerm nightly, clangd 23.1.0 and Nerd Fonts 3.5.1 release assets and requires a matching published SHA256 digest. It creates a local Python virtualenv, installs pinned Python/npm dependencies, restores locked plugins, builds Treesitter parsers and adds **Desktop Idle** to Start Menu. Existing configuration is backed up first. No system PATH, PowerShell profile, display layout or wallpaper settings are modified. If your policy blocks scripts, use your normal approved script-running process; the installer does not weaken execution policy.

WezTerm nightly is a moving upstream channel. The installer records the exact version/hash downloaded. Plugins are pinned by `config/nvim/lazy-lock.json`. Installation requires internet. **A clean-machine install of this exported repository has not yet been tested end-to-end**; the original installed configuration and core functions were tested on Windows 11. Compiler/library compatibility on another machine may need adjustment.

## Open a project

```powershell
.\Start-Coding.ps1 -Project 'D:\My Project'
```

Or open the Start Menu shortcut (defaults to your Documents folder). For this PowerShell session only, dot-source `Environment.ps1` to enable `ct` and `tc`:

```powershell
. .\Environment.ps1
ct 'D:\My Project'
```

`ct` without an argument opens the current folder; from the home/Windows directory it defaults to Documents. No global command aliases are installed. Do not move the installation after setup: its virtualenv and shortcut contain local paths.

## Everyday keys

| Key | Action |
|---|---|
| Ctrl+O / Home | Open file picker |
| Ctrl+S | Save, or ask for Save As |
| Ctrl+A / C / X / V | Select all / copy / cut / paste |
| Ctrl+Z / Ctrl+Y | Undo / redo |
| Ctrl+/ | Comment/uncomment line or selection |
| Ctrl+L / Ctrl+D | Select line / duplicate lines |
| Alt+Up / Down | Move lines |
| Ctrl+F / Ctrl+H | Find / replace with confirmation |
| Ctrl+Shift+F | Search project |
| Alt+E | Open buffers picker |
| Ctrl+B | Toggle explorer |
| Ctrl+Tab / Ctrl+Shift+Tab | Next/previous Neovim tab (`:tabnew` creates one) |
| F6 | Run Python or compile/run current C++ file (C++20) |
| F5 | Python debugger |
| Ctrl+K | Function/constructor signature |
| Ctrl+Q | Hide terminal output |
| F8 | Toggle Codex sidebar; expands WezTerm when screen space allows |
| F1 | Browse key mappings |
| Ctrl+Shift+O | Toggle opacity |
| Ctrl+Alt+[ / ] | Adjust opacity |
| Ctrl+Shift+B | Restore/hide title bar |
| Alt+Enter | Toggle fullscreen |

Neovim remains modal: `i` enters Insert mode, Escape returns to Normal. Ctrl+W then W changes editor splits. A `.py`/`.cpp` extension enables language features. Save before asking AI to read a file. Python interpreter selection respects active VIRTUAL_ENV and project `.venv`. C++ F6 builds a single file; larger projects need their own build system and compile_commands.json.

## Optional AI

Install Codex CLI separately and sign in with **your own account**. F8 opens the CLI in the current project; hiding it preserves the running conversation. No credentials, API keys, chat history or account configuration are included in this repository. No automatic prompt or code upload occurs just from the editor integration. CLI access, approvals, usage limits and charges follow your own Codex configuration/account. Selected code and unsaved buffers are not automatically attached.

## Customize and restore

Edit `config/wezterm.lua` for font/opacity/window keys, `config/nvim/lua/desktop_keys.lua` for editing keys and `config/nvim/lua/plugins.lua` for plugins. Optional ignored `settings.local.ps1` is loaded after environment setup for machine-specific environment overrides.

`Restore-Config.ps1` restores the newest timestamped config snapshot, preserving the current config in a second backup. Keep personal source projects outside this repository. Runtime downloads, caches, state, logs, backups and private machine settings are ignored by Git.

## Credits and scope

The repository distributes configuration and installer code, not third-party binaries or plugin source. WezTerm, Neovim, lazy.nvim, Catppuccin, Tokyo Night, Treesitter, Telescope, nvim-cmp, nvim-dap, Pyright, Ruff, clangd and Nerd Fonts retain their respective licenses. Wallpaper is supplied by the user and is not included.
