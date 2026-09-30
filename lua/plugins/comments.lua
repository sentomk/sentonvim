return {
  "numToStr/Comment.nvim",
  opts = {},
  config = function(_, opts)
    require("Comment").setup(opts)
    local api = require("Comment.api")
    -- Keep the familiar line toggles; use gc/gb for motions and selections.
    vim.keymap.set("n", "<leader>cc", api.toggle.linewise.current, { desc = "Toggle line comment" })
    vim.keymap.set("n", "<leader>bc", api.toggle.blockwise.current, { desc = "Toggle block comment" })
  end,
}
