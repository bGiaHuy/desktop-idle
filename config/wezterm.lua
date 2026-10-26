local wezterm = require 'wezterm'
local act = wezterm.action
local c = wezterm.config_builder()
c.front_end = 'Software'
local root = os.getenv('TRANSPARENT_CODING_ROOT') or (wezterm.config_dir .. '/..')
c.font_dirs = { root .. '/tools/fonts' }
c.font = wezterm.font_with_fallback { 'JetBrainsMono Nerd Font Mono', 'Consolas', 'Segoe UI' }
c.font_size = 14
c.color_scheme = 'Catppuccin Mocha'
c.window_background_opacity = 0.83
c.text_background_opacity = 1.0
c.window_decorations = 'RESIZE'
c.window_padding = { left = 10, right = 10, top = 8, bottom = 8 }
c.hide_tab_bar_if_only_one_tab = true
c.use_fancy_tab_bar = false
c.default_cursor_style = 'BlinkingBar'
c.cursor_blink_rate = 650
c.initial_cols = 112
c.initial_rows = 34
c.default_prog = { os.getenv('CODING_SHELL') or 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe', '-NoLogo', '-NoProfile' }
c.adjust_window_size_when_changing_font_size = false
local function opacity(delta, toggle)
  return wezterm.action_callback(function(window)
    local o = window:get_config_overrides() or {}
    local old = o.window_background_opacity or 0.83
    o.window_background_opacity = toggle and (old < 1 and 1 or 0.83) or math.max(0.45, math.min(1, old + delta))
    window:set_config_overrides(o)
  end)
end
c.keys = {
  { key='LeftArrow', mods='CTRL', action=act.SendString '\x1b[1;5D' },
  { key='RightArrow', mods='CTRL', action=act.SendString '\x1b[1;5C' },
  { key='w', mods='CTRL', action=act.SendString '\x17' },
  { key='/', mods='CTRL', action=act.SendString '\x1b[47;5u' },
  { key='F', mods='CTRL|SHIFT', action=act.SendString '\x1b[102;6u' },
  { key='P', mods='CTRL|SHIFT', action=act.SendString '\x1b[112;6u' },
  { key='Z', mods='CTRL|SHIFT', action=act.SendString '\x1b[122;6u' },
  { key='Tab', mods='CTRL', action=act.SendString '\x1b[9;5u' },
  { key='Tab', mods='CTRL|SHIFT', action=act.SendString '\x1b[9;6u' },
  { key='O', mods='CTRL|SHIFT', action=opacity(0, true) },
  { key='[', mods='CTRL|ALT', action=opacity(-0.05) },
  { key=']', mods='CTRL|ALT', action=opacity(0.05) },
  { key='Enter', mods='ALT', action=act.ToggleFullScreen },
  { key='B', mods='CTRL|SHIFT', action=wezterm.action_callback(function(window)
    local o=window:get_config_overrides() or {}
    o.window_decorations = o.window_decorations == 'TITLE|RESIZE' and 'RESIZE' or 'TITLE|RESIZE'
    window:set_config_overrides(o)
  end) },
  { key='E', mods='CTRL|SHIFT', action=act.SpawnCommandInNewTab { args={root .. '/tools/neovim/nvim-win64/bin/nvim.exe','.'} } },
  { key='D', mods='CTRL|SHIFT', action=act.SplitHorizontal { domain='CurrentPaneDomain' } },
  { key='D', mods='CTRL|ALT', action=act.SplitVertical { domain='CurrentPaneDomain' } },
  { key='LeftArrow', mods='ALT', action=act.ActivatePaneDirection 'Left' },
  { key='RightArrow', mods='ALT', action=act.ActivatePaneDirection 'Right' },
  { key='UpArrow', mods='ALT', action=act.SendString '\x1b[1;3A' },
  { key='DownArrow', mods='ALT', action=act.SendString '\x1b[1;3B' },
  { key='UpArrow', mods='CTRL|ALT', action=act.ActivatePaneDirection 'Up' },
  { key='DownArrow', mods='CTRL|ALT', action=act.ActivatePaneDirection 'Down' },
  { key='F9', mods='NONE', action=wezterm.action_callback(function(window)
    local d=window:get_dimensions()
    if d.is_full_screen then return end
    local screen=wezterm.gui.screens().active
    window:set_position(math.floor(screen.x+math.max(0,(screen.width-d.pixel_width)/2)),
      math.floor(screen.y+math.max(0,(screen.height-d.pixel_height)/2)))
  end) },
}
c.mouse_bindings = {
  { event={Down={streak=1,button='Left'}}, mods='ALT', action=act.StartWindowDrag },
}
local ai_sizes = {}
local center_pending = {}
local function center_window(window, screen)
  local d = window:get_dimensions()
  if d.is_full_screen then return end
  screen = screen or wezterm.gui.screens().active
  window:set_position(math.floor(screen.x + math.max(0,(screen.width-d.pixel_width)/2)),
    math.floor(screen.y + math.max(0,(screen.height-d.pixel_height)/2)))
end
wezterm.on('window-resized', function(window)
  local id = window:window_id()
  if center_pending[id] then
    local screen = center_pending[id]
    center_pending[id] = nil
    center_window(window, screen)
  end
end)
wezterm.on('user-var-changed', function(window, pane, name, value)
  if name ~= 'CODING_AI_WIDTH' then return end
  local id = window:window_id()
  local cols = tonumber(value) or 0
  if cols > 0 then
    if ai_sizes[id] then return end
    local d = window:get_dimensions()
    if d.is_full_screen then return end
    local cells = pane:get_dimensions().cols
    if cells < 1 then return end
    local screen = wezterm.gui.screens().active
    ai_sizes[id] = {width=d.pixel_width,height=d.pixel_height}
    center_pending[id] = screen
    window:set_inner_size(math.floor(d.pixel_width + cols * d.pixel_width / cells), d.pixel_height)
  elseif ai_sizes[id] then
    local saved = ai_sizes[id]
    local observed = window:get_dimensions()
    local log = io.open(root .. '/evidence/ai-window-resize.json', 'w')
    if log then
      log:write(wezterm.json_encode({original_width=saved.width,expanded_width=observed.pixel_width,
        original_height=saved.height,expanded_height=observed.pixel_height,restore_requested=true}))
      log:close()
    end
    ai_sizes[id] = nil
    center_pending[id] = wezterm.gui.screens().active
    window:set_inner_size(saved.width, saved.height)
  end
end)
wezterm.on('gui-startup', function(cmd)
  local _, _, window = wezterm.mux.spawn_window(cmd or {})
  local screen = wezterm.gui.screens().active
  local gui = window:gui_window()
  local d = gui:get_dimensions()
  gui:set_position(screen.x + math.max(0,(screen.width-d.pixel_width)/2), screen.y + math.max(0,(screen.height-d.pixel_height)/2))
  local effective = gui:effective_config()
  local f = io.open(root .. '/evidence/wezterm-runtime.json', 'w')
  if f then
    f:write(wezterm.json_encode({version=wezterm.version,opacity=effective.window_background_opacity,
      decorations=effective.window_decorations,font_size=effective.font_size,
      dimensions=d,screen=screen,config_loaded=true}))
    f:close()
  end
end)
return c
