return {
  { 'catppuccin/nvim', name='catppuccin', priority=1000, config=function()
    require('catppuccin').setup({flavour='mocha',transparent_background=true,
      integrations={cmp=true,gitsigns=true,nvimtree=true,treesitter=true},
      custom_highlights=function(c) return {CursorLine={bg=c.surface0},NormalFloat={bg='NONE'},FloatBorder={bg='NONE',fg=c.overlay1}} end})
    vim.cmd.colorscheme('catppuccin')
  end },
  { 'folke/tokyonight.nvim', lazy=true, opts={transparent=true,styles={sidebars='transparent',floats='transparent'}} },
  { 'nvim-tree/nvim-web-devicons' },
  { 'nvim-tree/nvim-tree.lua', cmd={'NvimTreeOpen','NvimTreeToggle','NvimTreeClose','NvimTreeFindFile'}, dependencies={'nvim-tree/nvim-web-devicons'}, opts={sync_root_with_cwd=true,respect_buf_cwd=true,view={width=28},renderer={highlight_git=true},filters={dotfiles=false}}, keys={{'<leader>e','<cmd>NvimTreeToggle<cr>',desc='Explorer'}} },
  { 'nvim-lualine/lualine.nvim', opts={options={theme='auto',component_separators='',section_separators=''},sections={lualine_a={'mode'},lualine_b={'branch'},lualine_c={{'filename',path=1}},lualine_x={'diagnostics','filetype'},lualine_y={'progress'},lualine_z={'location'}}} },
  { 'lewis6991/gitsigns.nvim', opts={} },
  { 'lukas-reineke/indent-blankline.nvim', main='ibl', opts={scope={enabled=false}} },
  { 'nvim-treesitter/nvim-treesitter', branch='master', build=':TSUpdate', config=function()
    require('nvim-treesitter.configs').setup({ensure_installed={},highlight={enable=true},indent={enable=true}})
  end },
  { 'nvim-telescope/telescope.nvim', cmd='Telescope', dependencies={'nvim-lua/plenary.nvim'}, opts={}, keys={
    {'<leader>ff','<cmd>Telescope find_files<cr>',desc='Find file'},
    {'<leader>fg','<cmd>Telescope live_grep<cr>',desc='Search project'},
    {'<leader>fb','<cmd>Telescope buffers<cr>',desc='Buffers'},
    {'<leader>gs','<cmd>Telescope git_status<cr>',desc='Git status'},
  } },
  { 'hrsh7th/nvim-cmp', dependencies={'hrsh7th/cmp-nvim-lsp','hrsh7th/cmp-buffer','hrsh7th/cmp-path'}, config=function()
    local cmp=require('cmp')
    cmp.setup({snippet={expand=function(args) vim.snippet.expand(args.body) end},
      mapping=cmp.mapping.preset.insert({['<C-Space>']=cmp.mapping.complete(),['<CR>']=cmp.mapping.confirm({select=false}),['<C-e>']=cmp.mapping.abort(),['<Tab>']=cmp.mapping.select_next_item(),['<S-Tab>']=cmp.mapping.select_prev_item()}),
      sources=cmp.config.sources({{name='nvim_lsp'},{name='path'}},{{name='buffer'}})})
  end },
  { 'mfussenegger/nvim-dap', config=function()
    local dap=require('dap')
    dap.adapters.python={type='executable',command=vim.env.CODING_PYTHON,args={'-m','debugpy.adapter'},options={detached=false}}
    dap.configurations.python={{type='python',request='launch',name='Python: current file',program='${file}',console='integratedTerminal',pythonPath=function() return require('coding').python() end}}
    vim.keymap.set('n','<F5>',dap.continue,{desc='Debug continue'})
    vim.keymap.set('n','<leader>db',dap.toggle_breakpoint,{desc='Breakpoint'})
  end },
}
