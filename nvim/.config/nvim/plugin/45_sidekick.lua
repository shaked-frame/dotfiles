-- ┌──────────────────────────────┐
-- │ Sidekick: inline completion  │
-- └──────────────────────────────┘
--
-- Scope deliberately reduced to inline completion ("ghost text", Insert mode)
-- and Next Edit Suggestions (NES, Normal mode) - sidekick's two Tab-driven
-- suggestion surfaces. See below for why they need separate mappings.
--
-- 'sidekick.nvim' can also run agent CLIs inside Neovim. Inside Herdr that
-- duplicates Herdr, which does it better: Herdr panes survive Neovim restarts
-- and detach, and Herdr tracks agent lifecycle state (idle / working /
-- blocked / done) via its installed integrations. The unified `<Leader>a*`
-- keymaps live in the dispatcher 'plugin/44_agent.lua' (adapters:
-- 'plugin/60_herdr.lua', 'plugin/46_sidekick_cli.lua').
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
    -- `picker` + `tools` are consumed outside Herdr by 'plugin/46_sidekick_cli.lua'.
    cli = {
      mux = { enabled = false },
      picker = 'snacks',
      -- Custom prompt library, sent via `<Leader>aP` (see
      -- 'plugin/46_sidekick_cli.lua'). Merged over sidekick's built-ins
      -- (`changes`, `diagnostics`, `explain`, `fix`, `optimize`, `review`,
      -- `tests`, ...). Values are templates with `{context}` variables
      -- (`{this}` file-or-selection, `{file}`, `{position}`, `{line}`,
      -- `{selection}`, `{diagnostics}`, `{function}`, `{class}`, ...) or
      -- `function(ctx)` returning the prompt text.
      prompts = {
        find_bugs = 'Find bugs in {this}. For each bug give the file and line.',
        simplify = 'Simplify {this} without changing its behavior.',
        -- Opencode slash commands (`~/.config/opencode/command/`): sending
        -- `/name` as chat input runs the command, so the library can trigger
        -- them. `{this}` becomes the command's `$ARGUMENTS`.
        create_pr = '/create-pr {this}',
      },
      win = {
        keys = {
          -- `<D-r>` mirrors the global 'Focus agent' mapping
          -- ('plugin/44_agent.lua'), but that one is Normal-mode only so it
          -- never fires inside the chat terminal. This buffer-local variant
          -- closes the chat from Terminal and Normal mode.
          hide_cmd_r = { '<D-r>', 'hide', mode = 'nt', desc = 'Hide sidekick chat' },
          -- Wheel in terminal-Normal mode scrolls Neovim's viewport, moving
          -- the *entire* agent UI (input box included) instead of just the
          -- transcript. Per `:h terminal-input`, wheel events are only
          -- forwarded to the app (which scrolls just the conversation, input
          -- pinned) in Terminal mode. Terminal-mode wheel is deliberately
          -- untouched: a mapping there would *stop* forwarding. Viewport
          -- scroll of a fullscreen TUI is never useful (no scrollback
          -- content), so nothing is lost.
          --
          -- Focus-aware: a wheel over the chat while it is focused re-enters
          -- Terminal mode and forwards the event to the agent. A wheel that
          -- merely hovers the unfocused chat is swallowed (`''`) so the pane
          -- stays in place - an unguarded `<Cmd>startinsert` here would run
          -- in the *focused* code window and drop it into Insert mode.
          wheel_up = { '<ScrollWheelUp>', function()
            if vim.api.nvim_get_current_win() == vim.fn.getmousepos().winid then
              return '<Cmd>startinsert<CR><ScrollWheelUp>'
            end
            return ''
          end, mode = 'n', expr = true, desc = 'Forward wheel to agent' },
          wheel_down = { '<ScrollWheelDown>', function()
            if vim.api.nvim_get_current_win() == vim.fn.getmousepos().winid then
              return '<Cmd>startinsert<CR><ScrollWheelDown>'
            end
            return ''
          end, mode = 'n', expr = true, desc = 'Forward wheel to agent' },
        },
      },
      tools = {
        opencode = {}, -- primary: matches ~/.config/opencode (MCPs, commands, skills)
        claude = {}, -- fallback for hardest reasoning tasks
        codex = {},
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
  -- To accept inline completion one word at a time instead, use `<C-l>` or
  -- Option+Tab (`<M-Tab>`; set up in 'plugin/40_plugins.lua' on `LspAttach`).
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
