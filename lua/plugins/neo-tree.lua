return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  lazy = false,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  keys = {
    { "<leader>e", "<Cmd>Neotree filesystem toggle left<CR>", desc = "Toggle file tree" },
    { "<leader>E", "<Cmd>Neotree filesystem reveal left<CR>", desc = "Reveal current file" },
  },
  opts = {
    window = {
      position = "left",
      width = 32,
      mappings = {
        ["<space>"] = "none",
        ["h"] = "close_node",
        ["l"] = "open",
      },
    },
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
    },
  },
}
