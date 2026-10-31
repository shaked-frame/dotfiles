-- ┌────────────────────────────┐
-- │ Split helpers (Zed parity) │
-- └────────────────────────────┘
--
-- Window split/move mechanics behind `Config.Splits`. The `ss/sv/sl/sh`
-- keymaps live in 'plugin/20_keymaps.lua'; this file owns only the behavior.

Config.Splits = {}

-- Runs `split_cmd` (e.g. 'vsplit', 'leftabove vsplit'), then moves the
-- buffer that was active *before* the split into the new window and
-- restores the original window to its alternate buffer (or a blank buffer
-- if there is none). Without this, Vim's split commands just show the same
-- buffer in both windows instead of "moving" it.
Config.Splits.split_and_move = function(split_cmd)
  local orig_win = vim.api.nvim_get_current_win()
  local alt_buf = vim.fn.bufnr('#')
  vim.cmd(split_cmd)
  local new_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(orig_win)
  if alt_buf > 0 and vim.fn.buflisted(alt_buf) == 1 then
    vim.cmd('buffer ' .. alt_buf)
  else
    vim.cmd('enew')
  end
  vim.api.nvim_set_current_win(new_win)
end

-- Moves the current window's buffer one step to the right/left, swapping
-- places with whichever window is directionally adjacent (`wincmd h`/`l`,
-- which is layout-aware). This matches Zed's "move pane" behavior of
-- stepping one slot at a time. With 3+ windows, `wincmd L`/`H` would instead
-- jump straight to the outer edge, skipping past any window in between.
-- If this is the only window, fall back to creating a fresh split and
-- moving the buffer into it, rather than duplicating it into both.
Config.Splits.move_to_side = function(dir) -- dir: 'h' (left) or 'l' (right)
  if #vim.api.nvim_tabpage_list_wins(0) == 1 then
    Config.Splits.split_and_move(dir == 'l' and 'vsplit' or 'leftabove vsplit')
    return
  end
  local cur_win = vim.api.nvim_get_current_win()
  vim.cmd('wincmd ' .. dir)
  local neighbor_win = vim.api.nvim_get_current_win()
  if neighbor_win == cur_win then return end -- already at the outer edge

  local cur_buf = vim.api.nvim_win_get_buf(cur_win)
  local neighbor_buf = vim.api.nvim_win_get_buf(neighbor_win)
  -- Save each window's view (cursor, topline, etc.) before swapping buffers,
  -- so the cursor position travels with its buffer instead of staying put.
  local cur_view = vim.api.nvim_win_call(cur_win, vim.fn.winsaveview)
  local neighbor_view = vim.api.nvim_win_call(neighbor_win, vim.fn.winsaveview)

  vim.api.nvim_win_set_buf(cur_win, neighbor_buf)
  vim.api.nvim_win_set_buf(neighbor_win, cur_buf)
  vim.api.nvim_win_call(cur_win, function() vim.fn.winrestview(neighbor_view) end)
  vim.api.nvim_win_call(neighbor_win, function() vim.fn.winrestview(cur_view) end)

  vim.api.nvim_set_current_win(neighbor_win) -- focus follows the moved buffer
end

-- Navigate between Neovim windows in `wincmd` ('h'|'j'|'k'|'l') direction and,
-- when already at a Neovim split edge inside Herdr, hand off focus to the
-- neighbouring Herdr pane. Works from both Normal and Terminal modes: if at a
-- split edge inside a terminal buffer, Terminal mode is preserved so the shell
-- or agent TUI is not stranded in Normal mode.
local dir_names = { h = 'left', j = 'down', k = 'up', l = 'right' }

Config.Splits.navigate = function(wincmd)
  local was_term = vim.fn.mode() == 't'
  if was_term then vim.cmd('stopinsert') end

  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd('wincmd ' .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev_win then
    return
  end

  if was_term then vim.cmd('startinsert') end

  -- Rex passes `<C-hjkl>` through while Neovim is the focused program (see
  -- ~/.config/rex/init.lua), so hand focus to the neighbouring Rex pane here.
  if vim.env.REX_BLOCK and vim.env.REX_BLOCK ~= '' then
    local rex_bin = (vim.env.REX_BIN_DIR and vim.env.REX_BIN_DIR ~= '') and (vim.env.REX_BIN_DIR .. '/rex') or 'rex'
    vim.system({ rex_bin, 'focus', dir_names[wincmd] })
    return
  end

  local pane_id = vim.env.HERDR_PANE_ID
  if pane_id and pane_id ~= '' then
    local herdr_bin = (vim.env.HERDR_BIN_PATH and vim.env.HERDR_BIN_PATH ~= '') and vim.env.HERDR_BIN_PATH or 'herdr'
    vim.system({ herdr_bin, 'pane', 'focus', '--direction', dir_names[wincmd], '--pane', pane_id })
  end
end
