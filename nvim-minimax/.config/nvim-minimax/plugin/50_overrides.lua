-- ┌───────────────────────────────┐
-- │ Mappings that must win last   │
-- └───────────────────────────────┘
--
-- Some MINI modules create mappings inside `Config.later()`, which runs *after*
-- 'plugin/20_keymaps.lua' has already been sourced. Anything defined there that
-- collides with a MINI mapping therefore loses.
--
-- Files in 'plugin/' are sourced in alphabetical order, and `Config.later()`
-- callbacks run in registration order. Because this file is sourced after
-- 'plugin/30_mini.lua', a `later()` callback registered here runs after MINI's,
-- so mappings below reliably take precedence.
--
-- Keep this file as small as possible: prefer non-conflicting keys where you can.

local later = Config.later

later(function()
  -- `gr` is the "replace" operator from 'mini.operators', and `grr` is its
  -- "replace line" variant. Zed maps `g r r` to editor::FindAllReferences, and
  -- LSP references are used far more often here than replacing a whole line.
  --
  -- Line-wise replace is still available as `gr_` (operator + `_` motion).
  -- Neovim's own default is `grr` too (see `:h grr`).
  local pick_lsp_references = function()
    vim.cmd.cclose()
    vim.cmd.lclose()
    vim.cmd([[Pick lsp scope="references"]])
  end

  vim.keymap.set('n', 'grr', pick_lsp_references, { desc = 'References' })
end)
