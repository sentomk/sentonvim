return {
  "Saghen/blink.cmp",
  version = "1.*",
  dependencies = { "rafamadriz/friendly-snippets" },
  opts = {
    keymap = {
      preset = "default",
      -- First item is pre-highlighted, so <CR> or <Tab> confirms in one key.
      -- Menu open: Tab confirms. Menu closed: Tab jumps to the next snippet
      -- placeholder. <C-l> / <S-Tab> jump forward / back even while the menu
      -- is open. Move in the menu with <C-j>/<C-k> (or <C-n>/<C-p>/<Up>/<Down>).
      ["<C-j>"] = { "select_next", "fallback" },
      ["<C-k>"] = { "select_prev", "fallback" },
      ["<Tab>"] = { "accept", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "snippet_backward", "fallback" },
      ["<C-l>"] = { "snippet_forward", "fallback" },
      ["<CR>"] = { "accept", "fallback" },
    },
    completion = {
      -- Highlight the first candidate without touching the buffer until confirmed.
      list = { selection = { preselect = true, auto_insert = false } },
      documentation = { auto_show = true },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "doxygen" },
      providers = {
        -- Doxygen commands after "@" or a backslash, inside C/C++ comments.
        doxygen = { name = "Doxygen", module = "core.doxygen", score_offset = 100 },
      },
    },
    signature = { enabled = true },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
}
