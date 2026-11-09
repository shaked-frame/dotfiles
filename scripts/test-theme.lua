-- Run with the full config:
-- nvim --headless -n -i NONE -c "lua dofile('scripts/test-theme.lua')"
local ok, err = xpcall(function()
  assert(vim.wait(5000, function() return Config.later_pending == 0 end), 'Deferred config did not finish')
  assert(vim.g.colors_name == 'solarized-osaka' and package.loaded['solarized-osaka'], 'Solarized Osaka is not loaded')
  assert(require('solarized-osaka.config').options.style == 'vivid', 'Use the vivid Solarized Osaka style')
  assert(not package.loaded.onedarkpro, 'One Dark Pro is still loaded')
  assert(vim.o.termguicolors, 'True color is disabled')
  assert(vim.o.laststatus == 3, 'Use a global statusline so horizontal splits have a line separator')
  assert(vim.o.cmdheight == 0, 'The idle command line must not leave a gap below the statusline')

  local hl = function(name) return vim.api.nvim_get_hl(0, { name = name, link = false, create = false }) end
  local expect_color = function(group, attr, expected)
    local actual = hl(group)[attr]
    assert(actual == expected, ('%s %s: expected #%06x, got %s'):format(group, attr, expected, vim.inspect(actual)))
  end

  local check_overrides = function()
    assert(hl('Normal').bg == nil, 'Background should be transparent')
    assert(hl('Normal').fg, 'Normal has no foreground')
    expect_color('DiffAdd', 'bg', 0x002800)
    expect_color('DiffText', 'bg', 0x006000)
    expect_color('OctoReviewDiffAdd', 'bg', tonumber(Config.vscode_diff.line_insert:sub(2), 16))
    expect_color('CodeDiffFiller', 'fg', tonumber(Config.vscode_diff.fill:sub(2), 16))
    assert(hl('Comment').italic, 'Comments should be italic')
    assert(vim.api.nvim_get_hl(0, { name = 'Folded', link = true }).link == 'LineNr', 'Fold styling was lost')
  end
  check_overrides()
  print('Scheme, vivid style, transparency and diff overrides: OK')

  assert(package.loaded.bufferline and MiniTabline == nil, 'File tabs should use Bufferline only')
  local check_file_tabs = function()
    local config = require('bufferline.config')
    assert(config.options.mode == 'buffers', 'Styling must not switch file tabs to Vim tabpages')
    assert(config.options.style_preset == require('bufferline').style_preset.default, 'Use the standard Bufferline preset')
    assert(config.options.separator_style == 'slant', 'Use the README slanted tab style')
    assert(config.options.diagnostics == 'nvim_lsp' and config.options.diagnostics_update_on_event, 'Refresh native LSP indicators when diagnostics change')
    assert(config.options.show_buffer_close_icons and config.options.show_close_icon, 'Use the standard close buttons')
    assert(config.options.custom_areas == nil, 'Remove the custom outer frame')
    for _, group in ipairs({ 'BufferLineBufferSelected', 'BufferLineBackground', 'BufferLineFill' }) do
      assert(not hl(group).overline and not hl(group).underline, group .. ' kept a custom outline')
    end
    assert(hl('BufferLineBufferSelected').fg, 'Bufferline did not derive colors from the theme')
    -- Transparent Normal leaves Bufferline nothing to derive backgrounds from,
    -- so the config paints them from the Osaka palette.
    local c = require('solarized-osaka.colors').setup()
    local bg = function(group) return string.format('#%06x', hl(group).bg or 0) end
    assert(bg('BufferLineFill') == c.base02, 'Tab bar should use base02')
    assert(bg('BufferLineBackground') == c.base03, 'Other tabs should use base03')
    assert(bg('BufferLineBufferSelected') == c.base04, 'Current tab should match the editor background')
    assert(string.format('#%06x', hl('BufferLineSeparator').fg) == c.base02, 'Slants should be drawn in the bar color')
  end
  check_file_tabs()
  local previous = vim.api.nvim_get_current_buf()
  local previous_columns = vim.o.columns
  vim.o.columns = 160 -- Keep both test tabs visible when diagnostic counts grow.
  local buf = vim.api.nvim_create_buf(true, false)
  local other = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, vim.fn.stdpath('cache') .. '/tab-border-one.txt')
  vim.api.nvim_buf_set_name(other, vim.fn.stdpath('cache') .. '/tab-border-two.txt')
  vim.api.nvim_set_current_buf(buf)
  local render_tabs = function()
    return vim.api.nvim_eval_statusline(nvim_bufferline(), { use_tabline = true, maxwidth = 160 }).str
  end
  local clean = render_tabs()
  vim.bo[buf].modified = true
  local dirty = render_tabs()
  assert(dirty:find('●', 1, true) and not clean:find('●', 1, true), 'Dirty dot should only appear on modified tabs')
  assert(vim.fn.strdisplaywidth(clean) == vim.fn.strdisplaywidth(dirty), 'Dirty dot should not shift neighboring tabs')
  assert(clean:find(require('bufferline.config').options.buffer_close_icon, 1, true), 'Missing standard file close button')
  assert(not clean:find('│', 1, true), 'The custom outer frame is still rendered')
  assert(clean:find('', 1, true) and clean:find('', 1, true), 'Slanted separators are not rendered')
  local elements = require('bufferline').get_elements().elements
  local first, second
  for i, element in ipairs(elements) do
    if element.id == buf then first = i end
    if element.id == other then second = i end
  end
  assert(first and second and first < second, 'Buffer creation-order navigation changed')

  local ns = vim.api.nvim_create_namespace('test-bufferline-diagnostics')
  vim.diagnostic.set(ns, buf, {
    { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'First test error' },
    { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'Second test error' },
  })
  vim.diagnostic.set(ns, other, {
    { lnum = 0, col = 0, severity = vim.diagnostic.severity.WARN, message = 'Test warning' },
  })
  local diagnostic_tabs = nvim_bufferline()
  local diagnostic_text = render_tabs()
  assert(diagnostic_text:find('(2)', 1, true), 'Error count is missing from the active file tab')
  assert(diagnostic_text:find('(1)', 1, true), 'Warning count is missing from the inactive file tab')
  assert(diagnostic_tabs:find('BufferLineErrorSelected', 1, true), 'Active error tab is not severity-colored')
  assert(diagnostic_tabs:find('BufferLineWarningDiagnostic', 1, true), 'Warning indicator is not severity-colored')
  vim.diagnostic.reset(ns)
  assert(not render_tabs():find('(2)', 1, true), 'Resolved diagnostic indicators did not clear')
  print('Active/inactive LSP counts, severity colors and diagnostic clearing: OK')
  vim.api.nvim_set_current_buf(previous)
  vim.api.nvim_buf_delete(buf, { force = true })
  vim.api.nvim_buf_delete(other, { force = true })
  vim.o.columns = previous_columns
  print('Slanted Bufferline UI, terminal tab styles, buffer order and dirty dot: OK')

  local source = 'function greet(name: string) { return <Button className="hello"><div>{name}</div></Button>; }'
  local parser = vim.treesitter.get_string_parser(source, 'tsx')
  local tree = parser:parse()[1]
  local captures = {}
  local query = assert(vim.treesitter.query.get('tsx', 'highlights'))
  for id, node in query:iter_captures(tree:root(), source, 0, -1) do
    local capture = query.captures[id]
    if capture:match('^tag') or capture == 'type.builtin' then
      captures[vim.treesitter.get_node_text(node, source)] = capture
    end
  end
  assert(captures.Button == 'tag' and captures.div == 'tag.builtin', 'Component and native tags must stay distinct')
  assert(captures.className == 'tag.attribute' and captures.string == 'type.builtin', 'Missing TSX captures')

  local rainbow = require('rainbow-delimiters')
  for i = 1, 4 do
    assert(hl(rainbow.hlgroup_at(i)).fg, 'Rainbow level ' .. i .. ' has no color')
  end
  query = assert(vim.treesitter.query.get('tsx', require('rainbow-delimiters.config').query.tsx))
  local delimiters = 0
  for id, node in query:iter_captures(tree:root(), source, 0, -1) do
    if query.captures[id] == 'delimiter' then
      local text = vim.treesitter.get_node_text(node, source)
      assert(text:match('^[%(%){%}%[%]]$'), 'Rainbow highlighting must not recolor JSX tags: ' .. text)
      delimiters = delimiters + 1
    end
  end
  assert(delimiters >= 6, 'Rainbow query is not capturing nested brackets')
  print('Real TSX captures and bracket-only rainbow query: OK')

  Config.toggle_transparency()
  assert(hl('Normal').bg, 'Transparency toggle did not restore the background')
  expect_color('DiffAdd', 'bg', 0x002800)
  Config.toggle_transparency()
  check_overrides()
  check_file_tabs()
  print('Transparency toggle and theme reload: OK')
end, debug.traceback)

if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
else
  print('THEME OK')
  vim.cmd('qa!')
end
