-- Run: nvim --headless -u NONE -l scripts/test-nes-repair.lua
-- 'lua/config/nes_repair.lua' fixes Copilot next-edit ranges that disagree
-- with their text. The first case is a real `copilotInlineEdit` response:
-- the range stops at `| 'recipient_ids'` while the text rewrites through the
-- function's closing `}`. Needs the tree-sitter TypeScript parser that
-- 'nvim-treesitter' installs under stdpath('data')/site.
local repo = vim.fn.getcwd()
vim.opt.rtp:prepend(repo .. '/home/dot_config/nvim')
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/site')
local repair = require('config.nes_repair')
assert(pcall(vim.treesitter.language.add, 'typescript'), 'no typescript parser')

local failures = {}
local check = function(name, cond, detail)
  if not cond then table.insert(failures, name .. (detail and (': ' .. detail) or '')) end
end

--- Apply `edit` (after repair) to `lines` in a scratch buffer; return the text.
local run = function(lines, edit)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. '.ts')
  vim.bo[buf].filetype = 'typescript'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.lsp.util.buf_versions[buf] = 7
  edit.textDocument = { uri = vim.uri_from_bufnr(buf), version = 7 }
  local repaired = repair.edit(edit, 'utf-16')
  vim.lsp.util.apply_text_edits({ { range = edit.range, newText = edit.text } }, buf, 'utf-16')
  local out = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
  vim.api.nvim_buf_delete(buf, { force = true })
  return out, repaired
end

local range = function(l1, c1, l2, c2)
  return { start = { line = l1, character = c1 }, ['end'] = { line = l2, character = c2 } }
end

-- 1. Real response: text runs past the range end ==========================
local file = {
  "type PhishingEventsSearchParams = { search?: string; campaign_ids?: string[]; event_type?: string; recipient_ids?: string[]; including_filtered?: boolean; page?: number };",
  '',
  'type PhishingEventsFiltersProps = Pick<',
  '  PhishingEventsSearchParams,',
  "  | 'search'",
  "  | 'campaign_ids'",
  "  | 'event_type'",
  "  | 'recipient_ids'",
  "  | 'including_filtered'",
  '>;',
  '',
  'export function phishingEventsFilters({',
  '  search,',
  '  campaign_ids,',
  '  event_type,',
  '  recipient_ids,',
  '  including_filtered,',
  '}: Pick<',
  '  PhishingEventsSearchParams,',
  "  | 'search'",
  "  | 'campaign_ids'",
  "  | 'event_type'",
  "  | 'recipient_ids'",
  "  | 'including_filtered'",
  '>) {',
  '  return {',
  '    search,',
  '    campaign_ids,',
  '    event_type,',
  '    recipient_ids,',
  '    including_filtered,',
  '  };',
  '}',
}
local body = table.concat({
  '  return {',
  '    search,',
  '    campaign_ids,',
  '    event_type,',
  '    recipient_ids,',
  '    including_filtered,',
  '  };',
  '}',
}, '\n')
local want = table.concat(vim.list_slice(file, 1, 17), '\n') .. '\n}: PhishingEventsFiltersProps) {\n' .. body
local out, repaired = run(file, { range = range(17, 0, 22, 19), text = '}: PhishingEventsFiltersProps) {\n' .. body })
check('overrun: repaired', repaired)
check('overrun: result', out == want, '\n' .. out)

-- 2. Text repeats the `>` right after the range ===========================
local small = { 'type A = { a: 1; b: 2 };', 'type P = Pick<A, "a">;', 'export const x = 1;' }
out = run(small, { range = range(1, 9, 1, 20), text = 'Pick<A, "a" | "b">' })
check('doubled >', out:find('type P = Pick<A, "a" | "b">;', 1, true) ~= nil, out)

-- 3. Range covers a `>` the text leaves out ===============================
out = run(small, { range = range(1, 9, 1, 21), text = 'Pick<A, "a" | "b"' })
check('missing >', out:find('type P = Pick<A, "a" | "b">;', 1, true) ~= nil, out)

-- 4. A correct edit is left alone =========================================
local ok_edit = { range = range(1, 9, 1, 21), text = 'Pick<A, "b">' }
out, repaired = run(small, ok_edit)
check('clean: untouched', not repaired)
check('clean: result', out:find('type P = Pick<A, "b">;', 1, true) ~= nil, out)

-- 5. Stale version: no repair =============================================
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. '.ts')
vim.bo[buf].filetype = 'typescript'
vim.api.nvim_buf_set_lines(buf, 0, -1, false, small)
vim.lsp.util.buf_versions[buf] = 3
check('stale: untouched', not repair.edit({
  range = range(1, 9, 1, 20),
  text = 'Pick<A, "a" | "b">',
  textDocument = { uri = vim.uri_from_bufnr(buf), version = 2 },
}, 'utf-16'))

if #failures > 0 then
  io.stderr:write(table.concat(failures, '\n') .. '\n')
  os.exit(1)
end
print('ok')
