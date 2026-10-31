-- ┌───────────────────────────────────┐
-- │ Rex: host, worktrees, agent panes │
-- └───────────────────────────────────┘
--
-- Rex (https://www.superlogical.com/rex) is the terminal multiplexer hosting
-- this Neovim. Three parts:
--
-- - `Config.Rex`: the Rex host (see CONTEXT.md). Detection and every `rex`
--   call from Neovim go through it; 'plugin/22_splits.lua' and
--   'plugin/44_agent.lua' use it at press time. All calls run through
--   `Config.Rex.runner`, which 'scripts/test-rex-host.lua' swaps for a recorder.
-- - `<Leader>gw`: pick a worktree session. Listing and opening live in the
--   `worktrees` / `worktree_open` actions in ~/.config/rex/init.lua; this
--   only shows and chooses. Switching the app's session from the CLI needs
--   Remote Control turned on in the Rex app (Settings > Rex Server).
-- - The Rex agent adapter behind 'plugin/44_agent.lua': `<Leader>a*` sends
--   editor context to a claude/codex pane in this Rex session. The dispatcher
--   only picks it when no sidekick chat is open and `available()` finds an
--   agent pane, so sidekick (inline completion, NES, its CLI chat) is untouched.

-- Host =======================================================================

Config.Rex = {}

--- Run `rex <argv>`. With `opts.wait`, wait and return
--- `{ code, stdout, stderr }`; otherwise start it and return nothing.
---@param argv string[]
---@param opts? { wait?: boolean }
---@return { code: integer, stdout: string, stderr: string }|nil
Config.Rex.runner = function(argv, opts)
  local dir = vim.env.REX_BIN_DIR
  local cmd = vim.list_extend({ (dir and dir ~= '') and (dir .. '/rex') or 'rex' }, argv)
  if opts and opts.wait then
    local out = vim.system(cmd, { text = true }):wait()
    return { code = out.code, stdout = out.stdout or '', stderr = out.stderr or '' }
  end
  vim.system(cmd)
end

--- Whether this Neovim runs in a Rex pane. Herdr wins when nested in Rex: it
--- is the multiplexer the pane actually sits in.
Config.Rex.active = function()
  return vim.env.HERDR_ENV ~= '1' and (vim.env.REX_BLOCK or '') ~= ''
end

--- Run a Rex action against this Neovim's pane and wait for its result.
--- Never notifies: callers decide whether a failure matters.
---@param name string
---@param args? table<string, string|number|boolean>
---@return table|nil result, string|nil err
Config.Rex.action = function(name, args)
  local argv = { 'do', name, '-b', vim.env.REX_BLOCK or '', '--json' }
  local keys = vim.tbl_keys(args or {})
  table.sort(keys)
  for _, k in ipairs(keys) do
    table.insert(argv, k .. '=' .. tostring(args[k]))
  end

  local out = Config.Rex.runner(argv, { wait = true })
  if out.code ~= 0 then return nil, vim.trim(out.stderr ~= '' and out.stderr or out.stdout) end
  local text = vim.trim(out.stdout)
  if text == '' or text == 'null' then return {} end
  local ok, decoded = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  if not ok or type(decoded) ~= 'table' then return nil, 'unreadable result from `rex do ' .. name .. '`' end
  return decoded
end

--- Focus a pane by ID, or the nearest pane in a direction
--- ('left'|'right'|'up'|'down').
---@param target string
Config.Rex.focus = function(target) Config.Rex.runner({ 'focus', target }) end

--- Type `text` into a pane as one bracketed paste, so multi-line text lands as
--- one block instead of each newline submitting. `submit` presses Enter after
--- a beat, or a TUI can eat it while it takes the paste.
---@param block_id string
---@param text string
---@param opts? { submit?: boolean }
Config.Rex.send = function(block_id, text, opts)
  Config.Rex.runner({ 'send', '-b', block_id, '\27[200~' .. text .. '\27[201~' })
  if opts and opts.submit then
    vim.defer_fn(function() Config.Rex.runner({ 'send-key', '-b', block_id, 'enter' }) end, 150)
  end
end

if not Config.Rex.active() then return end

-- Worktrees ==================================================================

-- Pick a Git worktree and open (or switch to) its worktree session.
-- Mirrors Zed's `space g w`.
local function pick_worktree()
  local res, err = Config.Rex.action('worktrees', { cwd = vim.fn.getcwd() })
  if not res then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  local list = res.worktrees or {}
  if #list == 0 then
    vim.notify('No Git worktrees found', vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, w in ipairs(list) do
    local name = w.branch or vim.fn.fnamemodify(w.path, ':t')
    local renamed = (w.label and w.label ~= name) and ('  [' .. w.label .. ']') or ''
    table.insert(items, {
      text = string.format(
        '%s%-44s %s%s',
        w.session_id and '● ' or '○ ',
        (w.detached and '(detached) ' or '') .. name,
        vim.fn.fnamemodify(w.path, ':~'),
        renamed
      ),
      path = w.path,
    })
  end

  MiniPick.start({
    source = {
      items = items,
      name = 'Rex worktrees (● open)',
      choose = function(item)
        -- Deferred: MiniPick is still tearing its window down at this point.
        vim.schedule(function()
          local _, open_err = Config.Rex.action('worktree_open', { path = item.path })
          if open_err then vim.notify(open_err, vim.log.levels.ERROR) end
        end)
      end,
    },
  })
end

-- Agents =====================================================================

local agents_cache = { at = 0, list = {} }

--- Agent panes in this Rex session, this tab's first, from the `list_agents`
--- action in ~/.config/rex/init.lua. Cached for a second: the dispatcher's
--- `available()` and the adapter call after it ask within one keypress. Any
--- failure (old config, server down) reads as "no agents", which sends the
--- dispatcher to sidekick instead of erroring.
local function agents()
  local now = vim.uv.now()
  if now - agents_cache.at < 1000 then return agents_cache.list end
  local res = Config.Rex.action('list_agents')
  agents_cache = { at = now, list = res and res.agents or {} }
  return agents_cache.list
end

--- Call `fn(agent)` with the agent pane to use: the only one in this tab, or a
--- pick among this tab's (or, with none here, the whole session's).
---@param prompt string
---@param fn fun(agent: table)
local function with_agent(prompt, fn)
  local all = agents()
  local here = vim.tbl_filter(function(a) return a.here end, all)
  local candidates = #here > 0 and here or all
  if #candidates == 0 then
    vim.notify('No agent pane in this Rex session', vim.log.levels.WARN)
    return
  end
  if #candidates == 1 then
    fn(candidates[1])
    return
  end

  local items = {}
  for i, a in ipairs(candidates) do
    table.insert(items, { text = string.format('%d. %-8s %s', i, a.program, a.here and 'this tab' or 'other tab'), agent = a })
  end
  MiniPick.start({
    source = {
      items = items,
      name = prompt,
      choose = function(item) vim.schedule(function() fn(item.agent) end) end,
    },
  })
end

if Config.Agent and Config.Agent.register then
  Config.Agent.register('rex', {
    available = function() return #agents() > 0 end,
    focus = function()
      with_agent('Rex agents -> focus', function(a) Config.Rex.focus(a.block_id) end)
    end,
    -- Stage without submitting, then move to the agent to add more and press Enter.
    attach = function(text, what)
      with_agent('Rex agents -> ' .. what, function(a)
        Config.Rex.send(a.block_id, text)
        Config.Rex.focus(a.block_id)
        vim.notify('Attached ' .. what .. ' to ' .. a.program .. ' (not sent)')
      end)
    end,
    send = function(text, what)
      with_agent('Rex agents -> ' .. what, function(a)
        Config.Rex.send(a.block_id, text, { submit = true })
        vim.notify('Sent ' .. what .. ' to ' .. a.program)
      end)
    end,
  })
end

-- Mappings ===================================================================

-- stylua: ignore start
vim.keymap.set('n', '<Leader>gw', pick_worktree, { desc = 'Worktrees (Rex)' })
-- stylua: ignore end
