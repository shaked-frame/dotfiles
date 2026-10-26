-- Run: nvim --headless -u NONE -l scripts/test-terminal-links.lua
-- Isolated child Neovim with a real terminal job and synthetic mouse input.
local repo = vim.fn.getcwd()
local root = assert(vim.uv.fs_mkdtemp(vim.fs.joinpath(vim.env.TMPDIR or '/tmp', 'terminal-links-XXXXXX')))
local child = vim.fn.jobstart({ vim.v.progpath, '--embed', '--headless', '-u', 'NONE', '-n' }, { rpc = true })
local exec = function(code, ...) return vim.rpcrequest(child, 'nvim_exec_lua', code, { ... }) end
local wait = function(code, message)
  local ready = vim.wait(3000, function() return exec(code) end, 10)
  assert(ready, message .. ': ' .. exec("return vim.inspect({ win = vim.api.nvim_get_current_win(), mode = vim.api.nvim_get_mode().mode, name = vim.api.nvim_buf_get_name(0) })"))
end

local ok, err = xpcall(function()
  vim.fn.mkdir(root .. '/.git', 'p')
  for _, path in ipairs({
    'frontend/apps/web/src/screen.tsx',
    'frontend/apps/web/src/shared.tsx',
    'frontend/packages/ui/src/shared.tsx',
    'frontend/packages/ui/src/unique.tsx',
    'frontend/apps/web/src/(group)/[id].tsx',
  }) do
    vim.fn.mkdir(vim.fs.dirname(root .. '/' .. path), 'p')
    vim.fn.writefile(vim.fn['repeat']({ 'const example = true;' }, 10), root .. '/' .. path)
  end
  vim.rpcrequest(child, 'nvim_ui_attach', 120, 40, { rgb = true })
  exec([[
    local repo, root = ...
    Config = {}
    vim.o.mouse = 'a'
    vim.o.mousetime = 0
    vim.o.hidden = true
    vim.g.mapleader = ' '
    dofile(repo .. '/nvim/.config/nvim/plugin/20_keymaps.lua')
    dofile(repo .. '/nvim/.config/nvim/plugin/23_terminal_links.lua')
    vim.cmd.cd(root .. '/frontend/apps/web')
    editor = vim.api.nvim_get_current_win()
    vim.cmd('botright 12split')
    terminal = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    job = vim.fn.jobstart({ '/bin/cat' }, { term = true })
    term_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_chan_send(job, 'web:check-types: src/screen.tsx(3,5): error TS2322\n')
  ]], repo, root)
  wait("return table.concat(vim.api.nvim_buf_get_lines(term_buf, 0, -1, false), '\\n'):find('TS2322', 1, true) ~= nil", 'Terminal output missing')

  exec([[
    local parse = Config.TerminalLinks.location
    for _, case in ipairs({
      { 'src/foo.ts:12:4: error', 'src/foo.ts', 12, 4 },
      { 'web:check-types: src/foo.ts(12, 4): error', 'src/foo.ts', 12, 4 },
      { 'at f (/tmp/file.ts:5:2)', '/tmp/file.ts', 5, 2 },
      { 'src/(group)/[id].tsx:7:3', 'src/(group)/[id].tsx', 7, 3 },
      { './foo.ts:8', './foo.ts', 8, 1 },
      { 'open src/foo.ts', 'src/foo.ts', 1, 1 },
    }) do
      local first = assert(case[1]:find(case[2], 1, true))
      local loc = assert(parse(case[1], first + 2), case[1])
      assert(loc.path == case[2] and loc.line == case[3] and loc.col == case[4], vim.inspect(loc))
    end
    local text = 'src/one.ts:2:3 src/two.ts:4:5'
    assert(parse(text, 20).path == 'src/two.ts')
    assert(parse('error: cannot assign value', 20) == nil)
    assert(parse('src/foo.ts:12:4: error', 20) == nil)
  ]])
  print('Diagnostic formats, bracketed routes, clicked token: OK')

  -- Ctrl-click must work even while an editor, not the terminal, has focus.
  local click = function(modifiers)
    local pos = exec([[
      local row
      for i, text in ipairs(vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)) do
        if text:find('TS2322', 1, true) then row = i break end
      end
      vim.api.nvim_win_set_cursor(terminal, { row, 20 })
      vim.cmd('redraw')
      local pos = vim.fn.screenpos(terminal, row, 21)
      return { pos.row - 1, pos.col - 1 }
    ]])
    vim.rpcrequest(child, 'nvim_input_mouse', 'left', 'press', modifiers, 0, pos[1], pos[2])
    vim.rpcrequest(child, 'nvim_input_mouse', 'left', 'release', modifiers, 0, pos[1], pos[2])
  end
  exec('vim.api.nvim_set_current_win(editor)')
  click('C')
  wait("return vim.api.nvim_buf_get_name(0):match('/src/screen.tsx$') ~= nil", 'Ctrl-click did not open the file')
  exec([[
    assert(vim.api.nvim_get_current_win() == editor, 'Expected editor window')
    assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 3, 4 }), 'Cursor: ' .. vim.inspect(vim.api.nvim_win_get_cursor(0)))
    assert(vim.api.nvim_win_get_buf(terminal) == term_buf, 'Terminal was replaced')
    assert(vim.fn.jobwait({ job }, 0)[1] == -1, 'Terminal job stopped')
  ]])
  print('Real Ctrl-click from editor, exact line/column, terminal preserved: OK')

  exec("vim.api.nvim_set_current_win(terminal); vim.cmd('startinsert')")
  wait("return vim.api.nvim_get_mode().mode == 't'", 'Terminal mode did not start')
  click('C')
  wait("return vim.api.nvim_get_current_win() == editor and vim.api.nvim_get_mode().mode == 'n'", 'Ctrl-click from Terminal mode failed')
  print('Real Ctrl-click from Terminal mode: OK')

  -- Double-click is a plain-mouse alternative when the host captures Cmd-click.
  exec("vim.o.mousetime = 1; vim.api.nvim_set_current_win(terminal)")
  vim.wait(10, function() return false end)
  click('')
  exec('vim.o.mousetime = 500')
  click('')
  wait("return vim.api.nvim_get_current_win() == editor", 'Double-click did not open the file')
  print('Real double-click: OK')

  exec([[
    vim.api.nvim_set_current_win(terminal)
    for row, text in ipairs(vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)) do
      if text:find('TS2322', 1, true) then vim.api.nvim_win_set_cursor(0, { row, 20 }) break end
    end
  ]])
  vim.rpcrequest(child, 'nvim_input', 'gf')
  wait("return vim.api.nvim_get_current_win() == editor", 'Terminal gf did not open the file')
  print('Keyboard gf fallback: OK')

  -- OSC 7 changes relative-path resolution without changing editor cwd.
  exec([[
    local root = ...
    vim.api.nvim_chan_send(job, '\27]7;file://' .. root .. '/frontend\27\\\n')
  ]], root)
  wait("return vim.b[term_buf].terminal_link_cwd:match('/frontend$') ~= nil", 'Real OSC 7 directory update missing')
  exec([[
    local root = ...
    assert(vim.fn.getcwd() == root .. '/frontend/apps/web')
    vim.api.nvim_chan_send(job, 'src/unique.tsx:4:2\n')
  ]], root)
  wait("return table.concat(vim.api.nvim_buf_get_lines(term_buf, 0, -1, false), '\\n'):find('unique.tsx', 1, true) ~= nil", 'Workspace diagnostic missing')
  exec([[
    for row, text in ipairs(vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)) do
      if text:find('unique.tsx', 1, true) then Config.TerminalLinks.open(terminal, row, 3) break end
    end
  ]])
  wait("return vim.api.nvim_buf_get_name(0):match('/packages/ui/src/unique.tsx$') ~= nil", 'Package-relative path resolution failed')
  print('OSC 7 directory tracking, asynchronous workspace path resolution: OK')

  exec([[
    vim.ui.select = function(items, _, callback)
      assert(#items == 2)
      selected = true
      callback(nil)
    end
    vim.api.nvim_chan_send(job, 'src/shared.tsx:2:1\n')
  ]])
  wait("return table.concat(vim.api.nvim_buf_get_lines(term_buf, 0, -1, false), '\\n'):find('shared.tsx', 1, true) ~= nil", 'Ambiguous diagnostic missing')
  exec([[
    for row, text in ipairs(vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)) do
      if text:find('shared.tsx', 1, true) then Config.TerminalLinks.open(terminal, row, 3) break end
    end
  ]])
  wait('return selected == true', 'Ambiguous paths should prompt rather than guess')
  print('Ambiguous workspace paths prompt instead of opening the wrong file: OK')

  exec([[
    -- With only a terminal left, opening creates an editor instead of replacing it.
    vim.api.nvim_win_close(editor, true)
    vim.b[term_buf].terminal_link_cwd = ...
    for row, text in ipairs(vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)) do
      if text:find('TS2322', 1, true) then Config.TerminalLinks.open(terminal, row, 20) break end
    end
    assert(#vim.api.nvim_tabpage_list_wins(0) == 2)
    assert(vim.api.nvim_win_get_buf(terminal) == term_buf)
    assert(vim.api.nvim_buf_get_name(0):match('/src/screen.tsx$'))
    assert(vim.fn.jobwait({ job }, 0)[1] == -1)
  ]], root .. '/frontend/apps/web')
  print('Lone terminal gets a new editor split: OK')
end, debug.traceback)

pcall(vim.fn.jobstop, child)
vim.fn.delete(root, 'rf') -- Only this test's newly-created fixture directory.
if not ok then error(err) end
print('TERMINAL LINKS OK')
