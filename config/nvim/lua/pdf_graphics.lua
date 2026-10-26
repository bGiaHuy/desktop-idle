local M={}
local sessions={}
local timer
M.enabled=vim.env.DESKTOP_IDLE_PDF_GRAPHICS=='1'
local function sync()
  for buf,s in pairs(sessions) do
    if not vim.api.nvim_buf_is_valid(buf) then
      vim.fn.delete(s.control)
      sessions[buf]=nil
    else
      local state={visible=false,buf=buf,current_buf=vim.api.nvim_get_current_buf(),windows=vim.fn.win_findbuf(buf)}
      for _,win in ipairs(vim.fn.win_findbuf(buf)) do
        if vim.api.nvim_win_get_tabpage(win)==vim.api.nvim_get_current_tabpage() then
          local pos=vim.fn.win_screenpos(win)
          state={visible=true,x=(pos[2]-1)/vim.o.columns,y=(pos[1]+1)/vim.o.lines,
            width=vim.api.nvim_win_get_width(win)/vim.o.columns,
            height=math.max(1,vim.api.nvim_win_get_height(win)-2)/vim.o.lines}
          break
        end
      end
      vim.fn.writefile({vim.json.encode(state)},s.control)
    end
  end
end
function M.stop(buf)
  local s=sessions[buf]
  if s then vim.fn.delete(s.control);sessions[buf]=nil end
end
function M.start(buf)
  if sessions[buf] then return end
  local root=vim.env.TRANSPARENT_CODING_ROOT
  local script=root..'/scripts/pdf_webview.py'
  if vim.fn.filereadable(script)~=1 then vim.notify('Graphical PDF viewer is not installed');return end
  local control=vim.fn.stdpath('cache')..'/pdf-'..vim.fn.getpid()..'-'..buf..'.json'
  vim.fn.mkdir(vim.fs.dirname(control),'p')
  sessions[buf]={control=control}
  sync()
  local stderr={}
  local job=vim.fn.jobstart({vim.env.CODING_PYTHON,script,'--file',vim.api.nvim_buf_get_name(buf),'--control',control,'--pid',tostring(vim.fn.getpid())},{
    stderr_buffered=true,on_stderr=function(_,data) stderr=data end,
    on_exit=function(_,code)
      vim.schedule(function()
        M.stop(buf)
        if code~=0 then vim.notify('PDF graphics stopped; text reader remains available. '..table.concat(stderr,' '),vim.log.levels.WARN) end
      end)
    end})
  if job<=0 then M.stop(buf);return end
  sessions[buf].job=job
  if not timer then
    timer=vim.uv.new_timer()
    timer:start(0,200,vim.schedule_wrap(sync))
  end
end
function M.toggle()
  local buf=vim.api.nvim_get_current_buf()
  if not vim.b[buf].desktop_pdf then vim.notify('Open a PDF first');return end
  if sessions[buf] then M.enabled=false;M.stop(buf) else M.enabled=true;M.start(buf) end
end
function M.setup()
  vim.api.nvim_create_user_command('PDFGraphics',M.toggle,{force=true})
  local group=vim.api.nvim_create_augroup('DesktopPDFGraphics',{clear=true})
  vim.api.nvim_create_autocmd('BufEnter',{group=group,callback=function(e)
    if M.enabled and vim.b[e.buf].desktop_pdf then
      vim.schedule(function() if vim.api.nvim_buf_is_valid(e.buf) then M.start(e.buf) end end)
    end
  end})
  vim.api.nvim_create_autocmd('BufWipeout',{group=group,callback=function(e) M.stop(e.buf) end})
  vim.api.nvim_create_autocmd('VimLeavePre',{group=group,callback=function()
    for buf in pairs(sessions) do M.stop(buf) end
    if timer then timer:stop();timer:close();timer=nil end
  end})
end
return M
