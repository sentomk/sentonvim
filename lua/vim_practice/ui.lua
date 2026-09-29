local M = {}
local ns = vim.api.nvim_create_namespace('vim_practice_ui')
local function set_option(win, name, value) vim.wo[win][name] = value end
function M.style(win, guide)
  for k, v in pairs({ number = not guide, relativenumber = false, wrap = guide,
    signcolumn = 'no', foldcolumn = '0', cursorline = not guide, spell = false,
    list = not guide, winfixwidth = guide, winfixheight = guide }) do set_option(win, k, v) end
  vim.wo[win].listchars = 'tab:» ,trail:·'
  vim.wo[win].colorcolumn = ''
  if guide then vim.wo[win].fillchars = 'eob: ' end
  vim.wo[win].winbar = guide and '  任务 / 目标' or '%#Title#  在这里操作 · 原生 Vim 按键%*'
  vim.wo[win].statusline = guide and ' F4 专题  F5 重来  F7 上题  F8 跳过  F9 自动' or ' %l:%c  %m%=%{mode()} '
end
function M.layout(s)
  local origin = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(s.guide_win or -1) then
    vim.api.nvim_set_current_win(s.work_win)
    vim.cmd('noautocmd rightbelow vsplit')
    s.guide_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(s.guide_win, s.guide_buf)
  end
  vim.api.nvim_set_current_win(s.guide_win)
  if vim.o.columns >= 108 then
    vim.cmd('noautocmd wincmd L')
    vim.api.nvim_win_set_width(s.guide_win, math.min(54, math.floor(vim.o.columns * .42)))
  else
    vim.cmd('noautocmd wincmd K')
    local n = vim.api.nvim_buf_line_count(s.guide_buf)
    vim.api.nvim_win_set_height(s.guide_win, math.min(math.max(n + 1, 8), math.max(6, vim.o.lines - 9)))
  end
  M.style(s.guide_win, true)
  if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
  if vim.api.nvim_win_is_valid(s.work_win) then
    vim.api.nvim_win_call(s.work_win, function()
      local view = vim.fn.winsaveview()
      if vim.fn.strdisplaywidth(vim.api.nvim_get_current_line()) < vim.api.nvim_win_get_width(s.work_win) - 8 then
        view.leftcol = 0
        vim.fn.winrestview(view)
      end
    end)
  end
end
local function wrap(text, width)
  local lines, line = {}, ''
  for _, char in ipairs(vim.fn.split(text, '\\zs')) do
    if vim.fn.strdisplaywidth(line .. char) > width then lines[#lines + 1], line = line, '' end
    line = line .. char
  end
  lines[#lines + 1] = line
  return lines
end
function M.render(s)
  if not s.lesson or not vim.api.nvim_buf_is_valid(s.guide_buf or -1) then return end
  local e = s.lesson
  local width = vim.api.nvim_win_is_valid(s.guide_win or -1) and vim.api.nvim_win_get_width(s.guide_win) - 2 or 48
  local lines, marks = {}, {}
  local function add(text, group)
    for _, line in ipairs(wrap(text, math.max(width, 20))) do
      lines[#lines + 1] = ' ' .. line
      if group then marks[#marks + 1] = { #lines - 1, group } end
    end
  end
  add(string.format('%d/%d  %s', s.index, #s.queue, e.title), 'Title')
  add('F4 专题  F5 重来  F7 上题  F8 下题  F9 自动:' .. (s.auto and '开' or '停'), 'Special')
  add('任务  ' .. (e.kind == 'history' and e.steps[s.stage] or e.task))
  add('操作  ' .. e.hint, 'Normal')
  if e.kind == 'history' then add(string.format('步骤 %d/%d', s.stage, #e.stages), 'Special') end
  local target = e.target or (e.stages and e.stages[s.stage])
  if e.kind == 'file' and e.goal == 'reload' and not s.reload_dirty then target = { 'status = wrong' } end
  if target then
    add('目标内容', 'Special')
    local current = vim.api.nvim_buf_is_valid(s.work_buf) and vim.api.nvim_buf_get_lines(s.work_buf, 0, -1, false) or {}
    for i, line in ipairs(target) do
      local visible = line:gsub('\t', '→   '):gsub(' +$', function(spaces) return string.rep('·', #spaces) end)
      add(string.format('%2d  %s', i, visible), current[i] ~= line and 'DiagnosticWarn' or 'String')
    end
  elseif e.kind == 'navigate' then
    add(string.format('目标位置  第 %d 行 · 第 %d 列', e.destination[1], e.destination[2] + 1), 'Special')
    add(e.lines[e.destination[1]], 'String')
    add('编辑区高亮标出终点，光标移到终点即完成。', 'Comment')
  else
    add('完成条件', 'Special')
    add(e.task, 'String')
  end
  if vim.api.nvim_win_is_valid(s.guide_win or -1) then
    local status = (s.status or '开始操作'):gsub('%%', '%%%%')
    vim.wo[s.guide_win].winbar = (s.passed and '%#DiagnosticOk#  ' or '%#DiagnosticInfo#  ') .. status .. '%*'
    vim.wo[s.guide_win].statusline = ' F4 专题  F5 重来  F7 上题  F8 跳过  F9 自动:' .. (s.auto and '开' or '停')
  end
  local old = vim.api.nvim_buf_get_lines(s.guide_buf, 0, -1, false)
  if not vim.deep_equal(old, lines) then
    vim.bo[s.guide_buf].modifiable = true
    vim.api.nvim_buf_set_lines(s.guide_buf, 0, -1, false, lines)
    vim.bo[s.guide_buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(s.guide_buf, ns, 0, -1)
    for _, m in ipairs(marks) do
      vim.api.nvim_buf_set_extmark(s.guide_buf, ns, m[1], 0, { line_hl_group = m[2] })
    end
  end
end
function M.target(s)
  local e = s.lesson
  if e.kind == 'navigate' then
    local row, col = unpack(e.destination)
    local suffix = e.lines[row]:sub(col + 1)
    local len = #vim.fn.strcharpart(suffix, 0, 1)
    vim.api.nvim_buf_set_extmark(s.work_buf, ns, row - 1, col, {
      end_col = col + len, hl_group = 'IncSearch', priority = 200,
    })
  end
end
return M
