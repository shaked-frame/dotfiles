-- Run: nvim --headless -u NONE -l scripts/test-agent-symbol.lua
-- `<Leader>as`/`aS` attach/send the LSP symbol around the cursor
-- ('lua/config/symbol.lua'); `<Leader>aq`/`aQ` and `<Leader>ad`/`aD` the
-- quickfix list and buffer diagnostics through sidekick's renderers. An
-- in-process fake language server answers `textDocument/documentSymbol` with
-- whatever `symbols` holds, and a stub adapter records what the dispatcher
-- hands over.
local repo = vim.fn.getcwd()
vim.opt.rtp:prepend(repo .. '/nvim/.config/nvim')
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/site/pack/core/opt/sidekick.nvim')
Config = {}
vim.g.mapleader = ' '
dofile(repo .. '/nvim/.config/nvim/plugin/44_agent.lua')

local got
Config.Agent.register('sidekick', {
  visible = function() return true end,
  focus = function() end,
  attach = function(text, what) got = { how = 'attach', text = text, what = what } end,
  send = function(text, what) got = { how = 'send', text = text, what = what } end,
})

local symbols
local fake_server = function(dispatchers)
  local closing = false
  return {
    request = function(method, _, callback)
      local result = nil
      if method == 'initialize' then result = { capabilities = { documentSymbolProvider = true } } end
      if method == 'textDocument/documentSymbol' then result = symbols end
      vim.schedule(function() callback(nil, result) end)
      return true, 1
    end,
    notify = function() return true end,
    is_closing = function() return closing end,
    terminate = function() closing = true end,
  }
end

vim.cmd('cd ' .. vim.fn.fnameescape(repo))
vim.api.nvim_buf_set_name(0, repo .. '/src/foo.ts')
vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(string.rep('line\n', 20), '\n'))
vim.lsp.start({ name = 'fake', cmd = fake_server })
assert(vim.wait(2000, function()
  return #vim.lsp.get_clients({ bufnr = 0, method = 'textDocument/documentSymbol' }) > 0
end), 'fake server did not attach')

local range = function(a, b) return { start = { line = a, character = 0 }, ['end'] = { line = b, character = 99 } } end
local sym = function(name, kind, a, b, children)
  return { name = name, kind = kind, range = range(a, b), selectionRange = range(a, a), children = children }
end
local K = { Package = 4, Class = 5, Method = 6, Function = 12, Variable = 13, Object = 19 }

local press = function(keys, line)
  vim.api.nvim_win_set_cursor(0, { line, 2 })
  got = nil
  vim.fn.maparg(keys, 'n', false, true).callback()
  return got
end

local cases = {
  {
    'A local variable reports its method, qualified by the class',
    { sym('Foo', K.Class, 0, 10, { sym('bar', K.Method, 2, 8, { sym('x', K.Variable, 3, 3) }) }) },
    ' as', 4, 'attach',
    'Look at method `Foo.bar` in `src/foo.ts` (lines 3-9), around line 4.',
  },
  {
    'A nested function joins with `>`; control flow (lua_ls `if` = Package) is skipped',
    { sym('outer', K.Function, 0, 10, { sym('if', K.Package, 1, 9, { sym('inner', K.Function, 2, 5) }) }) },
    ' aS', 4, 'send',
    'Look at function `outer > inner` in `src/foo.ts` (lines 3-6), around line 4.',
  },
  {
    'A name the server already qualified is not prefixed twice',
    { sym('M', K.Object, 0, 10, { sym('M.foo', K.Function, 2, 2) }) },
    ' as', 3, 'attach',
    'Look at function `M.foo` in `src/foo.ts` (line 3), around line 3.',
  },
  {
    'Flat SymbolInformation: the innermost containing symbol, with its container',
    {
      { name = 'Foo', kind = K.Class, location = { uri = 'file:///x', range = range(0, 10) } },
      { name = 'bar', kind = K.Method, containerName = 'Foo', location = { uri = 'file:///x', range = range(2, 8) } },
    },
    ' as', 4, 'attach',
    'Look at method `Foo.bar` in `src/foo.ts` (lines 3-9), around line 4.',
  },
  {
    'No symbol around the cursor falls back to the line',
    { sym('Foo', K.Class, 0, 2) },
    ' as', 8, 'attach',
    'Look at `src/foo.ts` around line 8.',
  },
}

for _, c in ipairs(cases) do
  local name, syms, keys, line, how, want = unpack(c)
  symbols = syms
  local r = press(keys, line)
  assert(r.how == how, name .. ': expected ' .. how .. ', got ' .. r.how)
  assert(r.text == want, name .. ':\n  want ' .. want .. '\n  got  ' .. r.text)
  print(name .. ': OK')
end

-- 'mini.icons' prefixes the protocol's kind names with an icon.
local plain = vim.lsp.protocol.SymbolKind[K.Method]
vim.lsp.protocol.SymbolKind[K.Method] = '󰆧 ' .. plain
symbols = { sym('Foo', K.Class, 0, 10, { sym('bar', K.Method, 2, 8, { sym('x', K.Variable, 3, 3) }) }) }
local r = press(' as', 4)
vim.lsp.protocol.SymbolKind[K.Method] = plain
assert(r.text == 'Look at method `Foo.bar` in `src/foo.ts` (lines 3-9), around line 4.', 'icon-prefixed kinds: ' .. r.text)
print('Icon-prefixed kind names still classify: OK')


-- Quickfix and diagnostics: sidekick's own renderers, through the dispatcher.
local file = repo .. '/src/foo.ts'
vim.fn.setqflist({ { filename = file, lnum = 3, col = 5, text = 'first' }, { filename = file, lnum = 7, col = 1, text = 'second' } })
r = press(' aQ', 1)
assert(r.how == 'send' and r.what == 'quickfix', vim.inspect(r))
assert(r.text:match('^Look at these quickfix entries:\n'), r.text)
assert(r.text:find('src/foo.ts :L3', 1, true) and r.text:find('second', 1, true), 'quickfix entries missing:\n' .. r.text)
print('Quickfix list reaches the agent: OK')

vim.fn.setqflist({}, 'r')
assert(press(' aq', 1) == nil, 'empty quickfix list must not reach the agent')
print('Empty quickfix list stays local: OK')

local ns = vim.api.nvim_create_namespace('test-agent-symbol')
vim.diagnostic.set(ns, 0, { { lnum = 4, col = 0, message = 'boom', severity = vim.diagnostic.severity.ERROR, source = 'fake' } })
r = press(' ad', 1)
assert(r.how == 'attach' and r.what == 'diagnostics', vim.inspect(r))
assert(r.text:match('^Look at these diagnostics:\n%[ERROR%] boom fake @src/foo.ts :L5'), r.text)
print('Buffer diagnostics reach the agent: OK')

vim.diagnostic.reset(ns, 0)
assert(press(' aD', 1) == nil, 'no diagnostics must not reach the agent')
print('No diagnostics stays local: OK')

vim.cmd('qa!')
