-- Smoke lint and startup verification.
--
-- Can be invoked in two ways:
-- 1. Pre-startup hook + post-startup verification (used by `scripts/smoke.sh`):
--      nvim --headless --cmd "cd /tmp" \
--        --cmd "lua dofile('scripts/smoke-keymaps.lua')" \
--        -c "lua SmokeVerify()" -c "qa"
-- 2. Standalone after startup:
--      nvim --headless -c "lua dofile('scripts/smoke-keymaps.lua')" -c "qa"

local function norm_lhs(lhs)
  local l = lhs:gsub('^ ', '<Space>'):gsub('^<[Ll]eader>', '<Space>')
  return vim.fn.keytrans(vim.keycode(l))
end

local function expand_modes(modes)
  local list = type(modes) == 'table' and modes or { modes }
  local out = {}
  for _, m in ipairs(list) do
    if m == '' then
      vim.list_extend(out, { 'n', 'x', 's', 'o' })
    elseif m == 'v' then
      vim.list_extend(out, { 'x', 's' })
    elseif m == '!' then
      vim.list_extend(out, { 'i', 'c' })
    else
      table.insert(out, m)
    end
  end
  return out
end

local function caller_site()
  for level = 3, 8 do
    local info = debug.getinfo(level, 'Sl')
    if not info then break end
    local src = info.short_src or '?'
    local line = info.currentline or 0
    local is_helper = (src:find('20_keymaps%.lua$') and (line <= 25 or line == 180 or line == 183))
      or (src:find('40_plugins%.lua$') and line >= 445 and line <= 460)
      or (src:find('43_octo%.lua$') and line >= 158 and line <= 161)
    if not is_helper then
      return src .. ':' .. tostring(line)
    end
  end
  local fallback = debug.getinfo(3, 'Sl')
  return ((fallback and fallback.short_src) or '?') .. ':' .. ((fallback and fallback.currentline) or '?')
end

if not _G._smoke_hooked then
  _G._smoke_hooked = true
  _G._smoke_active = {}
  _G._smoke_history = {}
  _G._smoke_overwrites = {}

  local orig_set = vim.keymap.set
  local orig_del = vim.keymap.del

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.keymap.set = function(modes, lhs, rhs, opts)
    opts = opts or {}
    if not opts.buffer and not opts.buf then
      local norm = norm_lhs(lhs)
      local site = caller_site()
      for _, m in ipairs(expand_modes(modes)) do
        local key = m .. ' ' .. norm
        if _G._smoke_active[key] ~= nil then
          _G._smoke_overwrites[key] = _G._smoke_overwrites[key] or { _G._smoke_active[key] }
          table.insert(_G._smoke_overwrites[key], site)
        end
        _G._smoke_active[key] = site
        _G._smoke_history[key] = _G._smoke_history[key] or {}
        table.insert(_G._smoke_history[key], site)
      end
    end
    return orig_set(modes, lhs, rhs, opts)
  end

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.keymap.del = function(modes, lhs, opts)
    opts = opts or {}
    if not opts.buffer and not opts.buf then
      local norm = norm_lhs(lhs)
      for _, m in ipairs(expand_modes(modes)) do
        local key = m .. ' ' .. norm
        _G._smoke_active[key] = nil
      end
    end
    return orig_del(modes, lhs, opts)
  end
end

_G.SmokeVerify = function()
  local failed = false
  local fail = function(msg)
    failed = true
    print('FAIL ' .. msg)
  end

  -- 1. Drain deferred Config.later() callbacks.
  if _G.Config and _G.Config.later_pending ~= nil then
    local ok = vim.wait(5000, function() return _G.Config.later_pending == 0 end, 5)
    if not ok then
      fail('Config.later() queue did not drain (pending=' .. tostring(_G.Config.later_pending) .. ')')
    end
  end

  -- 2. Check for unapproved global keymap overwrites captured by the hook.
  local overwrite_keys = vim.tbl_keys(_G._smoke_overwrites or {})
  table.sort(overwrite_keys)
  for _, key in ipairs(overwrite_keys) do
    failed = true
    print('DUPLICATE ' .. key .. ' <- ' .. table.concat(_G._smoke_overwrites[key], ' -> '))
  end

  -- 3. Check final keymap table for overlapping <Leader> mappings across modes.
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

  -- 4. Assert core modules and adapters are ready after deferred startup.
  if not (_G.Config and _G.Config.conform_ready == true) then
    fail('Config.conform_ready is not true after startup drain')
  end
  if not (_G.Config and _G.Config.Explorer and type(_G.Config.Explorer.open_cwd) == 'function') then
    fail('Config.Explorer is not ready')
  end
  if not (_G.Config and _G.Config.Agent and _G.Config.Agent.active_adapter() ~= nil) then
    fail('Config.Agent active_adapter() is nil')
  end

  -- 5. Assert Leader prefix clues cover every multi-key <Leader> group.
  if _G.Config and type(_G.Config.leader_group_clues) == 'table' then
    local clues = {}
    for _, c in ipairs(_G.Config.leader_group_clues) do
      clues[c.mode .. ' ' .. norm_lhs(c.keys)] = true
    end
    for _, mode in ipairs({ 'n', 'x' }) do
      local direct = {}
      local prefixes = {}
      for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
        local lhs = norm_lhs(m.lhs)
        direct[mode .. ' ' .. lhs] = true
        local group = lhs:match('^<Space>([a-zA-Z])[^a-zA-Z0-9]*$')
        if not group then
          local g1 = lhs:match('^<Space>([a-zA-Z]).+$')
          if g1 then prefixes[mode .. ' <Space>' .. g1] = true end
        end
      end
      for p, _ in pairs(prefixes) do
        if not clues[p] and not direct[p] then
          fail('Missing Config.leader_group_clues entry for ' .. p)
        end
      end
    end
  end

  -- 6. Verify MDX tree-sitter alias and syntax fold configuration.
  vim.cmd('edit /tmp/smoke_test.mdx')
  if vim.bo.filetype ~= 'mdx' then
    fail('Expected /tmp/smoke_test.mdx filetype=mdx, got ' .. tostring(vim.bo.filetype))
  end
  if vim.treesitter.language.get_lang('mdx') ~= 'markdown' then
    fail('Expected mdx tree-sitter language alias to resolve to markdown')
  end
  if vim.wo.foldmethod ~= 'expr' then
    fail('Expected mdx foldmethod=expr, got ' .. tostring(vim.wo.foldmethod))
  end

  if not failed then print('keymaps: no duplicates') end
end

-- If invoked after startup via `-c "lua dofile('scripts/smoke-keymaps.lua')"`,
-- run verification immediately.
if _G.Config ~= nil then
  _G.SmokeVerify()
end
