-- ┌──────────────────────────────┐
-- │ Sidekick: inline completion  │
-- └──────────────────────────────┘
--
-- Scope strictly covers inline completion ("ghost text", Insert mode) and Next
-- Edit Suggestions (NES, Normal mode), sidekick's two Tab-driven suggestion
-- surfaces.
--
-- Agent CLI terminal configuration and the sidekick agent adapter live in
-- 'plugin/46_sidekick_cli.lua', behind the dispatcher in 'plugin/44_agent.lua'.

local add = vim.pack.add
local later = Config.later

later(function()
  add({ 'https://github.com/folke/sidekick.nvim' })

  require('sidekick').setup({
    cli = { mux = { enabled = false } },
  })

  -- `<Tab>` in Insert mode, in priority order:
  -- 1. If the user already highlighted an item in the completion popup
  --    (`selected ~= -1`), keep cycling the popup menu (`<C-n>`).
  -- 2. Otherwise, if Copilot inline completion ("ghost text") is visible,
  --    accept it (and dismiss an unselected popup menu with `<C-e>` first).
  -- 3. Otherwise, if the completion popup is visible, select the first item.
  -- 4. Otherwise insert a literal `<Tab>`.
  --
  -- To accept inline completion one word at a time instead, use `<C-l>` or
  -- Option+Tab (`<M-Tab>`; set up in 'plugin/40_plugins.lua' on `LspAttach`).
  vim.keymap.set('i', '<Tab>', function()
    local pum = vim.fn.pumvisible() == 1
    if pum and vim.fn.complete_info({ 'selected' }).selected ~= -1 then
      return '<C-n>'
    end

    local ok, accepted = pcall(function() return vim.lsp.inline_completion.get() end)
    if ok and accepted then
      return pum and '<C-e>' or ''
    end

    if pum then return '<C-n>' end

    return '<Tab>'
  end, { expr = true, desc = 'Inline completion / completion / tab' })

  -- NOTE: unlike Insert mode above, the fallback here is `<C-i>`, not a
  -- literal `<Tab>`. Normal mode has no "insert a tab" behavior; `<Tab>` and
  -- `<C-i>` are the same keycode, and the built-in default for that keycode
  -- in Normal mode is jump-forward in the jumplist. Without this fallback,
  -- mapping `<Tab>` at all would silently shadow that built-in.
  vim.keymap.set('n', '<Tab>', function()
    if require('sidekick').nes_jump_or_apply() then return end
    return '<C-i>'
  end, { expr = true, desc = 'Goto/Apply Next Edit Suggestion' })
end)
