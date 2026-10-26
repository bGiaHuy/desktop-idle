local M={}
function M.context()
  local mode=vim.fn.mode()
  local buf=vim.api.nvim_get_current_buf()
  local line=vim.api.nvim_win_get_cursor(0)[1]
  local text=vim.api.nvim_get_current_line()
  if mode:match('^[vVsS\22\19]') then
    local a=vim.fn.getpos('v')
    local b=vim.fn.getpos('.')
    local ok,region=pcall(vim.fn.getregion,a,b,{type=mode:sub(1,1):gsub('s','v'):gsub('S','V')})
    if ok then text=table.concat(region,'\n');line=math.min(a[2],b[2]) end
  end
  return {buf=buf,path=vim.api.nvim_buf_get_name(buf),line=line,text=text,mode=mode}
end
function M.prompt(action,context)
  local text=context.text
  if #text>24000 then text=text:sub(1,24000)..'\n[Selection truncated]' end
  return action..'\nFile: '..(context.path~='' and context.path or '[unsaved buffer]')..'\nStarting line: '..context.line..'\nThe excerpt below is editor context, possibly unsaved:\n```\n'..text..'\n```'
end
function M.open()
  if vim.bo.buftype=='terminal' then return end
  local context=M.context()
  local source=vim.api.nvim_get_current_win()
  vim.cmd.stopinsert()
  if vim.fn.mode():match('^[vVsS\22\19]') then vim.cmd('normal! \27') end
  local entries={
    {'Ask AI about this…',function() vim.ui.input({prompt='Ask Codex: '},function(q) if q and q~='' then require('ai_panel').draft(M.prompt(q,context)) end end) end},
    {'Explain selection',function() require('ai_panel').draft(M.prompt('Explain this code in Vietnamese. Do not modify files.',context)) end},
    {'Find issues',function() require('ai_panel').draft(M.prompt('Review this code for bugs. Explain findings before making changes.',context)) end},
    {'Refactor…',function() require('ai_panel').draft(M.prompt('Suggest a refactor of this code that preserves behavior. Ask before applying changes.',context)) end},
    {'Go to definition',vim.lsp.buf.definition},
    {'Rename symbol',vim.lsp.buf.rename},
    {'Code actions',vim.lsp.buf.code_action},
    {'Show diagnostics',function() vim.diagnostic.open_float({border='rounded'}) end},
    {'Copy selection / line',function() vim.fn.setreg('+',context.text) end},
    {'Paste',function() vim.api.nvim_paste(vim.fn.getreg('+'),false,-1) end},
    {'Select all',function() vim.cmd('normal! ggVG') end},
  }
  local labels={}
  for _,entry in ipairs(entries) do table.insert(labels,'  '..entry[1]..'  ') end
  local buf=vim.api.nvim_create_buf(false,true)
  vim.bo[buf].bufhidden='wipe'
  vim.api.nvim_buf_set_lines(buf,0,-1,false,labels)
  vim.bo[buf].modifiable=false
  local mouse=vim.fn.getmousepos()
  local row=math.max(0,math.min((mouse.screenrow or 2)-1,vim.o.lines-#labels-4))
  local col=math.max(0,math.min((mouse.screencol or 2)-1,vim.o.columns-33))
  local win=vim.api.nvim_open_win(buf,true,{relative='editor',row=row,col=col,width=32,height=#labels,style='minimal',border='rounded',title=' Actions ',title_pos='center',zindex=200})
  vim.wo[win].winblend=0
  vim.wo[win].winhighlight='Normal:DesktopMenu,FloatBorder:DesktopMenuBorder,CursorLine:DesktopMenuSelected'
  vim.wo[win].cursorline=true
  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win,true) end
    if vim.api.nvim_win_is_valid(source) then vim.api.nvim_set_current_win(source) end
  end
  local function choose()
    local index=vim.api.nvim_win_get_cursor(win)[1]
    close()
    if vim.api.nvim_buf_is_valid(context.buf) then vim.api.nvim_set_current_buf(context.buf);entries[index][2]() end
  end
  for _,key in ipairs({'<CR>','<LeftRelease>'}) do vim.keymap.set('n',key,choose,{buffer=buf}) end
  for _,key in ipairs({'<Esc>','q','<RightMouse>'}) do vim.keymap.set('n',key,close,{buffer=buf}) end
  vim.api.nvim_create_autocmd('WinLeave',{buffer=buf,once=true,callback=function() vim.schedule(function() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win,true) end end) end})
end
function M.setup()
  -- popup_setpos consumes right-click before the custom mouse mapping.
  vim.opt.mousemodel='extend'
  local function colors()
    vim.api.nvim_set_hl(0,'DesktopMenu',{fg='#cdd6f4',bg='#181825'})
    vim.api.nvim_set_hl(0,'DesktopMenuBorder',{fg='#89b4fa',bg='#181825'})
    vim.api.nvim_set_hl(0,'DesktopMenuSelected',{fg='#cdd6f4',bg='#45475a',bold=true})
  end
  colors()
  local group=vim.api.nvim_create_augroup('DesktopContextMenu',{clear=true})
  vim.api.nvim_create_autocmd('ColorScheme',{group=group,callback=colors})
  vim.keymap.set({'n','x','s','i'},'<RightMouse>',M.open,{desc='Editor context menu'})
  vim.keymap.set({'n','x','s','i'},'<RightRelease>','<Nop>',{desc='Keep custom context menu'})
  vim.keymap.set({'n','x'},'<S-F10>',M.open,{desc='Editor context menu'})
end
return M
