-- ┌────────────────────────────────────────┐
-- │ Sidekick CLI + snacks (outside Herdr)  │
-- └────────────────────────────────────────┘
--
-- Inside Herdr (`HERDR_ENV=1`) agents live in Herdr panes - see
-- 'plugin/60_herdr.lua' - so this file is a no-op there.
--
-- Outside Herdr there is no agent pane to drive, so run the agent inside
-- Neovim via 'sidekick.nvim' CLI terminal (plain nvim terminal,
-- `mux.enabled = false`). Primary tool is opencode, matching
-- '~/.config/opencode' (MCPs, commands, skills); claude/codex are fallbacks.
-- Tools are declared in 'plugin/45_sidekick.lua'.
--
-- 'snacks.nvim' is *only* sidekick's preferred picker here (prompt/tool
-- selection) plus the `sidekick_send` picker action (`<M-a>`) to ship picker
-- selections to the CLI. File finding stays on 'mini.pick' (`<Leader>f*`).

-- Herdr owns `<Leader>a*` inside its panes; don't shadow those mappings.
if vim.env.HERDR_ENV == '1' then return end

local add = vim.pack.add
local later = Config.later

later(function()
  add({ 'https://github.com/folke/snacks.nvim' })

  require('snacks').setup({
    picker = {
      actions = {
        sidekick_send = function(...)
          return require('sidekick.cli.picker.snacks').send(...)
        end,
      },
      win = {
        input = {
          keys = {
            ['<a-a>'] = { 'sidekick_send', mode = { 'n', 'i' } },
          },
        },
      },
    },
  })

  local cli = require('sidekick.cli')

  -- Adapter implementing the `Config.Agent` interface declared in
  -- 'plugin/44_agent.lua' (the unified `<Leader>a*` keymaps live there).
  -- Lowercase attach stages text WITHOUT submitting and focuses the panel
  -- so more can be added and Enter pressed manually; uppercase send submits
  -- immediately. Removal: delete this file and the dispatcher falls back
  -- to Herdr.
  Config.AgentSidekick = {
    focus = function() cli.toggle() end,
    attach = function(text, _what)
      cli.send({ msg = text, submit = false })
      cli.focus()
    end,
    send = function(text, _what) cli.send({ msg = text, submit = true }) end,
  }

  -- Explicit tool toggles (opencode primary). No Herdr equivalent by design:
  -- inside Herdr the agent is picked via the dispatcher (`<Leader>aa`).
  vim.keymap.set({ 'n', 'x' }, '<Leader>ao', function() cli.toggle({ name = 'opencode' }) end, { desc = 'Opencode toggle' })
  vim.keymap.set({ 'n', 'x' }, '<Leader>ac', function() cli.toggle({ name = 'claude' }) end, { desc = 'Claude toggle' })
  vim.keymap.set({ 'n', 'x' }, '<Leader>ax', function() cli.toggle({ name = 'codex' }) end, { desc = 'Codex toggle' })
  -- Pick from installed CLI tools.
  vim.keymap.set('n', '<Leader>as', function() cli.select({ filter = { installed = true } }) end, { desc = 'AI CLI select' })
end)
