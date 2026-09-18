-- ┌──────────────────────────────┐
-- │ Sidekick: inline completion  │
-- └──────────────────────────────┘
--
-- Scope deliberately reduced to inline completion ("ghost text", Insert mode)
-- and Next Edit Suggestions (NES, Normal mode) - sidekick's two Tab-driven
-- suggestion surfaces. See below for why they need separate mappings.
--
-- 'sidekick.nvim' can also run agent CLIs inside Neovim, but that duplicates
-- Herdr, which is the terminal workspace manager already in use here and does
-- it better: Herdr panes survive Neovim restarts and detach, and Herdr tracks
-- agent lifecycle state (idle / working / blocked / done) via its installed
-- integrations. Agent mappings therefore drive Herdr - see 'plugin/60_herdr.lua'.
--
-- Sidekick's session persistence is also a no-op here regardless: it supports
-- only tmux and zellij backends ('sidekick/config.lua' validates exactly those)
-- and guards on `$TMUX` / `$ZELLIJ`, neither of which is set inside Herdr.

local add = vim.pack.add
local later = Config.later

later(function()
  add({ 'https://github.com/folke/sidekick.nvim' })

  require('sidekick').setup({
    -- Herdr owns session persistence; don't let sidekick try to manage one.
    cli = { mux = { enabled = false } },
  })

  -- `<Tab>` in Insert mode, in priority order:
  -- 1. If the completion popup is visible, select the next item. This matches
  --    `MiniKeymap.map_multistep('i', '<Tab>', { 'pmenu_next' })` from
  --    'plugin/30_mini.lua', which this mapping deliberately overrides.
  -- 2. Otherwise try to accept inline completion ("ghost text").
  -- 3. Otherwise insert a literal <Tab>.
  --
  -- To accept inline completion one word at a time instead, use `<C-l>`
  -- (set up in 'plugin/40_plugins.lua' on `LspAttach`).
  vim.keymap.set('i', '<Tab>', function()
    if vim.fn.pumvisible() == 1 then return '<C-n>' end

    local ok, accepted = pcall(function() return vim.lsp.inline_completion.get() end)
    if ok and accepted then return '' end

    return '<Tab>'
  end, { expr = true, desc = 'Completion / inline completion / tab' })

  -- NOTE: unlike Insert mode above, the fallback here is `<C-i>`, not a
  -- literal `<Tab>` - Normal mode has no "insert a tab" behavior; `<Tab>` and
  -- `<C-i>` are the same keycode, and the built-in default for that keycode
  -- in Normal mode is jump-forward in the jumplist. Without this fallback,
  -- mapping `<Tab>` at all would silently shadow that built-in.
  vim.keymap.set('n', '<Tab>', function()
    if require('sidekick').nes_jump_or_apply() then return end
    return '<C-i>'
  end, { expr = true, desc = 'Goto/Apply Next Edit Suggestion' })
end)
