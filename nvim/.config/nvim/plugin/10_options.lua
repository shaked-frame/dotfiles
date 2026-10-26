-- ┌──────────────────────────┐
-- │ Built-in Neovim behavior │
-- └──────────────────────────┘
--
-- This file defines Neovim's built-in behavior. The goal is to improve overall
-- usability in a way that works best with MINI.
--
-- Here `vim.o.xxx = value` sets default value of option `xxx` to `value`.
-- See `:h 'xxx'` (replace `xxx` with actual option name).
--
-- Option values can be customized on a per buffer or window basis.
-- See 'after/ftplugin/' for common example.
--
-- Notes:
-- - Some options (like `:h 'exrc'`) need to be set before this file is sourced.
--   Set them directly at the bottom of the 'init.lua' file.

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- General ====================================================================
vim.g.mapleader = ' ' -- Use `<Space>` as <Leader> key

vim.o.mouse       = 'a'            -- Enable mouse
vim.o.mousescroll = 'ver:3,hor:6'  -- Customize mouse scroll
vim.o.smoothscroll = true          -- Smooth screen-line scrolling
vim.o.switchbuf   = 'usetab'       -- Use already opened buffers when switching
vim.o.undofile    = true           -- Enable persistent undo
vim.o.clipboard   = 'unnamedplus'  -- Sync with system clipboard (macOS)

vim.o.shada = "'100,<50,s10,:1000,/100,@100,h" -- Limit ShaDa file (for startup)

-- Enable all filetype plugins and syntax (if not enabled, for better startup)
vim.cmd('filetype plugin indent on')
if vim.fn.exists('syntax_on') ~= 1 then vim.cmd('syntax enable') end

-- UI =========================================================================
vim.o.breakindent    = true       -- Indent wrapped lines to match line start
vim.o.breakindentopt = 'list:-1'  -- Add padding for lists (if 'wrap' is set)
vim.o.colorcolumn    = '+1'       -- Draw column on the right of maximum width
vim.o.cursorline     = true       -- Enable current line highlighting
vim.o.linebreak      = true       -- Wrap lines at 'breakat' (if 'wrap' is set)
vim.o.list           = true       -- Show helpful text indicators
vim.o.laststatus     = 3          -- One bottom statusline; thin lines between splits
vim.o.number         = true       -- Show line numbers
vim.o.relativenumber = true       -- Show relative line numbers
vim.o.pumborder      = 'single'   -- Use border in popup menu
vim.o.pumheight      = 10         -- Make popup menu smaller
vim.o.pummaxwidth    = 100        -- Make popup menu not too wide
vim.o.ruler          = false      -- Don't show cursor coordinates
vim.o.shortmess      = 'CFOSWaco' -- Disable some built-in completion messages
vim.o.showmode       = false      -- Don't show mode in command line
vim.o.signcolumn     = 'yes'      -- Always show signcolumn (less flicker)
vim.o.splitbelow     = true       -- Horizontal splits will be below
vim.o.splitkeep      = 'screen'   -- Reduce scroll during window split
vim.o.splitright     = true       -- Vertical splits will be to the right
vim.o.winborder      = 'single'   -- Use border in floating windows
vim.o.wrap           = false      -- Don't visually wrap lines (toggle with \w)

vim.o.cursorlineopt  = 'screenline,number' -- Show cursor line per screen line

-- Special UI symbols. More is set via 'mini.basics' later.
vim.o.fillchars = 'eob: ,fold:╌,foldopen:,foldclose:,diff:╱'

-- Diff mode closer to delta: histogram algorithm, word-level inline emphasis.
vim.opt.diffopt:remove('inline:char')
vim.opt.diffopt:append({ 'algorithm:histogram', 'inline:word' })
vim.o.listchars = 'extends:…,nbsp:␣,precedes:…,tab:> '

-- Folds (see `:h fold-commands`, `:h zM`, `:h zR`, `:h zA`, `:h zj`)
-- Left-click a chevron (or use `za` / `zc` / `zo`) to toggle.
vim.o.foldenable     = true  -- Allow folding at all (`zi` toggles this)
vim.o.foldlevel      = 99    -- Open everything by default ...
vim.o.foldlevelstart = 99    -- ... including on first window open
vim.o.foldcolumn     = '0'   -- No native fold column; chevrons live in 'statuscolumn'
vim.o.foldmethod     = 'expr'   -- Default: syntax-aware folds ...
vim.o.foldexpr       = 'v:lua.vim.treesitter.foldexpr()' -- ... via tree-sitter
vim.o.foldnestmax    = 10    -- Limit number of fold levels
vim.o.foldtext       = ''    -- Show text under fold with its highlighting

-- Fold chevrons, parent lines only. The native fold column marks every line
-- inside a fold (a wall of chevrons); this custom 'statuscolumn' keeps one
-- subtle column instead: a chevron appears only on the line that *opens* a
-- fold (`foldlevel` rises there), everything else stays blank. `%s` and `%l`
-- preserve the sign gutter and the (relative) line numbers as before.
Config.fold_chevron_for = function(lnum)
  local level = vim.fn.foldlevel(lnum)
  if level == 0 then return ' ' end
  if lnum > 1 and level <= vim.fn.foldlevel(lnum - 1) then return ' ' end
  return vim.fn.foldclosed(lnum) == -1 and '' or ''
end
Config.fold_chevron = function() return Config.fold_chevron_for(vim.v.lnum) end

-- Left-click a chevron toggles the fold on the clicked line.
Config.fold_chevron_click = function(_, _, button, _)
  if button ~= 'l' then return end
  local mouse = vim.fn.getmousepos()
  if mouse.winid == 0 or mouse.line == 0 then return end
  vim.api.nvim_win_call(mouse.winid, function()
    vim.api.nvim_win_set_cursor(mouse.winid, { mouse.line, 0 })
    vim.cmd('normal! za')
  end)
end

vim.o.statuscolumn = '%s %#LineNr#%@v:lua.Config.fold_chevron_click@%{v:lua.Config.fold_chevron()}%T%=%l '

-- Mute closed folds to match the chevron (`LineNr`): the whole closed-fold
-- line, filler dashes included, uses the `Folded` group, which onedark paints
-- loudly. Re-applied on every colorscheme change (which wipes custom links).
local mute_folded = function() vim.api.nvim_set_hl(0, 'Folded', { link = 'LineNr' }) end
Config.new_autocmd('ColorScheme', nil, mute_folded, 'Mute closed folds')
mute_folded()

-- Editing ====================================================================
vim.o.autoindent    = true    -- Use auto indent
vim.o.expandtab     = true    -- Convert tabs to spaces
vim.o.formatoptions = 'rqnl1j'-- Improve comment editing
vim.o.ignorecase    = true    -- Ignore case during search
vim.o.incsearch     = true    -- Show search matches while typing
vim.o.infercase     = true    -- Infer case in built-in completion
vim.o.shiftwidth    = 2       -- Use this number of spaces for indentation
vim.o.smartcase     = true    -- Respect case if search pattern has upper case
vim.o.smartindent   = true    -- Make indenting smart
vim.o.spelloptions  = 'camel' -- Treat camelCase word parts as separate words
vim.o.tabstop       = 2       -- Show tab as this number of spaces
vim.o.virtualedit   = 'block' -- Allow going past end of line in blockwise mode

vim.o.iskeyword = '@,48-57,_,192-255,-' -- Treat dash as `word` textobject part

-- Pattern for a start of numbered list (used in `gw`). This reads as
-- "Start of list item is: at least one special character (digit, -, +, *)
-- possibly followed by punctuation (. or `)`) followed by at least one space".
vim.o.formatlistpat = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

-- Built-in completion
vim.o.complete        = '.,w,b,kspell'                  -- Use less sources
vim.o.completeopt     = 'menuone,noselect,fuzzy,nosort' -- Use custom behavior
vim.o.completetimeout = 100                             -- Limit sources delay

-- Autocommands ===============================================================

-- Don't auto-wrap comments and don't insert comment leader after hitting 'o'.
-- Do on `FileType` to always override these changes from filetype plugins.
local f = function() vim.cmd('setlocal formatoptions-=c formatoptions-=o') end
Config.new_autocmd('FileType', nil, f, "Proper 'formatoptions'")

-- Tree-sitter attachment and fold-method fallback live together in
-- 'plugin/40_plugins.lua' so language aliases ('jsonc', 'mdx', 'octo') are
-- registered before `FileType` evaluates parser and fold query support.

-- Don't let LSP servers colorize text (e.g. CSS color values)
vim.lsp.document_color.enable(false)

-- Format on save via 'conform.nvim'. See 'plugin/40_plugins.lua' for formatters.
-- Guarded by `Config.conform_ready` (see scheduling contract in 'init.lua'):
-- a save before conform's deferred setup is a no-op, not an error.
local format_on_save = function(args)
  if not Config.conform_ready then return end
  require('conform').format({ bufnr = args.buf })
end
Config.new_autocmd('BufWritePre', '*', format_on_save, 'Format on save')

-- There are other autocommands created by 'mini.basics'. See 'plugin/30_mini.lua'.

-- Diagnostics ================================================================

-- Neovim has built-in support for showing diagnostic messages. This configures
-- a more conservative display while still being useful.
-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
local diagnostic_opts = {
  -- Show signs on top of any other sign, but only for warnings and errors
  signs = { priority = 9999, severity = { min = 'WARN', max = 'ERROR' } },

  -- Show all diagnostics as underline (for their messages type `<Leader>ld`)
  underline = { severity = { min = 'HINT', max = 'ERROR' } },

  -- Show more details immediately for errors on the current line
  virtual_lines = false,
  virtual_text = {
    current_line = true,
    severity = { min = 'ERROR', max = 'ERROR' },
  },

  -- Don't update diagnostics when typing
  update_in_insert = false,
}

-- Use `later()` to avoid sourcing `vim.diagnostic` on startup
Config.later(function() vim.diagnostic.config(diagnostic_opts) end)
-- stylua: ignore end
