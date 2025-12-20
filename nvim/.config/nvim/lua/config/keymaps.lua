-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local keymap = vim.keymap

local opts = { noremap = true, silent = true }

keymap.set("n", "<C-a>", "ggVG", { desc = "Select all text in buffer" })

-- New tab
keymap.set("n", "te", ":tabedit")
-- keymap.set("n", "<tab>", ":tabnext<Return>", opts)
-- keymap.set("n", "<s-tab>", ":tabprev<Return>", opts)

-- Split window
keymap.set("n", "ss", ":split<Return>", opts)
keymap.set("n", "sv", ":vsplit<Return>", opts)

vim.keymap.set("n", "<C-S-M-A-\\>", function()
  vim.diagnostic.jump({ count = 1 })
end, { desc = "Go to next diagnostic" })

-- Search files in ~/frame/frontend only
vim.keymap.set("n", "<leader>sf", function()
  Snacks.picker.files({ dirs = { vim.fn.expand("~/frame/frontend") } })
end, { desc = "Search Frontend files (frame)" })

-- Grep in ~/frame/frontend only
vim.keymap.set("n", "<leader>sF", function()
  Snacks.picker.grep({ dirs = { vim.fn.expand("~/frame/frontend") } })
end, { desc = "Grep Frontend files (frame)" })

vim.keymap.set("n", "<C-/>", function()
  Snacks.terminal()
end, { desc = "Toggle Terminal" })
vim.keymap.set("t", "<C-/>", "<cmd>close<cr>", { desc = "Close Terminal" })

vim.keymap.set("n", "<leader>bF", function()
  vim.cmd("!biome check --write " .. vim.fn.expand("%"))
  vim.cmd("edit") -- reload the buffer
end, { desc = "Biome Fix All" })
