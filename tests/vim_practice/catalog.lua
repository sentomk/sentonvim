local p = require('vim_practice')
local data = require('vim_practice.lessons')
p.setup({ progress_path = vim.fn.tempname(), delay = 500 })
local original_tab = vim.api.nvim_get_current_tabpage()
local seen, count = {}, 0
assert(#data.exercises == 122 and #data.categories == 19)
p.start('all')
p.toggle_auto()
for index, e in ipairs(data.exercises) do
  assert(not seen[e.id], 'duplicate lesson id')
  seen[e.id] = true
  assert(e.task ~= '' and e.hint ~= '' and #e.lines > 0)
  local s = p.state()
  assert(s.lesson.id == e.id and s.index == index)
  assert(vim.api.nvim_win_get_buf(s.guide_win) == s.guide_buf)
  assert(not vim.bo[s.guide_buf].modifiable)
  assert(not s.passed, e.id .. ' starts complete')
  if e.kind == 'edit' then
    assert(not vim.deep_equal(e.lines, e.target))
    vim.api.nvim_buf_set_lines(s.work_buf, 0, -1, false, e.target)
    p.check()
    assert(s.passed, e.id .. ' cannot complete')
    count = count + 1
  elseif e.kind == 'navigate' then
    assert(e.destination[1] <= #e.lines)
    assert(e.destination[2] < #e.lines[e.destination[1]])
    assert(not vim.deep_equal(e.start, e.destination))
    vim.api.nvim_win_set_cursor(s.work_win, e.destination)
    p.check()
    assert(s.passed, e.id .. ' cannot complete')
    count = count + 1
  end
  if index < #data.exercises then p.next() end
end
p.next()
assert(p.state().lesson == nil, 'last lesson must return to menu')
p.stop()
assert(vim.api.nvim_get_current_tabpage() == original_tab)
for _, b in ipairs(vim.api.nvim_list_bufs()) do
  assert(not vim.api.nvim_buf_get_name(b):match('^vimpractice://'), 'scratch buffer leaked')
end
assert(vim.fn.exists('#VimPracticeWorkbench') == 0)
print(string.format('PASS: 122 lesson schemas, %d content/cursor targets, full queue cleanup', count))
