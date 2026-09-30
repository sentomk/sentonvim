return {
  { "williamboman/mason.nvim", opts = {} },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "Saghen/blink.cmp", "williamboman/mason.nvim" },
    config = function()
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })
      vim.lsp.config("clangd", {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=never",
          "--completion-style=detailed",
        },
        init_options = { usePlaceholders = true },
      })
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = {
              library = { vim.env.VIMRUNTIME },
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("sentonvim_lsp", { clear = true }),
        callback = function(event)
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, desc = desc })
          end
          local telescope = require("telescope.builtin")
          map("n", "gd", telescope.lsp_definitions, "Go to definition")
          map("n", "gr", telescope.lsp_references, "Find references")
          map("n", "gi", telescope.lsp_implementations, "Go to implementation")
          map("n", "K", vim.lsp.buf.hover, "Show documentation")
          map("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map({ "n", "x" }, "<leader>cf", function()
            vim.lsp.buf.format({ async = false, timeout_ms = 3000 })
          end, "Format code")
          map("n", "<leader>fd", telescope.lsp_document_symbols, "Find document symbols")
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.name == "clangd" then
            map("n", "<leader>ch", "<Cmd>LspClangdSwitchSourceHeader<CR>", "Switch source/header")
          end
        end,
      })
      vim.diagnostic.config({ severity_sort = true, float = { border = "rounded" } })
      vim.lsp.enable({ "clangd", "rust_analyzer", "lua_ls" })
    end,
  },
  {
    "folke/trouble.nvim",
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Toggle diagnostics list" },
    },
  },
}
