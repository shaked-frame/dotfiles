-- ┌───────────────────┐
-- │ Sidekick and AI   │
-- └───────────────────┘
--
-- 'folke/sidekick.nvim' provides a terminal-embedded AI CLI ("sidekick") plus
-- helpers to send buffer/selection context to it.
--
-- Mappings live under the `<Leader>a` group (see 'plugin/20_keymaps.lua' for the
-- 'mini.clue' group registration). These mirror the Zed `space a *` bindings.

local add = vim.pack.add
local later = Config.later

later(function()
  add({ 'https://github.com/folke/sidekick.nvim' })

  require('sidekick').setup({
    cli = {
      mux = {
        -- NOTE: was 'zellij' before, which never matched the actual setup.
        -- Terminal multiplexer in use is tmux (see '~/.tmux.conf').
        backend = 'tmux',
        enabled = true,
      },
    },
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

  -- NOTE: Normal mode `<Tab>` is deliberately NOT mapped. Doing so shadows the
  -- built-in `<C-i>` (jump forward in the jumplist), since they are the same key.

  vim.keymap.set({ 'n', 't', 'i', 'x' }, '<C-.>', function()
    require('sidekick.cli').focus()
  end, { desc = 'Sidekick Focus' })

  -- stylua: ignore start
  local cli = function(fn) return function() fn(require('sidekick.cli')) end end

  vim.keymap.set('n', '<Leader>aa', cli(function(c) c.toggle() end),                          { desc = 'Toggle CLI' })
  vim.keymap.set('n', '<Leader>as', cli(function(c) c.select() end),                          { desc = 'Select CLI' })
  vim.keymap.set('n', '<Leader>ad', cli(function(c) c.close() end),                           { desc = 'Detach a CLI session' })
  vim.keymap.set('n', '<Leader>af', cli(function(c) c.send({ msg = '{file}' }) end),          { desc = 'Send file' })
  vim.keymap.set('x', '<Leader>av', cli(function(c) c.send({ msg = '{selection}' }) end),     { desc = 'Send visual selection' })

  vim.keymap.set({ 'n', 'x' }, '<Leader>at', cli(function(c) c.send({ msg = '{this}' }) end), { desc = 'Send this' })
  vim.keymap.set({ 'n', 'x' }, '<Leader>ap', cli(function(c) c.prompt() end),                 { desc = 'Select prompt' })

  -- Zed's `space a c` opens a thread with the "opencode" agent
  vim.keymap.set('n', '<Leader>ac', cli(function(c) c.toggle({ name = 'opencode', focus = true }) end), { desc = 'Toggle opencode' })
  vim.keymap.set('n', '<Leader>aC', cli(function(c) c.toggle({ name = 'claude', focus = true }) end),   { desc = 'Toggle Claude' })
  -- stylua: ignore end
end)
