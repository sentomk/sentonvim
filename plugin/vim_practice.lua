if vim.g.loaded_vim_practice_workbench then return end
vim.g.loaded_vim_practice_workbench = true
pcall(vim.api.nvim_del_user_command, 'VimPractice2')
local p = require('vim_practice')
local definitions = {
  VimPractice = { function(a) p.start(a.args) end, { nargs = '?', complete = function()
    local result = { 'all', 'random' }
    for _, c in ipairs(require('vim_practice.lessons').categories) do result[#result + 1] = c.id end
    return result
  end } },
  VimPracticeList = { p.menu }, VimPracticeMenu = { p.menu }, VimPracticeHint = { p.guide },
  VimPracticeTarget = { p.guide }, VimPracticeCheck = { function() p.check(true) end },
  VimPracticePrev = { p.previous },
  VimPracticeNext = { function() p.next(false) end }, VimPracticeReset = { p.reset },
  VimPracticeStop = { p.stop }, VimPracticeAuto = { p.toggle_auto },
}
for name, definition in pairs(definitions) do
  vim.api.nvim_create_user_command(name, definition[1], definition[2] or {})
end
