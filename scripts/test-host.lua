-- Run: nvim --headless -u NONE -l scripts/test-host.lua
-- Exercise the host module ('lua/config/host.lua') and its callers without a
-- Rex or Herdr server: `host.runner` is swapped for a recorder that returns
-- canned results, so both adapters are driven through the same seam.
local repo = vim.fn.getcwd()
local BLOCK = 'block:test-nvim'
local AGENT = 'block:test-agent'

local run = function(name, env, code)
  local child = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', 'NONE', '-n' }, { rpc = true })
  local ok, err = pcall(vim.rpcrequest, child, 'nvim_exec_lua', [=[
    local repo, env, code, agent = ...
    AGENT = agent -- global: the test bodies below read it
    for _, k in ipairs({ 'REX_BLOCK', 'REX_BIN_DIR', 'HERDR_ENV', 'HERDR_PANE_ID', 'HERDR_WORKSPACE_ID', 'HERDR_BIN_PATH' }) do
      vim.env[k] = env[k]
    end
    vim.opt.rtp:prepend(repo .. '/nvim/.config/nvim')
    Config = {}
    vim.g.mapleader = ' '
    dofile(repo .. '/nvim/.config/nvim/plugin/22_splits.lua')
    dofile(repo .. '/nvim/.config/nvim/plugin/44_agent.lua')
    host = require('config.host')

    -- Recorder: every CLI call lands in `calls` (binary in `bin`, the rest in
    -- `argv`). `reply(argv)` answers waited calls (default: empty success).
    calls, replies = {}, {}
    host.runner = function(cmd, opts)
      table.insert(calls, { bin = cmd[1], argv = vim.list_slice(cmd, 2), wait = opts and opts.wait or false })
      if opts and opts.wait then
        local key = cmd[2] == 'do' and cmd[3] or (cmd[2] .. ' ' .. cmd[3])
        return replies[key] or { code = 0, stdout = '', stderr = '' }
      end
    end
    replies.list_agents = {
      code = 0, stderr = '',
      stdout = vim.json.encode({ agents = { { block_id = AGENT, program = 'claude', here = true } } }),
    }
    argv_of = function(i) return table.concat(calls[i].argv, ' ') end
    messages = function() return vim.api.nvim_exec2('messages', { output = true }).output end
    assert(loadstring(code))()
  ]=], { repo, env, code, AGENT })
  pcall(vim.fn.jobstop, child)
  assert(ok, name .. ': ' .. tostring(err))
  print(name .. ': OK')
end

local IN_REX = { REX_BLOCK = BLOCK }
local NESTED = { REX_BLOCK = BLOCK, HERDR_ENV = '1', HERDR_PANE_ID = 'p-nvim' }
local IN_HERDR = { HERDR_ENV = '1', HERDR_PANE_ID = 'p-nvim', HERDR_WORKSPACE_ID = 'ws1', HERDR_BIN_PATH = '/opt/herdr' }
local OUTSIDE = {}

local herdr_agents = vim.json.encode({ result = { agents = {
  { pane_id = 'p-claude', name = 'claude-1', agent = 'claude', workspace_id = 'ws1', agent_status = 'idle' },
  { pane_id = 'p-chat', agent = 'opencode', workspace_id = 'ws1' },
  { pane_id = 'p-other', name = 'elsewhere', agent = 'codex', workspace_id = 'ws2' },
} } })

local ok, err = xpcall(function()
  run('kind(): Rex in a Rex pane, Herdr wins when nested, nil outside', OUTSIDE, [[
    assert(host.kind() == nil, 'host outside Rex and Herdr')
    vim.env.REX_BLOCK = 'block:x'
    assert(host.kind() == 'rex', 'not Rex in a Rex pane')
    vim.env.HERDR_ENV = '1'
    assert(host.kind() == 'herdr', 'Rex although Herdr is nested inside it')
    assert(Config.Agent.active_adapter() == host.agent, 'dispatcher ignores Herdr')
    vim.env.HERDR_ENV, vim.env.REX_BLOCK, vim.env.HERDR_PANE_ID = nil, nil, 'p1'
    assert(host.kind() == 'herdr', 'a Herdr pane without HERDR_ENV is not Herdr')
    vim.env.REX_BLOCK = 'block:x'
    assert(host.kind() == 'rex', 'an inherited HERDR_PANE_ID beat REX_BLOCK')
  ]])

  run('Outside a host the split edge and resize do nothing', OUTSIDE, [[
    Config.Splits.navigate('l')
    Config.Splits.resize('l')
    assert(#calls == 0, 'CLI called outside a host')
  ]])

  run('Rex worktrees: `rex do` on this pane with sorted args, picked and opened', IN_REX, [[
    replies.worktrees = { code = 0, stderr = '', stdout = vim.json.encode({ worktrees = {
      { path = '/r', branch = 'main', session_id = 's1', label = 'renamed' },
      { path = '/r/.worktrees/det', detached = true },
    } }) }
    local shown
    vim.ui.select = function(items, opts, choose)
      shown = vim.tbl_map(opts.format_item, items)
      choose(items[2])
    end
    host.pick_worktree()
    assert(argv_of(1) == 'do worktrees -b block:test-nvim --json cwd=' .. vim.fn.getcwd(), argv_of(1))
    assert(calls[1].bin == 'rex' and calls[1].wait, 'not a waited rex call')
    assert(shown[1]:match('^● main') and shown[1]:match('%[renamed%]$'), shown[1])
    assert(shown[2]:match('^○ %(detached%) det '), shown[2])
    vim.wait(200, function() return #calls == 2 end)
    assert(argv_of(2) == 'do worktree_open -b block:test-nvim --json path=/r/.worktrees/det', argv_of(2))
  ]])

  run('A failed `rex do` lands in :messages as an error, never raises', IN_REX, [[
    replies.worktrees = { code = 1, stdout = '', stderr = 'Error: boom\n' }
    host.pick_worktree()
    assert(messages():find('Error: boom', 1, true), 'error lost: ' .. messages())
  ]])

  run('Unreadable or silent `rex do` failures still explain themselves', IN_REX, [[
    replies.worktrees = { code = 0, stderr = '', stdout = 'plain text from an old Rex config' }
    host.pick_worktree()
    assert(messages():find('unreadable result from `rex do worktrees`', 1, true), 'plain text read as no worktrees: ' .. messages())
    replies.worktrees = { code = 2, stderr = '', stdout = '' }
    host.pick_worktree()
    assert(messages():find('`rex do worktrees` failed (exit 2)', 1, true), 'blank error: ' .. messages())
  ]])

  run('ctrl+l at the right edge hands focus to the Rex pane', IN_REX, [[
    Config.Splits.navigate('l')
    assert(#calls == 1 and argv_of(1) == 'focus right', #calls > 0 and argv_of(1) or 'no rex call')
  ]])

  run('Nested in Herdr, the split edge focuses the Herdr pane, not Rex', NESTED, [[
    Config.Splits.navigate('l')
    assert(#calls == 1 and calls[1].bin == 'herdr', 'expected one herdr call')
    assert(argv_of(1) == 'pane focus --direction right --pane p-nvim', argv_of(1))
  ]])

  run('Hyper+9 with no nvim split resizes the Rex pane, rex=true', IN_REX, [[
    Config.Splits.resize('l')
    assert(argv_of(1) == 'do resize -b block:test-nvim --json direction=right rex=true', argv_of(1))
  ]])

  run('Hyper+9 with an nvim split resizes nvim, not Rex', IN_REX, [[
    vim.cmd('vsplit')
    local before = vim.fn.winwidth(0)
    Config.Splits.resize('l')
    assert(#calls == 0, 'Rex called although nvim had a split')
    assert(vim.fn.winwidth(0) ~= before, 'nvim window did not resize')
  ]])

  run('Rex send: bracketed paste into the agent pane, then Enter', IN_REX, [[
    Config.Agent.send('hello\nworld', 'test')
    vim.wait(400, function() return #calls >= 3 end)
    assert(argv_of(1):match('^do list_agents '), 'agents not listed first: ' .. argv_of(1))
    assert(table.concat(calls[2].argv, '|') == 'send|-b|' .. AGENT .. '|\27[200~hello\nworld\27[201~', 'paste: ' .. argv_of(2))
    assert(argv_of(3) == 'send-key -b ' .. AGENT .. ' enter', 'no Enter after send: ' .. tostring(calls[3] and argv_of(3)))
  ]])

  run('Rex attach: paste without Enter, then focus the agent', IN_REX, [[
    Config.Agent.attach('staged', 'test')
    vim.wait(400)
    local argvs = vim.tbl_map(function(c) return table.concat(c.argv, ' ') end, calls)
    assert(#argvs == 3, 'expected list, paste, focus; got ' .. table.concat(argvs, ' / '))
    assert(argvs[3] == 'focus ' .. AGENT, 'agent not focused: ' .. argvs[3])
    for _, a in ipairs(argvs) do assert(not a:match('^send%-key'), 'attach pressed Enter') end
  ]])

  run('No Rex agent pane: dispatcher falls back to sidekick', IN_REX, [[
    replies.list_agents = { code = 0, stderr = '', stdout = '{"agents":{}}' }
    local fallback = { visible = function() return false end, focus = function() end, attach = function() end, send = function() end }
    Config.Agent.register('sidekick', fallback)
    assert(Config.Agent.active_adapter() == fallback, 'did not fall back to sidekick')
  ]])

  run('An open sidekick chat wins over a Rex agent pane', IN_REX, [[
    local chat = { visible = function() return true end }
    Config.Agent.register('sidekick', chat)
    assert(Config.Agent.active_adapter() == chat, 'Rex pane won over the open chat')
  ]])

  run('Herdr send: `agent prompt` to the only agent in this workspace', IN_HERDR, string.format([[
    replies['agent list'] = { code = 0, stderr = '', stdout = %q }
    Config.Agent.send('look here', 'file')
    assert(calls[1].bin == '/opt/herdr', 'HERDR_BIN_PATH ignored: ' .. calls[1].bin)
    assert(argv_of(2) == 'agent prompt claude-1 look here', argv_of(2))
  ]], herdr_agents))

  run('Herdr attach: send-text to the pane, then focus the agent', IN_HERDR, string.format([[
    replies['agent list'] = { code = 0, stderr = '', stdout = %q }
    Config.Agent.attach('staged', 'file')
    assert(argv_of(2) == 'pane send-text p-claude staged', argv_of(2))
    assert(argv_of(3) == 'agent focus claude-1', argv_of(3))
  ]], herdr_agents))

  run('Several agents: one picker line format for both hosts', IN_HERDR, string.format([[
    local agents = vim.json.decode(%q)
    table.insert(agents.result.agents, { pane_id = 'p-codex', agent = 'codex', workspace_id = 'ws1', cwd = '/w/feat' })
    replies['agent list'] = { code = 0, stderr = '', stdout = vim.json.encode(agents) }
    local lines
    vim.ui.select = function(items, opts) lines = vim.tbl_map(opts.format_item, items) end
    Config.Agent.focus()
    assert(lines[1]:match('^claude%%-1%%s+claude%%s+idle'), lines[1])
    assert(lines[2]:match('^p%%-codex%%s+codex%%s+/w/feat$'), lines[2])
  ]], herdr_agents))

  run('Herdr: a failed send-text does not focus, and lands in :messages', IN_HERDR, string.format([[
    replies['agent list'] = { code = 0, stderr = '', stdout = %q }
    replies['pane send-text'] = { code = 1, stdout = '', stderr = 'pane gone' }
    Config.Agent.attach('staged', 'file')
    assert(#calls == 2, 'focused after a failed paste')
    assert(messages():find('pane gone', 1, true), 'error lost: ' .. messages())
  ]], herdr_agents))

  run('Herdr worktrees: open ones focus their workspace, others open', IN_HERDR, [[
    replies['worktree list'] = { code = 0, stderr = '', stdout = vim.json.encode({ result = { worktrees = {
      { path = '/w/main', branch = 'main', open_workspace_id = 'ws1' },
      { path = '/w/feat', branch = 'feat', open_workspace_id = vim.NIL },
    } } }) }
    local picked = {}
    vim.ui.select = function(items, opts, choose)
      picked = vim.tbl_map(opts.format_item, items)
      choose(items[1])
      choose(items[2])
    end
    host.pick_worktree()
    vim.wait(200, function() return #calls == 3 end)
    assert(picked[1]:match('^● main') and picked[2]:match('^○ feat'), table.concat(picked, ' / '))
    assert(argv_of(2) == 'workspace focus ws1', argv_of(2))
    assert(argv_of(3) == 'worktree open --path /w/feat --focus', argv_of(3))
  ]])
end, debug.traceback)

if not ok then error(err) end
print('HOST OK')
