-- ┌────────────────────┐
-- │ Welcome to MiniMax │
-- └────────────────────┘
--
-- This is a config designed to mostly use MINI. It provides out of the box
-- a stable, polished, and feature rich Neovim experience. Its structure:
--
-- ├ init.lua          Initial (this) file executed during startup
-- ├ plugin/           Files automatically sourced during startup
-- ├── 10_options.lua  Built-in Neovim behavior
-- ├── 20_keymaps.lua  Custom mappings
-- ├── 30_mini.lua     MINI configuration
-- ├── 40_plugins.lua  Plugins outside of MINI
-- ├ snippets/         User defined snippets (has demo file)
-- ├ after/            Files to override behavior added by plugins
-- ├── ftplugin/       Files for filetype behavior (has demo file)
-- ├── lsp/            Language server configurations (has demo file)
-- ├── snippets/       Higher priority snippet files (has demo file)
--
-- Config files are meant to be read, preferably inside a Neovim instance running
-- this config and opened at its root. This will help you better understand your
-- setup. Start with this file. Any order is possible, prefer the one listed above.
-- Ways of navigating your config:
-- - `<Space>` + `e` + (one of) `iokmp` - edit 'init.lua' or 'plugin/' files.
-- - Inside config directory: `<Space>ff` (picker) or `<Space>ed` (explorer)
-- - Navigate existing buffers with `[b`, `]b`, or `<Space>fb`.
--
-- Config files are also meant to be customized. Initially it is a baseline of
-- a working config based on MINI. Modify it to make it yours. Some approaches:
-- - Modify already existing files in a way that keeps them consistent.
-- - Add new files in a way that keeps config consistent.
--   Usually inside 'plugin/' or 'after/'.
--
-- Documentation comments like this can be found throughout the config.
-- Common conventions:
--
-- - See `:h key-notation` for key notation used.
-- - `:h xxx` means "documentation of helptag xxx". Either type text directly
--   followed by Enter or type `<Space>fh` to open a helptag fuzzy picker.
-- - "Type `<Space>fh`" means "press <Space>, followed by f, followed by h".
--   Unless said otherwise, it assumes that Normal mode is current.
-- - "See 'path/to/file'" means see open file at described path and read it.
-- - `:SomeCommand ...` or `:lua ...` means execute mentioned command.

-- ┌────────────────┐
-- │ Plugin manager │
-- └────────────────┘
--
-- This config uses `vim.pack` - built-in plugin manager. Its main entry
-- point is a `vim.pack.add()` function, which acts like a "smarter `:packadd`":
-- load plugin after making sure it is installed from source. The state of
-- installed plugins is recorded in the lockfile named 'nvim-pack-lock.json'.
-- Example usage:
-- - `vim.pack.add({ ... })` - use inside config to add one or more plugins.
-- - `:lua vim.pack.update()` - update all plugins; execute `:write` to confirm.
-- - `:lua vim.pack.del({ ... })` - delete specific plugins.
--
-- See also:
-- - `:h vim.pack-examples` - how to use it
-- - `:h vim.pack-lockfile` - lockfile info
-- - `:h vim.pack-events` - available events and plugin hooks examples
-- - `:h vim.pack.update()` - more details about confirmation step

-- Define config table to be able to pass data between scripts
-- It is a global variable which can be use both as `_G.Config` and `Config`
_G.Config = {}

-- Never load netrw (directory browser + `gx` handler): `Config.Explorer`
-- ('plugin/24_explorer.lua') owns directory browsing and `gx` is a built-in
-- default mapping in Nvim 0.12. Skips its startup cost and its attack surface
-- (e.g. the NetrwBookHistSave code-injection fix in 0.12.6). Must stay here:
-- runtime plugins load right after 'init.lua', so setting this in 'plugin/' is
-- too late.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Define custom autocommand group and helper to create an autocommand.
-- Autocommands are Neovim's way to define actions that are executed on events
-- (like creating a buffer, setting an option, etc.).
--
-- See also:
-- - `:h autocommand`
-- - `:h nvim_create_augroup()`
-- - `:h nvim_create_autocmd()`
local gr = vim.api.nvim_create_augroup('custom-config', {})
Config.new_autocmd = function(event, pattern, callback, desc)
  local opts = { group = gr, pattern = pattern, callback = callback, desc = desc }
  vim.api.nvim_create_autocmd(event, opts)
end

-- Define custom `vim.pack.add()` hook helper. Plugin data is passed as
-- argument to the callback. See `:h vim.pack-events`.
-- Example usage: see 'plugin/40_plugins.lua'.
-- If any plugin requires installation hooks, add them after this function
-- and before the first `vim.pack.add()` call.
Config.on_packchanged = function(plugin_name, kinds, callback, desc)
  local f = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if not (name == plugin_name and vim.tbl_contains(kinds, kind)) then return end
    if not ev.data.active then vim.cmd.packadd(plugin_name) end
    callback(ev.data)
  end
  Config.new_autocmd('PackChanged', '*', f, desc)
end

-- Frame repo locator: nearest ancestor (up from cwd) holding
-- 'frontend/apps/web'. Covers '~/frame' and any
-- '~/worktrees/frame/<name>/frame' checkout. Returns nil outside frame repos.
-- Shared by 'plugin/21_pickers.lua' (scoped finders),
-- 'plugin/24_explorer.lua' (explorer bookmarks), and
-- 'after/lsp/tailwindcss.lua' (Tailwind v4 CSS entrypoint) so the sentinel,
-- walk direction, and lower bound live in one place. The optional argument
-- (defaulting to cwd) keeps the walk testable through this interface.
Config.frame_root = function(cwd)
  local home = vim.env.HOME or vim.fn.expand('~')
  local root = vim.fs.root(cwd or vim.fn.getcwd(), function(_, path)
    return #path >= #home and vim.fn.isdirectory(path .. '/frontend/apps/web') == 1
  end)
  return root
end

-- 'mini.nvim' - all-in-one plugin powering most MiniMax features.
-- See 'plugin/30_mini.lua' for how it is used.
-- Load now to have 'mini.misc' available for custom loading helpers.
vim.pack.add({ 'https://github.com/nvim-mini/mini.nvim' })

-- Loading helpers used to organize config into fail-safe parts. Example usage:
-- - `now` - execute immediately. Use for what must be executed during startup.
--   Like colorscheme, statusline, tabline, dashboard, etc.
-- - `later` - execute a bit later. Use for things not needed during startup.
-- - `now_if_args` - use only if needed during startup when Neovim is started
--   like `nvim -- path/to/file`, but otherwise delaying is fine.
-- - Others are better used only if the above is not enough for good performance.
--   Use only if you are comfortable with adding complexity to your config:
--   - `on_event` - execute once on a first matched event. Like "delay until
--     first Insert mode enter": `on_event('InsertEnter', function() ... end)`.
--   - `on_filetype` - execute once on a first matched filetype. Like "delay
--     until first Lua file": `on_filetype('lua', function() ... end)`.
--
-- See also:
-- - `:h MiniMisc.safely()`
-- - 'plugin/30_mini.lua' and 'plugin/40_plugins.lua'
local misc = require('mini.misc')
Config.now = function(f) misc.safely('now', f) end
Config.later_pending = 0
Config.later = function(f)
  Config.later_pending = Config.later_pending + 1
  misc.safely('later', function()
    local ok, err = pcall(f)
    Config.later_pending = Config.later_pending - 1
    if not ok then error(err, 0) end
  end)
end
Config.now_if_args = vim.fn.argc(-1) > 0 and Config.now or Config.later
Config.on_event = function(ev, f) misc.safely('event:' .. ev, f) end
Config.on_filetype = function(ft, f) misc.safely('filetype:' .. ft, f) end

-- Preload `vim.deprecated.health` at startup while the current Neovim runtime
-- directory is on disk, so a background `brew upgrade neovim` cannot break
-- plugins (`diffview.nvim`, `nvim-ts-autotag`) that trigger `vim.deprecate`.
pcall(require, 'vim.deprecated.health')

-- ┌─────────────────────┐
-- │ Scheduling contract │
-- └─────────────────────┘
--
-- Ordering in this config is load-bearing. Three rules everything depends on:
-- 1. Files in 'plugin/' source alphabetically: 10_options < 20_keymaps <
--    21_pickers < 22_splits < 23_terminal < 24_explorer < 30_mini < 40_plugins <
--    42_lazygit < 43_octo < 44_agent < 45_sidekick < 46_sidekick_cli < 60_herdr <
--    61_rex.
--    Slice modules (21/22/23/24) sort after the keymap catalog (20), so
--    keymaps reference `Config.Pickers` / `Config.Splits` / `Config.Terminal` /
--    `Config.Explorer` inside function bodies (press time), never as a bare
--    value at source time.
-- 2. `Config.later()` callbacks run in registration order, so a `later()`
--    registered in a later-sourced file runs after earlier ones.
--    `Config.later_pending` tracks the queue depth so `scripts/smoke.sh` can
--    drain all deferred blocks before asserting post-conditions.
-- 3. `Config.now_if_args()` runs now only when Neovim starts with file
--    arguments (otherwise it is `later()`); anything needed for first draw
--    on the dashboard must use `now()`, not `now_if_args()`.
--
-- Shared `Config` fields (writer -> reader; reads must happen after writes):
-- - `leader_group_clues`: written at source time in 'plugin/20_keymaps.lua',
--   read deferred in `later()` by 'plugin/30_mini.lua' (mini.clue setup).
-- - `Agent`: defined at source time in 'plugin/44_agent.lua'; adapters
--   register via `Config.Agent.register(name, adapter)` ('plugin/60_herdr.lua',
--   'plugin/61_rex.lua' and 'plugin/46_sidekick_cli.lua') and are resolved at
--   press time.
-- - `conform_ready`: written by 'plugin/40_plugins.lua' after
--   `require('conform').setup()`, read by the format-on-save autocmd in
--   'plugin/10_options.lua', so a save before setup is a no-op, not an error.
-- - `explorer` / `Explorer`: owned by 'plugin/24_explorer.lua', which exposes
--   `Config.Explorer` (`open_cwd`, `open_at_file`) at source time and
--   initializes the selected adapter ('oil' or 'mini.files') lazily or via
--   `now_if_args()`.
--
-- Consequences (do not break without updating all sides):
-- - Mason's bin dir is prepended to $PATH eagerly at source time in
--   'plugin/40_plugins.lua' because `require('mason').setup()` itself runs
--   deferred; a server spawned before that would otherwise miss Mason binaries.
