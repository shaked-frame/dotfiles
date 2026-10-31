-- ┌───────────────────────────────────┐
-- │ Rex: worktree sessions            │
-- └───────────────────────────────────┘
--
-- Rex (https://www.superlogical.com/rex) is the terminal multiplexer hosting
-- this Neovim. Each Git worktree gets its own Rex session, labelled with the
-- branch and laid out as nvim | claude. The session itself is built by the
-- `worktree_open` action in ~/.config/rex/init.lua; this file only picks.
--
-- Loaded after 'plugin/60_herdr.lua' so `<Leader>gw` here wins inside Rex,
-- while Herdr panes keep the Herdr picker.
--
-- Also the Rex agent adapter behind 'plugin/44_agent.lua': `<Leader>a*` sends
-- editor context to a claude/codex pane in this Rex session. The dispatcher
-- only picks it when no sidekick chat is open and `available()` finds an agent
-- pane, so sidekick (inline completion, NES, its CLI chat) is untouched.
--
-- Switching the app's session from the CLI needs Remote Control turned on in
-- the Rex app (Settings > Rex Server).

if not (Config.Agent and Config.Agent.in_rex and Config.Agent.in_rex()) then return end

local rex_bin = (vim.env.REX_BIN_DIR and vim.env.REX_BIN_DIR ~= '') and (vim.env.REX_BIN_DIR .. '/rex') or 'rex'

--- Run a command; return stdout, or nil after notifying the error.
---@param cmd string[]
---@return string|nil
local function run(cmd)
  local out = vim.system(cmd, { text = true }):wait()
  if out.code ~= 0 then
    vim.notify(table.concat(cmd, ' ') .. '\n' .. (out.stderr or ''), vim.log.levels.ERROR)
    return nil
  end
  return out.stdout
end

--- Git worktrees of the current repo as `{ branch, path }` tables.
local function worktrees()
  local out = run({ 'git', 'worktree', 'list', '--porcelain' })
  if not out then return {} end
  local items, path = {}, nil
  for line in out:gmatch('[^\n]+') do
    if line:match('^worktree ') then path = line:sub(10) end
    local branch = line:match('^branch refs/heads/(.+)')
    if branch then table.insert(items, { branch = branch, path = path }) end
    if line == 'detached' then table.insert(items, { branch = '(detached)', path = path }) end
  end
  return items
end

--- Labels of the open Rex sessions, as a set.
local function open_sessions()
  local out = run({ rex_bin, 'ls', '--json' })
  local ok, decoded = pcall(vim.json.decode, out or '')
  local set = {}
  for _, s in ipairs(ok and decoded.sessions or {}) do set[s.label] = true end
  return set
end

-- Pick a Git worktree and open (or switch to) its Rex session.
-- Mirrors Zed's `space g w`.
local function pick_worktree()
  local list = worktrees()
  if #list == 0 then
    vim.notify('No Git worktrees found', vim.log.levels.WARN)
    return
  end

  local open = open_sessions()
  local items = {}
  for _, w in ipairs(list) do
    table.insert(items, {
      text = string.format('%s%-44s %s', open[w.branch] and '● ' or '○ ', w.branch, vim.fn.fnamemodify(w.path, ':~')),
      branch = w.branch,
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
          run({ rex_bin, 'do', 'worktree_open', 'path=' .. item.path, 'branch=' .. item.branch })
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
  local out = vim.system({ rex_bin, 'do', 'list_agents', '-b', vim.env.REX_BLOCK, '--json' }, { text = true }):wait()
  local ok, decoded = pcall(vim.json.decode, out.code == 0 and out.stdout or '')
  agents_cache = { at = now, list = ok and type(decoded) == 'table' and decoded.agents or {} }
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

--- Type `text` into the agent's input. Wrapped in bracketed paste so a
--- multi-line selection lands as one block instead of each newline submitting.
local function paste(agent, text, submit)
  if not run({ rex_bin, 'send', '-b', agent.block_id, '\27[200~' .. text .. '\27[201~' }) then return false end
  if submit then
    -- Give the TUI a beat to take the paste before Enter, or it can be eaten.
    vim.defer_fn(function() run({ rex_bin, 'send-key', '-b', agent.block_id, 'enter' }) end, 150)
  end
  return true
end

if Config.Agent and Config.Agent.register then
  Config.Agent.register('rex', {
    available = function() return #agents() > 0 end,
    focus = function()
      with_agent('Rex agents -> focus', function(a) run({ rex_bin, 'focus', a.block_id }) end)
    end,
    -- Stage without submitting, then move to the agent to add more and press Enter.
    attach = function(text, what)
      with_agent('Rex agents -> ' .. what, function(a)
        if paste(a, text, false) then
          run({ rex_bin, 'focus', a.block_id })
          vim.notify('Attached ' .. what .. ' to ' .. a.program .. ' (not sent)')
        end
      end)
    end,
    send = function(text, what)
      with_agent('Rex agents -> ' .. what, function(a)
        if paste(a, text, true) then vim.notify('Sent ' .. what .. ' to ' .. a.program) end
      end)
    end,
  })
end

-- Mappings ===================================================================

-- stylua: ignore start
vim.keymap.set('n', '<Leader>gw', pick_worktree, { desc = 'Worktrees (Rex)' })
-- stylua: ignore end
