-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local keymap = vim.keymap

local opts = { noremap = true, silent = true }

keymap.set("n", "<C-a>", "ggVG", { desc = "Select all text in buffer" })

-- New tab
keymap.set("n", "te", ":tabedit")
keymap.set("n", "<tab>", ":tabnext<Return>", opts)
keymap.set("n", "<s-tab>", ":tabprev<Return>", opts)

-- Split window
keymap.set("n", "ss", ":split<Return>", opts)
keymap.set("n", "sv", ":vsplit<Return>", opts)

vim.keymap.set("n", "<C-S-M-A-\\>", function()
  vim.diagnostic.jump({ count = 1 })
end, { desc = "Go to next diagnostic" })
