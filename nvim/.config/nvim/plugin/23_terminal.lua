-- ┌─────────────────────────────┐
-- │ Terminal dock (Zed parity)  │
-- └─────────────────────────────┘
--
-- Dedicated bottom terminal split with its own internal terminal tabs,
-- independent of editor buffers and 'bufferline.nvim'. Keymaps live in
-- 'plugin/20_keymaps.lua' plus buffer-local bindings attached here.

Config.Terminal = {}

local state = {
  items = {}, -- { { buf = number, name = string, cwd = string }, ... }
  active = 1,
  win = nil,
  height = 16,
  prev_win = nil,
  counter = 0,
}
local adopt_terminals

local is_valid_win = function(win)
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local is_valid_buf = function(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local prune_items = function()
  local kept = {}
  for _, item in ipairs(state.items) do
    if is_valid_buf(item.buf) then table.insert(kept, item) end
  end
  state.items = kept
  if #state.items == 0 then
    state.active = 1
  elseif state.active > #state.items then
    state.active = #state.items
  elseif state.active < 1 then
    state.active = 1
  end
end

local record_prev_win = function()
  local cur = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(cur)
  if cur ~= state.win and vim.bo[buf].buftype == '' and vim.api.nvim_win_get_config(cur).relative == '' then
    state.prev_win = cur
  end
end

local restore_prev_win = function()
  if is_valid_win(state.prev_win) and state.prev_win ~= state.win then
    vim.api.nvim_set_current_win(state.prev_win)
  end
end

local configure_dock_win = function(win)
  vim.wo[win].winfixheight = true
  vim.wo[win].winfixwidth = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  vim.wo[win].statuscolumn = ''
  vim.wo[win].spell = false
  vim.wo[win].winbar = '%!v:lua.Config.Terminal.winbar()'
end

local refresh_winbar = function()
  if not is_valid_win(state.win) then return end
  vim.wo[state.win].winbar = '%!v:lua.Config.Terminal.winbar()'
  vim.cmd('redrawstatus')
end

-- Click handlers for the dock winbar (`%@v:lua.Config.Terminal.click_N@`).
for i = 1, 9 do
  Config.Terminal['click_' .. i] = function()
    Config.Terminal.select(i)
  end
end

Config.Terminal.winbar = function()
  prune_items()
  local parts = {}
  for i, item in ipairs(state.items) do
    local hl = (i == state.active) and '%#MiniTablineCurrent#' or '%#MiniTablineHidden#'
    local click = (i <= 9) and ('%@v:lua.Config.Terminal.click_' .. i .. '@') or ''
    local end_click = (i <= 9) and '%X' or ''
    local safe_name = item.name:gsub('%%', '%%%%')
    table.insert(parts, string.format('%s%s  %d:%s  %s', hl, click, i, safe_name, end_click))
  end
  local right = '%#MiniTablineFill#%=%#MiniTablineHint# [H/L] tab  [t] new  [r] rename  [x] close  [q] hide '
  return table.concat(parts, '%#MiniTablineSeparator#│') .. right .. '%#MiniTablineFill#'
end

local ensure_dock_win = function()
  adopt_terminals()
  if is_valid_win(state.win) then return state.win end

  record_prev_win()
  vim.cmd('botright ' .. tostring(state.height) .. 'split')
  state.win = vim.api.nvim_get_current_win()
  configure_dock_win(state.win)
  return state.win
end

local show_active_buf = function(enter_insert)
  prune_items()
  if #state.items == 0 then return end
  local win = ensure_dock_win()
  local target = state.items[state.active].buf
  if vim.api.nvim_win_get_buf(win) ~= target then
    vim.api.nvim_win_set_buf(win, target)
  end
  configure_dock_win(win)
  vim.api.nvim_set_current_win(win)
  refresh_winbar()
  if enter_insert then vim.cmd('startinsert') end
end

local attach_buf_keymaps = function(buf)
  local map = function(modes, lhs, rhs, desc)
    vim.keymap.set(modes, lhs, rhs, { buffer = buf, silent = true, nowait = true, desc = desc })
  end

  -- Escape from Terminal mode to Normal mode for scrollback and tab keys.
  map('t', '<Esc><Esc>', [[<C-\><C-n>]], 'Normal mode in terminal')

  -- Cycle terminal tabs directly from either mode.
  map({ 'n', 't' }, '<S-Left>',  function() Config.Terminal.prev() end, 'Previous terminal tab')
  map({ 'n', 't' }, '<S-Right>', function() Config.Terminal.next() end, 'Next terminal tab')

  -- Normal-mode dock controls (matches H/L editor buffer navigation).
  map('n', 'H', function() Config.Terminal.prev() end,   'Previous terminal tab')
  map('n', 'L', function() Config.Terminal.next() end,   'Next terminal tab')
  map('n', 't', function() Config.Terminal.new() end,    'New terminal tab')
  map('n', 'r', function() Config.Terminal.rename() end, 'Rename terminal tab')
  map('n', 'x', function() Config.Terminal.close() end,  'Close terminal tab')
  map('n', 'q', function() Config.Terminal.hide() end,   'Hide terminal dock')

  for i = 1, 9 do
    map('n', tostring(i), function() Config.Terminal.select(i) end, 'Terminal tab ' .. i)
  end
end

local remove_buf_item = function(buf)
  local removed_idx = nil
  for i, item in ipairs(state.items) do
    if item.buf == buf then
      removed_idx = i
      table.remove(state.items, i)
      break
    end
  end
  if removed_idx == nil then return end

  if #state.items == 0 then
    state.active = 1
    if is_valid_win(state.win) then
      local w = state.win
      state.win = nil
      restore_prev_win()
      if is_valid_win(w) and #vim.api.nvim_tabpage_list_wins(0) > 1 then
        pcall(vim.api.nvim_win_close, w, true)
      end
    end
  else
    if state.active > #state.items then state.active = #state.items end
    if is_valid_win(state.win) then
      local next_buf = state.items[state.active].buf
      vim.api.nvim_win_set_buf(state.win, next_buf)
      configure_dock_win(state.win)
      refresh_winbar()
    end
  end

  if is_valid_buf(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

-- Session files restart terminal jobs but cannot restore this module's Lua
-- registry. Ordinary :terminal buffers also bypass new(). Adopt their jobs,
-- not their processes, and consolidate their visible splits into one dock.
adopt_terminals = function()
  prune_items()
  local tab = vim.api.nvim_get_current_tabpage()
  -- Preserve the existing cross-tab toggle behavior; don't consolidate this
  -- tab's windows into a dock that currently belongs to another tabpage.
  if is_valid_win(state.win) and vim.api.nvim_win_get_tabpage(state.win) ~= tab then return end
  local tracked = {}
  for _, item in ipairs(state.items) do tracked[item.buf] = true end

  if is_valid_win(state.win) and not tracked[vim.api.nvim_win_get_buf(state.win)] then
    -- The user opened an editor buffer in the old dock window.
    vim.wo[state.win].winfixheight = false
    vim.wo[state.win].winbar = ''
    state.win = nil
  end

  local adopted_current
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local ft = vim.bo[buf].filetype
    local name = vim.api.nvim_buf_get_name(buf)
    local command = name:match('^term://.-//%d+:(.*)') or ''
    local executable = vim.fn.fnamemodify(command:match('^(%S+)') or '', ':t')
    local managed_tool = ({ opencode = true, claude = true, codex = true, pi = true, lazygit = true })[executable]
    local eligible = vim.bo[buf].buftype == 'terminal' and (ft == '' or ft == 'terminal') and not managed_tool
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.api.nvim_win_get_config(win).relative ~= '' or vim.api.nvim_win_get_tabpage(win) ~= tab then eligible = false end
    end
    if eligible and not tracked[buf] then
      local job = vim.b[buf].terminal_job_id
      if type(job) == 'number' and vim.fn.jobwait({ job }, 0)[1] == -1 then
        state.counter = state.counter + 1
        local label = vim.b[buf].terminal_dock_name or (executable .. '-' .. state.counter)
        local cwd = vim.b[buf].terminal_link_cwd or name:match('^term://(.-)//%d+:') or vim.fn.getcwd()
        table.insert(state.items, { buf = buf, name = label, cwd = cwd })
        tracked[buf] = true
        if buf == vim.api.nvim_get_current_buf() then adopted_current = buf end
        vim.b[buf].is_dock_terminal = true
        vim.b[buf].terminal_dock_name = label
        vim.bo[buf].buflisted = false
        vim.bo[buf].bufhidden = 'hide'
        attach_buf_keymaps(buf)
      end
    end
  end

  local windows = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if tracked[vim.api.nvim_win_get_buf(win)] and vim.api.nvim_win_get_config(win).relative == '' then
      table.insert(windows, win)
    end
  end
  if #windows == 0 then return end
  record_prev_win()
  if not is_valid_win(state.win) then
    state.win = windows[#windows]
    local buf = adopted_current or vim.api.nvim_win_get_buf(state.win)
    for i, item in ipairs(state.items) do
      if item.buf == buf then state.active = i break end
    end
  elseif adopted_current then
    for i, item in ipairs(state.items) do
      if item.buf == adopted_current then state.active = i break end
    end
  end
  if adopted_current then
    vim.api.nvim_win_set_buf(state.win, adopted_current)
  end

  -- Leave an editor window to return to, even if only terminals were restored.
  if #windows == #vim.api.nvim_tabpage_list_wins(tab) then
    vim.cmd('topleft new')
    state.prev_win = vim.api.nvim_get_current_win()
  end
  configure_dock_win(state.win)
  for _, win in ipairs(windows) do
    if win ~= state.win then vim.api.nvim_win_close(win, false) end
  end
  local layout = vim.fn.winlayout()
  local bottom = layout[1] == 'col' and layout[2][#layout[2]] or nil
  if not (bottom and bottom[1] == 'leaf' and bottom[2] == state.win) then
    vim.api.nvim_win_call(state.win, function()
      vim.cmd('wincmd J')
      vim.api.nvim_win_set_height(0, state.height)
    end)
  end
end

Config.Terminal.new = function(name)
  prune_items()
  local cwd = vim.fn.getcwd()
  local win = ensure_dock_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buflisted = false
  vim.b[buf].is_dock_terminal = true

  state.counter = state.counter + 1
  local shell_name = vim.fn.fnamemodify(vim.o.shell, ':t')
  local label = (name and name ~= '') and name or (state.counter == 1 and shell_name or (shell_name .. '-' .. state.counter))
  vim.b[buf].terminal_dock_name = label

  table.insert(state.items, { buf = buf, name = label, cwd = cwd })
  state.active = #state.items

  vim.api.nvim_win_set_buf(win, buf)
  configure_dock_win(win)
  attach_buf_keymaps(buf)

  vim.fn.jobstart({ vim.o.shell }, {
    term = true,
    cwd = cwd,
    on_exit = function()
      vim.schedule(function() remove_buf_item(buf) end)
    end,
  })

  vim.bo[buf].buflisted = false
  vim.api.nvim_set_current_win(win)
  refresh_winbar()
  vim.cmd('startinsert')
end

Config.Terminal.hide = function()
  if not is_valid_win(state.win) then return end
  state.height = vim.api.nvim_win_get_height(state.win)
  local w = state.win
  state.win = nil
  restore_prev_win()
  if is_valid_win(w) and #vim.api.nvim_tabpage_list_wins(0) > 1 then
    vim.api.nvim_win_close(w, false)
  end
end

Config.Terminal.open = function()
  adopt_terminals()
  if #state.items == 0 then
    Config.Terminal.new()
    return
  end
  show_active_buf(true)
end

Config.Terminal.toggle = function()
  adopt_terminals()
  if is_valid_win(state.win) then
    if vim.api.nvim_get_current_win() == state.win then
      Config.Terminal.hide()
    else
      record_prev_win()
      vim.api.nvim_set_current_win(state.win)
      vim.cmd('startinsert')
    end
    return
  end
  Config.Terminal.open()
end

local switch_to = function(idx)
  prune_items()
  if #state.items == 0 then return end
  local was_term_mode = vim.fn.mode() == 't'
  state.active = ((idx - 1) % #state.items) + 1
  show_active_buf(was_term_mode)
end

Config.Terminal.next = function()
  switch_to(state.active + 1)
end

Config.Terminal.prev = function()
  switch_to(state.active - 1)
end

Config.Terminal.select = function(idx)
  prune_items()
  if idx < 1 or idx > #state.items then return end
  switch_to(idx)
end

Config.Terminal.rename = function()
  prune_items()
  local cur = state.items[state.active]
  if cur == nil then return end
  vim.ui.input({ prompt = 'Terminal name: ', default = cur.name }, function(input)
    if input and input ~= '' then
      cur.name = input
      vim.b[cur.buf].terminal_dock_name = input
      refresh_winbar()
    end
  end)
end

Config.Terminal.close = function()
  prune_items()
  local cur = state.items[state.active]
  if cur == nil then return end
  remove_buf_item(cur.buf)
end

Config.Terminal.pick = function()
  adopt_terminals()
  if #state.items == 0 then
    Config.Terminal.new()
    return
  end
  local items = {}
  for i, item in ipairs(state.items) do
    local mark = (i == state.active) and '*' or ' '
    table.insert(items, {
      text = string.format('%s %d: %s  (%s)', mark, i, item.name, vim.fn.fnamemodify(item.cwd, ':~')),
      idx = i,
    })
  end
  MiniPick.start({
    source = {
      name = 'Terminal tabs',
      items = items,
      choose = function(chosen)
        if chosen == nil then return end
        vim.schedule(function()
          state.active = chosen.idx
          show_active_buf(true)
        end)
      end,
    },
  })
end

-- Remember the dock height whenever splits are resized, and keep `state.prev_win`
-- pointing at the last non-dock window the user visited.
Config.new_autocmd('WinResized', nil, function()
  if is_valid_win(state.win) then
    state.height = vim.api.nvim_win_get_height(state.win)
  end
end, 'Remember terminal dock height')

Config.new_autocmd('WinLeave', nil, function()
  record_prev_win()
end, 'Track previous editor window for terminal dock')

Config.new_autocmd('SessionLoadPost', nil, function()
  vim.schedule(adopt_terminals)
end, 'Adopt restored terminals into the bottom dock')

Config.new_autocmd({ 'TermClose', 'BufWipeout' }, nil, function(ev)
  vim.schedule(function() remove_buf_item(ev.buf) end)
end, 'Remove closed adopted terminal tabs')
