-- Run: nvim --headless -u NONE -l scripts/test-open-without-comment.lua
-- Exercise the mappings, option restoration, and existing Other shortcuts.
vim.opt.rtp:prepend(vim.fn.getcwd() .. '/home/dot_config/nvim')
Config = {}
vim.g.mapleader = ' '
dofile(vim.fn.getcwd() .. '/home/dot_config/nvim/plugin/20_keymaps.lua')
local type_keys = function(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), 'xt', false)
end

for _, comment in ipairs({
  { text = '// comment', comments = 'b://' },
  { text = '-- comment', comments = 'b:--' },
  { text = '* comment', comments = 's1:/*,mb:*,ex:*/' },
}) do
  for _, formatoptions in ipairs({ 'croq', 'rq' }) do
    for _, direction in ipairs({ 'below', 'above' }) do
      vim.cmd.enew({ bang = true })
      vim.bo.autoindent = true
      vim.bo.smartindent = false
      vim.bo.cindent = false
      vim.bo.indentexpr = ''
      vim.bo.comments = comment.comments
      vim.bo.formatoptions = formatoptions
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { '  ' .. comment.text })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })

      local keys = direction == 'below' and ' o' or ' O'
      type_keys(keys .. 'hello<Esc>')
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      local row = direction == 'below' and 2 or 1
      assert(lines[row] == '  hello', 'Unexpected ' .. direction .. ' line: ' .. vim.inspect(lines))
      assert(lines[3 - row] == '  ' .. comment.text, 'Original comment changed')
      assert(vim.bo.formatoptions == formatoptions, 'Buffer formatoptions were not restored')
    end
  end
end

local toggled = false
Config.toggle_transparency = function() toggled = true end
type_keys(' ob')
assert(toggled, 'Existing Space o b shortcut became inaccessible')
assert(vim.fn.maparg('dw', 'n') == '', 'Normal dw was remapped')
assert(vim.fn.maparg(' dw', 'n') == '', 'Space dw was added')
print('OPEN WITHOUT COMMENT OK')
