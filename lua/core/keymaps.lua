vim.g.mapleader = " "
vim.g.maplocalleader = " "

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

map("n", "<C-s>", "<Cmd>write<CR>", "Save file")
map("i", "<C-s>", "<Esc><Cmd>write<CR>", "Save file")
map("n", "<leader>w", "<Cmd>write<CR>", "Save file")
map("i", "jk", "<Esc>", "Exit Insert mode")
map("n", "<leader>/", "<Cmd>nohlsearch<CR>", "Clear search highlight")
map("n", "<leader>cd", vim.diagnostic.open_float, "Show diagnostic details")
map("n", "<leader>e", "<Cmd>Explore<CR>", "Browse files")
