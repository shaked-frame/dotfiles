-- Run: nvim --headless -u NONE -l scripts/test-terminal-dock.lua
-- Exercise dock ownership with real terminal jobs, file links, and Ctrl-/.
local repo = vim.fn.getcwd()
local root = assert(vim.uv.fs_mkdtemp(vim.fs.joinpath(vim.env.TMPDIR or '/tmp', 'terminal-dock-XXXXXX')))
vim.fn.writefile({ 'first line', 'second line' }, root .. '/example.ts')

local run = function(name, code)
  local child = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', 'NONE', '-n' }, { rpc = true })
  local ok, err = pcall(vim.rpcrequest, child, 'nvim_exec_lua', [[
    local repo, root, code = ...
    Config = {}
    Config.new_autocmd = function(event, pattern, callback, desc)
      vim.api.nvim_create_autocmd(event, { pattern = pattern, callback = callback, desc = desc })
    end
    vim.o.hidden = true
    vim.o.shell = '/bin/cat'
    vim.g.mapleader = ' '
    vim.cmd.cd(root)
    dofile(repo .. '/nvim/.config/nvim/plugin/20_keymaps.lua')
    dofile(repo .. '/nvim/.config/nvim/plugin/23_terminal.lua')
    dofile(repo .. '/nvim/.config/nvim/plugin/23_terminal_links.lua')
    editor = vim.api.nvim_get_current_win()
    count_terminals = function()
      local count = 0
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buftype == 'terminal' then count = count + 1 end
      end
      return count
    end
    assert(loadstring(code))()
  ]], { repo, root, code })
  pcall(vim.fn.jobstop, child)
  assert(ok, name .. ': ' .. tostring(err))
  print(name .. ': OK')
end

local ok, err = xpcall(function()
  run('Space t v reuses the dock; Space t n creates a new terminal tab', [[
    local toggle = assert(vim.fn.maparg(' tv', 'n', false, true).callback)
    toggle()
    local buf = vim.api.nvim_get_current_buf()
    local job = vim.b[buf].terminal_job_id
    vim.api.nvim_set_current_win(editor)
    toggle()
    assert(count_terminals() == 1, 'Space t v created another terminal instead of reusing the dock')
    assert(vim.api.nvim_get_current_buf() == buf, 'Space t v changed the active terminal')
    toggle()
    assert(#vim.api.nvim_tabpage_list_wins(0) == 1, 'Space t v did not hide the dock')
    toggle()
    assert(vim.api.nvim_get_current_buf() == buf, 'Space t v did not reopen the same terminal')
    assert(vim.fn.jobwait({ job }, 0)[1] == -1, 'Space t v stopped the terminal job')
    assert(vim.fn.maparg(' tn', 'n', false, true).callback)()
    assert(count_terminals() == 2, 'Space t n no longer creates a new terminal tab')
    assert(#vim.api.nvim_tabpage_list_wins(0) == 2, 'New terminal tab opened another pane')
  ]])

  run('Dock toggle reuses the same running terminal after opening a file', [[
    Config.Terminal.new()
    local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    local job = vim.b[buf].terminal_job_id
    vim.api.nvim_chan_send(job, 'example.ts:2:1\n')
    assert(vim.wait(1000, function()
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'):find('example.ts', 1, true) ~= nil
    end))
    Config.TerminalLinks.open(win, 1, 3)
    assert(vim.api.nvim_get_current_win() == editor)
    Config.Terminal.toggle() -- Focus the dock from the opened file.
    Config.Terminal.toggle() -- Hide it.
    Config.Terminal.toggle() -- Reopen the same job.
    assert(vim.api.nvim_get_current_buf() == buf, 'Toggle created a different terminal')
    assert(count_terminals() == 1, 'Extra terminal job was created')
    assert(vim.fn.jobwait({ job }, 0)[1] == -1, 'Original job stopped')
    assert(#vim.api.nvim_tabpage_list_wins(0) == 2, 'Dock created an extra pane')
  ]])

  run('Existing terminal belongs to the bottom dock instead of a second pane', [[
    vim.cmd('botright 10split')
    vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    local job = vim.fn.jobstart({ '/bin/cat' }, { term = true })
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_win(editor)
    Config.Terminal.toggle()
    assert(count_terminals() == 1, 'Ctrl-/ created another terminal instead of adopting the existing one')
    assert(vim.api.nvim_get_current_buf() == buf, 'Ctrl-/ did not reuse the existing terminal')
    assert(#vim.api.nvim_tabpage_list_wins(0) == 2, 'Ctrl-/ created a second terminal pane')
    Config.Terminal.hide()
    assert(#vim.api.nvim_tabpage_list_wins(0) == 1, 'Hiding the dock left a terminal pane behind')
    Config.Terminal.toggle()
    assert(vim.api.nvim_get_current_buf() == buf, 'Reopen lost the terminal')
    assert(vim.fn.jobwait({ job }, 0)[1] == -1, 'Adoption stopped the existing job')
  ]])

  run('Several existing terminals become tabs in one bottom pane', [[
    local buffers, jobs = {}, {}
    for i = 1, 2 do
      vim.cmd('vsplit')
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
      jobs[i] = vim.fn.jobstart({ '/bin/cat' }, { term = true })
      buffers[i] = vim.api.nvim_get_current_buf()
      vim.bo[vim.api.nvim_get_current_buf()].bufhidden = 'wipe'
    end
    vim.api.nvim_set_current_win(editor)
    Config.Terminal.toggle()
    assert(count_terminals() == 2, 'Adoption changed the number of terminal jobs')
    assert(#vim.api.nvim_tabpage_list_wins(0) == 2, 'Terminals were not consolidated into one dock')
    local dock = vim.api.nvim_get_current_win()
    assert(vim.fn.winlayout()[1] == 'col', 'Dock is not a bottom pane')
    for i = 1, 2 do
      Config.Terminal.select(i)
      assert(vim.api.nvim_get_current_buf() == buffers[i], 'Dock tab lost its terminal')
      assert(vim.api.nvim_get_current_win() == dock, 'Switching tabs opened a different pane')
      assert(vim.fn.jobwait({ jobs[i] }, 0)[1] == -1, 'Adoption stopped a job')
    end
    Config.Terminal.hide()
    assert(#vim.api.nvim_tabpage_list_wins(0) == 1, 'A terminal pane escaped the dock')
    Config.Terminal.toggle()
    assert(vim.api.nvim_get_current_buf() == buffers[2], 'Toggle forgot the active terminal tab')
  ]])

  run('Replaced dock window is not reused as a terminal pane', [[
    Config.Terminal.new()
    local terminal = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_buf(0, vim.fn.bufadd('example.ts'))
    Config.Terminal.toggle()
    assert(vim.bo.buftype == 'terminal', 'Toggle focused the stale editor window')
    assert(vim.api.nvim_get_current_buf() == terminal, 'Toggle lost the original terminal')
    assert(count_terminals() == 1, 'Toggle spawned another job')
  ]])

  run('Adopting another split preserves its active terminal tab', [[
    Config.Terminal.new()
    vim.cmd('vsplit')
    vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    local job = vim.fn.jobstart({ '/bin/cat' }, { term = true })
    local active = vim.api.nvim_get_current_buf()
    Config.Terminal.toggle()
    Config.Terminal.open()
    assert(vim.api.nvim_get_current_buf() == active, 'Toggle switched to another terminal instead of keeping the active job')
    assert(count_terminals() == 2, 'Adoption restarted or lost a job')
    assert(#vim.api.nvim_tabpage_list_wins(0) == 2, 'Another terminal pane remains outside the dock')
    assert(vim.fn.jobwait({ job }, 0)[1] == -1, 'Adoption stopped the active job')
  ]])

  run('File links keep a lone dock below the new editor', [[
    Config.Terminal.new()
    local dock, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    local job = vim.b[buf].terminal_job_id
    vim.api.nvim_win_close(editor, true)
    vim.api.nvim_chan_send(job, 'example.ts:2:1\n')
    assert(vim.wait(1000, function()
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'):find('example.ts', 1, true) ~= nil
    end))
    Config.TerminalLinks.open(dock, 1, 3)
    local layout = vim.fn.winlayout()
    assert(layout[1] == 'col' and layout[2][2][2] == dock, 'File link moved the dock into a side pane')
    assert(vim.api.nvim_buf_get_name(0):match('/example.ts$'))
    Config.Terminal.toggle()
    Config.Terminal.toggle()
    Config.Terminal.toggle()
    assert(vim.api.nvim_get_current_buf() == buf, 'Toggle lost the lone terminal')
    assert(count_terminals() == 1, 'File link or toggle created another job')
  ]])

  run('Plugin terminals stay outside the shell dock', [[
    local agent = vim.api.nvim_create_buf(false, true)
    vim.cmd('vsplit')
    vim.api.nvim_win_set_buf(0, agent)
    vim.fn.jobstart({ '/bin/cat' }, { term = true })
    vim.bo[agent].filetype = 'sidekick_terminal'
    local agent_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(editor)
    Config.Terminal.toggle()
    assert(vim.api.nvim_get_current_buf() ~= agent, 'Dock adopted the agent terminal')
    Config.Terminal.hide()
    assert(vim.api.nvim_win_is_valid(agent_win), 'Hiding dock closed the agent pane')
    assert(vim.api.nvim_win_get_buf(agent_win) == agent, 'Dock replaced the agent buffer')
  ]])

  run('Closing an adopted terminal removes only its dock tab', [[
    local buffers, jobs = {}, {}
    for i = 1, 2 do
      vim.cmd('split')
      vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
      jobs[i] = vim.fn.jobstart({ '/bin/cat' }, { term = true })
      buffers[i] = vim.api.nvim_get_current_buf()
    end
    vim.api.nvim_set_current_win(editor)
    Config.Terminal.toggle()
    vim.fn.jobstop(jobs[1])
    assert(vim.wait(1000, function() return not vim.api.nvim_buf_is_valid(buffers[1]) end))
    Config.Terminal.select(1)
    assert(vim.api.nvim_get_current_buf() == buffers[2], 'Closed tab left a blank or stale buffer')
    assert(vim.fn.jobwait({ jobs[2] }, 0)[1] == -1, 'Closing one tab stopped the other job')
  ]])

  run('Create a terminal session fixture', [[
    Config.Terminal.new()
    vim.cmd('mksession! dock-session.vim')
  ]])
  run('Session-restored terminal is reused without spawning another job', [[
    vim.cmd('source dock-session.vim')
    local restored
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buftype == 'terminal' then restored = buf break end
    end
    assert(restored, 'Session did not restore its terminal')
    Config.Terminal.toggle()
    assert(count_terminals() == 1, 'Session restore caused a duplicate terminal')
    Config.Terminal.toggle()
    assert(vim.api.nvim_get_current_buf() == restored, 'Toggle failed to restore the original session terminal')
  ]])
end, debug.traceback)

vim.fn.delete(root, 'rf') -- Only this test's fixture directory.
if not ok then error(err) end
print('TERMINAL DOCK OK')
