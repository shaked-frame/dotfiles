-- Run: nvim --headless -n -i NONE -c "lua dofile('scripts/test-statusline.lua')"
local ok, err = xpcall(function()
  assert(vim.wait(5000, function() return Config.later_pending == 0 end), 'Deferred config did not finish')
  local status = require('config.statusline')
  local cwd = vim.fn.getcwd()
  vim.o.columns = 200
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  local set_name = function(path)
    vim.api.nvim_buf_set_name(buf, path)
    vim.bo.modified = false
  end
  local render = function()
    return vim.api.nvim_eval_statusline(status.active(), { maxwidth = vim.o.columns }).str
  end

  set_name(cwd .. '/src/components/settings/AccountPanel.tsx')
  vim.b.minigit_summary = { root = cwd, head_name = 'feature/statusline' }
  vim.b.minidiff_summary = { add = 3, change = 2, delete = 1 }
  local text = render()
  assert(text:find('^ NORMAL   feature/statusline '), 'Missing connected mode/branch arrow segments: ' .. text)
  local check_left_colors = function()
    local hl = function(name) return vim.api.nvim_get_hl(0, { name = name, link = false }) end
    local mode = hl('ConfigStatuslineModeNormal')
    local branch = hl('ConfigStatuslineBranch')
    local arrow = hl('ConfigStatuslineModeNormalToBranch')
    local end_arrow = hl('ConfigStatuslineBranchToFilename')
    assert(mode.bg == hl('Function').fg, 'Normal mode segment should use the theme blue')
    assert(mode.bg ~= branch.bg, 'Mode and branch should have different fills')
    assert(arrow.fg == mode.bg and arrow.bg == branch.bg, 'Mode arrow does not join the branch segment')
    assert(end_arrow.fg == branch.bg and end_arrow.bg == hl('MiniStatuslineFilename').bg, 'Branch arrow does not join the path background')
  end
  check_left_colors()
  assert(text:find('src/components/settings/AccountPanel.tsx', 1, true), text)
  assert(text:find('feature/statusline', 1, true), 'Branch is missing')
  for _, count in ipairs({ '+3', '~2', '-1' }) do assert(text:find(count, 1, true), 'Missing diff ' .. count) end
  assert(status.pretty_path():find('ConfigStatuslineFilename', 1, true), 'Filename is not emphasized')

  vim.b.minigit_summary = { root = cwd .. '/src', head_name = 'main' }
  assert(render():find('󱉭 src', 1, true), 'Different project root was not displayed')
  vim.b.minigit_summary = { root = cwd, head_name = 'main' }
  vim.b.minigit_summary = nil
  assert(render():find('^ NORMAL  '), 'Mode arrow is missing outside Git')
  assert(not render():find('', 1, true), 'Empty branch segment should be hidden')
  vim.b.minigit_summary = { root = cwd, head_name = 'main' }
  local ns = vim.api.nvim_create_namespace('test-statusline-diagnostics')
  vim.diagnostic.set(ns, buf, {
    { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'Test error' },
    { lnum = 0, col = 0, severity = vim.diagnostic.severity.WARN, message = 'Test warning' },
  })
  assert(vim.wait(500, function() return render():find(' 1', 1, true) ~= nil end), 'Diagnostics are missing')
  assert(status.active():find('%%#DiagnosticError#') and status.active():find('%%#DiagnosticWarn#'), 'Diagnostics lost severity colors')
  vim.diagnostic.reset(ns)
  local reg_recording = vim.fn.reg_recording
  vim.fn.reg_recording = function() return 'q' end
  local recorded = render()
  vim.fn.reg_recording = reg_recording
  assert(recorded:find('@q', 1, true), 'Macro recording register is missing')

  vim.bo.modified, vim.bo.readonly = true, true
  local path = status.pretty_path()
  assert(path:find('ConfigStatuslineModified', 1, true) and path:find('󰌾', 1, true), 'Missing modified/readonly styling')
  vim.bo.modified, vim.bo.readonly = false, false

  set_name(cwd .. '/src/100%complete.ts')
  assert(render():find('100%complete.ts', 1, true), 'Percent in a filename became a status item')
  vim.b.minigit_summary = { root = cwd, head_name = 'feature%test' }
  assert(render():find('feature%test', 1, true), 'Percent in branch name was not escaped')

  set_name(cwd .. '-sibling/lib/Outside.ts')
  assert(render():find(vim.fs.basename(cwd) .. '-sibling', 1, true), 'Sibling directory was treated as inside cwd')

  set_name(cwd .. '/very/long/nested/components/settings/AccountPanel.tsx')
  vim.o.columns = 90
  text = render()
  assert(text:find('AccountPanel.tsx', 1, true), 'Narrow layout lost the filename')
  assert(status.pretty_path():find('…', 1, true), 'Long path was not shortened')
  assert(vim.fn.strdisplaywidth(text) <= 90, 'Statusline overflowed')

  vim.o.columns = 200
  vim.api.nvim_buf_set_name(buf, '')
  assert(render():find('[No Name]', 1, true), 'Unnamed buffer is missing')
  for _, ft in ipairs({ 'dashboard', 'alpha', 'ministarter', 'snacks_dashboard' }) do
    vim.bo.filetype = ft
    assert(status.active() == '', 'Dashboard statusline should be empty: ' .. ft)
  end
  vim.bo.filetype = ''

  set_name('octo://owner/repo/review/123/SomeFile.ts')
  vim.bo.buftype = 'nofile'
  assert(render():find('SomeFile.ts', 1, true), 'Special buffer name was lost')

  vim.cmd('colorscheme onedark')
  check_left_colors()
  assert(vim.api.nvim_get_hl(0, { name = 'ConfigStatuslineFilename' }).bold, 'Theme reload lost filename styling')
  assert(vim.o.laststatus == 3, 'Global statusline was changed')
  assert(not package.loaded.lualine, 'Lualine should not be loaded')
end, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
end
print('STATUSLINE OK')
vim.cmd('qa!')
