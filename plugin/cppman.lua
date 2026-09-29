-- Open cppman in a separate window; keep K for LSP hover in code buffers.
local function open_manual(query)
  query = vim.trim(query or '')
  if query == '' then
    return
  end
  if vim.fn.executable('cppman') == 0 then
    vim.notify('Install cppman first: brew install cppman', vim.log.levels.ERROR)
    return
  end

  vim.cmd('botright new')
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'man'
  vim.bo[buf].iskeyword = vim.bo[buf].iskeyword .. ',:'
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    'Loading ' .. query .. ' …',
    'The first lookup requires an internet connection. Press q to close.',
  })
  vim.bo[buf].modifiable = false
  vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf, silent = true })
  vim.keymap.set('n', 'K', function()
    open_manual(vim.fn.expand('<cword>'))
  end, { buffer = buf, desc = 'Look up this C++ symbol' })

  vim.system({
    'cppman', '--force-columns=' .. math.max(40, vim.api.nvim_win_get_width(win)), '--', query,
  }, { text = true, timeout = 60000 }, vim.schedule_wrap(function(result)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local output = vim.trim(result.stdout or '')
    if result.code ~= 0 or output == '' then
      output = 'Lookup failed: ' .. query .. '\n'
        .. vim.trim(result.stderr or '') .. '\nCheck the symbol name or your connection, then retry with :Cppman.'
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, '\n', { plain = true }))
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
  end))
end

local function prompt()
  vim.ui.input({ prompt = 'C++ documentation (e.g. std::thread): ' }, function(query)
    if query then
      open_manual(query)
    end
  end)
end

vim.api.nvim_create_user_command('Cppman', function(args)
  if args.args == '' then
    prompt()
  else
    open_manual(args.args)
  end
end, { nargs = '*', desc = 'Look up C++ standard library documentation with cppman' })

vim.keymap.set('n', '<leader>cm', function()
  open_manual(vim.fn.expand('<cword>'))
end, { desc = 'C++: Look up the symbol under the cursor' })
vim.keymap.set('n', '<leader>cs', prompt, { desc = 'C++: Search documentation by name' })
