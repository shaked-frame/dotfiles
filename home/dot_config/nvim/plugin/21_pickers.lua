-- ┌────────────────────────────┐
-- │ Picker helpers (Snacks)    │
-- └────────────────────────────┘
--
-- Picker construction behind `Config.Pickers`. The `<Leader>f/b/v` keymaps
-- live in 'plugin/20_keymaps.lua', which stays a thin catalog; this file owns
-- only how pickers are built. Providers are touched at press time, never at
-- source time. MiniVisits remains the visit-history data source.

Config.Pickers = {}

-- Keep the existing buffer deletion shortcut; Snacks refreshes the list.
Config.Pickers.buffers = function()
  Snacks.picker.buffers({
    current = true, hidden = false,
    win = { input = { keys = { ['<C-d>'] = { 'bufdelete', mode = { 'n', 'i' } } } } },
  })
end

-- Search live buffer text, including unsaved edits and unnamed buffers.
Config.Pickers.buffer_lines = function()
  local items = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.api.nvim_buf_is_loaded(buf) then
      local file = vim.api.nvim_buf_get_name(buf)
      for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        items[#items + 1] = { buf = buf, file = file, pos = { lnum, 0 }, line = line,
          text = file .. ' ' .. line }
      end
    end
  end
  Snacks.picker({ title = 'Lines (all buffers)', items = items, format = 'file' })
end

-- Find files including hidden/ignored ones, and follow symlinks. `--follow` is
-- important for the chezmoi-managed dotfiles: files under '~/.config' are
-- symlinks into '~/dotfiles/home', which `rg` skips by default.
Config.Pickers.files_all = function()
  Snacks.picker.files({ title = 'Files (all)', hidden = true, ignored = true, follow = true, exclude = { '.git' } })
end

-- Scoped finders search the frontend ('init.lua'), or cwd outside frame repos.
local frontend_or_cwd = function() return Config.frontend() or vim.fn.getcwd() end

Config.Pickers.frontend_files = function()
  Snacks.picker.files({ title = 'Files (frontend)', cwd = frontend_or_cwd() })
end

Config.Pickers.frontend_grep = function()
  Snacks.picker.grep({ title = 'Grep (frontend)', cwd = frontend_or_cwd() })
end

Config.Pickers.visits = function(cwd, filter, title)
  local items = {}
  local sort = MiniVisits.gen_sort.default({ recency_weight = 1 })
  for i, path in ipairs(MiniVisits.list_paths(cwd, { filter = filter, sort = sort })) do
    items[i] = { file = path, text = path }
  end
  Snacks.picker({ title = title or 'Visited files', items = items, format = 'file',
    sort = { fields = { 'score:desc', 'idx' } }, matcher = { sort_empty = false } })
end

-- Picker over "core"-labeled visits, scoped to cwd (`nil`) or everywhere (`''`).
Config.Pickers.core_visits = function(cwd, desc)
  Config.Pickers.visits(cwd, 'core', desc)
end

-- File restrictions use resolved paths, not fuzzy queries that can match siblings.
Config.Pickers.git_diff = function(opts, current_file)
  opts = vim.deepcopy(opts or {})
  if current_file then
    local file = vim.api.nvim_buf_get_name(0)
    if file == '' or vim.bo.buftype ~= '' then
      vim.notify('No file in the current buffer', vim.log.levels.WARN)
      return
    end
    local resolved = vim.uv.fs_realpath(file) or file
    opts.transform = function(item)
      -- The Git finder also forwards transforms to raw process-output lines.
      if item.file then
        local path = Snacks.picker.util.path(item)
        return path == file or (path and vim.uv.fs_realpath(path) == resolved) or false
      end
    end
  end
  return Snacks.picker.git_diff(opts)
end

-- Browsing history must not check out a commit on Enter (Snacks' default).
Config.Pickers.git_log = function(current_file)
  local opts = { confirm = function(picker, item)
    picker:close()
    if item then vim.schedule(function() vim.cmd('Git show ' .. item.commit) end) end
  end }
  if current_file then Snacks.picker.git_log_file(opts) else Snacks.picker.git_log(opts) end
end

-- Completion menu in the prompt ('mini.completion' runs there too). Snacks
-- refilters on `TextChangedI`, which Neovim replaces with `TextChangedP` while
-- the menu is open, so forward it to the picker's own handler (its augroup
-- only, not every `TextChangedI` listener). Results then follow both typing
-- and the menu item being previewed.
Config.Pickers.prompt_refresh = function(ev)
  for _, picker in ipairs(Snacks.picker.get({ tab = false })) do
    local win = picker.input.win
    if win.buf == ev.buf and win.augroup then
      vim.api.nvim_exec_autocmds('TextChangedI', { group = win.augroup, buffer = ev.buf })
    end
  end
end
Config.new_autocmd('FileType', 'snacks_picker_input', function(ev)
  vim.api.nvim_create_autocmd('TextChangedP', {
    buffer = ev.buf, desc = 'Refilter picker while completing',
    callback = function(e) Config.Pickers.prompt_refresh(e) end,
  })
end, 'Refilter picker while completing')

-- `<C-n>`/`<C-p>`/`<CR>` drive the menu while it is open, else the picker
-- action. `<Tab>`/`<S-Tab>` stay Snacks' multi-select at all times.
local feed = function(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'n', false)
end
local pum_or = function(keys, action)
  return function(picker)
    if vim.fn.pumvisible() == 1 then return feed(keys) end
    picker:action(action)
  end
end
Config.Pickers.prompt_actions = {
  pum_next = pum_or('<C-n>', 'list_down'),
  pum_prev = pum_or('<C-p>', 'list_up'),
  -- `<CR>` accepts a highlighted item; with none (`noselect`), it confirms.
  pum_confirm = function(picker)
    if vim.fn.pumvisible() == 1 and vim.fn.complete_info({ 'selected' }).selected ~= -1 then
      return feed('<C-y>')
    end
    picker:action('confirm')
  end,
}
Config.Pickers.prompt_keys = {
  ['<C-n>'] = { 'pum_next', mode = { 'i' } },
  ['<C-p>'] = { 'pum_prev', mode = { 'i' } },
  ['<CR>'] = { 'pum_confirm', mode = { 'i' } },
}

-- Keep the Neovim 0.12 stale-code-action protection around the Snacks provider.
Config.Pickers.setup_select = function()
  local select = require('snacks.picker').select
  vim.ui.select = function(items, opts, on_choice)
    if opts and opts.kind == 'codeaction' and type(items) == 'table' then
      items = vim.tbl_filter(function(item)
        return type(item) ~= 'table' or not item.ctx or not item.ctx.client_id
          or vim.lsp.get_client_by_id(item.ctx.client_id) ~= nil
      end, items)
      if #items == 0 then
        vim.notify('No code actions available', vim.log.levels.INFO)
        return
      end
      if type(opts.format_item) == 'function' then
        local format = opts.format_item
        opts = vim.tbl_extend('force', opts, { format_item = function(item)
          local ok, text = pcall(format, item)
          if ok and type(text) == 'string' then return text end
          return (type(item) == 'table' and item.action and item.action.title) or tostring(item)
        end })
      end
      local choose = on_choice
      on_choice = function(choice, idx)
        if choice and choice.ctx and choice.ctx.client_id and not vim.lsp.get_client_by_id(choice.ctx.client_id) then
          vim.notify('LSP client restarted before code action could be applied', vim.log.levels.WARN)
          return
        end
        return choose(choice, idx)
      end
    end
    return select(items, opts, on_choice)
  end
end
