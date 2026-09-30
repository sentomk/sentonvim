return {
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      vim.cmd.colorscheme("tokyonight-moon")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = { theme = "tokyonight" },
      sections = {
        lualine_x = {
          "encoding",
          { "fileformat", symbols = { unix = "LF", dos = "CRLF", mac = "CR" } },
          "filetype",
        },
      },
    },
  },
}
