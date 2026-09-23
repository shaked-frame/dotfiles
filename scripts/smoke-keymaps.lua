-- Smoke lint: every <Leader> mapping must be defined at exactly one site.
-- Run headless after full startup:
--   nvim --headless -c "lua dofile('scripts/smoke-keymaps.lua')" -c "qa"
-- Exits silently on success; prints DUPLICATE lines (one per offending
-- mode+lhs with distinct definition sites) on failure.

local function norm_lhs(lhs)
  local l = lhs:gsub('^ ', '<Space>')
  if l:find('^<Leader>') then l = l:gsub('^<Leader>', '<Space>', 1) end
  return l
end

local seen = {}
for _, mode in ipairs({ 'n', 'x', 'v', 'i', 't', 'o', 'c' }) do
  for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
    local lhs = norm_lhs(m.lhs)
    if lhs:find('^<Space>') then
      local src = 'rhs:' .. (m.rhs or '')
      if m.callback then
        local info = debug.getinfo(m.callback, 'S')
        src = (info.short_src or '?') .. ':' .. (info.linedefined or '?')
      end
      local key = mode .. ' ' .. lhs
      seen[key] = seen[key] or {}
      table.insert(seen[key], src)
    end
  end
end

local failed = false
local keys = vim.tbl_keys(seen)
table.sort(keys)
for _, key in ipairs(keys) do
  local sites = {}
  for _, s in ipairs(seen[key]) do sites[s] = true end
  if vim.tbl_count(sites) > 1 then
    failed = true
    print('DUPLICATE ' .. key .. ' <- ' .. table.concat(vim.tbl_keys(sites), ' | '))
  end
end

if not failed then print('keymaps: no duplicates') end
