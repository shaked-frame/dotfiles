-- ┌──────────────────────────────────────────────┐
-- │ Next Edit Suggestions: repair a bad range    │
-- └──────────────────────────────────────────────┘
--
-- Copilot's `textDocument/copilotInlineEdit` sometimes returns a range that
-- does not match its text: the text rewrites code past the range end (or
-- before its start), or drops a closing bracket the range covers. Applied as
-- sent, the old tail survives next to the new one: `>` or `}` doubled,
-- missing, or whole blocks repeated. VS Code diffs a suggestion against the
-- file before applying it, so it never shows these; sidekick applies the
-- range verbatim.
--
-- `M.edit()` runs on each edit before sidekick sees it ('plugin/45_sidekick.lua').
-- Only when the edit as sent would leave tree-sitter errors, it tries nearby
-- ranges where the text overlaps the code around it, and keeps the one that
-- parses with the fewest errors (strictly fewer than as sent). With no parser
-- for the buffer, or no better range, the edit is left untouched.

local M = {}

-- Overlap shorter than this is only trusted when it touches the range.
local MIN_DISTANT = 20
-- How far past the range ends to look for overlap, in bytes.
local WINDOW = 4000

--- Number of ERROR and MISSING nodes under `node`.
---@param node TSNode
---@return integer
M.count_errors = function(node)
  if not node:has_error() then return 0 end
  local n = (node:type() == 'ERROR' or node:missing()) and 1 or 0
  for child in node:iter_children() do
    n = n + M.count_errors(child)
  end
  return n
end

--- Errors in `src` parsed as `lang`, or nil when there is no parser.
---@param src string
---@param lang string
---@return integer?
local errors_in = function(src, lang)
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, lang)
  if not (ok and parser) then return nil end
  local ok_parse, trees = pcall(parser.parse, parser)
  if not (ok_parse and trees and trees[1]) then return nil end
  return M.count_errors(trees[1]:root())
end

--- Errors in buffer `buf`, or nil when it has no parser.
---@param buf integer
---@return integer?
M.buf_errors = function(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if not (ok and parser) then return nil end
  local tree = parser:parse()[1]
  return tree and M.count_errors(tree:root()) or nil
end

--- Candidate start offsets (0-based, into `src`) for replacing `text` at `[s, e)`.
local start_candidates = function(src, s, text)
  local out = { s }
  local before = src:sub(math.max(1, s - WINDOW + 1), s)
  local base = s - #before -- offset of `before`'s first byte
  -- The text starts with what is right before the range: move the start back.
  for len = math.min(#text, #before), 1, -1 do
    if before:sub(-len) == text:sub(1, len) then
      table.insert(out, s - len)
      break
    end
  end
  -- The text starts by rewriting code further up: start where it matches.
  for len = math.min(#text, #before), MIN_DISTANT, -1 do
    local head, at = text:sub(1, len), nil
    local from = 1
    while true do -- last occurrence, the one closest to the range
      local i = before:find(head, from, true)
      if not i then break end
      at, from = i, i + 1
    end
    if at then
      table.insert(out, base + at - 1)
      break
    end
  end
  -- The range takes opening punctuation the text leaves out.
  for n = 1, 3 do
    local ch = src:sub(s + n, s + n)
    if not ch:match('^[%(%[{<]$') then break end
    table.insert(out, s + n)
  end
  return out
end

--- Candidate end offsets (0-based, exclusive) for replacing `text` at `[s, e)`.
local end_candidates = function(src, s, e, text)
  local out = { e }
  local after = src:sub(e + 1, e + WINDOW)
  -- The text ends with what follows the range: move the end forward.
  for len = math.min(#text, #after), 1, -1 do
    if after:sub(1, len) == text:sub(-len) then
      table.insert(out, e + len)
      break
    end
  end
  -- The text ends by rewriting code further down: end where it matches.
  for len = math.min(#text, #after), MIN_DISTANT, -1 do
    local i = after:find(text:sub(-len), 2, true)
    if i then
      table.insert(out, e + i - 1 + len)
      break
    end
  end
  -- The range takes closing punctuation the text leaves out.
  for n = 1, 3 do
    if e - n < s then break end
    local ch = src:sub(e - n + 1, e - n + 1)
    if not ch:match('^[%)%]}>;,]$') then break end
    table.insert(out, e - n)
  end
  return out
end

--- Best `[s, e)` for replacing `text` into `src`, or nil to keep the original.
---@param src string
---@param s integer 0-based start offset
---@param e integer 0-based exclusive end offset
---@param text string
---@param lang string
---@return integer?, integer?
M.range = function(src, s, e, text, lang)
  local apply = function(a, b) return src:sub(1, a) .. text .. src:sub(b + 1) end
  local base = errors_in(apply(s, e), lang)
  if base == nil or base == 0 then return nil end

  local best, best_s, best_e, best_moved = base, nil, nil, math.huge
  local seen = {}
  for _, a in ipairs(start_candidates(src, s, text)) do
    for _, b in ipairs(end_candidates(src, s, e, text)) do
      local key = a .. ':' .. b
      if a <= b and not seen[key] and (a ~= s or b ~= e) then
        seen[key] = true
        local n = errors_in(apply(a, b), lang)
        local moved = math.abs(a - s) + math.abs(b - e)
        if n and (n < best or (n == best and best_s and moved < best_moved)) then
          best, best_s, best_e, best_moved = n, a, b, moved
        end
      end
    end
  end
  return best_s, best_e
end

-- LSP position <-> byte offset into the buffer joined with "\n".
local to_offset = function(lines, starts, pos, enc)
  local line = lines[pos.line + 1]
  if line == nil then return starts[#starts] + #lines[#lines] end
  local ok, col = pcall(vim.str_byteindex, line, enc, pos.character, false)
  return starts[pos.line + 1] + (ok and col or #line)
end

local to_pos = function(lines, starts, offset, enc)
  local row = #starts
  for i = 1, #starts do
    if starts[i] > offset then
      row = i - 1
      break
    end
  end
  local col = offset - starts[row]
  return { line = row - 1, character = vim.str_utfindex(lines[row], enc, col, false) }
end

--- Repair `edit.range` in place (a `copilotInlineEdit` result item).
---@param edit {range: lsp.Range, text: string, textDocument: {uri: string, version: integer}}
---@param enc string client offset encoding
---@return boolean repaired
M.edit = function(edit, enc)
  if type(edit.text) ~= 'string' or not (edit.range and edit.textDocument) then return false end
  local buf = vim.fn.bufnr(vim.uri_to_fname(edit.textDocument.uri), false)
  if buf == -1 or not vim.api.nvim_buf_is_loaded(buf) then return false end
  if edit.textDocument.version ~= vim.lsp.util.buf_versions[buf] then return false end
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not lang then return false end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local starts, offset = {}, 0
  for i, line in ipairs(lines) do
    starts[i] = offset
    offset = offset + #line + 1
  end
  local src = table.concat(lines, '\n')

  local s = to_offset(lines, starts, edit.range.start, enc)
  local e = to_offset(lines, starts, edit.range['end'], enc)
  local new_s, new_e = M.range(src, s, e, edit.text, lang)
  if not new_s then return false end
  edit.range = { start = to_pos(lines, starts, new_s, enc), ['end'] = to_pos(lines, starts, new_e, enc) }
  return true
end

return M
