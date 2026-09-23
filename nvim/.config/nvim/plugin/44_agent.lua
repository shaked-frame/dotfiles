-- ┌────────────────────────────────────────┐
-- │ Agent: one seam, two adapters          │
-- └────────────────────────────────────────┘
--
-- 'Send editor context to an agent' has a single interface here:
-- focus / attach (stage, no submit) / send (submit now) / prompt.
-- Two adapters sit behind it, branched on exactly once:
-- - Herdr panes ('plugin/60_herdr.lua', when HERDR_ENV=1)
-- - sidekick CLI terminal ('plugin/46_sidekick_cli.lua', otherwise)
--
-- Adapters expose focus(), attach(text, what), send(text, what) and are
-- resolved at press time, not source time. Removal: delete one adapter file
-- and the dispatcher falls back to the other.
--
-- Conventions (both backends):
-- - Lowercase (`af`/`at`/`av`) attaches context to the agent's input WITHOUT
--   submitting it, focusing the agent UI so more can be added and Enter
--   pressed manually. Uppercase (`aF`/`aT`/`aV`) sends it immediately.

-- Context builders (backend-agnostic Markdown) ================================

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

-- Dispatcher =================================================================

local function active_adapter()
  if vim.env.HERDR_ENV == '1' and Config.AgentHerdr ~= nil then
    return Config.AgentHerdr
  end
  return Config.AgentSidekick
end

local function with_adapter(fn_name, fn)
  local adapter = active_adapter()
  if adapter == nil then
    vim.notify('No agent adapter available', vim.log.levels.WARN)
    return
  end
  fn(adapter)
end

Config.Agent = {}

Config.Agent.focus = function()
  with_adapter('focus', function(a) a.focus() end)
end

Config.Agent.attach = function(text, what)
  with_adapter('attach', function(a) a.attach(text, what) end)
end

Config.Agent.send = function(text, what)
  with_adapter('send', function(a) a.send(text, what) end)
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

vim.keymap.set('x', '<Leader>av', function()
  local m = selection_message(); if m then Config.Agent.attach(m, 'selection') end
end, { desc = 'Attach selection to agent' })
vim.keymap.set('x', '<Leader>aV', function()
  local m = selection_message(); if m then Config.Agent.send(m, 'selection') end
end, { desc = 'Send selection to agent' })

vim.keymap.set('n', '<Leader>ap', Config.Agent.prompt, { desc = 'Prompt agent' })
-- stylua: ignore end
