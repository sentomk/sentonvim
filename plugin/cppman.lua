-- cppman 文档在独立窗口打开，代码中的 K 继续用于 LSP hover。
local function open_manual(query)
  query = vim.trim(query or '')
  if query == '' then
    return
  end
  if vim.fn.executable('cppman') == 0 then
    vim.notify('请先安装 cppman：brew install cppman', vim.log.levels.ERROR)
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
    '正在加载 ' .. query .. ' …',
    '首次查询需要联网；q 关闭文档。',
  })
  vim.bo[buf].modifiable = false
  vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf, silent = true })
  vim.keymap.set('n', 'K', function()
    open_manual(vim.fn.expand('<cword>'))
  end, { buffer = buf, desc = '查询此 C++ 名称' })

  vim.system({
    'cppman', '--force-columns=' .. math.max(40, vim.api.nvim_win_get_width(win)), '--', query,
  }, { text = true, timeout = 60000 }, vim.schedule_wrap(function(result)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local output = vim.trim(result.stdout or '')
    if result.code ~= 0 or output == '' then
      output = '查询失败：' .. query .. '\n'
        .. vim.trim(result.stderr or '') .. '\n请检查名称或网络，再用 :Cppman 重试。'
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, '\n', { plain = true }))
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
  end))
end

local function prompt()
  vim.ui.input({ prompt = 'C++ 文档（例如 std::thread）：' }, function(query)
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
end, { nargs = '*', desc = '查询 cppman 标准库文档' })

vim.keymap.set('n', '<leader>cm', function()
  open_manual(vim.fn.expand('<cword>'))
end, { desc = 'C++：查询光标下名称的文档' })
vim.keymap.set('n', '<leader>cs', prompt, { desc = 'C++：输入名称查询文档' })
