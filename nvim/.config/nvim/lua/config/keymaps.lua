-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jj", "<Esc>")
vim.keymap.set("i", "jk", "<Esc>")

vim.keymap.set("", "<C-f>", "20jzz")
vim.keymap.set("", "<C-b>", "20kzz")
vim.keymap.set("", "<C-d>", "12jzz")
vim.keymap.set("", "<C-u>", "12kzz")
