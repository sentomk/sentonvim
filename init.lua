-- Treat even empty .mm files as Objective-C++, not nroff documents.
vim.filetype.add({ extension = { mm = "objcpp" } })

require("core.keymaps")
require("core.options")
require("core.spell_check")

require("core.lazy").setup()
require("lazy").setup("plugins")
