-- ┌──────────────────────────────────────────┐
-- │ Host: the multiplexer this Neovim sits in │
-- └──────────────────────────────────────────┘
--
-- Neovim runs inside Rex, inside Herdr, or neither (see "host" in
-- CONTEXT.md). This module is the only place that detects which one and the
-- only place that runs the `rex` / `herdr` CLIs. Callers get the same
-- operations whichever host it is:
--
-- - `kind()`             'rex' | 'herdr' | nil. Herdr wins when nested in Rex:
--                        it is the multiplexer the pane actually sits in.
-- - `agent_panes_only()` the host's agent panes replace the sidekick chat
--                        entirely (Herdr). In Rex they are used only while an
--                        agent pane exists (`has_agents()`).
-- - `focus(direction)`   hand focus to the neighbouring pane
--                        ('left'|'right'|'up'|'down'), for `<C-hjkl>` at a
--                        split edge ('plugin/22_splits.lua').
-- - `resize(direction)`  resize this pane when Neovim has no split to resize.
-- - `has_agents()`       an agent pane exists (the dispatcher's Rex rule).
-- - `agent`              the agent adapter ('plugin/44_agent.lua'):
--                        `focus()`, `attach(text, what)`, `send(text, what)`.
-- - `pick_worktree()`    open a worktree from a picker (`<Leader>gw`).
--
-- Every CLI call goes through `runner`, which 'scripts/test-host.lua' swaps
-- for a recorder. CLI failures land in `:messages` as errors, never as
-- notifications; "nothing found" stays a short warning.

local M = {}

--- Run `cmd` (binary first). With `opts.wait`, wait and return
--- `{ code, stdout, stderr }`; otherwise start it and return nothing.
---@param cmd string[]
---@param opts? { wait?: boolean }
---@return { code: integer, stdout: string, stderr: string }|nil
M.runner = function(cmd, opts)
  if opts and opts.wait then
    local out = vim.system(cmd, { text = true }):wait()
    return { code = out.code, stdout = out.stdout or '', stderr = out.stderr or '' }
  end
  vim.system(cmd)
end

local env = function(name)
  local value = vim.env[name]
  return (value ~= nil and value ~= '') and value or nil
end

local echo_error = function(message) vim.api.nvim_echo({ { message } }, true, { err = true }) end

--- Run and decode a waited call. Fails with the CLI's own message. With
--- `json`, output that is neither empty nor JSON is an error too (an outdated
--- Rex config answering in plain text); without it only the exit code counts,
--- as `herdr pane send-text` / `agent focus` print nothing or plain text.
---@return table|nil result, string|nil err
local call = function(cmd, json)
  local out = M.runner(cmd, { wait = true })
  local name = vim.fn.fnamemodify(cmd[1], ':t') .. ' ' .. (cmd[2] or '') .. (cmd[2] == 'do' and (' ' .. cmd[3]) or '')
  if out.code ~= 0 then
    local msg = vim.trim(out.stderr ~= '' and out.stderr or out.stdout)
    return nil, msg ~= '' and msg or ('`' .. name .. '` failed (exit ' .. out.code .. ')')
  end
  local text = vim.trim(out.stdout)
  if text == '' or text == 'null' then return {} end
  local ok, decoded = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  if ok and type(decoded) == 'table' then return decoded end
  if json then return nil, 'unreadable result from `' .. name .. '`' end
  return {}
end

-- Rex ========================================================================
-- Listing and opening worktrees and listing agents are actions in
-- ~/.config/rex/init.lua (`rex do <action>`), run against this Neovim's pane.

local rex = { no_agents = 'No agent pane in this Rex session' }

local rex_cmd = function(argv)
  local dir = env('REX_BIN_DIR')
  return vim.list_extend({ dir and (dir .. '/rex') or 'rex' }, argv)
end

local rex_action = function(name, args)
  local argv = { 'do', name, '-b', env('REX_BLOCK') or '', '--json' }
  local keys = vim.tbl_keys(args or {})
  table.sort(keys)
  for _, k in ipairs(keys) do
    table.insert(argv, k .. '=' .. tostring(args[k]))
  end
  return call(rex_cmd(argv), true)
end

rex.focus = function(target) M.runner(rex_cmd({ 'focus', target })) end

-- `rex=true` stops Rex from sending the resize back to Neovim.
rex.resize = function(direction) rex_action('resize', { direction = direction, rex = true }) end

-- Cached for a second: the dispatcher's `has_agents()` and the adapter call
-- after it ask within one keypress. Any failure (old Rex config, server down)
-- reads as "no agents", which sends the dispatcher to sidekick.
local agents_cache = { at = -math.huge, list = {} }
rex.agents = function()
  local now = vim.uv.now()
  if now - agents_cache.at < 1000 then return agents_cache.list end
  local list = {}
  for _, a in ipairs((rex_action('list_agents') or {}).agents or {}) do
    table.insert(list, {
      id = a.block_id,
      label = a.program,
      here = a.here,
    })
  end
  agents_cache = { at = now, list = list }
  return list
end

rex.focus_agent = function(agent) rex.focus(agent.id) end

-- One bracketed paste, so multi-line text lands as one block instead of each
-- newline submitting. Enter follows a beat later, or a TUI can eat it while it
-- takes the paste.
rex.paste = function(agent, text, submit)
  M.runner(rex_cmd({ 'send', '-b', agent.id, '\27[200~' .. text .. '\27[201~' }))
  if submit then
    vim.defer_fn(function() M.runner(rex_cmd({ 'send-key', '-b', agent.id, 'enter' })) end, 150)
  end
  return true
end

rex.worktrees = function()
  local res, err = rex_action('worktrees', { cwd = vim.fn.getcwd() })
  if not res then return nil, err end
  return vim.tbl_map(function(w)
    return { path = w.path, branch = w.branch, detached = w.detached, open = w.session_id ~= nil, label = w.label }
  end, res.worktrees or {})
end

rex.open_worktree = function(w)
  local _, err = rex_action('worktree_open', { path = w.path })
  return err
end

-- Herdr ======================================================================
-- Herdr injects HERDR_ENV / HERDR_PANE_ID / HERDR_WORKSPACE_ID into the panes
-- it manages. Field names come from its `AgentInfo` schema (`herdr api schema`).

local herdr = { no_agents = 'No live Herdr agents in this workspace. Start one with `herdr agent start`.' }

local herdr_cmd = function(args) return vim.list_extend({ env('HERDR_BIN_PATH') or 'herdr' }, args) end

local herdr_call = function(args)
  local res, err = call(herdr_cmd(args))
  if err then err = 'herdr ' .. table.concat(vim.list_slice(args, 1, 2), ' ') .. '\n' .. err end
  return res, err
end

herdr.focus = function(direction)
  local pane = env('HERDR_PANE_ID')
  if pane then M.runner(herdr_cmd({ 'pane', 'focus', '--direction', direction, '--pane', pane })) end
end

-- Excludes `opencode` (the assistant chatting in a pane next to this Neovim,
-- never a hand-off target) and agents in other Herdr workspaces.
herdr.agents = function()
  local res, err = herdr_call({ 'agent', 'list' })
  if err then echo_error(err) end
  local ws = env('HERDR_WORKSPACE_ID')
  local list = {}
  for _, a in ipairs(res and res.result and res.result.agents or {}) do
    if a.agent ~= 'opencode' and a.display_agent ~= 'opencode' and (not ws or a.workspace_id == ws) then
      table.insert(list, {
        id = a.pane_id,
        label = a.name or a.pane_id,
        program = a.display_agent or a.agent,
        status = a.agent_status,
        -- Tells apart two agents of one kind in worktree workspaces.
        cwd = a.cwd,
        here = true,
      })
    end
  end
  return list
end

herdr.focus_agent = function(agent)
  local _, err = herdr_call({ 'agent', 'focus', agent.label })
  if err then echo_error(err) end
end

-- `agent prompt` always submits; `pane send-text` types without Enter.
herdr.paste = function(agent, text, submit)
  local args = submit and { 'agent', 'prompt', agent.label, text } or { 'pane', 'send-text', agent.id, text }
  local _, err = herdr_call(args)
  if err then echo_error(err) end
  return err == nil
end

herdr.worktrees = function()
  local res, err = herdr_call({ 'worktree', 'list' })
  if not res then return nil, err end
  return vim.tbl_map(function(w)
    return { path = w.path, branch = w.branch, detached = w.branch == nil, open = w.open_workspace_id ~= nil, workspace = w.open_workspace_id }
  end, res.result and res.result.worktrees or {})
end

-- Focus the worktree's workspace when it has one instead of opening a duplicate.
herdr.open_worktree = function(w)
  local args = w.workspace and { 'workspace', 'focus', w.workspace } or { 'worktree', 'open', '--path', w.path, '--focus' }
  local _, err = herdr_call(args)
  return err
end

-- Interface ==================================================================

local adapters = { rex = rex, herdr = herdr }

---@return 'rex'|'herdr'|nil
-- Herdr injects both HERDR_ENV and HERDR_PANE_ID into its panes; either
-- marks one, but HERDR_ENV=1 is the one that beats an inherited REX_BLOCK.
M.kind = function()
  if vim.env.HERDR_ENV == '1' then return 'herdr' end
  if env('REX_BLOCK') then return 'rex' end
  if env('HERDR_PANE_ID') then return 'herdr' end
end

M.agent_panes_only = function() return M.kind() == 'herdr' end

local current = function() return adapters[M.kind()] end

M.focus = function(direction)
  local host = current()
  if host then host.focus(direction) end
end

M.resize = function(direction)
  local host = current()
  if host and host.resize then host.resize(direction) end
end

M.has_agents = function()
  local host = current()
  return host ~= nil and #host.agents() > 0
end

--- One picker line: name, program, status, then where it runs.
local format_agent = function(a)
  local program = a.program ~= a.label and a.program or ''
  local where = a.cwd and vim.fn.fnamemodify(a.cwd, ':~') or (a.here and 'this tab' or 'other tab')
  return string.format('%-18s %-10s %-9s %s', a.label or '?', program or '', a.status or '', where)
end

--- Call `fn(host, agent)` with the agent pane to use: the only one, or a pick
--- among this tab's (or, with none here, all of them).
local with_agent = function(what, fn)
  local host = current()
  if not host then return end
  local all = host.agents()
  local here = vim.tbl_filter(function(a) return a.here end, all)
  local candidates = #here > 0 and here or all
  if #candidates == 0 then return vim.notify(host.no_agents, vim.log.levels.WARN) end
  if #candidates == 1 then return fn(host, candidates[1]) end
  vim.ui.select(candidates, { prompt = 'Agent -> ' .. what, format_item = format_agent }, function(agent)
    -- Deferred: the picker is still tearing its window down at this point.
    if agent then vim.schedule(function() fn(host, agent) end) end
  end)
end

M.agent = {
  focus = function()
    with_agent('focus', function(host, agent) host.focus_agent(agent) end)
  end,
  -- Stage without submitting, then move to the agent to add more and press Enter.
  attach = function(text, what)
    with_agent(what, function(host, agent)
      if not host.paste(agent, text, false) then return end
      host.focus_agent(agent)
      vim.notify('Attached ' .. what .. ' to ' .. agent.label .. ' (not sent)')
    end)
  end,
  send = function(text, what)
    with_agent(what, function(host, agent)
      if host.paste(agent, text, true) then vim.notify('Sent ' .. what .. ' to ' .. agent.label) end
    end)
  end,
}

local format_worktree = function(w)
  local name = w.branch or vim.fn.fnamemodify(w.path, ':t')
  local renamed = (w.label and w.label ~= name) and ('  [' .. w.label .. ']') or ''
  local title = (w.detached and '(detached) ' or '') .. name
  return string.format('%s%-44s %s%s', w.open and '● ' or '○ ', title, vim.fn.fnamemodify(w.path, ':~'), renamed)
end

M.pick_worktree = function()
  local host = current()
  if not host then return end
  local list, err = host.worktrees()
  if not list then return echo_error(err) end
  if #list == 0 then return vim.notify('No Git worktrees found', vim.log.levels.WARN) end
  vim.ui.select(list, { prompt = 'Worktrees (● open)', format_item = format_worktree }, function(w)
    if not w then return end
    vim.schedule(function()
      local open_err = host.open_worktree(w)
      if open_err then echo_error(open_err) end
    end)
  end)
end

return M
