local M={}
local function buffers()
  return vim.tbl_filter(function(b) return vim.bo[b].buflisted and (vim.bo[b].buftype=='' or vim.b[b].desktop_pdf) end,vim.api.nvim_list_bufs())
end
function M.select(_,buf) if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_set_current_buf(buf) end end
function M.render()
  local result=''
  for _,b in ipairs(buffers()) do
    local name=vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b),':t')
    if name=='' then name='Untitled' end
    name=name:gsub('%%','%%%%')
    result=result..'%'..b..'@v:lua.DesktopFileTabsClick@'..(b==vim.api.nvim_get_current_buf() and '%#TabLineSel#' or '%#TabLine#')..'  '..name..(vim.bo[b].modified and ' ●' or '')..'  %T%#TabLineFill# '
  end
  return result..'%#TabLineFill#%='
end
function M.cycle(delta)
  local list=buffers()
  for i,b in ipairs(list) do if b==vim.api.nvim_get_current_buf() then vim.api.nvim_set_current_buf(list[(i-1+delta)%#list+1]);return end end
  if list[1] then vim.api.nvim_set_current_buf(list[1]) end
end
function M.close()
  vim.cmd.stopinsert()
  local buf=vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype~='' and not vim.b[buf].desktop_pdf then return end
  local function remove()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local replacement
    for _,b in ipairs(buffers()) do if b~=buf then replacement=b;break end end
    if not replacement then replacement=vim.api.nvim_create_buf(true,false) end
    for _,win in ipairs(vim.fn.win_findbuf(buf)) do vim.api.nvim_win_set_buf(win,replacement) end
    vim.api.nvim_buf_delete(buf,{force=true})
  end
  if not vim.bo[buf].modified then remove();return end
  local choice=vim.fn.confirm('Save changes before closing?','&Save\n&Discard\n&Cancel',3)
  if choice==2 then remove()
  elseif choice==1 then
    local function save(path)
      if not vim.api.nvim_buf_is_valid(buf) then return end
      vim.api.nvim_buf_call(buf,function()
        local ok,err=pcall(function()
          if path then vim.cmd('saveas '..vim.fn.fnameescape(path)) else vim.cmd.write() end
        end)
        if ok then remove() else vim.notify(tostring(err),vim.log.levels.ERROR) end
      end)
    end
    if vim.api.nvim_buf_get_name(buf)=='' then
      vim.ui.input({prompt='Save as: ',default=vim.fn.getcwd()..'/',completion='file'},function(path) if path and path~='' then save(path) end end)
    else save() end
  end
end
function M.setup()
  _G.DesktopFileTabsClick=function(buf) M.select(nil,buf) end
  _G.DesktopFileTabsRender=M.render
  vim.o.tabline='%!v:lua.DesktopFileTabsRender()'
  vim.o.showtabline=2
  vim.keymap.set({'n','i'},'<C-w>',M.close,{desc='Close file (ask to save)'})
  for _,mode in ipairs({'n','i','t'}) do
    vim.keymap.set(mode,'<C-Left>',function() vim.cmd.stopinsert();vim.cmd('wincmd h') end,{desc='Focus left editor pane'})
    vim.keymap.set(mode,'<C-Right>',function() vim.cmd.stopinsert();vim.cmd('wincmd l') end,{desc='Focus right editor pane'})
  end
  vim.keymap.set({'n','i'},'<F7>',function() vim.o.showtabline=vim.o.showtabline==0 and 2 or 0 end,{desc='Show / hide file tabs'})
  vim.keymap.set({'n','i'},'<C-Tab>',function() vim.cmd.stopinsert();M.cycle(1) end,{desc='Next open file'})
  vim.keymap.set({'n','i'},'<C-S-Tab>',function() vim.cmd.stopinsert();M.cycle(-1) end,{desc='Previous open file'})
end
return M
