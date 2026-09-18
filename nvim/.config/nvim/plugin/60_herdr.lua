-- ┌───────────────────────────────────┐
-- │ Herdr: worktrees and agent panes  │
-- └───────────────────────────────────┘
--
-- Herdr (https://herdr.dev) is the terminal workspace manager hosting this
-- Neovim. Its model maps onto Zed's neatly:
--
--   Zed window   ~  Herdr workspace   (often backed by a Git worktree)
--   Zed pane     ~  Herdr pane
--
-- Cross-worktree switching therefore belongs to Herdr, not Neovim: use
-- `prefix+w` (workspace picker), `prefix+shift+o` (open worktree) or
-- `prefix+shift+g` (create worktree). The mappings below exist so the same
-- actions are reachable without leaving Neovim, mirroring the Zed bindings
-- (`space g w` -> git::Worktree, `space a *` -> agent).
--
-- Everything here shells out to the `herdr` CLI, which talks to the running
-- server over a socket. There is no Neovim plugin for Herdr, and no Herdr
-- integration for 'sidekick.nvim' - the CLI *is* the integration surface.
--
-- See also:
-- - `herdr --skill`      - full CLI control guide
-- - `herdr worktree`     - list / create / open / remove
-- - `herdr agent`        - list / prompt / focus / read / send-keys

-- Herdr only injects HERDR_ENV into panes it manages. Anything below is
-- meaningless outside one, and Herdr's own guidance is not to drive the focused
-- session from outside it, so fail loudly rather than silently doing nothing.
local function in_herdr()
  if vim.env.HERDR_ENV == '1' then return true end
  vim.notify('Not inside a Herdr pane (HERDR_ENV is unset)', vim.log.levels.WARN)
  return false
end

--- Run a herdr CLI command and decode its JSON response.
---@param args string[]
---@return table|nil
local function herdr(args)
  local cmd = vim.list_extend({ 'herdr' }, args)
  local out = vim.system(cmd, { text = true }):wait()

  if out.code ~= 0 then
    -- Server errors arrive as JSON on stderr with status 1; syntax errors use 2.
    vim.notify('herdr ' .. table.concat(args, ' ') .. '\n' .. (out.stderr or ''), vim.log.levels.ERROR)
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, out.stdout or '')
  if not ok then return nil end
  return decoded
end

-- Worktrees ==================================================================

-- Pick a Git worktree and open (or focus) it as a Herdr workspace.
-- Mirrors Zed's `space g w`.
--
-- `herdr worktree list` reports `open_workspace_id` for worktrees that already
-- have a workspace, so focus those instead of opening a duplicate.
local function pick_worktree()
  if not in_herdr() then return end

  local res = herdr({ 'worktree', 'list' })
  local worktrees = res and res.result and res.result.worktrees
  if not worktrees or #worktrees == 0 then
    vim.notify('No Git worktrees found', vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, w in ipairs(worktrees) do
    local marker = w.open_workspace_id and '● ' or '○ '
    table.insert(items, {
      text = string.format('%s%-44s %s', marker, w.branch or '(detached)', vim.fn.fnamemodify(w.path, ':~')),
      path = w.path,
      workspace_id = w.open_workspace_id,
    })
  end

  MiniPick.start({
    source = {
      items = items,
      name = 'Herdr worktrees (● open)',
      choose = function(item)
        -- Deferred: MiniPick is still tearing its window down at this point.
        vim.schedule(function()
          if item.workspace_id then
            herdr({ 'workspace', 'focus', item.workspace_id })
          else
            herdr({ 'worktree', 'open', '--path', item.path, '--focus' })
          end
        end)
      end,
    },
  })
end

-- Agents =====================================================================

--- Pick a live Herdr agent, then call `fn(agent)` with its `AgentInfo` table
--- (see `herdr api schema`) — notably `.name` (may be nil) and `.pane_id`
--- (always set, needed for pane-level commands like `pane send-text`).
---@param prompt string
---@param fn fun(agent: table)
local function with_agent(prompt, fn)
  if not in_herdr() then return end

  local res = herdr({ 'agent', 'list' })
  local agents = res and res.result and res.result.agents
  if not agents or #agents == 0 then
    vim.notify('No live Herdr agents. Start one with `herdr agent start`.', vim.log.levels.WARN)
    return
  end

  -- With a single agent there is nothing to choose.
  if #agents == 1 then
    fn(agents[1])
    return
  end

  -- Field names come from Herdr's own `AgentInfo` schema (`herdr api schema`):
  -- the agent kind is `display_agent` / `agent`, NOT `kind`, and the lifecycle
  -- state is `agent_status`. `cwd` is shown because with worktree-backed
  -- workspaces it is what actually distinguishes two agents of the same kind.
  local items = {}
  for _, a in ipairs(agents) do
    table.insert(items, {
      text = string.format(
        '%-18s %-10s %-9s %s',
        a.name or a.pane_id or '?',
        a.display_agent or a.agent or '?',
        a.agent_status or '?',
        a.cwd and vim.fn.fnamemodify(a.cwd, ':~') or ''
      ),
      agent = a,
    })
  end

  MiniPick.start({
    source = {
      items = items,
      name = prompt,
      choose = function(item) vim.schedule(function() fn(item.agent) end) end,
    },
  })
end

--- Type text into a chosen agent's input WITHOUT submitting it, then focus
--- that pane so you can add more and press Enter yourself. Uses the pane-level
--- `send-text` (vs. `agent prompt`, which always appends Enter and submits).
local function attach_to_agent(text, what)
  with_agent('Herdr agents -> ' .. what, function(agent)
    if herdr({ 'pane', 'send-text', agent.pane_id, text }) then
      herdr({ 'agent', 'focus', agent.name or agent.pane_id })
      vim.notify('Attached ' .. what .. ' to ' .. (agent.name or agent.pane_id) .. ' (not sent)')
    end
  end)
end

--- Send text to a chosen agent and submit it immediately. Not `--wait`:
--- Neovim should not block.
local function send_to_agent(text, what)
  with_agent('Herdr agents -> ' .. what, function(agent)
    local target = agent.name or agent.pane_id
    if herdr({ 'agent', 'prompt', target, text }) then
      vim.notify('Sent ' .. what .. ' to ' .. target)
    end
  end)
end

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

-- Context message builders, shared between the "attach" (no submit) and
-- "send" (submit) mapping of each kind below. Return `nil` when there is
-- nothing sensible to attach/send (e.g. an unnamed buffer for `af`/`aF`, or
-- an empty Visual selection for `av`/`aV`).
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

-- Mappings ===================================================================

-- stylua: ignore start
vim.keymap.set('n', '<Leader>gw', pick_worktree, { desc = 'Worktrees (Herdr)' })

vim.keymap.set('n', '<Leader>aa', function()
  with_agent('Herdr agents -> focus', function(agent) herdr({ 'agent', 'focus', agent.name or agent.pane_id }) end)
end, { desc = 'Focus agent' })

-- Lowercase attaches context to the agent's input WITHOUT submitting it (and
-- focuses that pane so you can add more and press Enter yourself). Uppercase
-- keeps the old behavior of sending it immediately. See `attach_to_agent()`
-- and `send_to_agent()` above.
vim.keymap.set('n', '<Leader>af', function()
  local m = file_message(); if m then attach_to_agent(m, 'file') end
end, { desc = 'Attach file to agent' })
vim.keymap.set('n', '<Leader>aF', function()
  local m = file_message(); if m then send_to_agent(m, 'file') end
end, { desc = 'Send file to agent' })

vim.keymap.set('n', '<Leader>at', function() attach_to_agent(location_message(), 'location') end, { desc = 'Attach location to agent' })
vim.keymap.set('n', '<Leader>aT', function() send_to_agent(location_message(), 'location') end,   { desc = 'Send location to agent' })

vim.keymap.set('x', '<Leader>av', function()
  local m = selection_message(); if m then attach_to_agent(m, 'selection') end
end, { desc = 'Attach selection to agent' })
vim.keymap.set('x', '<Leader>aV', function()
  local m = selection_message(); if m then send_to_agent(m, 'selection') end
end, { desc = 'Send selection to agent' })

vim.keymap.set('n', '<Leader>ap', function()
  vim.ui.input({ prompt = 'Prompt agent: ' }, function(text)
    if text and text ~= '' then send_to_agent(text, 'prompt') end
  end)
end, { desc = 'Prompt agent' })
-- stylua: ignore end
