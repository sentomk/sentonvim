local languages = {
  "c", "cpp", "rust", "lua", "php", "java", "python",
  "markdown", "markdown_inline", "doxygen",
}

-- Match the Visual selection using Tree-sitter's exclusive end coordinates.
local function selection_range()
  local regions = vim.fn.getregionpos(vim.fn.getpos("v"), vim.fn.getpos("."), {
    type = "v", exclusive = false,
  })
  if #regions == 0 then return end
  local first, last = regions[1][1], regions[#regions][2]
  return { first[2] - 1, first[3] - 1, last[2] - 1, last[3] }
end

local scope_history = {}

local function shrink_selection()
  local buf = vim.api.nvim_get_current_buf()
  local history = scope_history[buf] or {}
  local saved = history[#history]
  local range = selection_range()
  if saved and saved.tick == vim.b.changedtick and vim.deep_equal(range, saved.after) then
    for _ = 1, saved.steps do
      vim.treesitter.select("child")
      if vim.deep_equal(selection_range(), saved.before) then break end
    end
    table.remove(history)
  else
    vim.treesitter.select("child", vim.v.count1)
  end
end

local function select_scope()
  local parser = vim.treesitter.get_parser(0)
  local range = selection_range()
  if not parser or not range then return end
  parser:parse()
  local tree = parser:language_for_range(range)
  local query = vim.treesitter.query.get(tree:lang(), "locals")
  local node = tree:named_node_for_range(range)
  if not query or not node then
    vim.treesitter.select("parent", vim.v.count1)
    return
  end
  local scopes = {}
  tree:for_each_tree(function(tstree, language_tree)
    if language_tree == tree then
      for id, captured in query:iter_captures(tstree:root(), 0) do
        if query.captures[id] == "local.scope" then
          scopes[captured:id()] = true
        end
      end
    end
  end)
  local target = node:parent()
  while target and not scopes[target:id()] do target = target:parent() end
  if not target then return end
  local wanted = { target:range() }
  local before, steps = range, 0
  while not vim.deep_equal(range, wanted) do
    vim.treesitter.select("parent")
    steps = steps + 1
    local next_range = selection_range()
    if not next_range or vim.deep_equal(next_range, range) then break end
    range = next_range
  end
  if steps > 0 then
    local buf = vim.api.nvim_get_current_buf()
    scope_history[buf] = scope_history[buf] or {}
    table.insert(scope_history[buf], {
      before = before, after = range, steps = steps, tick = vim.b.changedtick,
    })
  end
end

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local treesitter = require("nvim-treesitter")
    treesitter.setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
    treesitter.install(languages)

    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("sentonvim_treesitter", { clear = true }),
      callback = function(event)
        if not vim.treesitter.get_parser(event.buf) then return end
        vim.treesitter.start(event.buf)
        local opts = { buffer = event.buf }
        vim.keymap.set({ "n", "x" }, "<CR>", function()
          vim.treesitter.select("parent", vim.v.count1)
        end, vim.tbl_extend("force", opts, { desc = "Expand syntax node selection" }))
        vim.keymap.set("x", "<BS>", shrink_selection, vim.tbl_extend("force", opts, { desc = "Shrink syntax node selection" }))
        vim.keymap.set("x", "<Tab>", select_scope,
          vim.tbl_extend("force", opts, { desc = "Expand selection to surrounding scope" }))
        -- Keep native C/C++ indentation, including while code is incomplete.
        if vim.bo[event.buf].filetype ~= "c" and vim.bo[event.buf].filetype ~= "cpp" then
          if vim.treesitter.query.get(vim.treesitter.language.get_lang(vim.bo[event.buf].filetype), "indents") then
            vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end
      end,
    })
    vim.opt.foldmethod = "expr"
    vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    vim.opt.foldlevel = 99
  end,
}
