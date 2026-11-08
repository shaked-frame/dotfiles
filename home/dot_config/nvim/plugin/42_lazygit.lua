-- ┌─────────────────────┐
-- │ LazyGit Integration │
-- └─────────────────────┘
--
-- Keep LazyGit-specific runtime behavior here instead of in '40_plugins.lua'.
--
-- Goal:
-- - Open LazyGit in a Neovim float via `Snacks.lazygit` (`<Leader>gg`), or on
--   the current file's log (`<Leader>gG`).
-- - When pressing `e` inside LazyGit, reuse the current Neovim instance.
-- - Open the target file in a normal editing window/buffer, not inside the
--   LazyGit terminal float.
-- - Hide the LazyGit float after opening the file (LazyGit keeps running, so
--   the next `<Leader>gg` is instant).
--
-- Approach:
-- - Neovim always runs an RPC server and hands its address to terminal jobs
--   as `$NVIM`, so LazyGit can call back without any setup.
-- - A LazyGit overlay config (Neovim cache dir) points its edit commands at a
--   small script that calls `Config.lazygit_edit()` via `--remote-expr`.
--   An expression runs whatever mode Neovim is in. Replayed keys
--   (`<C-w>p:close<CR>`) don't: Snacks re-enters Terminal mode on focusing
--   the float, so the keys were typed into LazyGit. Snacks' default
--   `nvim-remote` preset is no help either: it opens files in a new tab.
-- - `configure = false`: Snacks would otherwise append a theme generated
--   from the colorscheme, overriding the shared 'lazygit/config.yml' theme
--   that every other LazyGit door uses ('docs/lazygit-contract.md').

local term = require('config.term')

-- The LazyGit float is not a terminal dock tab ('lua/config/term.lua').
term.claim({ 'lazygit' })

-- Called back by LazyGit's edit commands (see the script below).
Config.lazygit_edit = function(file, line)
  for _, t in ipairs(Snacks.terminal.list()) do
    if type(t.cmd) == 'table' and t.cmd[1] == 'lazygit' then t:hide() end
  end
  local win = term.editor_win()
  if win then vim.api.nvim_set_current_win(win) end
  vim.cmd.drop(vim.fn.fnameescape(file))
  if line > 0 then vim.api.nvim_win_set_cursor(0, { math.min(line, vim.api.nvim_buf_line_count(0)), 0 }) end
  return ''
end

local ensure_lazygit_remote_config = function()
  local cache = vim.fn.stdpath('cache')
  -- $1 file, $2 line (optional). Outside Neovim's float, plain `nvim`.
  local script = vim.fs.joinpath(cache, 'lazygit-nvim-edit.sh')
  vim.fn.writefile({
    '[ -z "$NVIM" ] && exec nvim ${2:+"+$2"} -- "$1"',
    "file=$(printf '%s' \"$1\" | sed \"s/'/''/g\")",
    [[exec nvim --server "$NVIM" --remote-expr "v:lua.Config.lazygit_edit('$file', ${2:-0})" >/dev/null]],
  }, script)

  local config_path = vim.fs.joinpath(cache, 'lazygit-nvim-remote.yml')
  vim.fn.writefile({
    'os:',
    ("  edit: 'sh %s {{filename}}'"):format(script),
    ("  editAtLine: 'sh %s {{filename}} {{line}}'"):format(script),
    ("  editAtLineAndWait: 'sh %s {{filename}} {{line}}'"):format(script),
    '  editInTerminal: false',
    'promptToReturnFromSubprocess: false',
  }, config_path)
  return config_path
end

-- `open` is a `Snacks.lazygit` entry point: `open` or `log_file`.
local lazygit = function(open)
  return function()
    local config_files = {}
    local default_config = vim.fs.joinpath(vim.env.HOME, '.config/lazygit/config.yml')
    if vim.uv.fs_stat(default_config) then table.insert(config_files, default_config) end
    table.insert(config_files, ensure_lazygit_remote_config())
    vim.env.LG_CONFIG_FILE = table.concat(config_files, ',')

    Snacks.lazygit[open]({ configure = false })
  end
end

vim.keymap.set('n', '<Leader>gg', lazygit('open'), { desc = 'Open LazyGit' })
vim.keymap.set('n', '<Leader>gG', lazygit('log_file'), { desc = 'LazyGit log buffer' })
