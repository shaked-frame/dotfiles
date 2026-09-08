-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- This file contains installation and configuration of plugins outside of MINI.
-- They significantly improve user experience in a way not yet possible with MINI.
-- These are mostly plugins that provide programming language specific behavior.
--
-- Use this file to install and configure other such plugins.

-- Make concise helpers for installing/adding plugins in two stages
local add = vim.pack.add
local now_if_args, later = Config.now_if_args, Config.later

-- Tree-sitter ================================================================

-- Tree-sitter is a tool for fast incremental parsing. It converts text into
-- a hierarchical structure (called tree) that can be used to implement advanced
-- and/or more precise actions: syntax highlighting, textobjects, indent, etc.
--
-- Tree-sitter support is built into Neovim (see `:h treesitter`). However, it
-- requires two extra pieces that don't come with Neovim directly:
-- - Language parsers: programs that convert text into trees. Some are built-in
--   (like for Lua), 'nvim-treesitter' provides many others.
--   NOTE: It requires third party software to build and install parsers.
--   See the link for more info in "Requirements" section of the MiniMax README.
-- - Query files: definitions of how to extract information from trees in
--   a useful manner (see `:h treesitter-query`). 'nvim-treesitter' also provides
--   these, while 'nvim-treesitter-textobjects' provides the ones for Neovim
--   textobjects (see `:h text-objects`, `:h MiniAi.gen_spec.treesitter()`).
--
-- Add these plugins now if file (and not 'mini.starter') is shown after startup.
--
-- Troubleshooting:
-- - Run `:checkhealth vim.treesitter nvim-treesitter` to see potential issues.
-- - In case of errors related to queries for Neovim bundled parsers (like `lua`,
--   `vimdoc`, `markdown`, etc.), manually install them via 'nvim-treesitter'
--   with `:TSInstall <language>`. Be sure to have necessary system dependencies
--   (see MiniMax README section for software requirements).
now_if_args(function()
  -- Define hook to update tree-sitter parsers after plugin is updated
  local ts_update = function() vim.cmd('TSUpdate') end
  Config.on_packchanged('nvim-treesitter', { 'update' }, ts_update, ':TSUpdate')

  add({
    'https://github.com/nvim-treesitter/nvim-treesitter',
    'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
    'https://github.com/windwp/nvim-ts-autotag',
  })

  -- Define languages which will have parsers installed and auto enabled
  -- After changing this, restart Neovim once to install necessary parsers. Wait
  -- for the installation to finish before opening a file for added language(s).
  local languages = {
    -- These are already pre-installed with Neovim. Used as an example.
    'lua',
    'vimdoc',
    'markdown',
    'go',
    'typescript',
    'tsx',
    'javascript',
    'terraform',
    'yaml',
    'zsh',
    -- Config file formats edited regularly in this setup: herdr and atuin use
    -- TOML, Zed and Neovim lockfiles use JSON.
    -- NOTE: no 'jsonc' entry - nvim-treesitter has no such parser (it warns
    -- "skipping unsupported language"). The 'json' parser covers jsonc files.
    'toml',
    'json',
    'css',
    'bash',
    -- Add here more languages with which you want to use tree-sitter
    -- To see available languages:
    -- - Execute `:=require('nvim-treesitter').get_available()`
    -- - Visit 'SUPPORTED_LANGUAGES.md' file at
    --   https://github.com/nvim-treesitter/nvim-treesitter/blob/main
  }
  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then require('nvim-treesitter').install(to_install) end

  -- Enable tree-sitter after opening a file for a target language
  local filetypes = {}
  for _, lang in ipairs(languages) do
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      table.insert(filetypes, ft)
    end
  end
  local ts_start = function(ev) vim.treesitter.start(ev.buf) end
  Config.new_autocmd('FileType', filetypes, ts_start, 'Start tree-sitter')

  -- Auto close/rename HTML and JSX tags
  require('nvim-ts-autotag').setup()
end)

-- Language servers ===========================================================

-- Make Mason's binaries discoverable before any language server is spawned.
--
-- `require('mason').setup()` is what normally prepends this directory to $PATH,
-- but it runs from `now_if_args()` near the bottom of this file. When Neovim
-- starts without file arguments (i.e. on the 'mini.starter' dashboard) that is
-- deferred, so a server spawned right after opening a file can lose the race
-- and fail with "Spawning language server with cmd: ... failed".
--
-- Doing it here is just string manipulation - no plugin is loaded - so it is
-- safe to run unconditionally on every startup.
local mason_bin = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'bin')
if not (vim.env.PATH or ''):find(mason_bin, 1, true) then
  vim.env.PATH = mason_bin .. ':' .. (vim.env.PATH or '')
end

-- Language Server Protocol (LSP) is a set of conventions that power creation of
-- language specific tools. It requires two parts:
-- - Server - program that performs language specific computations.
-- - Client - program that asks server for computations and shows results.
--
-- Here Neovim itself is a client (see `:h vim.lsp`). Language servers need to
-- be installed separately based on your OS, CLI tools, and preferences.
-- See note about 'mason.nvim' at the bottom of the file.
--
-- Neovim's team collects commonly used configurations for most language servers
-- inside 'neovim/nvim-lspconfig' plugin.
--
-- Add it now if file (and not 'mini.starter') is shown after startup.
--
-- Troubleshooting:
-- - Run `:checkhealth vim.lsp` to see potential issues.
now_if_args(function()
  add({ 'https://github.com/neovim/nvim-lspconfig' })

  -- Use `:h vim.lsp.enable()` to automatically enable language server based on
  -- the rules provided by 'nvim-lspconfig'.
  -- Use `:h vim.lsp.config()` or 'after/lsp/' directory to configure servers.
  vim.lsp.config('copilot', {
    settings = { telemetry = { telemetryLevel = 'off' } },
  })

  vim.lsp.enable({
    'bashls',
    'lua_ls',
    -- TypeScript 7 native server ('tsgo'). Configured in 'after/lsp/tsc.lua'.
    -- NOTE: the server name is 'tsc', not 'tsgo' - nvim-lspconfig's 'tsgo' entry
    -- is a deprecated shim that just forwards to 'tsc'.
    'tsc',
    'tailwindcss',
    'copilot',
    -- Linting, via the oxc toolchain. 'oxlint --lsp' reports diagnostics as a
    -- language server, so no separate lint plugin (nvim-lint / none-ls) is
    -- needed. Formatting is handled by 'oxfmt' through conform above rather
    -- than by enabling the 'oxfmt' language server, to keep one formatting path.
    'oxlint',
  })

  -- Inline completion (a.k.a. "ghost text" / edit prediction).
  -- Enabled per buffer whenever an attached server supports it.
  local enable_inline_completion = function(args)
    local bufnr = args.buf
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client == nil then return end
    if not client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, bufnr) then
      return
    end

    vim.lsp.inline_completion.enable(true, { bufnr = bufnr })

    -- Accept inline completion word-by-word with `<C-l>`
    -- (Zed: `alt-tab` = editor::AcceptNextWordEditPrediction)
    vim.keymap.set('i', '<C-l>', function()
      local ok = vim.lsp.inline_completion.get({
        bufnr = bufnr,
        on_accept = function(item)
          local ins = item.insert_text
          local text = type(ins) == 'table' and ins.value or ins
          if type(text) ~= 'string' or text == '' then return item end

          -- Accept first word (+ trailing spaces for natural repeated presses)
          local chunk = text:match('^%s*%S+%s*')
          if not chunk or chunk == '' then return item end

          if type(ins) == 'table' then
            item.insert_text = vim.tbl_extend('force', ins, { value = chunk })
          else
            item.insert_text = chunk
          end
          return item
        end,
      })
      return ok and '' or '<C-l>'
    end, { expr = true, buffer = bufnr, desc = 'Accept inline completion word' })
  end

  Config.new_autocmd('LspAttach', nil, enable_inline_completion, 'Enable inline completion')
end)

-- Formatting =================================================================

-- Programs dedicated to text formatting (a.k.a. formatters) are very useful.
-- Neovim has built-in tools for text formatting (see `:h gq` and `:h 'formatprg'`).
-- They can be used to configure external programs, but it might become tedious.
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup.
later(function()
  add({ 'https://github.com/stevearc/conform.nvim' })

  -- See also:
  -- - `:h Conform`
  -- - `:h conform-options`
  -- - `:h conform-formatters`
  require('conform').setup({
    default_format_opts = {
      -- Allow formatting from LSP server if no dedicated formatter is available
      lsp_format = 'fallback',
    },
    -- Map of filetype to formatters
    -- Make sure that necessary CLI tool is available (all of these come from
    -- Mason; run `:checkhealth conform` or `:ConformInfo` if formatting is a
    -- no-op, which is what happens when the binary is missing).
    --
    -- NOTE: 'oxfmt' (from the oxc toolchain) replaces the previous 'biome'
    -- entries, matching the switch already made on the Mason side.
    formatters_by_ft = {
      lua = { 'stylua' },
      javascript = { 'oxfmt' },
      javascriptreact = { 'oxfmt' },
      typescript = { 'oxfmt' },
      typescriptreact = { 'oxfmt' },
      json = { 'oxfmt' },
      jsonc = { 'oxfmt' },
      toml = { 'oxfmt' },
    },
  })
end)

-- Snippets ===================================================================

-- Although 'mini.snippets' provides functionality to manage snippet files, it
-- deliberately doesn't come with those.
--
-- The 'rafamadriz/friendly-snippets' is currently the largest collection of
-- snippet files. They are organized in 'snippets/' directory (mostly) per language.
-- 'mini.snippets' is designed to work with it as seamlessly as possible.
-- See `:h MiniSnippets.gen_loader.from_lang()`.
later(function()
  add({ 'https://github.com/rafamadriz/friendly-snippets' })
  -- LazyGit integration lives in 'plugin/42_lazygit.lua'
  add({ 'https://github.com/kdheepak/lazygit.nvim' })
end)

-- Editing extras =============================================================

-- - 'yanky.nvim'      - yank ring: cycle through previous yanks after pasting
-- - 'dial.nvim'       - smarter `<C-a>`/`<C-x>` increment/decrement
-- - 'inc-rename.nvim' - live preview while renaming via LSP (`<Leader>lr`)
-- - 'trouble.nvim'    - pretty diagnostics/quickfix/reference lists (`<Leader>x*`)
-- - 'grug-far.nvim'   - project-wide search and replace (`<Leader>r*`)
later(function()
  add({
    'https://github.com/gbprod/yanky.nvim',
    'https://github.com/monaqa/dial.nvim',
    'https://github.com/smjonas/inc-rename.nvim',
    'https://github.com/folke/trouble.nvim',
    'https://github.com/MagicDuck/grug-far.nvim',
  })

  require('yanky').setup()
  require('inc_rename').setup()
  require('trouble').setup()
  require('grug-far').setup()

  -- 'dial.nvim' needs a mapping per mode/kind
  --
  -- NOTE: deliberately NOT on the conventional `<C-a>` / `<C-x>`. Herdr uses
  -- `ctrl+a` as its prefix key, and unlike tmux (which offers `send-prefix`)
  -- Herdr has no action to emit a literal `Ctrl-A` - so `<C-a>` never reaches
  -- Neovim inside a Herdr pane. `<C-Up>` / `<C-Down>` are free in both Neovim
  -- and the Ghostty keybindings.
  local dial_map = require('dial.map')
  local dial = function(mode, lhs, direction, kind, desc)
    vim.keymap.set(mode, lhs, function() dial_map.manipulate(direction, kind) end, { desc = desc })
  end

  dial('n', '<C-Up>',    'increment', 'normal',  'Increment')
  dial('n', '<C-Down>',  'decrement', 'normal',  'Decrement')
  dial('x', '<C-Up>',    'increment', 'visual',  'Increment')
  dial('x', '<C-Down>',  'decrement', 'visual',  'Decrement')
  dial('n', 'g<C-Up>',   'increment', 'gnormal', 'Increment sequentially')
  dial('n', 'g<C-Down>', 'decrement', 'gnormal', 'Decrement sequentially')
  dial('x', 'g<C-Up>',   'increment', 'gvisual', 'Increment sequentially')
  dial('x', 'g<C-Down>', 'decrement', 'gvisual', 'Decrement sequentially')

  -- 'yanky.nvim' replaces the put mappings to enable cycling with `]y`/`[y`
  vim.keymap.set({ 'n', 'x' }, 'p',  '<Plug>(YankyPutAfter)')
  vim.keymap.set({ 'n', 'x' }, 'P',  '<Plug>(YankyPutBefore)')
  vim.keymap.set({ 'n', 'x' }, 'gp', '<Plug>(YankyGPutAfter)')
  vim.keymap.set({ 'n', 'x' }, 'gP', '<Plug>(YankyGPutBefore)')
  vim.keymap.set('n', ']y', '<Plug>(YankyCycleForward)',  { desc = 'Next yank' })
  vim.keymap.set('n', '[y', '<Plug>(YankyCycleBackward)', { desc = 'Previous yank' })
end)

-- Honorable mentions =========================================================

-- 'mason-org/mason.nvim' (a.k.a. "Mason") is a great tool (package manager) for
-- installing external language servers, formatters, and linters. It provides
-- a unified interface for installing, updating, and deleting such programs.
--
-- The caveat is that these programs will be set up to be mostly used inside Neovim.
-- If you need them to work elsewhere, consider using other package managers.
--
-- You can use it like so:
now_if_args(function()
  add({ 'https://github.com/mason-org/mason.nvim' })
  require('mason').setup()
end)

-- Color scheme ===============================================================
--
-- Overrides the 'mini.hues'-based 'miniwinter' that 'plugin/30_mini.lua' would
-- otherwise set (that line is commented out there, so this is the only one that
-- loads and there is no startup flash of the wrong theme).
--
-- Italics for comments, keywords and types are applied on top by the
-- `ColorScheme` autocommand in 'plugin/30_mini.lua'. That merges `italic` into
-- whatever the active scheme defined, so it keeps working across theme changes
-- and does not need onedark's own `code_style` option.
Config.now(function()
  add({ 'https://github.com/navarasu/onedark.nvim' })

  require('onedark').setup({
    -- Available: dark, darker, cool, deep, warm, warmer, light
    --
    -- 'dark' is the canonical Atom / Zed One Dark palette, matching it exactly:
    --   bg #282c34   fg #abb2bf   comment #5c6370   blue #61afef   purple #c678dd
    -- The other styles are recolours - 'darker' in particular darkens and
    -- desaturates everything (bg #1f2329, fg #a0a8b7), which is why it did not
    -- look like One Dark.
    style = 'dark',

    -- One Dark's own comment colour is only 2.32:1 against its background,
    -- below the 3:1 WCAG floor for UI text - so authentic does not mean legible.
    -- Use the palette's own `light_grey` (#848b98, 4.08:1): readable, still
    -- clearly dimmer than code (`fg` #abb2bf is 6.57:1), no invented colours.
    --
    -- Scoped to the comment groups on purpose: `grey` also drives LineNr,
    -- NonText, Whitespace, FloatBorder and DiagnosticUnnecessary, which are
    -- meant to stay dim. Remove this block for a pixel-exact One Dark.
    highlights = {
      Comment = { fg = '$light_grey' },
      SpecialComment = { fg = '$light_grey' },
      ['@comment'] = { fg = '$light_grey' },
    },
  })
  require('onedark').load()
end)
