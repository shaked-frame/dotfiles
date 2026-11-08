-- ┌──────────────────────────────────────────────┐
-- │ The symbol around the cursor, for agents     │
-- └──────────────────────────────────────────────┘
--
-- `describe(win)` names the symbol around `win`'s cursor, e.g.
-- "method `Foo.bar` in `src/foo.ts` (lines 3-9)", or returns `nil`. Used by
-- `<Leader>as`/`<Leader>aS` ('plugin/44_agent.lua') and sidekick's `{symbol}`
-- context ('plugin/45_sidekick.lua').
--
-- The buffer's language server answers (`textDocument/documentSymbol`), so
-- every language with an LSP works. The request is synchronous (sidekick
-- context functions are) and gives up after `TIMEOUT_MS`.
--
-- Nested symbols are joined into a path: `Class.method`, and
-- `function > nested_function` past a function. Inside a function only
-- callables and classes count, so a local variable reports its function.
-- Kinds that are not declarations (lua_ls reports `if` blocks as Package,
-- table values as String/Number/...) are skipped.

local M = {}

local METHOD = 'textDocument/documentSymbol'
local TIMEOUT_MS = 3000 -- a cold lua_ls takes ~1.5 s for the first request; warm ~10 ms

local function_kinds = { Function = true, Method = true, Constructor = true }
local skip_kinds = {
  Package = true, String = true, Number = true, Boolean = true, Array = true,
  Null = true, Key = true, TypeParameter = true,
}

-- Plain kind names: 'mini.icons' prepends an icon to the protocol table's.
local kind_of = function(s) return (vim.lsp.protocol.SymbolKind[s.kind] or ''):match('(%a+)$') end

-- `{ name, kind, range }` of the symbol around `pos` in an LSP result.
local find = function(result, pos)
  local contains = function(range)
    local s, e = range.start, range['end']
    return (pos.line > s.line or (pos.line == s.line and pos.character >= s.character))
      and (pos.line < e.line or (pos.line == e.line and pos.character <= e.character))
  end

  -- `SymbolInformation[]` (flat): the containing symbol that starts last.
  if result[1].location then
    local best
    for _, s in ipairs(result) do
      local r = s.location.range
      if contains(r) and not skip_kinds[kind_of(s)]
        and (not best or r.start.line >= best.location.range.start.line) then
        best = s
      end
    end
    if not best then return nil end
    local container = best.containerName
    local name = container and container ~= '' and (container .. '.' .. best.name) or best.name
    return { name = name, kind = kind_of(best), range = best.location.range }
  end

  -- `DocumentSymbol[]` (a tree): descend through the symbols around the cursor.
  local found, path, in_function = nil, '', false
  local symbols = result
  while symbols do
    local inner
    for _, s in ipairs(symbols) do
      if s.range and contains(s.range) then inner = s; break end
    end
    if not inner then break end
    local kind = kind_of(inner)
    if not skip_kinds[kind] and (not in_function or function_kinds[kind] or kind == 'Class') then
      if path == '' or vim.startswith(inner.name, path .. '.') then
        path = inner.name
      else
        path = path .. (in_function and ' > ' or '.') .. inner.name
      end
      found = { name = path, kind = kind, range = inner.range }
      in_function = in_function or function_kinds[kind] == true
    end
    symbols = inner.children
  end
  return found
end

--- Describe the symbol around `win`'s cursor (default: current window).
---@param win? integer
---@return string?
M.describe = function(win)
  win = win or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local client = vim.lsp.get_clients({ bufnr = buf, method = METHOD })[1]
  if not client then return nil end

  local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }
  local response = client:request_sync(METHOD, params, TIMEOUT_MS, buf)
  local result = response and not response.err and response.result
  if type(result) ~= 'table' or #result == 0 then return nil end

  local symbol = find(result, vim.lsp.util.make_position_params(win, client.offset_encoding).position)
  if not symbol then return nil end

  local name = vim.api.nvim_buf_get_name(buf)
  local path = name == '' and '[scratch]' or vim.fn.fnamemodify(name, ':.')
  local first, last = symbol.range.start.line + 1, symbol.range['end'].line + 1
  local span = first == last and ('line ' .. first) or string.format('lines %d-%d', first, last)
  return string.format('%s `%s` in `%s` (%s)', (symbol.kind or 'symbol'):lower(), symbol.name, path, span)
end

return M
