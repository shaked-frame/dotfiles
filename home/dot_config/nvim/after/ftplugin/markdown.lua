-- ┌─────────────────────────┐
-- │ Filetype config example │
-- └─────────────────────────┘
--
-- This is an example of a configuration that will apply only to a particular
-- filetype, which is the same as file's basename ('markdown' in this example;
-- which is for '*.md' files).
--
-- It can contain any code which will be usually executed when the file is opened
-- (strictly speaking, on every 'filetype' option value change to target value).
-- Usually it needs to define buffer/window local options and variables.
-- So instead of `vim.o` to set options, use `vim.bo` for buffer-local options and
-- `vim.cmd('setlocal ...')` for window-local options (currently more robust).
--
-- This is also a good place to set buffer-local 'mini.nvim' variables.
-- See `:h mini.nvim-buffer-local-config` and `:h mini.nvim-disabling-recipes`.

-- Skip non-file buffers (such as LSP hover floats, which also use
-- `filetype=markdown`) so they don't get spell-checked or mutated.
if vim.bo.buftype ~= '' then return end

-- Enable spelling and wrap for window
vim.cmd('setlocal spell wrap')

-- Folds come from the tree-sitter lifecycle in 'plugin/40_plugins.lua'.

-- Disable buffer-local `gO` (outline view) in favor of 'mini.basics'.
-- Guarded: hover floats (`K`) also get `filetype=markdown`, but treesitter
-- may not start there, so no buffer-local mapping exists and bare `del`
-- throws E31 and aborts the float.
pcall(vim.keymap.del, 'n', 'gO', { buf = 0 })

-- Set markdown-specific surrounding in 'mini.surround'
vim.b.minisurround_config = {
  custom_surroundings = {
    -- Markdown link. Common usage:
    -- `saiwL` + [type/paste link] + <CR> - add link
    -- `sdL` - delete link
    -- `srLL` + [type/paste link] + <CR> - replace link
    L = {
      input = { '%[().-()%]%(.-%)' },
      output = function()
        local link = require('mini.surround').user_input('Link: ')
        return { left = '[', right = '](' .. link .. ')' }
      end,
    },
  },
}
