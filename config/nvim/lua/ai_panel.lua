local M = {}
local sessions = {}
local expanded=false
local pending=false
local function resize_terminal(cols)
  if not vim.env.WEZTERM_PANE then return end
  local sequence='\27]1337;SetUserVar=CODING_AI_WIDTH='..vim.base64.encode(tostring(cols))..'\7'
  io.stdout:write(sequence)
  io.stdout:flush()
end
local function executable()
  local found=vim.fn.exepath('codex')
  if found~='' then return found end
  local base=vim.env.LOCALAPPDATA .. '/OpenAI/Codex/bin'
  local matches=vim.fn.glob(base .. '/*/codex.exe',false,true)
  table.sort(matches,function(a,b) return vim.fn.getftime(a)>vim.fn.getftime(b) end)
  return matches[1]
end
local function toggle_panel(width)
  vim.cmd.stopinsert()
  -- Each project retains its own running conversation.
  local cwd=vim.fn.getcwd()
  local key=vim.fs.normalize(cwd):lower()
  local session=sessions[key]
  if session and vim.api.nvim_buf_is_valid(session.buf) then
    local windows=vim.fn.win_findbuf(session.buf)
    for _,win in ipairs(windows) do
      if vim.api.nvim_win_get_tabpage(win)==vim.api.nvim_get_current_tabpage() then
        if #vim.api.nvim_tabpage_list_wins(0)>1 then vim.api.nvim_win_hide(win)
        else vim.cmd('hide enew') end
        resize_terminal(0)
        expanded=false
        return
      end
    end
    if vim.fn.jobwait({session.job},0)[1]~=-1 then
      sessions[key]=nil
      session=nil
    end
  else session=nil end
  local cmd=executable()
  if not cmd then vim.notify('Codex CLI not found on this machine',vim.log.levels.ERROR);return end
  width=width or math.min(76,math.max(38,math.floor(vim.o.columns*0.42)))
  vim.cmd('botright '..width..'vnew')
  if session then
    local empty=vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_buf(0,session.buf)
    vim.api.nvim_buf_delete(empty,{force=true})
  else
    local buf=vim.api.nvim_get_current_buf()
    vim.bo[buf].bufhidden='hide'
    local job=vim.fn.jobstart({cmd,'--no-alt-screen','--cd',cwd},{term=true,cwd=cwd})
    if job<=0 then vim.cmd.bwipeout();vim.notify('Could not start Codex CLI',vim.log.levels.ERROR);return end
    sessions[key]={buf=buf,job=job,cwd=cwd}
    vim.b[buf].coding_ai_panel=true
    vim.b[buf].coding_ai_cwd=cwd
  end
  vim.wo.number=false
  vim.wo.relativenumber=false
  vim.wo.signcolumn='no'
  vim.wo.winfixwidth=true
  vim.cmd.startinsert()
end
function M.toggle()
  if pending then return end
  local visible=false
  for _,win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.b[vim.api.nvim_win_get_buf(win)].coding_ai_panel then visible=true;break end
  end
  if visible or not vim.env.WEZTERM_PANE then toggle_panel();return end
  local width=62
  local before=vim.o.columns
  pending=true
  resize_terminal(width+1)
  expanded=true
  vim.defer_fn(function()
    pending=false
    if vim.o.columns<=before then
      vim.notify('Window could not expand (screen edge/fullscreen); AI shares available space',vim.log.levels.INFO)
    end
    toggle_panel(width)
  end,400)
end
function M.setup()
  vim.keymap.set({'n','i','t'},'<F8>',M.toggle,{desc='Toggle Codex AI sidebar'})
  vim.keymap.set('n','<leader>ai',M.toggle,{desc='Codex AI sidebar'})
  local group=vim.api.nvim_create_augroup('CodingAIRefresh',{clear=true})
  vim.api.nvim_create_autocmd('WinClosed',{group=group,callback=function()
    vim.schedule(function()
      if not expanded then return end
      for _,win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.b[vim.api.nvim_win_get_buf(win)].coding_ai_panel then return end
      end
      resize_terminal(0)
      expanded=false
    end)
  end})
  vim.api.nvim_create_autocmd('VimLeavePre',{group=group,callback=function() if expanded then resize_terminal(0) end end})
  vim.api.nvim_create_autocmd({'FocusGained','BufEnter'},{group=group,callback=function()
    if vim.bo.buftype=='' and not vim.bo.modified then vim.cmd('silent! checktime') end
  end})
end
return M
