-- ┌────────────────────────────────────────┐
-- │ Agent: one seam, two adapters          │
-- └────────────────────────────────────────┘
--
-- 'Send editor context to an agent' has a single interface here:
-- focus / attach (stage, no submit) / send (submit now) / prompt.
-- Two adapters sit behind it, chosen in one place (`active_adapter()`):
-- - the host's agent panes (`require('config.host').agent`, Rex or Herdr):
--   always inside Herdr; inside Rex when an agent pane exists and no
--   sidekick chat is open in this tabpage
-- - sidekick CLI terminal ('plugin/45_sidekick.lua', otherwise)
--
-- Adapters provide `focus()`, `attach(text, what)`, `send(text, what)` and are
-- resolved at press time. Sidekick registers via `Config.Agent.register()`
-- with an extra `visible()`; delete its file and the host is the only one.
--
-- Conventions (both adapters):
-- - Lowercase (`af`/`at`/`as`/`aq`/`ad`/`av`) attaches context to the
--   agent's input WITHOUT submitting it, focusing the agent UI so more can be
--   added and Enter pressed manually. Uppercase (`aF`/`aT`/`aS`/`aQ`/`aD`/`aV`)
--   sends it immediately.

-- Context builders (adapter-agnostic Markdown) ===============================

local function relative_path()
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then return nil end
  return vim.fn.fnamemodify(path, ':.')
end

local function visual_selection()
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    vim.cmd('normal! \27') -- leave Visual so the '< '> marks are set
  end

  local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = vim.fn.visualmode() })
  return table.concat(lines, '\n')
end

local function file_message()
  local path = relative_path()
  return path and ('Look at `' .. path .. '`.') or nil
end

local function location_message()
  local path = relative_path() or '[scratch]'
  return string.format('Look at `%s` around line %d.', path, vim.fn.line('.'))
end

local function selection_message()
  local path = relative_path() or '[scratch]'
  local selection = visual_selection()
  if selection == '' then return nil end
  return string.format('In `%s`:\n\n```\n%s\n```', path, selection)
end

-- `nil` without a symbol is not a dead end: the location goes instead.
local function symbol_message()
  local symbol = require('config.symbol').describe()
  if not symbol then
    vim.notify('No LSP symbol at the cursor; using the line instead', vim.log.levels.INFO)
    return location_message()
  end
  return string.format('Look at %s, around line %d.', symbol, vim.fn.line('.'))
end

-- Quickfix and diagnostics reuse sidekick's context renderers (`{quickfix}`,
-- `{diagnostics}`), so every adapter gets the same text as sidekick's prompt
-- library. Sidekick loads in every host; without it these keys only warn.
local function sidekick_message(msg, empty)
  local ok, context = pcall(require, 'sidekick.cli.context')
  if not ok then
    vim.notify('sidekick.nvim is not loaded', vim.log.levels.WARN)
    return nil
  end
  local text = context.get():render({ msg = msg, this = false })
  if not text or text == '' then vim.notify(empty, vim.log.levels.INFO) end
  return text ~= '' and text or nil
end

local function quickfix_message()
  return sidekick_message('Look at these quickfix entries:\n{quickfix}', 'The quickfix list is empty')
end

local function diagnostics_message()
  return sidekick_message('Look at these diagnostics:\n{diagnostics}', 'No diagnostics in this buffer')
end

-- Dispatcher =================================================================

local host = require('config.host')
local adapters = {}

Config.Agent = {}

Config.Agent.register = function(name, adapter)
  adapters[name] = adapter
end

local function active_adapter()
  local sidekick = adapters.sidekick
  if host.agent_panes_only() then return host.agent end
  -- Otherwise the agent on screen wins: an open sidekick chat first, then an
  -- agent running in a host pane. With neither (or outside a host), sidekick
  -- opens its chat, so `<Leader>a*` never dead-ends.
  if not (sidekick and sidekick.visible()) and host.has_agents() then return host.agent end
  return sidekick
end

Config.Agent.active_adapter = active_adapter

local function with_adapter(fn)
  local adapter = active_adapter()
  if adapter == nil then
    vim.notify('No agent adapter available', vim.log.levels.WARN)
    return
  end
  fn(adapter)
end

Config.Agent.focus = function()
  with_adapter(function(a) a.focus() end)
end

Config.Agent.attach = function(text, what)
  with_adapter(function(a) a.attach(text, what) end)
end

Config.Agent.send = function(text, what)
  with_adapter(function(a) a.send(text, what) end)
end

Config.Agent.prompt = function()
  vim.ui.input({ prompt = 'Prompt agent: ' }, function(text)
    if text and text ~= '' then Config.Agent.send(text, 'prompt') end
  end)
end

-- Mappings ===================================================================

-- stylua: ignore start
vim.keymap.set('n', '<Leader>aa', Config.Agent.focus, { desc = 'Focus agent' })
vim.keymap.set('n', '<D-r>',      Config.Agent.focus, { desc = 'Focus agent' })

vim.keymap.set('n', '<Leader>af', function()
  local m = file_message(); if m then Config.Agent.attach(m, 'file') end
end, { desc = 'Attach file to agent' })
vim.keymap.set('n', '<Leader>aF', function()
  local m = file_message(); if m then Config.Agent.send(m, 'file') end
end, { desc = 'Send file to agent' })

vim.keymap.set('n', '<Leader>at', function() Config.Agent.attach(location_message(), 'location') end, { desc = 'Attach location to agent' })
vim.keymap.set('n', '<Leader>aT', function() Config.Agent.send(location_message(), 'location') end,   { desc = 'Send location to agent' })

vim.keymap.set('n', '<Leader>as', function() Config.Agent.attach(symbol_message(), 'symbol') end, { desc = 'Attach symbol to agent' })
vim.keymap.set('n', '<Leader>aS', function() Config.Agent.send(symbol_message(), 'symbol') end,   { desc = 'Send symbol to agent' })

vim.keymap.set('n', '<Leader>aq', function()
  local m = quickfix_message(); if m then Config.Agent.attach(m, 'quickfix') end
end, { desc = 'Attach quickfix to agent' })
vim.keymap.set('n', '<Leader>aQ', function()
  local m = quickfix_message(); if m then Config.Agent.send(m, 'quickfix') end
end, { desc = 'Send quickfix to agent' })

vim.keymap.set('n', '<Leader>ad', function()
  local m = diagnostics_message(); if m then Config.Agent.attach(m, 'diagnostics') end
end, { desc = 'Attach diagnostics to agent' })
vim.keymap.set('n', '<Leader>aD', function()
  local m = diagnostics_message(); if m then Config.Agent.send(m, 'diagnostics') end
end, { desc = 'Send diagnostics to agent' })

vim.keymap.set('x', '<Leader>av', function()
  local m = selection_message(); if m then Config.Agent.attach(m, 'selection') end
end, { desc = 'Attach selection to agent' })
vim.keymap.set('x', '<Leader>aV', function()
  local m = selection_message(); if m then Config.Agent.send(m, 'selection') end
end, { desc = 'Send selection to agent' })

vim.keymap.set('n', '<Leader>ap', Config.Agent.prompt, { desc = 'Prompt agent' })
-- stylua: ignore end
