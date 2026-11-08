-- ┌──────────────────┐
-- │ Explorer (Oil)   │
-- └──────────────────┘
--
-- Directory browsing with 'stevearc/oil.nvim' + 'oil-git-status.nvim':
-- `Config.Explorer.open_cwd()` (`<Leader>ed`) and
-- `Config.Explorer.open_at_file()` (`-`, `<Leader>ef`). Oil is set up on first
-- use, or at startup when Neovim is launched with arguments (e.g. `nvim .`).

-- `'<key>` bookmarks inside Oil. Frontend ones resolve from cwd, else from the
-- directory Oil shows, so they also work after browsing into a frame repo.
local bookmarks = {
  c = { desc = 'Config', path = function() return vim.fn.stdpath('config') end },
  P = { desc = 'Plugins', path = function() return vim.fn.stdpath('data') .. '/site/pack/core/opt' end },
  w = { desc = 'Working directory', path = vim.fn.getcwd },
}
for key, spec in pairs({ a = { 'Web app', '/apps/web' }, f = { 'Frontend', '' }, p = { 'Packages', '/packages' } }) do
  bookmarks[key] = {
    desc = spec[1],
    path = function()
      local frontend = Config.frontend() or Config.frontend(require('oil').get_current_dir())
      return frontend and (frontend .. spec[2]) or nil
    end,
  }
end

local setup = function()
  vim.pack.add({
    'https://github.com/stevearc/oil.nvim',
    'https://github.com/refractalize/oil-git-status.nvim',
  })

  local scroll_preview_or_oil = function(preview_action, fallback_key)
    return function()
      local util = require('oil.util')
      if util.get_preview_win() then
        require('oil.actions')[preview_action].callback()
      else
        vim.cmd('normal! ' .. vim.keycode(fallback_key))
      end
    end
  end

  local keymaps = {
    -- Keep `<C-h>` and `<C-l>` free for split and multiplexer pane navigation,
    -- and `<C-s>` free for `:write` to apply Oil edits.
    ['<C-h>'] = false,
    ['<C-l>'] = false,
    ['<C-s>'] = false,
    ['gr'] = 'actions.refresh',
    ['gy'] = { 'actions.yank_entry', opts = { modify = ':.' }, mode = 'n', desc = 'Yank relative path' },
    ['gY'] = { 'actions.yank_entry', mode = 'n', desc = 'Yank absolute path' },
    ['<C-d>'] = { callback = scroll_preview_or_oil('preview_scroll_down', '<C-d>'), mode = 'n', desc = 'Scroll preview or Oil down' },
    ['<C-u>'] = { callback = scroll_preview_or_oil('preview_scroll_up', '<C-u>'), mode = 'n', desc = 'Scroll preview or Oil up' },
  }
  for key, mark in pairs(bookmarks) do
    keymaps["'" .. key] = {
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
    keymaps = keymaps,
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
end

local ready = false
local ensure = function()
  if ready then return end
  ready = true
  setup()
end

Config.Explorer = {
  open_cwd = function() ensure(); require('oil').open(vim.fn.getcwd()) end,
  open_at_file = function() ensure(); require('oil').open() end,
}

Config.now_if_args(ensure)
