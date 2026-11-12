-- Run: nvim --headless -n -i NONE -c "lua dofile('scripts/test-snacks-pickers.lua')"
local picker, select_provider, client_lookup, list_paths, original_cmd, gd_opts
local call_opts_of = function() return vim.deepcopy(gd_opts) end
local directory
local ok, err = xpcall(function()
  assert(vim.wait(5000, function() return Config.later_pending == 0 end), 'Startup queue did not drain')
  picker = Snacks.picker
  local sources = require('snacks.picker.config.sources')
  local call
  Snacks.picker = setmetatable({ util = picker.util }, {
    __index = function(_, source)
      assert(sources[source] or source == 'resume', 'Unknown Snacks source: ' .. source)
      return function(opts) call = { source = source, opts = opts or {} } end
    end,
    __call = function(_, opts) call = { source = 'custom', opts = opts } end,
  })
  local invoke = function(keys, expected)
    call = nil
    local map = vim.fn.maparg(' ' .. keys, 'n', false, true)
    assert(type(map.callback) == 'function', 'Missing callback: ' .. keys)
    map.callback()
    assert(call and call.source == expected, keys .. ': wrong picker ' .. vim.inspect(call))
    return call.opts
  end
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, vim.fn.getcwd() .. '/picker-test.txt')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'unsaved picker test text' })
  for keys, source in pairs({
    [' '] = 'buffers', fb = 'buffers', ff = 'files', fF = 'files', fg = 'grep', fG = 'grep',
    fh = 'help', fH = 'highlights', fk = 'keymaps', fL = 'lines', fd = 'diagnostics', fD = 'diagnostics_buffer',
    ['f/'] = 'search_history', ['f:'] = 'command_history', fr = 'resume',
    fR = 'lsp_references', lR = 'lsp_references', fs = 'lsp_workspace_symbols',
    fS = 'lsp_symbols', eb = 'lsp_symbols', mf = 'git_status',
    gd = 'git_diff', gD = 'git_diff', ga = 'git_diff', gA = 'git_diff',
    fm = 'git_diff', fM = 'git_diff', fa = 'git_diff', fA = 'git_diff',
    fc = 'git_log', fC = 'git_log_file', gl = 'git_log', gL = 'git_log_file',
  }) do invoke(keys, source) end
  assert(invoke('gD', 'git_diff').group == true and call.opts.staged == nil, 'gD should group staged and unstaged changes')
  assert(invoke('gd', 'git_diff').group == true and call.opts.staged == nil, 'gd should group staged and unstaged files')
  gd_opts = vim.deepcopy(call.opts)
  assert(invoke('fa', 'git_diff').staged == true and call.opts.group == false, 'fa should show staged hunks')
  assert(invoke('fG', 'grep').regex == false, 'Word search should be literal')
  local all = invoke('fF', 'files')
  assert(all.hidden and all.ignored and all.follow, 'All-files search lost hidden/ignored/symlink support')
  assert(invoke('fb', 'buffers').win.input.keys['<C-d>'][1] == 'bufdelete', 'Buffer delete shortcut lost')

  -- The keymap preview explains the binding instead of jumping to its source.
  local keymap_opts = invoke('fk', 'keymaps')
  assert(type(keymap_opts.preview) == 'function', 'fk should replace the keymap preview')
  local title, preview_lines
  local ctx = {
    item = { item = vim.fn.maparg(' fk', 'n', false, true) },
    preview = {
      reset = function() end,
      set_title = function(_, value) title = value end,
      set_lines = function(_, value) preview_lines = value end,
      highlight = function() end,
    },
  }
  keymap_opts.preview(ctx)
  local text = table.concat(preview_lines, '\n')
  assert(title == '<Leader>fk', 'Preview title should show the keys: ' .. tostring(title))
  assert(text:find('Mode%s+Normal'), 'Preview should name the mode:\n' .. text)
  assert(text:find('Scope%s+Global'), 'Preview should name the scope:\n' .. text)
  assert(text:find('Does%s+Keymaps'), 'Preview should show the description:\n' .. text)
  assert(text:find('Runs%s+Lua function'), 'Preview should show what runs:\n' .. text)
  assert(text:find('From%s+plugin/20_keymaps%.lua:%d+'), 'Preview should show the defining file:\n' .. text)
  -- A command mapping shows its right-hand side and has no defining file.
  ctx.item.item = vim.fn.maparg('[p', 'n', false, true)
  keymap_opts.preview(ctx)
  text = table.concat(preview_lines, '\n')
  assert(text:find('Keys%s+<Leader>%[p') == nil, 'A non-leader mapping should not show <Leader>:\n' .. text)
  assert(text:find('Does%s+Paste Above'), 'Preview should show the description:\n' .. text)
  assert(text:find('Runs%s+<Cmd>exe'), 'Preview should show the command:\n' .. text)
  assert(not text:find('From'), 'A command mapping has no defining file:\n' .. text)

  -- Real resolution against a frame-shaped tree, from a nested directory.
  local cwd = vim.fn.getcwd()
  local tree = vim.uv.fs_realpath(vim.fn.fnamemodify(vim.fn.tempname(), ':h')) .. '/frame-' .. vim.uv.hrtime()
  vim.fn.mkdir(tree .. '/frame/frontend/apps/web/src', 'p')
  vim.cmd.cd(tree .. '/frame/frontend/apps/web/src')
  assert(invoke('fe', 'files').cwd == tree .. '/frame/frontend', 'Frontend file scope lost')
  assert(invoke('fE', 'grep').cwd == tree .. '/frame/frontend', 'Frontend grep scope lost')
  assert(Config.frontend(tree) == nil, 'Frontend resolved outside a frame repo')
  vim.cmd.cd(tree)
  assert(invoke('fe', 'files').cwd == tree, 'Outside a frame repo the finder should use cwd')
  vim.cmd.cd(cwd)
  vim.fn.delete(tree, 'rf')
  local items = invoke('fl', 'custom').items
  assert(vim.iter(items):any(function(item) return item.buf == buf and item.line == 'unsaved picker test text' end), 'Buffer lines lost unsaved text')

  list_paths = MiniVisits.list_paths
  local visit_cwd, visit_filter
  MiniVisits.list_paths = function(cwd, opts)
    visit_cwd, visit_filter = cwd, opts.filter
    return { '/test/recent.txt' }
  end
  assert(invoke('fv', 'custom').items[1].file == '/test/recent.txt' and visit_cwd == '', 'Global visits scope lost')
  invoke('fV', 'custom')
  assert(visit_cwd == nil, 'Current-directory visits scope lost')
  invoke('vc', 'custom')
  assert(visit_filter == 'core', 'Core visit label lost')
  MiniVisits.list_paths, list_paths = list_paths, nil

  -- Enter in the commit picker opens a commit, never checks one out.
  local commit_opts = invoke('fc', 'git_log')
  original_cmd = vim.cmd
  local command, closed
  vim.cmd = function(cmd) command = cmd end
  commit_opts.confirm({ close = function() closed = true end }, { commit = 'abcdef0' })
  assert(vim.wait(500, function() return command ~= nil end))
  local commit_command = command
  vim.fn.maparg(' gu', 'n', false, true).callback()
  assert(command == 'CodeDiff', 'Space gu no longer opens CodeDiff')
  vim.cmd, original_cmd = original_cmd, nil
  assert(closed and commit_command == 'Git show abcdef0', 'Commit browsing changed checkout state')
  Snacks.picker = picker

  -- The guarded global select really delegates to Snacks and rejects stale LSP clients.
  select_provider, client_lookup = picker.select, vim.lsp.get_client_by_id
  local selected, callback, select_opts
  picker.select = function(items, opts, choose) selected, callback, select_opts = items, choose, opts end
  Config.Pickers.setup_select()
  vim.ui.select({ 'one' }, {}, function() end)
  assert(selected[1] == 'one', 'Global select does not use Snacks')
  vim.lsp.get_client_by_id = function(id) return id == 1 and {} or nil end
  local applied = false
  vim.ui.select({ { ctx = { client_id = 2 } }, { ctx = { client_id = 1 }, action = { title = 'Safe action' } } },
    { kind = 'codeaction', format_item = function() error('Client disappeared') end },
    function() applied = true end)
  assert(#selected == 1 and selected[1].ctx.client_id == 1, 'Stale code action was not filtered')
  assert(select_opts.format_item(selected[1]) == 'Safe action', 'Code-action formatting guard lost its fallback')
  vim.lsp.get_client_by_id = function() return nil end
  callback(selected[1], 1)
  assert(not applied, 'Stale code action was applied')
  picker.select, vim.lsp.get_client_by_id = select_provider, client_lookup
  select_provider, client_lookup = nil, nil
  Config.Pickers.setup_select()
  print('Picker mappings, scopes, visits, commit safety and select guard: OK')

  -- Real finder test in a disposable repository; never stages user files.
  directory = vim.fn.tempname()
  assert(vim.fn.mkdir(directory, 'p') == 1)
  local git = function(args)
    local result = vim.system(vim.list_extend({ 'git', '-C', directory }, args), { text = true }):wait()
    assert(result.code == 0, result.stderr)
  end
  git({ 'init', '--quiet' })
  for _, name in ipairs({ 'one.txt', 'two.txt' }) do
    vim.fn.writefile({ 'staged content' }, directory .. '/' .. name)
  end
  git({ 'add', 'one.txt', 'two.txt' })
  for _, name in ipairs({ 'one.txt', 'two.txt' }) do
    vim.fn.writefile({ 'unstaged content' }, directory .. '/' .. name)
  end
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_name(0, directory .. '/one.txt')
  for _, staged in ipairs({ false, true }) do
    local active = assert(Config.Pickers.git_diff({ cwd = directory, staged = staged, group = true, focus = 'list' }, true), 'Diff picker did not open')
    assert(vim.wait(5000, function() return not active:is_active() end), 'Diff finder did not finish')
    local found = active:items()
    assert(#found == 1 and found[1].file == 'one.txt', 'Current-file diff restriction failed: ' .. #found)
    assert(found[1].staged == staged, 'Staged/unstaged diff scope changed')
    active:close()
  end
  -- `<Space>gd` scope: staged and unstaged changes of every file together.
  vim.fn.writefile({ 'staged only' }, directory .. '/three.txt')
  git({ 'add', 'three.txt' })
  local opts = vim.tbl_extend('force', call_opts_of('gd'), { cwd = directory, focus = 'list' })
  local active = assert(Config.Pickers.git_diff(opts), 'Diff picker did not open')
  assert(vim.wait(5000, function() return not active:is_active() end), 'Diff finder did not finish')
  local files = {}
  for _, item in ipairs(active:items()) do
    files[item.file] = files[item.file] or {}
    files[item.file][item.staged and 'staged' or 'unstaged'] = true
  end
  active:close()
  assert(files['three.txt'] and files['three.txt'].staged, 'gd hides staged-only files: ' .. vim.inspect(files))
  assert(files['one.txt'] and files['one.txt'].staged and files['one.txt'].unstaged, 'gd hides a staged side: ' .. vim.inspect(files))
  assert(files['two.txt'], 'gd lost a file: ' .. vim.inspect(files))
  print('gd lists staged and unstaged changes of every file: OK')

  -- Completion menu in the prompt: Neovim fires `TextChangedP` instead of
  -- `TextChangedI` while it is open, and results must still follow the text.
  local prompt = Snacks.picker({ items = { { text = 'alpha' }, { text = 'beta' } } })
  assert(vim.wait(1000, function() return prompt.input.win:valid() and #prompt:items() == 2 end), 'Picker did not open')
  local pbuf = prompt.input.win.buf
  vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, { 'alp' })
  vim.api.nvim_exec_autocmds('TextChangedP', { buffer = pbuf })
  assert(vim.wait(1000, function() return #prompt:items() == 1 end), 'Results froze while the completion menu was open')
  -- Prompt keys drive the menu when it is open, else the picker.
  local pumvisible, feedkeys, complete_info = vim.fn.pumvisible, vim.api.nvim_feedkeys, vim.fn.complete_info
  local fed, acted, menu, selected_item
  vim.fn.pumvisible = function() return menu and 1 or 0 end
  vim.fn.complete_info = function() return { selected = selected_item } end
  vim.api.nvim_feedkeys = function(keys) fed = keys end
  prompt.action = function(_, name) acted = name end
  local press = function(key, open, sel)
    fed, acted, menu, selected_item = nil, nil, open, sel or -1
    local map = vim.api.nvim_buf_call(pbuf, function() return vim.fn.maparg(key, 'i', false, true) end)
    assert(type(map.callback) == 'function', 'No prompt mapping for ' .. key)
    map.callback()
    return fed and vim.fn.keytrans(fed) or acted
  end
  local key_ok, key_err = pcall(function()
    for key, want in pairs({ ['<C-n>'] = { '<C-N>', 'list_down' }, ['<C-p>'] = { '<C-P>', 'list_up' } }) do
      assert(press(key, true) == want[1], key .. ' does not move in the open menu')
      assert(press(key, false) == want[2], key .. ' lost its picker action')
    end
    -- Multi-select wins over the menu: selecting files is what Tab is for here.
    prompt.action = nil
    assert(press('<Tab>', true) == nil and #prompt:selected() == 1, '<Tab> must multi-select even with the menu open')
    assert(press('<S-Tab>', true) == nil and #prompt:selected() == 0, '<S-Tab> must multi-select even with the menu open')
    prompt.action = function(_, name) acted = name end
    assert(press('<CR>', true, 0) == '<C-Y>', '<CR> does not accept the highlighted item')
    assert(press('<CR>', true) == 'confirm', '<CR> with no highlighted item should confirm')
    assert(press('<CR>', false) == 'confirm', '<CR> lost confirm')
  end)
  vim.fn.pumvisible, vim.api.nvim_feedkeys, vim.fn.complete_info = pumvisible, feedkeys, complete_info
  prompt.action = nil
  prompt:close()
  assert(key_ok, key_err)
  print('Completion menu in the picker prompt: live results and menu keys: OK')
  print('Real Snacks staged/unstaged diff finder and current-file filtering: OK')
end, debug.traceback)
if picker then Snacks.picker = picker end
if select_provider then picker.select = select_provider end
if client_lookup then vim.lsp.get_client_by_id = client_lookup end
if list_paths then MiniVisits.list_paths = list_paths end
if original_cmd then vim.cmd = original_cmd end
if directory then vim.fn.delete(directory, 'rf') end
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
end
print('SNACKS PICKERS OK')
vim.cmd('qa!')
