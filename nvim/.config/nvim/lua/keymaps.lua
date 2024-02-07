vim.g.mapleader = " "

local keymap = vim.keymap

-- vim.keymap.set("i", "jj", "<Esc>")
-- vim.keymap.set("i", "jk", "<Esc>")

-- consistent page jumps
vim.keymap.set("", "<C-f>", "20jzz")
vim.keymap.set("", "<C-b>", "20kzz")
vim.keymap.set("", "<C-d>", "12jzz")
vim.keymap.set("", "<C-u>", "12kzz")

-- easier window management
keymap.set("n", "<leader>wv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>wh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>we", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>wd", "<cmd>close<CR>", { desc = "Close current split" })

keymap.set("n", "<C-h>", "<C-w>h", { desc = "Jump to left pane" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Jump to right pane" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Jump to top pane" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Jump to bottom pane" })
