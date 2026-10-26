local M={}
local map=vim.keymap.set
function M.open()
  vim.cmd.stopinsert()
  require('lazy').load({plugins={'telescope.nvim'}})
  require('telescope.builtin').find_files({hidden=true})
end
function M.save()
  if vim.bo.buftype~='' then
    vim.notify('Select a file buffer before saving',vim.log.levels.WARN)
    return
  end
  local buffer=vim.api.nvim_get_current_buf()
  local function write(path)
    if not vim.api.nvim_buf_is_valid(buffer) then return end
    vim.api.nvim_buf_call(buffer,function()
      local ok,err=pcall(function()
        if path then vim.cmd('saveas ' .. vim.fn.fnameescape(vim.fn.fnamemodify(path,':p')))
        else vim.cmd.write() end
      end)
      if not ok then vim.notify(tostring(err),vim.log.levels.ERROR) end
    end)
  end
  if vim.api.nvim_buf_get_name(buffer)=='' then
    vim.ui.input({prompt='Save as: ',default=vim.fn.getcwd() .. '/',completion='file'},function(path)
      if path and path:match('%S') then write(path) end
    end)
  else write() end
end
map('n','<C-o>',M.open,{desc='Open file'})
map('n','<Home>',M.open,{desc='Open file'})
map('i','<C-o>',function() vim.cmd.stopinsert();vim.schedule(M.open) end,{desc='Open file'})
map('i','<Home>',function() vim.cmd.stopinsert();vim.schedule(M.open) end,{desc='Open file'})
map('n','<C-s>',M.save,{desc='Save / Save as'})
map({'i','v'},'<C-s>','<Esc><Cmd>lua require("coding").save()<CR>',{desc='Save / Save as'})
function M.python()
  if vim.env.VIRTUAL_ENV then return vim.env.VIRTUAL_ENV .. '/Scripts/python.exe' end
  local root=vim.fs.root(0,{'.venv','pyproject.toml','.git'}) or vim.fn.getcwd()
  local p=root .. '/.venv/Scripts/python.exe'
  return vim.fn.executable(p)==1 and p or vim.env.CODING_PYTHON
end
function M.terminal(argv,cwd)
  vim.cmd('botright 12new')
  vim.fn.jobstart(argv,{term=true,cwd=cwd or vim.fn.getcwd()})
  vim.cmd.startinsert()
end
function M.run()
  if vim.bo.buftype~='' then return end
  vim.cmd.write()
  local file=vim.api.nvim_buf_get_name(0)
  local cwd=vim.fs.dirname(file)
  if vim.bo.filetype=='python' then M.terminal({M.python(),file},cwd)
  elseif vim.bo.filetype=='cpp' then
    local exe=vim.fn.stdpath('cache') .. '/build/' .. vim.fn.sha256(file):sub(1,16) .. '.exe'
    vim.fn.mkdir(vim.fs.dirname(exe),'p')
    vim.system({'g++','-std=c++20','-Wall','-Wextra','-g',file,'-o',exe},{text=true,cwd=cwd},vim.schedule_wrap(function(r)
      if r.code==0 then M.terminal({exe},cwd) else
        vim.fn.setqflist({},' ',{title='C++ build',lines=vim.split(r.stderr,'\n')})
        vim.cmd.copen()
      end
    end))
  else vim.notify('Run supports Python and C++',vim.log.levels.WARN) end
end
map('n','<F6>',M.run,{desc='Run Python / build C++20'})
map('n','<leader>rr',M.run,{desc='Run current file'})
map('n','<leader>tt',function() M.terminal({vim.env.CODING_SHELL,'-NoLogo','-NoProfile'}) end,{desc='Terminal'})
map('t','<Esc><Esc>',[[<C-\><C-n>]])
map('n','<leader>ai',function() M.terminal({'codex'}) end,{desc='Codex CLI'})
map('n','<leader>ac',function()
  if vim.fn.executable('claude')==1 then M.terminal({'claude'}) else vim.notify('Claude Code is not installed') end
end,{desc='Claude Code if installed'})
map('n','<leader>ct',function()
  if vim.g.colors_name=='tokyonight' then vim.cmd.colorscheme('catppuccin') else vim.cmd.colorscheme('tokyonight') end
end,{desc='Toggle theme'})
map('n','<leader>cf',function()
  vim.cmd.write()
  local file=vim.api.nvim_buf_get_name(0)
  local args=vim.bo.filetype=='python' and {'ruff','format',file} or {'clang-format','-i',file}
  local r=vim.system(args,{text=true}):wait()
  if r.code==0 then vim.cmd.checktime() else vim.notify(r.stderr,vim.log.levels.ERROR) end
end,{desc='Format file'})
local caps=require('cmp_nvim_lsp').default_capabilities()
vim.lsp.config('pyright',{cmd={'pyright-langserver.cmd','--stdio'},filetypes={'python'},root_markers={'pyproject.toml','.git'},capabilities=caps,
  before_init=function(_,c) c.settings=c.settings or {}; c.settings.python={pythonPath=M.python(),analysis={autoSearchPaths=true,useLibraryCodeForTypes=true,autoImportCompletions=true}} end})
vim.lsp.config('ruff',{cmd={'ruff','server'},filetypes={'python'},root_markers={'pyproject.toml','ruff.toml','.git'},capabilities=caps})
local driver=vim.fn.exepath('g++'):gsub('\\','/')
local clangd_cmd={'clangd','--background-index','--clang-tidy'}
if driver~='' then table.insert(clangd_cmd,'--query-driver='..driver) end
vim.lsp.config('clangd',{cmd=clangd_cmd,filetypes={'c','cpp'},root_markers={'compile_commands.json','.clangd','.git'},capabilities=caps,
  init_options={fallbackFlags={'-std=c++20','--target=x86_64-w64-windows-gnu'}}})
vim.lsp.enable({'pyright','ruff','clangd'})
map({'n','i'},'<C-k>',function() vim.lsp.buf.signature_help({border='rounded'}) end,{desc='Show function / constructor parameters'})
local signature_group=vim.api.nvim_create_augroup('CodingSignatureHelp',{clear=true})
vim.api.nvim_create_autocmd('InsertCharPre',{group=signature_group,callback=function()
  if vim.v.char~='(' and vim.v.char~=',' then return end
  local buf=vim.api.nvim_get_current_buf()
  vim.defer_fn(function()
    if vim.api.nvim_get_current_buf()~=buf or vim.fn.mode()~='i' then return end
    for _,client in ipairs(vim.lsp.get_clients({bufnr=buf})) do
      if client:supports_method('textDocument/signatureHelp',buf) then
        vim.lsp.buf.signature_help({border='rounded',focusable=false})
        break
      end
    end
  end,180)
end})
vim.diagnostic.config({virtual_text={prefix='●'},severity_sort=true,float={border='rounded'},underline=true})
map('n','gd',vim.lsp.buf.definition)
map('n','gr',vim.lsp.buf.references)
map('n','K',vim.lsp.buf.hover)
map('n','<leader>rn',vim.lsp.buf.rename)
map('n','<leader>ca',vim.lsp.buf.code_action)
return M
