local M = {}
local function lines()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  if vim.fn.mode():match('^[vVsS]') then
    local anchor = vim.fn.getpos('v')[2]
    return math.min(row, anchor), math.max(row, anchor)
  end
  return row, row
end
function M.duplicate()
  if vim.bo.buftype ~= '' or not vim.bo.modifiable then return end
  local first, last = lines()
  local content = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  vim.api.nvim_buf_set_lines(0, last, last, false, content)
  vim.api.nvim_win_set_cursor(0, {last + 1, 0})
end
function M.move(delta)
  if vim.bo.buftype ~= '' or not vim.bo.modifiable then return end
  local first, last = lines()
  if first + delta < 1 or last + delta > vim.api.nvim_buf_line_count(0) then return end
  local mode = vim.fn.mode()
  if mode:match('^[vVsS]') then vim.cmd('normal! \27') end
  local target = delta < 0 and first - 2 or last + 1
  vim.cmd(string.format('%d,%dmove %d', first, last, target))
  vim.api.nvim_win_set_cursor(0, {first + delta, 0})
  if first ~= last then
    vim.cmd('normal! V' .. tostring(last - first) .. 'j')
  end
end
function M.replace()
  vim.cmd.stopinsert()
  vim.ui.input({prompt='Find (literal): ',default=vim.fn.expand('<cword>')},function(find)
    if not find or find=='' then return end
    vim.ui.input({prompt='Replace with: '},function(replacement)
      if replacement==nil then return end
      local pattern=vim.fn.escape(find,'\\/')
      local value=vim.fn.escape(replacement,'\\/&')
      local ok,err=pcall(vim.cmd, '%s/\\V' .. pattern .. '/' .. value .. '/gc')
      if not ok then vim.notify(tostring(err),vim.log.levels.WARN) end
    end)
  end)
end
function M.picker(name)
  vim.cmd.stopinsert()
  require('lazy').load({plugins={'telescope.nvim'}})
  require('telescope.builtin')[name]()
end
function M.close_output()
  vim.cmd.stopinsert()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == 'terminal' then
        if #vim.api.nvim_tabpage_list_wins(0) > 1 then
          vim.api.nvim_win_hide(win)
        else
          vim.api.nvim_win_call(win, function() vim.cmd('hide enew') end)
        end
      end
    end
  end
end
function M.setup()
  vim.keymap.set('n', '<C-/>', 'gcc', {remap=true,desc='Toggle comment'})
  vim.keymap.set('i', '<C-/>', '<Esc>gccgi', {remap=true,desc='Toggle comment'})
  vim.keymap.set('x', '<C-/>', 'gc', {remap=true,desc='Toggle selection comment'})
  vim.keymap.set('s', '<C-/>', '<C-g>gc', {remap=true,desc='Toggle selection comment'})
  vim.keymap.set({'n','i'}, '<C-l>', '<Esc>V', {desc='Select line'})
  vim.keymap.set('x', '<C-l>', 'j', {desc='Extend line selection'})
  vim.keymap.set({'n','i','x','s'}, '<C-d>', M.duplicate, {desc='Duplicate lines'})
  vim.keymap.set({'n','i','x','s'}, '<A-Up>', function() M.move(-1) end, {desc='Move lines up'})
  vim.keymap.set({'n','i','x','s'}, '<A-Down>', function() M.move(1) end, {desc='Move lines down'})
  vim.keymap.set({'n','i'}, '<C-f>', '<Esc>/', {desc='Find in file; Enter then n/N'})
  vim.keymap.set({'n','i'}, '<C-h>', M.replace, {desc='Find and replace with confirmation'})
  vim.keymap.set({'n','i'}, '<C-S-f>', function() M.picker('live_grep') end, {desc='Search project'})
  vim.keymap.set({'n','i'}, '<A-e>', function() M.picker('buffers') end, {desc='Switch open files'})
  vim.keymap.set({'n','i'}, '<F1>', function() M.picker('keymaps') end, {desc='Show keyboard shortcuts'})
  vim.keymap.set('x', '<Tab>', '>gv', {desc='Indent selected lines'})
  vim.keymap.set('x', '<S-Tab>', '<gv', {desc='Unindent selected lines'})
  vim.keymap.set('s', '<Tab>', '<C-g>>gv', {desc='Indent selected lines'})
  vim.keymap.set('s', '<S-Tab>', '<C-g><gv', {desc='Unindent selected lines'})
  vim.keymap.set({'n','i'}, '<C-b>', function() vim.cmd.stopinsert();vim.cmd.NvimTreeToggle() end, {desc='Toggle explorer'})
  vim.keymap.set({'n','i'}, '<C-S-p>', function() M.picker('commands') end, {desc='Command palette'})
  vim.opt.keymodel = 'startsel,stopsel'
  vim.opt.selectmode = 'mouse,key'
  vim.keymap.set({'n', 'i'}, '<C-a>', '<Esc>ggVG', { desc = 'Select all' })
  vim.keymap.set('n', '<C-z>', 'u', { desc = 'Undo' })
  vim.keymap.set('i', '<C-z>', '<C-o>u', { desc = 'Undo' })
  vim.keymap.set('x', '<C-z>', '<Esc>u', { desc = 'Undo' })
  vim.keymap.set('s', '<C-z>', '<Esc>u', { desc = 'Undo' })
  vim.keymap.set('n', '<C-y>', '<C-r>', { desc = 'Redo' })
  vim.keymap.set('i', '<C-y>', '<C-o><C-r>', { desc = 'Redo' })
  vim.keymap.set('n', '<C-S-z>', '<C-r>', { desc = 'Redo' })
  vim.keymap.set('i', '<C-S-z>', '<C-o><C-r>', { desc = 'Redo' })
  vim.keymap.set('x', '<C-c>', '"+y', { desc = 'Copy selection' })
  vim.keymap.set('s', '<C-c>', '<C-g>"+y', { desc = 'Copy selection' })
  vim.keymap.set('n', '<C-c>', '"+yy', { desc = 'Copy line' })
  vim.keymap.set('i', '<C-c>', '<C-o>"+yy', { desc = 'Copy line' })
  vim.keymap.set('x', '<C-x>', '"+d', { desc = 'Cut selection' })
  vim.keymap.set('s', '<C-x>', '<C-g>"+d', { desc = 'Cut selection' })
  vim.keymap.set('n', '<C-x>', '"+dd', { desc = 'Cut line' })
  vim.keymap.set('i', '<C-x>', '<C-o>"+dd', { desc = 'Cut line' })
  vim.keymap.set({'n', 'i'}, '<C-Tab>', function() vim.cmd.stopinsert(); vim.cmd.tabnext() end, { desc = 'Next editor tab' })
  vim.keymap.set({'n', 'i'}, '<C-S-Tab>', function() vim.cmd.stopinsert(); vim.cmd.tabprevious() end, { desc = 'Previous editor tab' })
  vim.keymap.set({'n', 't'}, '<C-q>', M.close_output, { desc = 'Close output panel' })
  vim.opt.wildmenu = true
  vim.opt.wildmode = 'longest:full,full'
  vim.opt.wildoptions = 'pum'
  vim.opt.wildignorecase = true
  vim.keymap.set('c', '<Tab>', '<C-z>', { desc = 'Complete command / path' })
  vim.keymap.set('c', '<S-Tab>', '<C-p>', { desc = 'Previous completion' })
  vim.keymap.set('c', '<C-v>', '<C-r>+', { desc = 'Paste clipboard into command' })
  vim.keymap.set('i', '<C-v>', '<C-r><C-p>+', { desc = 'Paste clipboard' })
  vim.keymap.set('n', '<C-v>', '"+p', { desc = 'Paste clipboard' })
  vim.keymap.set('x', '<C-v>', '"+p', { desc = 'Replace selection with clipboard' })
  vim.keymap.set('s', '<C-v>', '<C-g>"+p', { desc = 'Replace selection with clipboard' })
end
return M
