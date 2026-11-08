-- Run: nvim --headless -u NONE -l scripts/test-native-messages.lua
-- Canned CLI failures must reach native history without notification popups.
local plugin = vim.fn.getcwd() .. '/home/dot_config/nvim/plugin/'
vim.opt.rtp:prepend(vim.fn.getcwd() .. '/home/dot_config/nvim')
local host = require('config.host')
local original_system, original_notify = vim.system, vim.notify
local original_echo, original_select = vim.api.nvim_echo, vim.ui.select
local original_herdr, original_rex = vim.env.HERDR_ENV, vim.env.REX_BLOCK
local notifications, echoes = {}, {}

Config = {
  later = function() end,
  new_autocmd = function() end,
}
vim.g.mapleader = ' '
vim.notify = function(message, level)
  table.insert(notifications, { message = message, level = level })
end
vim.api.nvim_echo = function(chunks, history, opts)
  table.insert(echoes, { history = history, opts = opts })
  return original_echo(chunks, history, opts)
end

local invoke = function(lhs)
  local mapping = vim.fn.maparg(lhs, 'n', false, true)
  assert(type(mapping.callback) == 'function', 'Missing callback for ' .. lhs)
  mapping.callback()
end

local check_error = function(text)
  local output = vim.api.nvim_exec2('messages', { output = true }).output
  assert(output:find(text, 1, true), 'Native history lost: ' .. text)
  assert(echoes[#echoes].history == true, 'Error was not recorded in history')
  assert(echoes[#echoes].opts.err == true, 'Message was not marked as an error')
  for _, notification in ipairs(notifications) do
    assert(notification.level ~= vim.log.levels.ERROR, 'CLI error became a notification')
  end
end

local ok, err = xpcall(function()
  -- `<Leader>gw` is only mapped inside a host; which one is decided per press.
  vim.env.HERDR_ENV, vim.env.REX_BLOCK = '1', ''
  dofile(plugin .. '20_keymaps.lua')
  assert(vim.fn.maparg(' eM', 'n') == '<Cmd>messages<CR>', 'Missing native Messages binding')
  assert(vim.fn.maparg(' en', 'n') == '<Cmd>lua MiniNotify.show_history()<CR>', 'Mini history binding changed')

  host.runner = function()
    return { code = 1, stderr = 'Herdr failed\nFull details', stdout = '' }
  end
  invoke(' gw')
  check_error('Herdr failed\nFull details')

  vim.env.HERDR_ENV, vim.env.REX_BLOCK = '0', 'block:test'
  host.runner = function()
    return { code = 1, stderr = 'Rex listing failed\nFull details', stdout = '' }
  end
  invoke(' gw')
  check_error('Rex listing failed\nFull details')

  local picker
  vim.ui.select = function(items, _, choose) picker = { items = items, choose = choose } end
  host.runner = function(cmd)
    if cmd[3] == 'worktrees' then
      return { code = 0, stderr = '', stdout = '{"worktrees":[{"path":"/test","branch":"main"}]}' }
    end
    return { code = 1, stderr = 'Rex opening failed\nFull details', stdout = '' }
  end
  invoke(' gw')
  local count = #echoes
  picker.choose(picker.items[1])
  assert(vim.wait(500, function() return #echoes > count end), 'Worktree opening callback did not run')
  check_error('Rex opening failed\nFull details')

  vim.system = function(_, _, callback)
    callback({ code = 1, stderr = 'GitHub failed\nFull details', stdout = '' })
    return {}
  end
  dofile(plugin .. '43_octo.lua')
  count = #echoes
  invoke(' gpq')
  assert(vim.wait(500, function() return #echoes > count end), 'GitHub callback did not run')
  check_error('gh: GitHub failed\nFull details')

  -- Empty results remain short warning notifications, not native errors.
  count = #echoes
  host.runner = function() return { code = 0, stderr = '', stdout = '{"worktrees":[]}' } end
  invoke(' gw')
  assert(#echoes == count, 'Empty worktree result became a native error')
  local notification = notifications[#notifications]
  assert(notification.message == 'No Git worktrees found' and notification.level == vim.log.levels.WARN)
end, debug.traceback)

vim.system, vim.notify, vim.api.nvim_echo = original_system, original_notify, original_echo
vim.ui.select = original_select
vim.env.HERDR_ENV, vim.env.REX_BLOCK = original_herdr, original_rex
if not ok then error(err) end
print('NATIVE MESSAGES OK')
