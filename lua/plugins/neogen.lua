-- Generates a Doxygen comment for the function or class under the cursor, in
-- the `///` style used by Kumo: @brief first, then @tparam, @param and @return
-- already filled in with the names, and the cursor on the first blank to fill.
return {
  "danymat/neogen",
  cmd = "Neogen",
  keys = {
    {
      "<leader>cg",
      function() require("neogen").generate() end,
      desc = "Generate Doxygen comment",
    },
  },
  opts = function()
    local item = require("neogen.types.template").item
    -- A blank `///` separates the summary from the details, but only when
    -- there is something to document (that is what the plain `nil` items do).
    local template = {
      annotation_convention = "doxygen_slashes",
      doxygen_slashes = {
        { nil,            "/// @file",        { no_results = true, type = { "file" } } },
        { nil,            "/// @brief $1",    { no_results = true, type = { "func", "file", "class" } } },
        { nil,            "",                 { no_results = true, type = { "file" } } },

        { nil,            "/// @brief $1",    { type = { "func", "class", "type" } } },
        { nil,            "///",              { type = { "func" } } },
        { item.Tparam,    "/// @tparam %s $1" },
        { item.Parameter, "/// @param %s $1" },
        { item.Return,    "/// @return $1" },
      },
    }
    return {
      -- Neovim's own snippets, so the jump keys of blink.cmp work in it.
      snippet_engine = "nvim",
      languages = { c = { template = template }, cpp = { template = template } },
    }
  end,
}
