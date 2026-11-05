-- Run with the full config:
-- nvim --headless -n -i NONE -c "lua dofile('scripts/test-insert-accept.lua')"
-- Insert-mode accept keys ('lua/config/completion.lua')
-- and sidekick's ownership of agent terminals, after deferred startup.
local get, pumvisible, complete_info = vim.lsp.inline_completion.get, vim.fn.pumvisible, vim.fn.complete_info
local ok, err = xpcall(function()
  assert(vim.wait(5000, function() return Config.later_pending == 0 end), 'Deferred config did not finish')

  -- Stubbed state: ghost text shown or not, popup menu visible / selected.
  local ghost, pum, selected, accepted = false, false, -1, nil
  vim.lsp.inline_completion.get = function(opts)
    if not ghost then return false end
    accepted = opts or {}
    return true
  end
  vim.fn.pumvisible = function() return pum and 1 or 0 end
  vim.fn.complete_info = function() return { selected = selected } end
  local press = function(lhs)
    local map = vim.fn.maparg(lhs, 'i', false, true)
    assert(map.buffer == 0, lhs .. ' must be global so snippet sessions can take it over')
    return map.callback()
  end

  assert(press('<Tab>') == '<Tab>', 'Tab without menu or ghost text must insert a tab')
  selected = 0
  assert(press('<Tab>') == '<Tab>', 'a stale selection without a visible menu must not cycle')
  selected = -1
  vim.lsp.inline_completion.get = function() error('server gone') end
  assert(press('<Tab>') == '<Tab>', 'a failing inline completion must not break Tab')
  vim.lsp.inline_completion.get = function(opts)
    if not ghost then return false end
    accepted = opts or {}
    return true
  end
  pum = true
  assert(press('<Tab>') == '<C-n>', 'Tab with a menu must select its first item')
  ghost = true
  assert(press('<Tab>') == '<C-e>' and accepted.on_accept == nil, 'Tab must accept ghost text and close an unselected menu')
  selected = 0
  assert(press('<Tab>') == '<C-n>', 'Tab must keep cycling a menu the user already selected in')
  pum, selected = false, -1
  assert(press('<Tab>') == '' and accepted, 'Tab must accept ghost text')
  print('Tab: selected menu > ghost text > menu > literal: OK')

  accepted = nil
  assert(press('<M-Tab>') == '' and accepted.on_accept, 'Option+Tab must accept one word')
  local word = accepted.on_accept({ insert_text = 'local value = 1', _index = 1 })
  assert(word.insert_text == 'local ', 'one word per press, got ' .. vim.inspect(word.insert_text))
  ghost = false
  assert(press('<C-l>'):upper() == '<C-L>', 'C-l without ghost text falls back to itself')
  print('Word accept on Option+Tab and C-l: OK')

  local session = MiniSnippets.session.get
  MiniSnippets.session.get = function() return {} end
  ghost = true
  local keys = press('<C-l>')
  MiniSnippets.session.get = session
  assert(keys:find('MiniSnippets.session.jump', 1, true), 'C-l must jump snippet tabstops during a session: ' .. keys)
  print('C-l jumps to the next snippet tabstop during a session: OK')

  -- mini.completion drops edits and commands for a client that already stopped.
  require('mini.completion')
  local H
  for i = 1, 20 do
    local name, value = debug.getupvalue(MiniCompletion.completefunc_lsp, i)
    if name == 'H' then H = value break end
  end
  assert(H, 'mini.completion internals moved: update lua/config/completion.lua')
  local edit = { range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } }, newText = 'x' }
  assert(pcall(H.apply_text_edits, 99999, { edit }), 'edit for a stopped client raised')
  assert(pcall(H.exec_command, 99999, { command = 'noop', title = 'noop' }), 'command for a stopped client raised')
  print('mini.completion ignores stopped LSP clients: OK')

  -- Sidekick claims every tool it knows (built-ins too), so the terminal dock
  -- never adopts a restored chat.
  local term = require('config.term')
  vim.cmd('split')
  vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
  vim.fn.jobstart({ '/bin/cat' }, { term = true })
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, 'term://' .. vim.fn.getcwd() .. '//1:gemini')
  assert(term.claimed(buf), 'built-in sidekick tool (gemini) not claimed')
  assert(vim.fn.maparg('<Tab>', 'n', false, true).desc == 'Goto/Apply Next Edit Suggestion', 'NES Tab lost')
  print('Sidekick claims its tools and owns Normal-mode Tab: OK')

  local skconfig = require('sidekick.config')
  assert(type(skconfig.cli.context.symbol) == 'function', 'sidekick {symbol} context missing')
  assert(skconfig.cli.prompts.symbol == '{symbol}', 'sidekick symbol prompt missing')
  assert(require('sidekick.cli.context').get():render({ msg = 'x {symbol}', this = false }) == nil,
    '{symbol} without a language server must drop the message')
  print('Sidekick renders {symbol} through config.symbol: OK')

  -- An accepted next edit suggestion is reverted when it breaks the syntax,
  -- and formatted (in the same undo step) when it does not. A stand-in for
  -- sidekick's apply makes the edit, then fires its real `SidekickNesDone`.
  local sidekick = require('sidekick')
  local jump_or_apply = sidekick.nes_jump_or_apply
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  vim.cmd('silent only | edit ' .. vim.fn.fnameescape(dir .. '/nes.lua'))
  local nes_buf = vim.api.nvim_get_current_buf()
  local original = { 'if true then', '  print(1)', 'end' }
  local done
  local suggest = function(lines)
    done = false
    sidekick.nes_jump_or_apply = function()
      vim.schedule(function()
        vim.cmd('let &undolevels = &undolevels') -- the edit is its own undo step
        vim.api.nvim_buf_set_lines(nes_buf, 0, -1, false, lines)
        vim.schedule(function()
          vim.api.nvim_exec_autocmds('User', { pattern = 'SidekickNesDone', data = { buffer = nes_buf } })
          done = true
        end)
      end)
      return true
    end
    vim.fn.maparg('<Tab>', 'n', false, true).callback()
    assert(vim.wait(2000, function() return done end), 'suggestion was not applied')
  end
  local reset = function()
    vim.api.nvim_buf_set_lines(nes_buf, 0, -1, false, original)
    vim.cmd('let &undolevels = &undolevels')
  end
  local text = function() return table.concat(vim.api.nvim_buf_get_lines(nes_buf, 0, -1, false), '\n') end

  local notify, notified = vim.notify, ''
  vim.notify = function(msg, ...) notified = notified .. msg .. '\n'; return notify(msg, ...) end
  reset()
  suggest({ 'if true then', '  print(1', 'end' })
  assert(text() == table.concat(original, '\n'), 'broken suggestion kept:\n' .. text())
  vim.notify = notify
  assert(notified:find('Reverted the next edit suggestion', 1, true), 'revert not announced: ' .. notified)
  print('A suggestion that breaks the syntax is reverted: OK')

  reset()
  suggest({ 'if true then', 'print(2)', 'end' })
  assert(vim.wait(5000, function() return vim.api.nvim_buf_get_lines(nes_buf, 1, 2, false)[1]:match('^%s+print%(2%)$') end),
    'suggestion not formatted:\n' .. text())
  vim.cmd('silent undo')
  assert(text() == table.concat(original, '\n'), 'one undo should revert suggestion and formatting:\n' .. text())
  print('An accepted suggestion is formatted in the same undo step: OK')

  sidekick.nes_jump_or_apply = jump_or_apply
  vim.cmd('bwipeout!')
  vim.fn.delete(dir, 'rf')
end, debug.traceback)

vim.lsp.inline_completion.get, vim.fn.pumvisible, vim.fn.complete_info = get, pumvisible, complete_info
if not ok then
  io.stderr:write(err .. '\n')
  vim.cmd('cquit 1')
end
print('INSERT ACCEPT OK')
vim.cmd('qa!')
