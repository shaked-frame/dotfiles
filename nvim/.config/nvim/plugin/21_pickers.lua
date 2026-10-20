-- ┌────────────────────────────┐
-- │ Picker helpers (mini.pick) │
-- └────────────────────────────┘
--
-- Picker construction behind `Config.Pickers`. The `<Leader>f/b/v` keymaps
-- live in 'plugin/20_keymaps.lua', which stays a thin catalog; this file owns
-- only how pickers are built. Mini* globals are touched at press time, never
-- at source time.

Config.Pickers = {}

-- Buffer picker that allows deleting a buffer with `<C-d>` without closing it.
Config.Pickers.buffers = function()
  local pick = require('mini.pick')

  local delete_current = function()
    local matches = pick.get_picker_matches()
    local current = matches and matches.current or nil
    local bufnr = current and current.bufnr or nil
    if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return end

    MiniBufremove.delete(bufnr)
    if not pick.is_picker_active() then return end

    local items = vim.tbl_filter(function(it) return it.bufnr ~= bufnr end, pick.get_picker_items() or {})
    if #items == 0 then return true end
    pick.set_picker_items(items)
  end

  pick.builtin.buffers({ include_current = true, include_unlisted = false }, {
    mappings = { delete_buffer = { char = '<C-d>', func = delete_current } },
  })
end

-- Find files including hidden/ignored ones, and follow symlinks. `--follow` is
-- important for stow-managed dotfiles: '~/.config/*' are symlinks into
-- '~/dotfiles', which `rg` will not descend into by default.
Config.Pickers.files_all = function()
  local command = { 'rg', '--files', '--hidden', '--no-ignore', '--follow', '--glob', '!.git/**' }
  MiniPick.builtin.cli({ command = command }, { source = { name = 'Files (all)', cwd = vim.fn.getcwd() } })
end

-- Frontend dir for scoped finders (falls back to cwd outside frame repos).
-- Root detection lives in `Config.frame_root()` ('init.lua').
Config.Pickers.frontend_dir = function()
  local root = Config.frame_root()
  return root and (root .. '/frontend') or vim.fn.getcwd()
end

Config.Pickers.frontend_files = function()
  MiniPick.builtin.files(nil, { source = { name = 'Files (frontend)', cwd = Config.Pickers.frontend_dir() } })
end

Config.Pickers.frontend_grep = function()
  MiniPick.builtin.grep_live(nil, { source = { name = 'Grep (frontend)', cwd = Config.Pickers.frontend_dir() } })
end

-- Picker over "core"-labeled visits, scoped to cwd (`nil`) or everywhere (`''`).
Config.Pickers.core_visits = function(cwd, desc)
  local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
  local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
  MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
end
