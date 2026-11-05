-- ┌──────────────────────────────────────┐
-- │ Terminal buffers: what they run, who │
-- │ owns them, where files open          │
-- └──────────────────────────────────────┘
--
-- The terminal dock ('plugin/23_terminal.lua'), clickable paths
-- ('plugin/23_terminal_links.lua') and sidekick chat adoption
-- ('plugin/45_sidekick.lua') all ask the same questions about terminal
-- buffers, restored ones included. They ask here:
--
-- - `info(buf)`             `{ cwd, executable, running }`, nil if `buf`
--                           is not a terminal. `cwd` follows the shell (OSC 7,
--                           see `:h terminal-osc7`), else the directory it
--                           started in. `running`: its job is still alive.
-- - `claim(executables)`    terminals running one of these belong to another
--                           feature; `claimed(buf)` reports it. The terminal
--                           dock leaves claimed terminals alone.
-- - `is_editor_win(win)`    a normal (not floating) window showing a file buffer.
-- - `editor_win(exclude)`   where to open a file: the current window, the
--                           previous one, then any editor window that may
--                           change buffer (not 'winfixbuf').

local M = {}

-- `term://{cwd}//{pid}:{cmd}`: kept by session files for restored terminals.
M.info = function(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= 'terminal' then return nil end
  local name = vim.api.nvim_buf_get_name(buf)
  local start_cwd, command = name:match('^term://(.-)//%d+:(.*)$')
  command = command or ''
  local job = vim.b[buf].terminal_job_id
  return {
    -- No `term://` name: the directory of the window showing it, else global.
    cwd = vim.b[buf].osc7_dir or start_cwd or vim.fn.getcwd(vim.fn.bufwinid(buf)),
    executable = vim.fn.fnamemodify(command:match('^(%S+)') or '', ':t'),
    running = type(job) == 'number' and job > 0 and vim.fn.jobwait({ job }, 0)[1] == -1,
  }
end

local claimed = {}

---@param executables string[]
M.claim = function(executables)
  for _, exe in ipairs(executables) do
    claimed[exe] = true
  end
end

M.claimed = function(buf)
  local info = M.info(buf)
  return info ~= nil and claimed[info.executable] == true
end

M.is_editor_win = function(win)
  if not (win and vim.api.nvim_win_is_valid(win)) or vim.api.nvim_win_get_config(win).relative ~= '' then return false end
  return vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ''
end

M.editor_win = function(exclude)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  table.insert(wins, 1, vim.fn.win_getid(vim.fn.winnr('#')))
  table.insert(wins, 1, vim.api.nvim_get_current_win())
  for _, win in ipairs(wins) do
    if win ~= exclude and M.is_editor_win(win) and not vim.wo[win].winfixbuf then return win end
  end
end

-- Track the shell's directory as it changes (`:h terminal-osc7`).
vim.api.nvim_create_autocmd('TermRequest', {
  group = vim.api.nvim_create_augroup('config-term-osc7', {}),
  desc = 'Track terminal shell directory (OSC 7)',
  callback = function(ev)
    local dir = (ev.data and ev.data.sequence or ''):match('^\027%]7;file://[^/]*(/.*)')
    if not dir then return end
    dir = dir:gsub('\027\\$', ''):gsub('\007$', ''):gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end)
    if vim.fn.isdirectory(dir) == 1 then vim.b[ev.buf].osc7_dir = dir end
  end,
})

return M
