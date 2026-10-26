-- Open paths from terminal output in an editor window, keeping the job alive.
-- Mouse mappings live in '20_keymaps.lua'; gf is local to terminal scrollback.

Config.TerminalLinks = {}
local links = Config.TerminalLinks

-- Match the clicked location, not just the first filename on a diagnostic line.
-- Parentheses and square brackets can be part of route directory names.
links.location = function(text, column)
  local filename = [[([^%s:"'`<>|]+)]]
  for _, pattern in ipairs({ filename .. ':(%d+):(%d+)', filename .. '%((%d+),%s*(%d+)%)', filename .. ':(%d+)' }) do
    local from = 1
    while true do
      local first, last, path, line, col = text:find(pattern, from)
      if not first then break end
      if first <= column and column <= last then
        -- Stack traces put an extra '(' before the path: fn (/path:12:4).
        local _, opens = path:gsub('%(', '')
        local _, closes = path:gsub('%)', '')
        if opens > closes then path = path:gsub('^%(', '') end
        return { path = path, line = tonumber(line), col = tonumber(col) or 1 }
      end
      from = last + 1
    end
  end
  for first, path, last in text:gmatch('()([^%s"\'`<>|]+)()') do
    if first <= column and column < last then
      path = path:gsub('[,;:]$', '')
      if path:find('/', 1, true) or path:match('%.[%w]+$') then return { path = path, line = 1, col = 1 } end
    end
  end
end

local terminal_cwd = function(buf, win)
  return vim.b[buf].terminal_link_cwd
    or vim.api.nvim_buf_get_name(buf):match('^term://(.-)//%d+:')
    or vim.fn.getcwd(win)
end

local editor_window = function(source)
  local current = vim.api.nvim_get_current_win()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  -- Prefer the editor the user is already in, then the alternate editor window.
  table.insert(wins, 1, vim.fn.win_getid(vim.fn.winnr('#')))
  table.insert(wins, 1, current)
  for _, win in ipairs(wins) do
    if win ~= source and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == '' then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == '' and not vim.wo[win].winfixbuf then return win end
    end
  end
end

local open_file = function(source, path, location)
  if not vim.api.nvim_win_is_valid(source) then return end
  vim.cmd('stopinsert')
  local target = editor_window(source)
  if target then
    vim.api.nvim_set_current_win(target)
  else
    -- Keep a lone terminal below the editor, never turn the dock into a side pane.
    vim.cmd('topleft new')
  end
  local ok, err = pcall(vim.cmd.edit, { args = { path } })
  if not ok then
    vim.notify(tostring(err), vim.log.levels.WARN)
    return
  end
  local line = math.max(1, math.min(location.line, vim.api.nvim_buf_line_count(0)))
  local text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ''
  vim.api.nvim_win_set_cursor(0, { line, math.max(0, math.min(location.col - 1, #text)) })
  vim.cmd('normal! zvzz')
end

links.open = function(win, row, column)
  if not vim.api.nvim_win_is_valid(win) or row < 1 then return end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= 'terminal' then return end
  local text = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ''
  local location = links.location(text, column)
  if not location then return end
  local cwd = terminal_cwd(buf, win)
  local path = location.path
  if path:sub(1, 2) == '~/' then path = vim.env.HOME .. path:sub(2) end
  if path:sub(1, 1) == '/' then
    if vim.fn.filereadable(path) == 1 then
      open_file(win, path, location)
    else
      vim.notify('File not found: ' .. path, vim.log.levels.WARN)
    end
    return
  end

  -- Try the shell directory, then ancestors up to the repository boundary.
  -- This handles output relative to either the package or the workspace root.
  local root = vim.fs.root(cwd, '.git') or cwd
  local base = cwd
  while base do
    local candidate = vim.fs.normalize(base .. '/' .. path)
    if vim.fn.filereadable(candidate) == 1 then
      open_file(win, candidate, location)
      return
    end
    if base == root then break end
    local parent = vim.fs.dirname(base)
    if parent == base then break end
    base = parent
  end

  -- Workspace runners can print package-relative paths while their shell stays
  -- at the root. Search on click only, asynchronously, and never guess between
  -- multiple packages with the same src/foo.ts path.
  if vim.fn.executable('rg') == 0 or path:sub(1, 3) == '../' then
    vim.notify('File not found: ' .. path, vim.log.levels.WARN)
    return
  end
  local suffix = '/' .. path:gsub('^%./', '')
  local command = { 'rg', '--files', '--hidden', '-g', '!.git', '-g', '!node_modules' }
  vim.system(command, { cwd = root, text = true, timeout = 2000 }, function(result)
    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then return end
      local matches = {}
      if result.code == 0 then
        for file in (result.stdout or ''):gmatch('[^\n]+') do
          if ('/' .. file):sub(-#suffix) == suffix then table.insert(matches, file) end
        end
      end
      table.sort(matches)
      if #matches == 1 then
        open_file(win, root .. '/' .. matches[1], location)
      elseif #matches > 1 then
        vim.ui.select(matches, { prompt = 'Open terminal path:' }, function(choice)
          if choice then open_file(win, root .. '/' .. choice, location) end
        end)
      else
        vim.notify('File not found: ' .. path, vim.log.levels.WARN)
      end
    end)
  end)
end

links.mouse = function(fallback)
  local mouse = vim.fn.getmousepos()
  if mouse.winid == 0 or mouse.line == 0 or not vim.api.nvim_win_is_valid(mouse.winid) then return fallback end
  local buf = vim.api.nvim_win_get_buf(mouse.winid)
  if vim.bo[buf].buftype ~= 'terminal' then return fallback end
  local text = vim.api.nvim_buf_get_lines(buf, mouse.line - 1, mouse.line, false)[1] or ''
  if not links.location(text, mouse.column) then return fallback end
  -- Expression mappings cannot switch windows or edit buffers directly.
  vim.schedule(function() links.open(mouse.winid, mouse.line, mouse.column) end)
  return ''
end

local attach = function(buf)
  vim.b[buf].terminal_link_cwd = terminal_cwd(buf, 0)
  vim.keymap.set('n', 'gf', function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    links.open(vim.api.nvim_get_current_win(), cursor[1], cursor[2] + 1)
  end, { buffer = buf, desc = 'Open terminal file at cursor' })
end

vim.api.nvim_create_autocmd('TermOpen', { callback = function(ev) attach(ev.buf) end })
vim.api.nvim_create_autocmd('TermRequest', {
  desc = 'Track terminal shell directory for clickable paths',
  callback = function(ev)
    local sequence = ev.data and ev.data.sequence or ''
    local dir = sequence:match('^\027%]7;file://[^/]*(/.*)')
    if not dir then return end
    dir = dir:gsub('\027\\$', ''):gsub('\007$', ''):gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end)
    if vim.fn.isdirectory(dir) == 1 then vim.b[ev.buf].terminal_link_cwd = dir end
  end,
})
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[buf].buftype == 'terminal' then attach(buf) end
end
