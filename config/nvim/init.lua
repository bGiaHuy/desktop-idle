vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.python3_host_prog = vim.env.CODING_PYTHON
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.signcolumn = 'yes'
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.scrolloff = 7
vim.opt.wrap = false
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'
vim.opt.updatetime = 250
vim.opt.showmode = false
vim.opt.laststatus = 3
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.undofile = true
vim.opt.shell = vim.env.CODING_SHELL
vim.opt.shellcmdflag = '-NoLogo -NoProfile -Command'
vim.opt.shellquote = ''
vim.opt.shellxquote = ''
local lazy = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazy) then
  error('lazy.nvim is missing. Restore the supplied data directory or run the installation script.')
end
vim.opt.rtp:prepend(lazy)
require('lazy').setup('plugins', {
  lockfile=vim.fn.stdpath('config') .. '/lazy-lock.json',
  checker={enabled=false}, change_detection={notify=false},
})
require('coding')
require('desktop_keys').setup()
require('ai_panel').setup()
require('file_tabs').setup()
require('pdf_reader').setup()
require('context_menu').setup()
