local M={}
function M.open(path)
  path=vim.fn.fnamemodify(vim.fn.expand(path:gsub('\\','/')),':p')
  if not path:lower():match('%.pdf$') or vim.fn.filereadable(path)~=1 then vim.notify('Choose an existing PDF file',vim.log.levels.WARN);return end
  vim.cmd.edit(vim.fn.fnameescape(path))
end
function M.page(buf,page)
  local path=vim.api.nvim_buf_get_name(buf)
  vim.system({vim.env.CODING_PYTHON,vim.env.TRANSPARENT_CODING_ROOT..'/scripts/read_pdf.py',path,tostring(page)},{text=true},vim.schedule_wrap(function(r)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local lines
    if r.code~=0 then lines={'PDF could not be read:',r.stderr}
    else
      local ok,data=pcall(vim.json.decode,r.stdout)
      if not ok then lines={'Invalid PDF reader response'} else
        vim.b[buf].pdf_page=data.page
        vim.b[buf].pdf_pages=data.pages
        lines={string.format('PDF  |  Page %d / %d  |  ]p next  [p previous  gp go to page',data.page,data.pages),'────────────────────────────────────────────────────────'}
        vim.list_extend(lines,vim.split(data.text~='' and data.text or '[No text on this page. Scanned/images-only PDF needs OCR.]','\n'))
      end
    end
    vim.bo[buf].modifiable=true
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    vim.bo[buf].modified=false
    vim.bo[buf].modifiable=false
  end))
end
function M.read(buf)
  vim.b[buf].desktop_pdf=true
  vim.b[buf].pdf_page=1
  vim.bo[buf].buftype='nofile'
  vim.bo[buf].buflisted=true
  vim.bo[buf].swapfile=false
  vim.bo[buf].filetype='desktop_pdf'
  vim.bo[buf].modifiable=true
  vim.api.nvim_buf_set_lines(buf,0,-1,false,{'Loading PDF…'})
  vim.bo[buf].modified=false
  vim.bo[buf].modifiable=false
  vim.keymap.set('n',']p',function() M.page(buf,(vim.b[buf].pdf_page or 1)+1) end,{buffer=buf,desc='Next PDF page'})
  vim.keymap.set('n','[p',function() M.page(buf,math.max(1,(vim.b[buf].pdf_page or 1)-1)) end,{buffer=buf,desc='Previous PDF page'})
  vim.keymap.set('n','gp',function() vim.ui.input({prompt='PDF page: '},function(p) if tonumber(p) then M.page(buf,tonumber(p)) end end) end,{buffer=buf})
  M.page(buf,1)
end
function M.pick()
  require('lazy').load({plugins={'telescope.nvim'}})
  local pickers=require('telescope.pickers')
  local finders=require('telescope.finders')
  local actions=require('telescope.actions')
  local state=require('telescope.actions.state')
  local files=vim.fn.globpath(vim.fn.getcwd(),'**/*.pdf',false,true)
  pickers.new({}, {prompt_title='Read PDF in editor',finder=finders.new_table({results=files}),
    sorter=require('telescope.config').values.generic_sorter({}),attach_mappings=function(buf)
      actions.select_default:replace(function() local entry=state.get_selected_entry();actions.close(buf);if entry then M.open(entry[1]) end end)
      return true
    end}):find()
end
function M.setup()
  local group=vim.api.nvim_create_augroup('DesktopPDF',{clear=true})
  vim.api.nvim_create_autocmd('BufReadCmd',{group=group,pattern={'*.pdf','*.PDF'},callback=function(e) M.read(e.buf) end})
  vim.api.nvim_create_user_command('PDF',function(o) if o.args=='' then M.pick() else M.open(o.args) end end,{nargs='?',complete='file',force=true})
  vim.keymap.set('n','<leader>pd',M.pick,{desc='Read project PDF in editor'})
end
return M
