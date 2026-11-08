-- ┌──────────────────────────────────────────────┐
-- │ Insert-mode completion: accept keys and the  │
-- │ guarded reach into plugin internals          │
-- └──────────────────────────────────────────────┘
--
-- Two completion sources share Insert mode: the 'mini.completion' popup menu
-- and the built-in `vim.lsp.inline_completion` ghost text (enabled per buffer
-- on `LspAttach` in 'plugin/40_plugins.lua'). Everything that arbitrates
-- between them, or patches either one, is here:
--
-- - `map_keys()`             every Insert-mode accept key, as 'mini.keymap'
--                            multi-step mappings (`:h MiniKeymap.map_multistep()`).
--                            Call after `require('mini.keymap').setup()`.
-- - `patch_mini(MiniCompletion, { doc = fn })`
--                            drop 'mini.completion' edits and commands for LSP
--                            clients that already stopped, and pass item docs
--                            through `doc` (if given).
--
-- Both reach plugin internals through `debug.getupvalue`. Each lookup fails
-- soft: after a plugin update it finds nothing and patches nothing.

local M = {}

-- Ghost text =================================================================

--- Upvalue `name` of function `fn`, if it is a table.
local upvalue = function(fn, name)
  for i = 1, 20 do
    local key, value = debug.getupvalue(fn, i)
    if key == nil then return nil end
    if key == name and type(value) == 'table' then return value end
  end
end

-- Accept the shown suggestion through `on_accept`, closing an unselected popup
-- menu first. `false` (nothing shown, or `get()` failed) lets the multi-step
-- mapping move on to its next step: a broken server must never break `<Tab>`.
local accept_with = function(on_accept)
  local pum = vim.fn.pumvisible() == 1
  local ok, accepted = pcall(vim.lsp.inline_completion.get, { on_accept = on_accept })
  if not (ok and accepted) then return false end
  return pum and '<C-e>' or ''
end

--- `on_accept` that shrinks the item to its next word (Zed: `alt-tab`,
--- editor::AcceptNextWordEditPrediction).
local next_word = function(item)
  local ins = item.insert_text
  local text = type(ins) == 'table' and ins.value or ins
  if type(text) ~= 'string' or text == '' then return item end

  -- `item.insert_text` starts at `item.range` (often column 0 of the line), so
  -- keep the prefix already before the cursor and slice one word from the
  -- ghost-text suffix after it.
  local prefix_len = 0
  if item.range then
    local start_row, start_col = item.range:to_extmark()
    local cur = vim.api.nvim_win_get_cursor(0)
    if start_row == cur[1] - 1 and cur[2] > start_col then prefix_len = cur[2] - start_col end
  end
  local suffix = text:sub(prefix_len + 1)
  local chunk = suffix:match('^%s*[%w_]+%s*') or suffix:match('^%s*%S+%s*')
  if not chunk or chunk == '' then return item end

  local new_text = text:sub(1, prefix_len) .. chunk
  local accepted = vim.tbl_extend('force', item, {
    insert_text = type(ins) == 'table' and vim.tbl_extend('force', ins, { value = new_text }) or new_text,
  })

  -- More ghost text left: put the suggestion back with its range end moved to
  -- the new cursor, so rapid presses keep stepping word by word instead of
  -- waiting for a new server response. The shown suggestion lives in the
  -- private `Completor` (an upvalue of `get()`).
  if #chunk < #suffix then
    local buf, full, range = vim.api.nvim_get_current_buf(), vim.deepcopy(ins), item.range
    vim.schedule(function()
      local completor = upvalue(vim.lsp.inline_completion.get, 'Completor')
      local comp = completor and completor.active and completor.active[buf]
      if not comp then return end
      if range then
        local cur = vim.api.nvim_win_get_cursor(0)
        range.end_row, range.end_col = cur[1] - 1, cur[2]
      end
      comp.current = {
        _index = item._index or 1,
        client_id = item.client_id,
        insert_text = full,
        range = range,
        _filter_text = item._filter_text,
        command = item.command,
      }
      pcall(comp.show, comp)
    end)
  end
  return accepted
end

local always = function() return true end
local ghost_text = { condition = always, action = function() return accept_with(nil) end }
local ghost_word = { condition = always, action = function() return accept_with(next_word) end }

-- An item the user already highlighted keeps the menu cycling.
local pmenu_selected_next = {
  condition = function() return vim.fn.pumvisible() == 1 and vim.fn.complete_info({ 'selected' }).selected ~= -1 end,
  action = function() return '<C-n>' end,
}

M.map_keys = function()
  local map = MiniKeymap.map_multistep
  -- `<Tab>`: cycle a menu with a selection > accept ghost text > select the
  -- first menu item > literal `<Tab>`.
  map('i', '<Tab>', { pmenu_selected_next, ghost_text, 'pmenu_next' })
  map('i', '<S-Tab>', { 'pmenu_prev' })
  -- `<CR>` accepts the selected item, else respects 'mini.pairs'.
  map('i', '<CR>', { 'pmenu_accept', 'minipairs_cr' })
  map('i', '<BS>', { 'minipairs_bs' })
  -- Ghost text one word per press: Option+Tab, or `<C-l>`, which jumps to the
  -- next tabstop first while a 'mini.snippets' session is active. Both are
  -- global so a snippet session can take `<C-l>` over and give it back.
  map('i', '<M-Tab>', { ghost_word })
  map('i', '<C-l>', { 'minisnippets_next', ghost_word })
end

-- mini.completion ============================================================

-- Accepting an item can apply edits or run a command on the client that
-- produced it. If that client stopped since (LSP restart, `:LspStop`, crash,
-- branch switch), 'mini.completion' throws. Its helpers live in the private
-- `H` table, an upvalue of `completefunc_lsp`.
M.patch_mini = function(MiniCompletion, opts)
  local H = upvalue(MiniCompletion.completefunc_lsp, 'H')
  if not H then return false end

  local live = function(client_id) return client_id == nil or vim.lsp.get_client_by_id(client_id) ~= nil end
  for _, name in ipairs({ 'apply_text_edits', 'exec_command' }) do
    local original = H[name]
    if type(original) == 'function' then
      H[name] = function(client_id, ...)
        if live(client_id) then return original(client_id, ...) end
      end
    end
  end

  local normalize_item_doc = H.normalize_item_doc
  if opts and opts.doc and type(normalize_item_doc) == 'function' then
    H.normalize_item_doc = function(...) return opts.doc(normalize_item_doc(...)) end
  end
  return true
end

return M
