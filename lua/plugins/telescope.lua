return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("telescope").setup({})
    local builtin = require("telescope.builtin")
    local mappings = {
      ff = { builtin.find_files, "Find files" },
      fg = { builtin.live_grep, "Search project text" },
      fb = { builtin.buffers, "Find buffers" },
      fh = { builtin.help_tags, "Find help" },
      fr = { builtin.oldfiles, "Find recent files" },
      fs = { builtin.grep_string, "Find current word" },
      fc = { builtin.commands, "Find commands" },
      fk = { builtin.keymaps, "Find keymaps" },
    }
    for key, action in pairs(mappings) do
      vim.keymap.set("n", "<leader>" .. key, action[1], { desc = action[2] })
    end
  end,
}
