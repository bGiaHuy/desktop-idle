local M={}
function M.open(url)
  url=vim.trim(url or '')
  if url=='' then url='about:blank' end
  if url:match('^localhost[:/]') or url:match('^127%.0%.0%.1[:/]') then url='http://'..url end
  if not url:match('^%a[%w+.-]*:') then url='https://'..url end
  if not (url:match('^https?://') or url=='about:blank') then vim.notify('Use an HTTP or HTTPS URL',vim.log.levels.WARN);return end
  local buf=vim.api.nvim_create_buf(true,true)
  vim.b[buf].desktop_browser=true
  vim.b[buf].desktop_tab_label='Browser '..buf
  vim.b[buf].browser_url=url
  vim.bo[buf].buftype='nofile'
  vim.bo[buf].bufhidden='hide'
  vim.bo[buf].swapfile=false
  vim.api.nvim_buf_set_name(buf,'desktop-browser://'..buf)
  vim.api.nvim_buf_set_lines(buf,0,-1,false,{'Browser  |  '..url,'Click the address bar to navigate. Click this header to return to editor shortcuts.','Starting WebView2…'})
  vim.bo[buf].modifiable=false
  vim.bo[buf].modified=false
  vim.api.nvim_set_current_buf(buf)
  vim.wo.wrap=false
  require('pdf_graphics').start(buf)
end
function M.setup()
  vim.api.nvim_create_user_command('Browser',function(o) M.open(o.args) end,{nargs='?',force=true})
  -- Neovim requires uppercase user commands; abbreviation provides the requested :brs.
  vim.cmd([[cnoreabbrev <expr> brs getcmdtype() == ':' && getcmdline() ==# 'brs' ? 'Browser' : 'brs']])
end
return M
