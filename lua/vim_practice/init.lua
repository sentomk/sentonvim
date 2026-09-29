local M = {}
local lessons = require('vim_practice.lessons')
local ui = require('vim_practice.ui')
local progress = require('vim_practice.progress')
local api = vim.api
local session
local options = { delay = 900, progress_path = vim.fn.stdpath('state') .. '/vim-practice/progress.json' }
local key_ns = api.nvim_create_namespace('vim_practice_keys')
local schedule_check
local function valid_buf(b) return b and api.nvim_buf_is_valid(b) end
local function valid_win(w) return w and api.nvim_win_is_valid(w) end
local function valid_tab(t) return t and api.nvim_tabpage_is_valid(t) end
local function equal(a, b) return vim.deep_equal(a, b) end
local function lines(b) return valid_buf(b) and api.nvim_buf_get_lines(b, 0, -1, false) or {} end
local function mode_normal() return api.nvim_get_mode().mode == 'n' end
local function current_lesson() return session and session.lesson end
local function persist(s)
  local ok = progress.save(options.progress_path, s.progress)
  if not ok and not s.save_warned then
    s.save_warned = true
    vim.notify('练习进度无法保存；本次练习可继续。', vim.log.levels.WARN)
  end
end
local function keymaps(buf, guide)
  local function map(key, fn, desc) vim.keymap.set('n', key, fn, { buffer = buf, silent = true, desc = desc }) end
  map('<F4>', M.menu, '返回练习专题')
  map('<F5>', M.reset, '重新练习本题')
  map('<F7>', M.previous, '返回上一题')
  map('<F8>', M.next, '跳过本题')
  map('<F9>', M.toggle_auto, '暂停/恢复自动下一题')
  if guide then
    map('<Tab>', M.focus, '返回编辑区')
    map('q', M.focus, '返回编辑区')
  end
end
local function own_buffer(s, buf)
  s.buffers[buf] = api.nvim_buf_get_name(buf)
  return buf
end
local function scratch(s, content, label)
  local buf = api.nvim_create_buf(false, true)
  if label ~= false then api.nvim_buf_set_name(buf, 'vimpractice://' .. s.id .. '/' .. label .. '/' .. buf) end
  local undo_levels = vim.bo[buf].undolevels
  vim.bo[buf].undolevels = -1
  api.nvim_buf_set_lines(buf, 0, -1, false, content or {})
  vim.bo[buf].undolevels = undo_levels
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.bo[buf].filetype = 'vimpractice'
  vim.b[buf].completion = false
  if package.loaded.cmp then
    api.nvim_buf_call(buf, function() require('cmp').setup.buffer({ enabled = false }) end)
  end
  vim.bo[buf].shiftwidth, vim.bo[buf].tabstop, vim.bo[buf].softtabstop = 4, 4, 4
  vim.bo[buf].expandtab = true
  vim.bo[buf].autoindent, vim.bo[buf].smartindent, vim.bo[buf].cindent = false, false, false
  vim.bo[buf].indentexpr = ''
  vim.bo[buf].formatoptions = ''
  vim.bo[buf].modified = false
  own_buffer(s, buf)
  keymaps(buf)
  return buf
end
local function owned(s, b)
  local name = s.buffers[b]
  if name == nil or not valid_buf(b) then return false end
  local actual = api.nvim_buf_get_name(b)
  if actual == name then return true end
  return s.file_paths[actual] == true
end
local function isolate_window(s, win)
  if vim.fn.exists('+eventignorewin') == 0 or not valid_win(win) then return end
  if owned(s, api.nvim_win_get_buf(win)) then
    if s.window_options[win] == nil then s.window_options[win] = s.original_ignore end
    local ignore = vim.split(s.window_options[win], ',', { trimempty = true })
    -- nvim-cmp injects keys on InsertEnter even when completion is disabled.
    -- Keep those hooks out of the disposable exercise windows, including macros.
    if not vim.tbl_contains(ignore, 'InsertEnter') then ignore[#ignore + 1] = 'InsertEnter' end
    vim.wo[win].eventignorewin = table.concat(ignore, ',')
  elseif s.window_options[win] ~= nil then
    vim.wo[win].eventignorewin = s.window_options[win]
    s.window_options[win] = nil
  end
end
local function work_windows(s)
  if not valid_tab(s.tab) then return {} end
  local result = {}
  for _, w in ipairs(api.nvim_tabpage_list_wins(s.tab)) do
    if w ~= s.guide_win and owned(s, api.nvim_win_get_buf(w)) then result[#result + 1] = w end
  end
  return result
end
local function cleanup(s, ending)
  s.busy = true
  s.generation = s.generation + 1
  -- :saveas can create an alternate buffer for the original temporary file.
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if s.file_paths[api.nvim_buf_get_name(buf)] then own_buffer(s, buf) end
  end
  local keep = {}
  if not ending then
    if valid_tab(s.tab) then api.nvim_set_current_tabpage(s.tab) end
    for _, win in ipairs(work_windows(s)) do
      if not s.work_win or not valid_win(s.work_win) then s.work_win = win end
      if win ~= s.work_win then pcall(api.nvim_win_close, win, true) end
    end
    if valid_win(s.work_win) and owned(s, api.nvim_win_get_buf(s.work_win)) then
      local placeholder = scratch(s, {}, 'loading')
      api.nvim_win_set_buf(s.work_win, placeholder)
      keep[placeholder] = true
    end
    if s.guide_buf then keep[s.guide_buf] = true end
  end
  for tab in pairs(s.tabs) do
    if valid_tab(tab) and (ending or tab ~= s.tab) then
      local safe = true
      for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
        if not owned(s, api.nvim_win_get_buf(win)) then safe = false end
      end
      if safe and #api.nvim_list_tabpages() > 1 then
        api.nvim_set_current_tabpage(tab)
        vim.cmd('noautocmd tabclose!')
      end
    end
  end
  for buf in pairs(s.buffers) do
    if not keep[buf] and owned(s, buf) then pcall(api.nvim_buf_delete, buf, { force = true }) end
    if not valid_buf(buf) then s.buffers[buf] = nil end
  end
  for path in pairs(s.file_paths) do pcall(vim.fn.delete, path) end
  s.file_paths = {}
  if s.temp_dir then pcall(vim.fn.delete, s.temp_dir, 'd') end
  s.temp_dir = nil
  s.busy = false
end
local function first_change(e)
  if e.start then return e.start end
  local target = e.target or (e.stages and e.stages[1])
  if target then
    for row, before in ipairs(e.lines) do
      local after = target[row] or ''
      if before ~= after then
        local col = 0
        while col < #before and before:byte(col + 1) == after:byte(col + 1) do col = col + 1 end
        col = math.min(col, math.max(0, #before - 1))
        while col > 0 and before:byte(col + 1) >= 128 and before:byte(col + 1) < 192 do col = col - 1 end
        return { row, col }
      end
    end
  end
  return { 1, 0 }
end
local function ensure_surface(s)
  if not valid_tab(s.tab) then return false end
  api.nvim_set_current_tabpage(s.tab)
  if not valid_win(s.work_win) or (s.work_buf and not owned(s, api.nvim_win_get_buf(s.work_win))) then
    local wins = work_windows(s)
    s.work_win = wins[1]
    if not s.work_win then
      vim.cmd('noautocmd botright new')
      s.work_win = api.nvim_get_current_win()
      own_buffer(s, api.nvim_get_current_buf())
    end
  end
  api.nvim_set_current_win(s.work_win)
  return true
end
local function render(s) if session == s then ui.render(s) end end
local function load_lesson(s)
  if not ensure_surface(s) then M.stop(); return end
  cleanup(s, false)
  ensure_surface(s)
  s.busy = true
  s.lesson = s.queue[s.index]
  s.stage, s.passed, s.pending, s.reload_dirty = 1, false, false, false
  s.read_after_dirty, s.written, s.new_tab = false, nil, nil
  s.status = '开始操作，完成后自动检查。'
  local e = s.lesson
  local label = e.id
  if e.kind == 'file' then label = false end
  s.work_buf = scratch(s, e.lines, label)
  api.nvim_win_set_buf(s.work_win, s.work_buf)
  vim.bo[s.work_buf].syntax = e.filetype
  ui.style(s.work_win, false)
  vim.wo[s.work_win].foldmethod = 'manual'
  vim.wo[s.work_win].foldenable = true
  vim.wo[s.work_win].foldlevel = 0
  if e.kind == 'file' then
    s.temp_dir = vim.fn.tempname()
    vim.fn.mkdir(s.temp_dir, 'p')
    s.path = s.temp_dir .. '/practice.txt'
    s.copy_path = s.temp_dir .. '/practice-copy.txt'
    vim.fn.writefile(e.lines, s.path)
    vim.bo[s.work_buf].buftype = ''
    api.nvim_buf_set_name(s.work_buf, s.path)
    s.path = api.nvim_buf_get_name(s.work_buf)
    s.copy_path = vim.fn.fnamemodify(s.path, ':r') .. '-copy.txt'
    s.buffers[s.work_buf] = s.path
    s.file_paths[s.path], s.file_paths[s.copy_path] = true, true
    vim.cmd('noautocmd edit!')
  elseif e.kind == 'fold' then
    if e.setup ~= 'none' then vim.cmd('2,4fold') end
    if e.setup:match('both') then vim.cmd('5,6fold') end
    if e.setup:match('open') then vim.cmd('normal! zR') end
  elseif e.kind == 'workspace' then
    if e.goal == 'switch_window' then
      vim.cmd('noautocmd rightbelow vsplit')
      s.work_win = api.nvim_get_current_win()
      ui.style(s.work_win, false)
      s.start_win = s.work_win
    elseif e.goal == 'alternate_buffer' then
      s.partner = scratch(s, { '上一个缓冲区：切回这里即可完成。' }, 'alternate')
      api.nvim_win_set_buf(s.work_win, s.partner)
      api.nvim_win_set_buf(s.work_win, s.work_buf)
    end
  end
  local pos = e.kind == 'fold' and { 2, 0 } or first_change(e)
  api.nvim_win_set_cursor(s.work_win, pos)
  vim.cmd('normal! zt')
  s.base_seq = vim.fn.undotree().seq_cur
  s.initial_bufs = {}
  for _, b in ipairs(api.nvim_list_bufs()) do s.initial_bufs[b] = true end
  ui.target(s)
  if not valid_buf(s.guide_buf) then s.guide_buf = scratch(s, {}, 'guide') end
  keymaps(s.guide_buf, true)
  ui.render(s)
  ui.layout(s)
  ui.render(s)
  ui.layout(s)
  ui.render(s)
  if e.kind == 'workspace' and e.goal == 'switch_window' then
    s.work_win = work_windows(s)[1]
    s.start_win = s.work_win
  end
  for _, win in ipairs(api.nvim_tabpage_list_wins(s.tab)) do isolate_window(s, win) end
  api.nvim_set_current_win(s.work_win)
  s.progress.last = e.id
  persist(s)
  s.busy = false
end
local function file_lines(path)
  local ok, content = pcall(vim.fn.readfile, path)
  return ok and content or nil
end
local function verify(s)
  local e = s.lesson
  local content = lines(s.work_buf)
  if e.kind == 'edit' then
    if equal(content, e.target) then return true end
    for i = 1, math.max(#content, #e.target) do
      if content[i] ~= e.target[i] then return false, '还差一点：第 ' .. i .. ' 行与目标不同。' end
    end
  elseif e.kind == 'navigate' then
    for _, win in ipairs(work_windows(s)) do
      if api.nvim_get_current_win() == win and api.nvim_win_get_buf(win) == s.work_buf then
        return equal(content, e.lines) and equal(api.nvim_win_get_cursor(win), e.destination)
      end
    end
  elseif e.kind == 'history' then
    local seq = api.nvim_buf_call(s.work_buf, function() return vim.fn.undotree().seq_cur end)
    if equal(content, e.stages[s.stage]) and mode_normal() then
      local direction = s.stage == 1 and seq > s.base_seq
        or s.stage == 2 and seq < s.previous_seq
        or s.stage == 3 and seq == s.edited_seq
      if not direction then return false, '内容已匹配；这一步需要实际执行撤销或重做。' end
      if s.stage == #e.stages then return true end
      s.previous_seq = seq
      if s.stage == 1 then s.edited_seq = seq end
      s.stage = s.stage + 1
      s.status = '上一步完成，继续步骤 ' .. s.stage .. '。'
    end
  elseif e.kind == 'fold' and valid_win(s.work_win) then
    return api.nvim_win_call(s.work_win, function()
      if not equal(content, e.lines) then return false end
      local open = e.goal:match('open') ~= nil
      local function matches(a, b)
        if open then return vim.fn.foldlevel(a) > 0 and vim.fn.foldclosed(a) == -1 end
        return vim.fn.foldclosed(a) == a and vim.fn.foldclosedend(a) == b
      end
      return matches(2, 4) and (not e.goal:match('both') or matches(5, 6))
    end)
  elseif e.kind == 'file' then
    if e.goal == 'reload' then
      if equal(content, { 'status = wrong' }) then
        s.reload_dirty = true
        s.status = '修改完成。现在输入 :e!，从磁盘恢复。'
      end
      return s.reload_dirty and s.read_after_dirty and equal(content, e.target)
    end
    local expected = e.goal == 'save' and s.path or s.copy_path
    return s.written == expected and equal(content, e.target) and equal(file_lines(expected), e.target)
  elseif e.kind == 'workspace' then
    local wins = work_windows(s)
    local current = api.nvim_get_current_win()
    if e.goal == 'split_h' or e.goal == 'split_v' then
      local positions = {}
      for _, w in ipairs(wins) do
        if api.nvim_win_get_buf(w) == s.work_buf then positions[#positions + 1] = api.nvim_win_get_position(w) end
      end
      for i = 1, #positions do for j = i + 1, #positions do
        local a, b = positions[i], positions[j]
        if e.goal == 'split_h' and a[1] ~= b[1] and a[2] == b[2] then return true end
        if e.goal == 'split_v' and a[2] ~= b[2] and a[1] == b[1] then return true end
      end end
    elseif e.goal == 'switch_window' then
      return current ~= s.start_win and current ~= s.guide_win and vim.tbl_contains(wins, current)
    elseif e.goal == 'alternate_buffer' then
      return current == s.work_win and api.nvim_get_current_buf() == s.partner
    elseif e.goal == 'new_buffer' then
      local b = api.nvim_get_current_buf()
      if current == s.work_win and not s.initial_bufs[b] and api.nvim_buf_get_name(b) == '' and equal(lines(b), { '' }) then
        own_buffer(s, b)
        keymaps(b)
        return true
      end
    elseif e.goal == 'new_tab' then return s.new_tab and valid_tab(s.new_tab) end
  end
  return false
end
local function in_session(s)
  return valid_tab(s.tab) and (api.nvim_get_current_tabpage() == s.tab or api.nvim_get_current_tabpage() == s.new_tab)
end
local function can_advance(s)
  return mode_normal() and in_session(s) and api.nvim_get_current_win() ~= s.guide_win
    and owned(s, api.nvim_get_current_buf())
end
local function advance_later(s)
  if s.pending or not s.auto then return end
  s.pending = true
  local generation = s.generation
  vim.defer_fn(function()
    if session ~= s or s.generation ~= generation then return end
    s.pending = false
    if s.auto and s.passed and can_advance(s) then
      M.check(false)
      if s.passed then M.next(true) end
    end
  end, options.delay)
end
function M.check(explicit)
  local s = session
  if not s or not s.lesson or s.busy or not valid_buf(s.work_buf) then return end
  if not in_session(s) then return end
  if s.passed then
    if s.lesson.kind ~= 'navigate' and s.lesson.kind ~= 'history' and not verify(s) then
      s.passed = false
      s.status = '内容又有改动，请完成当前目标。'
      render(s)
    else advance_later(s); return end
  end
  local ok, hint = verify(s)
  if ok then
    if not mode_normal() then s.status = '已达到目标。按 Esc 回到普通模式继续。'
    else
      s.passed = true
      s.progress.done[s.lesson.id] = true
      s.status = s.auto and '✓ 完成！即将进入下一题。' or '✓ 完成！F9 继续，F8 下一题。'
      persist(s)
      advance_later(s)
    end
  elseif explicit then s.status = hint or '尚未完成，请按照任务和目标继续。' end
  render(s)
end
schedule_check = function()
  local s = session
  if not s or s.busy or s.check_queued then return end
  s.check_queued = true
  vim.schedule(function()
    s.check_queued = false
    if session == s then M.check(false) end
  end)
end
local function attach(s)
  s.group = api.nvim_create_augroup('VimPracticeWorkbench', { clear = true })
  api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'CursorMoved', 'InsertLeave', 'BufEnter', 'WinEnter', 'TabEnter', 'ModeChanged' }, {
    group = s.group, callback = schedule_check,
  })
  api.nvim_create_autocmd('BufWinEnter', { group = s.group, callback = function()
    if not s.busy then isolate_window(s, api.nvim_get_current_win()) end
  end })
  api.nvim_create_autocmd('BufWritePost', { group = s.group, callback = function(a)
    if s.lesson and not s.busy and a.buf == s.work_buf then s.written = api.nvim_buf_get_name(a.buf); schedule_check() end
  end })
  api.nvim_create_autocmd('BufReadPost', { group = s.group, callback = function(a)
    if not s.busy and a.buf == s.work_buf and s.reload_dirty then s.read_after_dirty = true; schedule_check() end
  end })
  api.nvim_create_autocmd('TabLeave', { group = s.group, callback = function() s.last_tab = api.nvim_get_current_tabpage() end })
  api.nvim_create_autocmd('TabNewEntered', { group = s.group, callback = function()
    if s.busy or not s.lesson or s.lesson.goal ~= 'new_tab' or s.last_tab ~= s.tab then return end
    local b, t = api.nvim_get_current_buf(), api.nvim_get_current_tabpage()
    if api.nvim_buf_get_name(b) == '' and equal(lines(b), { '' }) then
      own_buffer(s, b)
      s.tabs[t], s.new_tab = true, t
      keymaps(b)
      schedule_check()
    end
  end })
  api.nvim_create_autocmd('VimResized', { group = s.group, callback = function()
    if s.lesson and not s.busy and api.nvim_get_current_tabpage() == s.tab then
      s.busy = true; ui.layout(s); render(s); ui.layout(s); render(s); s.busy = false
    end
  end })
  api.nvim_create_autocmd('TabClosed', { group = s.group, callback = function()
    vim.schedule(function() if session == s and not s.busy and not valid_tab(s.tab) then M.stop() end end)
  end })
  vim.on_key(schedule_check, key_ns)
end
local function new_session()
  local s = { id = tostring(vim.uv.hrtime()), buffers = {}, tabs = {}, file_paths = {}, generation = 0,
    window_options = {}, original_ignore = vim.fn.exists('+eventignorewin') == 1 and vim.wo.eventignorewin or '',
    auto = true, progress = progress.load(options.progress_path), original_win = api.nvim_get_current_win(),
    original_tab = api.nvim_get_current_tabpage(), registers = {}, busy = true }
  for _, r in ipairs(vim.fn.split('"0123456789abcdefghijklmnopqrstuvwxyz-/', '\\zs')) do s.registers[r] = vim.fn.getreginfo(r) end
  vim.cmd('noautocmd tabnew')
  s.tab, s.work_win = api.nvim_get_current_tabpage(), api.nvim_get_current_win()
  s.tabs[s.tab] = true
  own_buffer(s, api.nvim_get_current_buf())
  session = s
  attach(s)
  s.busy = false
  return s
end
local function start_queue(category, resume)
  local s = session or new_session()
  local queue = {}
  for _, e in ipairs(lessons.exercises) do
    if category == 'all' or category == 'random' or e.category == category then queue[#queue + 1] = e end
  end
  if #queue == 0 then vim.notify('未知专题：' .. category, vim.log.levels.WARN); return end
  if category == 'random' then
    for i = #queue, 2, -1 do local j = math.random(i); queue[i], queue[j] = queue[j], queue[i] end
  end
  s.skipped = 0
  s.queue, s.index, s.category_name = queue, 1, '全部练习'
  for _, c in ipairs(lessons.categories) do if c.id == category then s.category_name = c.name end end
  if category == 'random' then s.category_name = '随机练习' end
  if resume then
    for i, e in ipairs(queue) do if e.id == s.progress.last then s.index = i; break end end
    if s.progress.done[queue[s.index].id] then
      for offset = 1, #queue do
        local i = (s.index + offset - 1) % #queue + 1
        if not s.progress.done[queue[i].id] then s.index = i; break end
      end
    end
  end
  load_lesson(s)
end
function M.start(category)
  if not category or category == '' then return M.menu() end
  if category ~= 'all' and category ~= 'random' and not vim.tbl_contains(vim.tbl_map(function(c) return c.id end, lessons.categories), category) then
    vim.notify('未知专题：' .. category, vim.log.levels.WARN); return
  end
  start_queue(category)
end
function M.menu(message)
  if not mode_normal() then return end
  local s = session or new_session()
  if not ensure_surface(s) then M.stop(); return end
  cleanup(s, false)
  s.busy, s.lesson = true, nil
  if valid_win(s.guide_win) then pcall(api.nvim_win_close, s.guide_win, true) end
  s.guide_win = nil
  ensure_surface(s)
  local content = {
    '  VIM PRACTICE  /  编辑练习台', '',
    '  选择专题，Enter 开始。j / k 移动；c 继续上次；q 退出。',
    '  任务和目标常驻；练习区保留 Vim 原生按键；完成后自动下一题。',
    '  F4 专题  ·  F5 重来  ·  F7 上题  ·  F8 跳过  ·  F9 暂停自动继续', '',
    '  ' .. (type(message) == 'string' and message or '选择一个专题开始。可随时切换，已完成的题目也能重练。'), '',
  }
  local entries = {}
  for _, c in ipairs(lessons.categories) do
    local done, total = 0, 0
    for _, e in ipairs(lessons.exercises) do if e.category == c.id then
      total = total + 1; if s.progress.done[e.id] then done = done + 1 end
    end end
    content[#content + 1] = string.format('  %d/%d  %s  — %s', done, total, c.name, c.description)
    entries[#content] = c.id
  end
  content[#content + 1] = ''
  content[#content + 1] = '  全部练习 · 按专题顺序'; entries[#content] = 'all'
  content[#content + 1] = '  随机练习 · 混合全部专题'; entries[#content] = 'random'
  s.work_buf = scratch(s, content, 'menu')
  api.nvim_win_set_buf(s.work_win, s.work_buf)
  ui.style(s.work_win, true)
  vim.wo[s.work_win].cursorline = true
  vim.wo[s.work_win].winbar = '  选择专题'
  vim.wo[s.work_win].statusline = ' j/k 选择   Enter 开始   c 继续上次   q 退出 %=%l/%L '
  vim.bo[s.work_buf].modifiable = false
  local function map(key, callback) vim.keymap.set('n', key, callback, { buffer = s.work_buf, silent = true }) end
  map('<CR>', function() local category = entries[api.nvim_win_get_cursor(0)[1]]; if category then start_queue(category) end end)
  map('c', function()
    for _, e in ipairs(lessons.exercises) do if e.id == s.progress.last then start_queue(e.category, true); return end end
    start_queue('edit')
  end)
  map('q', M.stop)
  map('<Esc>', M.stop)
  api.nvim_win_set_cursor(s.work_win, { 9, 0 })
  vim.cmd('normal! gg')
  api.nvim_win_set_cursor(s.work_win, { 9, 0 })
  s.busy = false
end
function M.next(automatic)
  local s = session
  if not s or not s.lesson or not mode_normal() then return end
  if not automatic and not s.passed then s.skipped = (s.skipped or 0) + 1 end
  if s.index == #s.queue then
    local completed = 0
    for _, e in ipairs(s.queue) do if s.progress.done[e.id] then completed = completed + 1 end end
    return M.menu(string.format('%s已结束 · 已完成 %d/%d 题。选择专题继续。', s.category_name, completed, #s.queue))
  end
  s.index = s.index + 1
  load_lesson(s)
end
function M.previous()
  local s = session
  if not s or not s.lesson or not mode_normal() then return end
  if s.index == 1 then
    s.status = '已经是本组第一题。'
    render(s)
    return
  end
  s.index = s.index - 1
  load_lesson(s)
end
function M.reset() if current_lesson() and mode_normal() then load_lesson(session) end end
function M.toggle_auto()
  if not session then return end
  session.auto = not session.auto
  if session.lesson then
    session.status = session.passed and (session.auto and '✓ 完成！即将进入下一题。' or '✓ 完成！F9 继续，F8 下一题。') or '继续操作；F9 可切换自动继续。'
    render(session); M.check(false)
  end
end
function M.focus()
  if session and valid_win(session.work_win) then api.nvim_set_current_win(session.work_win) end
end
function M.guide()
  if session and valid_win(session.guide_win) then api.nvim_set_current_win(session.guide_win); vim.cmd('normal! gg') end
end
function M.stop()
  local s = session
  if not s then return end
  session = nil
  vim.on_key(nil, key_ns)
  if s.group then pcall(api.nvim_del_augroup_by_id, s.group) end
  for win, value in pairs(s.window_options) do
    if valid_win(win) then vim.wo[win].eventignorewin = value end
  end
  cleanup(s, true)
  if valid_tab(s.original_tab) then api.nvim_set_current_tabpage(s.original_tab) end
  if valid_win(s.original_win) then api.nvim_set_current_win(s.original_win) end
  for r, info in pairs(s.registers) do if r ~= '"' then pcall(vim.fn.setreg, r, info) end end
  pcall(vim.fn.setreg, '"', s.registers['"'])
end
function M.setup(opts) options = vim.tbl_extend('force', options, opts or {}) end
function M.state() return session end
return M
