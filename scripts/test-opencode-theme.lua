-- Run: nvim --headless -u NONE -l scripts/test-opencode-theme.lua
local root = 'home/dot_config/'
local theme = vim.json.decode(table.concat(vim.fn.readfile(root .. 'opencode/themes/solarized-osaka-vivid.json'), '\n'))
local ghostty = table.concat(vim.fn.readfile(root .. 'ghostty/themes/solarized-osaka-vivid'), '\n')
assert(theme.base and theme.dark and not theme.theme, 'Use the V2 semantic theme format')
assert(theme.base.background.base == ghostty:match('\nbackground = (#%x+)'), 'Background differs from Ghostty')
assert(theme.base.text.base == ghostty:match('\nforeground = (#%x+)'), 'Foreground differs from Ghostty')
local tokens = vim.tbl_deep_extend('force', theme.base, theme.dark)
local function resolve(value, seen)
  if type(value) ~= 'string' or value:sub(1, 1) ~= '$' then return value end
  seen = vim.deepcopy(seen or {})
  assert(not seen[value], 'Circular reference: ' .. value)
  seen[value] = true
  local target = tokens
  for key in value:sub(2):gmatch('[^.]+') do
    target = type(target) == 'table' and target[key] or nil
    assert(target ~= nil, 'Missing reference: ' .. value)
  end
  return resolve(target, seen)
end
local function check(tree)
  for _, value in pairs(tree) do
    if type(value) == 'table' then check(value) else resolve(value) end
  end
end
check(tokens)
for _, name in ipairs({ 'gray', 'red', 'orange', 'yellow', 'green', 'cyan', 'blue', 'purple', 'accent', 'interactive', 'neutral' }) do
  local scale = resolve(theme.dark.hue[name])
  assert(type(scale) == 'table', 'Missing hue: ' .. name)
  for step = 1, 9 do
    assert((scale[tostring(step * 100)] or ''):match('^#%x%x%x%x%x%x$'), 'Missing hue step: ' .. name .. step)
  end
end
for _, group in ipairs({ 'text', 'background', 'border', 'scrollbar', 'diff', 'syntax', 'markdown' }) do
  assert(type(theme.base[group]) == 'table', 'Missing semantic group: ' .. group)
end
print('OpenCode theme: Ghostty colors, hue scales and references OK')
