-- Run with the full config:
-- nvim --headless -n -i NONE -c "lua dofile('scripts/test-theme.lua')"
local ok, err = xpcall(function()
  assert(vim.wait(5000, function() return Config.later_pending == 0 end), 'Deferred config did not finish')
  assert(vim.g.colors_name == 'onedark' and package.loaded.onedarkpro, 'One Dark Pro is not loaded')
  assert(not package.loaded.onedark, 'The old One Dark plugin is still loaded')
  assert(vim.o.termguicolors, 'True color is disabled')
  assert(vim.o.laststatus == 3, 'Use a global statusline so horizontal splits have a line separator')
  assert(vim.o.cmdheight == 0, 'The idle command line must not leave a gap below the statusline')

  local hl = function(name) return vim.api.nvim_get_hl(0, { name = name, link = false, create = false }) end
  local expect_color = function(group, attr, expected)
    local actual = hl(group)[attr]
    assert(actual == expected, ('%s %s: expected #%06x, got %s'):format(group, attr, expected, vim.inspect(actual)))
  end

  for group, color in pairs({
    Normal = 0xabb2bf,
    Comment = 0x7f848e,
    ['@variable'] = 0xe06c75,
    ['@variable.member'] = 0xe06c75,
    ['@operator'] = 0x56b6c2,
    ['@punctuation.delimiter'] = 0xabb2bf,
    ['@type.builtin.tsx'] = 0xe5c07b,
    ['@tag.tsx'] = 0xe5c07b,
    ['@tag.builtin.tsx'] = 0xe06c75,
    ['@tag.attribute.tsx'] = 0xd19a66,
    ['@lsp.type.variable'] = 0xe06c75,
    ['@lsp.type.property'] = 0xe06c75,
    ['@lsp.type.enumMember'] = 0x56b6c2,
    ['@lsp.typemod.variable.readonly'] = 0xd19a66,
    MiniTablineCurrent = 0xdcdcdc,
    WinSeparator = 0x4b5263,
  }) do
    expect_color(group, 'fg', color)
  end
  expect_color('Normal', 'bg', 0x282c34)
  expect_color('DiffAdd', 'bg', 0x002800)
  assert(hl('Comment').italic and hl('@variable.parameter').italic, 'Comments and parameters should be italic')
  assert(hl('@tag.attribute.tsx').italic, 'JSX props should be italic')
  assert(not hl('@keyword.return').italic and not hl('Type').italic, 'Keywords and types should not be italic')
  print('Palette, token colors, semantic highlights and text styles: OK')

  local check_tabs = function()
    for _, group in ipairs({ 'MiniTablineCurrent', 'MiniTablineModifiedCurrent' }) do
      expect_color(group, 'fg', 0xdcdcdc)
      expect_color(group, 'bg', 0x282c34)
      expect_color(group, 'sp', 0xb4b4b4)
      assert(hl(group).underline and not hl(group).bold and not hl(group).italic, group .. ' has incorrect text styling')
    end
    for _, group in ipairs({
      'MiniTablineVisible', 'MiniTablineHidden', 'MiniTablineModifiedVisible', 'MiniTablineModifiedHidden',
      'MiniTablineFill', 'MiniTablineTabpagesection', 'MiniTablineTrunc',
    }) do
      expect_color(group, 'bg', 0x21252b)
      assert(not hl(group).bold and not hl(group).italic and not hl(group).underline, group .. ' should be a flat inactive tab')
    end
    expect_color('MiniTablineHidden', 'fg', 0x7e8184)
    assert(not hl('MiniTablineHint').italic, 'Terminal tab hints should not use comment italics')
  end
  check_tabs()
  assert(package.loaded.bufferline and MiniTabline == nil, 'File tabs should use Bufferline only')
  local check_file_tabs = function()
    local config = require('bufferline.config')
    assert(config.options.mode == 'buffers', 'Styling must not switch file tabs to Vim tabpages')
    assert(config.options.style_preset == require('bufferline').style_preset.default, 'Use the standard Bufferline preset')
    assert(config.options.separator_style == 'thin' and config.options.indicator.style == 'icon', 'Use stock separators and active indicator')
    assert(config.options.show_buffer_close_icons and config.options.show_close_icon, 'Use the standard close buttons')
    assert(config.options.custom_areas == nil, 'Remove the custom outer frame')
    assert(next(config.user.highlights or {}) == nil, 'Let Bufferline derive highlights from the theme')
    for _, group in ipairs({ 'BufferLineBufferSelected', 'BufferLineBackground', 'BufferLineFill' }) do
      assert(not hl(group).overline and not hl(group).underline, group .. ' kept a custom outline')
    end
    expect_color('BufferLineBufferSelected', 'bg', 0x282c34)
    expect_color('BufferLineBufferSelected', 'fg', 0xabb2bf)
  end
  check_file_tabs()
  local previous = vim.api.nvim_get_current_buf()
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
  local elements = require('bufferline').get_elements().elements
  local first, second
  for i, element in ipairs(elements) do
    if element.id == buf then first = i end
    if element.id == other then second = i end
  end
  assert(first and second and first < second, 'Buffer creation-order navigation changed')
  vim.api.nvim_set_current_buf(previous)
  vim.api.nvim_buf_delete(buf, { force = true })
  vim.api.nvim_buf_delete(other, { force = true })
  print('Stock Bufferline UI, terminal tab styles, buffer order and dirty dot: OK')

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
  for i, color in ipairs({ 0xd19a66, 0xc678dd, 0x56b6c2, 0xd19a66 }) do
    expect_color(rainbow.hlgroup_at(i), 'fg', color)
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
  assert(hl('Normal').bg == nil, 'Transparency toggle did not clear the background')
  Config.toggle_transparency()
  expect_color('Normal', 'bg', 0x282c34)
  expect_color('@tag.attribute.tsx', 'fg', 0xd19a66)
  expect_color('WinSeparator', 'fg', 0x4b5263)
  check_tabs()
  check_file_tabs()
  assert(hl('@tag.attribute.tsx').italic, 'Text styles were lost on theme reload')
  assert(vim.api.nvim_get_hl(0, { name = 'Folded', link = true }).link == 'LineNr', 'Fold styling was lost')
  print('Transparency toggle and theme reload: OK')
end, debug.traceback)

if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd('cquit 1')
else
  print('THEME OK')
  vim.cmd('qa!')
end
