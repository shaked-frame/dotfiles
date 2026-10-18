-- ┌────────────────────────────────────────┐
-- │ Explorer: one seam, two adapters       │
-- └────────────────────────────────────────┘
--
-- Directory browsing has a single interface here:
-- `Config.Explorer.open_cwd()` (`<Leader>ed`) and
-- `Config.Explorer.open_at_file()` (`-`, `<Leader>ef`).
--
-- Two adapters sit behind it, selected by `Config.explorer`:
-- - 'oil'        ('stevearc/oil.nvim' + 'oil-git-status.nvim')
-- - 'mini.files' (Miller columns with git status marks)
--
-- Both adapters share the bookmark catalog in `Config.explorer_bookmarks()`,
-- including frame monorepo bookmarks resolved via `Config.frame_root()`.

Config.explorer = 'oil'

Config.explorer_bookmarks = function()
  local frame_subpath = function(sub)
    return function()
      local oil_dir = package.loaded.oil and require('oil').get_current_dir() or nil
      local root = Config.frame_root() or (oil_dir and Config.frame_root(oil_dir))
      return root and (root .. sub) or nil
    end
  end
  return {
    c = { path = function() return vim.fn.stdpath('config') end, desc = 'Config' },
    P = { path = function() return vim.fn.stdpath('data') .. '/site/pack/core/opt' end, desc = 'Plugins' },
    w = { path = vim.fn.getcwd, desc = 'Working directory' },
    a = { path = frame_subpath('/frontend/apps/web'), desc = 'Web app' },
    f = { path = frame_subpath('/frontend'), desc = 'Frontend' },
    p = { path = frame_subpath('/frontend/packages'), desc = 'Packages' },
  }
end

local initialized = false
local adapter_impl = nil

local setup_oil = function()
  vim.pack.add({
    'https://github.com/stevearc/oil.nvim',
    'https://github.com/refractalize/oil-git-status.nvim',
  })

  local oil_keymaps = {
    -- Keep `<C-h>` and `<C-l>` free for split and Herdr pane navigation,
    -- and `<C-s>` free for `:write` to apply Oil edits.
    ['<C-h>'] = false,
    ['<C-l>'] = false,
    ['<C-s>'] = false,
    ['gr'] = 'actions.refresh',
  }
  for key, mark in pairs(Config.explorer_bookmarks()) do
    oil_keymaps["'" .. key] = {
      callback = function()
        local target = mark.path()
        if target == nil then
          vim.notify('Not in a frame repository', vim.log.levels.WARN)
          return
        end
        require('oil').open(target)
      end,
      desc = 'Bookmark: ' .. mark.desc,
      mode = 'n',
    }
  end

  require('oil').setup({
    default_file_explorer = true,
    win_options = {
      signcolumn = 'yes:2',
    },
    view_options = {
      show_hidden = true,
    },
    keymaps = oil_keymaps,
  })

  require('oil-git-status').setup()

  -- Tell attached LSP servers (such as tsgo) to update imports when a file is
  -- renamed or moved inside an Oil buffer.
  Config.new_autocmd('User', 'OilActionsPost', function(event)
    if event.data.actions == nil then return end
    for _, action in ipairs(event.data.actions) do
      if action.type == 'move' then
        require('snacks.rename').on_rename_file(action.src_url, action.dest_url)
      end
    end
  end, 'Inform LSP when Oil moves or renames a file')

  return {
    open_cwd = function() require('oil').open(vim.fn.getcwd()) end,
    open_at_file = function() require('oil').open() end,
  }
end

local setup_mini_files = function()
  local git_hl = {
    M = 'MiniFilesGitModified',
    A = 'MiniFilesGitAdded',
    D = 'MiniFilesGitDeleted',
    R = 'MiniFilesGitRenamed',
    ['?'] = 'MiniFilesGitUntracked',
  }
  for group, link in pairs({
    MiniFilesGitModified = 'DiffChange',
    MiniFilesGitAdded = 'DiffAdd',
    MiniFilesGitDeleted = 'DiffDelete',
    MiniFilesGitRenamed = 'DiffChange',
    MiniFilesGitUntracked = 'Comment',
  }) do
    vim.api.nvim_set_hl(0, group, { link = link })
  end

  local git_cache = {}
  local git_changes = function(dir)
    local now = vim.uv.now()
    local cached = git_cache[dir]
    if cached ~= nil and now - cached.at < 2000 then return cached.items end
    local items = {}
    local root_res = vim.system({ 'git', '-C', dir, 'rev-parse', '--show-toplevel' }):wait()
    if root_res.code == 0 then
      local root = (root_res.stdout or ''):gsub('%s+$', '')
      local res = vim.system({ 'git', '-C', dir, 'status', '--porcelain=v1', '-z', '--untracked-files=normal', '--', '.' }):wait()
      if res.code == 0 then
        local chunks = {}
        for c in (res.stdout or ''):gmatch('[^%z]+') do table.insert(chunks, c) end
        local i = 1
        while i <= #chunks do
          local status, path = chunks[i]:match('^(..) (.*)$')
          if path == nil then break end
          i = i + 1
          if status:sub(1, 1) == 'R' or status:sub(1, 1) == 'C' then
            path = chunks[i]
            i = i + 1
          end
          if path ~= nil then
            path = path:gsub('/$', '')
            local x, y = status:sub(1, 1), status:sub(2, 2)
            local s = (y ~= ' ' and y ~= '?') and y or (x ~= ' ' and x or (y == '?' and '?' or nil))
            if s == 'T' or s == 'U' then s = 'M' end
            if s ~= nil then table.insert(items, { path = root .. '/' .. path, status = s }) end
          end
        end
      end
    end
    git_cache[dir] = { at = now, items = items }
    return items
  end

  local git_symbol = function(fs_entry)
    local dir = fs_entry.path:match('^(.*)/[^/]+$')
    if dir == nil then return nil end
    local rank = { M = 4, D = 3, A = 2, R = 1, ['?'] = 0 }
    local best, best_rank = nil, -1
    for _, item in ipairs(git_changes(dir)) do
      if item.path == fs_entry.path or item.path:sub(1, #fs_entry.path + 1) == fs_entry.path .. '/' then
        local r = rank[item.status] or 0
        if r > best_rank then best, best_rank = item.status, r end
      end
    end
    return best
  end

  require('mini.files').setup({
    windows = { preview = true, width_focus = 35, width_preview = 75 },
    content = {
      prefix = function(fs_entry)
        local icon, hl = MiniFiles.default_prefix(fs_entry)
        local s = git_symbol(fs_entry)
        if s == nil then return '  ' .. icon, hl end
        return s .. ' ' .. icon, git_hl[s] or hl
      end,
      highlight = function(fs_entry)
        local s = git_symbol(fs_entry)
        if s == nil then return MiniFiles.default_highlight(fs_entry) end
        return git_hl[s] or MiniFiles.default_highlight(fs_entry)
      end,
    },
  })

  local add_marks = function()
    for key, mark in pairs(Config.explorer_bookmarks()) do
      local target = mark.path()
      if target ~= nil then
        MiniFiles.set_bookmark(key, target, { desc = mark.desc })
      end
    end
  end
  Config.new_autocmd('User', 'MiniFilesExplorerOpen', add_marks, 'Add bookmarks')

  return {
    open_cwd = function() MiniFiles.open() end,
    open_at_file = function()
      local path = vim.api.nvim_buf_get_name(0)
      if path == '' then
        MiniFiles.open()
        return
      end
      MiniFiles.open(path, true)
    end,
  }
end

local ensure_adapter = function()
  if not initialized then
    initialized = true
    if Config.explorer == 'mini.files' then
      adapter_impl = setup_mini_files()
    else
      adapter_impl = setup_oil()
    end
  end
  return adapter_impl
end

Config.Explorer = {
  open_cwd = function() ensure_adapter().open_cwd() end,
  open_at_file = function() ensure_adapter().open_at_file() end,
}

-- Initialize during startup when launched with arguments (e.g. `nvim .`).
Config.now_if_args(function() ensure_adapter() end)
