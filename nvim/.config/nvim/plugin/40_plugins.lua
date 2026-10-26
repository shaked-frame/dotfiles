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
-- Neovim detects no `*.mdx` filetype out of the box; register it at source
-- time so `nvim foo.mdx` fires `FileType mdx` during startup.
vim.filetype.add({ extension = { mdx = 'mdx' } })

now_if_args(function()
  -- Define hook to update tree-sitter parsers after plugin is updated
  local ts_update = function() vim.cmd('TSUpdate') end
  Config.on_packchanged('nvim-treesitter', { 'update' }, ts_update, ':TSUpdate')

  add({
    'https://github.com/nvim-treesitter/nvim-treesitter',
    'https://github.com/nvim-treesitter/nvim-treesitter-textobjects',
    'https://github.com/nvim-treesitter/nvim-treesitter-context',
    'https://github.com/windwp/nvim-ts-autotag',
    'https://github.com/HiPhish/rainbow-delimiters.nvim',
  })

  -- VS Code One Dark Pro cycles orange, purple, cyan for nested brackets.
  require('rainbow-delimiters.setup').setup({
    highlight = { 'RainbowDelimiterOrange', 'RainbowDelimiterViolet', 'RainbowDelimiterCyan' },
    -- queries/tsx/rainbow-delimiters.scm leaves JSX tag names to the theme.
    blacklist = { 'html', 'xml' },
  })

  require('treesitter-context').setup({
    max_lines = 3,
    multiline_threshold = 1,
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
    -- Lets 'render-markdown.nvim' hide HTML comments and tags in Markdown,
    -- e.g. bot boilerplate in GitHub PR bodies and comments (Octo).
    'html',
    -- Add here more languages with which you want to use tree-sitter
    -- To see available languages:
    -- - Execute `:=require('nvim-treesitter').get_available()`
    -- - Visit 'SUPPORTED_LANGUAGES.md' file at
    --   https://github.com/nvim-treesitter/nvim-treesitter/blob/main
  }
  -- Checking only the parser binary is not enough. `install()` also copies
  -- (usually as symlinks) that language's query files into a directory on
  -- 'runtimepath'. When those go stale, say after switching Neovim data
  -- directories, the parser file still exists but the highlight query
  -- resolves to nothing. Every buffer for that language then renders with
  -- zero syntax highlighting, and `:checkhealth` plus `require('nvim-treesitter')`
  -- both report nothing wrong. Checking the query as well as the parser
  -- makes that failure self-heal on the next startup instead of sitting
  -- there unnoticed.
  local isnt_installed = function(lang)
    local has_parser = #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) > 0
    local has_query = vim.treesitter.query.get(lang, 'highlights') ~= nil
    return not (has_parser and has_query)
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then require('nvim-treesitter').install(to_install, { force = true }) end

  -- Language aliases must be registered before building `ts_filetypes` and
  -- evaluating fold queries:
  -- - 'jsonc' uses the 'json' grammar.
  -- - 'mdx' and 'octo' (GitHub PR/comment buffers) use the 'markdown' grammar.
  vim.treesitter.language.register('json', 'jsonc')
  vim.treesitter.language.register('markdown', { 'mdx', 'octo' })

  local ts_filetypes = {}
  for _, lang in ipairs(languages) do
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      ts_filetypes[ft] = true
    end
  end

  -- Unified buffer lifecycle: start tree-sitter for supported filetypes and
  -- configure syntax folds when both a parser binary and `folds` query exist,
  -- falling back to `indent` folds otherwise.
  local attach_treesitter_and_folds = function(ev)
    local buf = ev.buf
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
    local ft = vim.bo[buf].filetype
    if ft == '' then return end
    if ts_filetypes[ft] then pcall(vim.treesitter.start, buf) end

    local lang = vim.treesitter.language.get_lang(ft) or ft
    local has_parser = #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) > 0
    local has_folds = vim.treesitter.query.get(lang, 'folds') ~= nil
    local use_expr = has_parser and has_folds

    if buf == vim.api.nvim_get_current_buf() then
      if use_expr then
        vim.cmd('setlocal foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr()')
      else
        vim.cmd('setlocal foldmethod=indent')
      end
    end
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if use_expr then
        vim.wo[win].foldmethod = 'expr'
        vim.wo[win].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
      else
        vim.wo[win].foldmethod = 'indent'
      end
    end
  end

  Config.new_autocmd('FileType', '*', attach_treesitter_and_folds, 'Start tree-sitter and configure folds')
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= '' then
      attach_treesitter_and_folds({ buf = buf })
    end
  end

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
  add({
    'https://github.com/neovim/nvim-lspconfig',
    -- Feeds 'jsonls' (and 'yamlls', if enabled later) the SchemaStore catalog,
    -- so files like 'package.json' / 'tsconfig.json' get schema-driven
    -- completion, hover docs, and validation. Wired in 'after/lsp/jsonls.lua'.
    'https://github.com/b0o/schemastore.nvim',
  })

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
    -- 'vscode-json-language-server' (Mason package: 'json-lsp'). Handles
    -- 'json' and 'jsonc' filetypes; schema wiring lives in 'after/lsp/jsonls.lua'.
    'jsonls',
    'copilot',
    -- Prose lint (spelling + grammar with code actions) for markdown.
    -- Mason package: 'harper-ls'. Complements the built-in `spell` flagging
    -- in 'after/ftplugin/markdown.lua', which has no hover or actions.
    -- Configured in 'after/lsp/harper_ls.lua'.
    'harper_ls',
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

    -- Accept inline completion word-by-word, one word per press
    -- (Zed: `alt-tab` = editor::AcceptNextWordEditPrediction).
    -- `<M-Tab>` is Option+Tab; `<C-l>` is an alternative chord.
    local get_completor_table = function()
      for i = 1, 10 do
        local name, val = debug.getupvalue(vim.lsp.inline_completion.get, i)
        if name == 'Completor' and type(val) == 'table' then return val end
      end
    end

    local accept_word = function(fallback)
      return function()
        local pum = vim.fn.pumvisible() == 1
        local ok = vim.lsp.inline_completion.get({
          bufnr = bufnr,
          on_accept = function(item)
            local ins = item.insert_text
            local text = type(ins) == 'table' and ins.value or ins
            if type(text) ~= 'string' or text == '' then return item end

            -- `item.insert_text` starts at `item.range` (often column 0 of the
            -- line), so keep the prefix already before the cursor and slice one
            -- word from the ghost-text suffix after the cursor.
            local prefix_len = 0
            if item.range then
              local start_row, start_col = item.range:to_extmark()
              local cur = vim.api.nvim_win_get_cursor(0)
              local cur_row, cur_col = cur[1] - 1, cur[2]
              if start_row == cur_row and cur_col > start_col then
                prefix_len = cur_col - start_col
              end
            end

            local prefix = text:sub(1, prefix_len)
            local suffix = text:sub(prefix_len + 1)
            local chunk = suffix:match('^%s*[%w_]+%s*') or suffix:match('^%s*%S+%s*')
            if not chunk or chunk == '' then return item end

            local full_ins = vim.deepcopy(ins)
            local orig_range = item.range
            local new_text = prefix .. chunk
            local accepted_item = vim.tbl_extend('force', item, {
              insert_text = type(ins) == 'table' and vim.tbl_extend('force', ins, { value = new_text }) or new_text,
            })

            -- If more ghost text remains after this word, restore `comp.current`
            -- with its range end advanced to the new cursor position so rapid
            -- Option+Tab presses keep stepping word-by-word without duplication.
            if #chunk < #suffix then
              vim.schedule(function()
                local Completor = get_completor_table()
                local comp = Completor and Completor.active and Completor.active[bufnr]
                if not comp then return end
                if orig_range then
                  local cur = vim.api.nvim_win_get_cursor(0)
                  orig_range.end_row = cur[1] - 1
                  orig_range.end_col = cur[2]
                end
                comp.current = {
                  _index = item._index or 1,
                  client_id = item.client_id,
                  insert_text = full_ins,
                  range = orig_range,
                  _filter_text = item._filter_text,
                  command = item.command,
                }
                pcall(comp.show, comp)
              end)
            end

            return accepted_item
          end,
        })
        if ok then return pum and '<C-e>' or '' end
        return fallback
      end
    end
    vim.keymap.set('i', '<C-l>', accept_word('<C-l>'), { expr = true, buffer = bufnr, desc = 'Accept inline completion word' })
    vim.keymap.set('i', '<M-Tab>', accept_word('<M-Tab>'), { expr = true, buffer = bufnr, desc = 'Accept inline completion word' })
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
      -- Needs `:Mason` install of `prettierd` (no md formatter yet).
      markdown = { 'prettierd' },
    },
  })

  -- Signal to the format-on-save autocmd in 'plugin/10_options.lua' that
  -- setup ran; saves before this are a no-op (see scheduling contract).
  Config.conform_ready = true
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

-- Snacks & Markdown rendering ================================================
--
-- 'snacks.nvim' is shared across 'octo.nvim' (`picker = 'snacks'`),
-- 'sidekick.nvim' (`picker = 'snacks'` + `<M-a>` send action), and Oil's
-- `snacks.rename` LSP hook in 'plugin/24_explorer.lua'.
-- 'render-markdown.nvim' renders Markdown, MDX, and Octo buffers in-place.
later(function()
  add({
    'https://github.com/folke/snacks.nvim',
    'https://github.com/MeanderingProgrammer/render-markdown.nvim',
  })

  require('snacks').setup({
    picker = {
      -- Keep 'mini.pick' as the global `vim.ui.select` handler; 'snacks' is
      -- only used where explicitly requested ('octo.nvim' and 'sidekick.nvim').
      ui_select = false,
      actions = {
        sidekick_send = function(...)
          return require('sidekick.cli.picker.snacks').send(...)
        end,
      },
      win = {
        input = {
          keys = {
            ['<a-a>'] = { 'sidekick_send', mode = { 'n', 'i' } },
          },
        },
      },
    },
  })

  require('render-markdown').setup({
    file_types = { 'markdown', 'mdx', 'octo' },
    html = {
      tag = {
        details = { icon = '' },
        summary = { icon = '▸ ', highlight = 'RenderMarkdownH6' },
        a = { icon = '󰌹 ', highlight = 'RenderMarkdownLink' },
        img = { icon = '󰥶 ', highlight = 'RenderMarkdownLink' },
      },
    },
  })
end)

-- Editing extras =============================================================

-- - 'yanky.nvim'      - yank ring: cycle through previous yanks after pasting
-- - 'dial.nvim'       - smarter `<C-a>`/`<C-x>` increment/decrement
-- - 'inc-rename.nvim' - live preview while renaming via LSP (`<Leader>lr`)
-- - 'trouble.nvim'    - pretty diagnostics/quickfix/reference lists (`<Leader>x*`)
-- - 'quicker.nvim'    - editable quickfix buffers with expandable context (`<Leader>eq`)
-- - 'grug-far.nvim'   - project-wide search and replace (`<Leader>r*`)
-- - 'diffview.nvim'   - all touched files rendered side by side (`<Leader>gu`);
--   needs 'plenary.nvim' as a dependency
later(function()
  add({
    'https://github.com/gbprod/yanky.nvim',
    'https://github.com/monaqa/dial.nvim',
    'https://github.com/smjonas/inc-rename.nvim',
    'https://github.com/folke/trouble.nvim',
    'https://github.com/stevearc/quicker.nvim',
    'https://github.com/MagicDuck/grug-far.nvim',
    'https://github.com/nvim-lua/plenary.nvim',
    'https://github.com/sindrets/diffview.nvim',
  })

  require('yanky').setup()
  require('inc_rename').setup()
  require('trouble').setup()
  require('quicker').setup({
    keys = {
      {
        '>',
        function() require('quicker').expand({ before = 2, after = 2, add_to_existing = true }) end,
        desc = 'Expand quickfix context',
      },
      {
        '<',
        function() require('quicker').collapse() end,
        desc = 'Collapse quickfix context',
      },
    },
  })
  require('grug-far').setup()

  -- Extend every 'grug-far' buffer with path-filling actions (`\u` open
  -- buffers, `\Q` quickfix files, `\g` pick files via mini.pick, `\B` pick
  -- open buffers via mini.pick) and `\h` to toggle `--help` in Flags.
  -- Appending to `inst._context.actions` puts them in the top virtual help
  -- header and the `g?` help window automatically.
  local pick_into_grug_paths = function(buf, source_kind)
    local inst = require('grug-far').get_instance(buf)
    if not inst then return end

    local apply_paths = function(paths)
      if not paths or #paths == 0 then return end
      local escaped = vim.tbl_map(function(p)
        local rel = vim.fn.fnamemodify(p, ':.')
        return (rel:gsub(' ', '\\ '))
      end, paths)
      vim.schedule(function()
        if inst:is_valid() then
          inst:update_input_values({ paths = table.concat(escaped, '\n') }, false)
        end
      end)
    end

    local item_path = function(m)
      if type(m) ~= 'table' then return m end
      return m.path or (m.bufnr and vim.api.nvim_buf_get_name(m.bufnr)) or m.text
    end

    local choose_one = function(item)
      if not item then return end
      local matches = MiniPick.get_picker_matches()
      if matches and matches.marked and #matches.marked > 0 then
        apply_paths(vim.tbl_map(item_path, matches.marked))
        return
      end
      apply_paths({ item_path(item) })
    end

    local choose_many = function(items)
      apply_paths(vim.tbl_map(item_path, items or {}))
    end

    local opts = {
      source = {
        name = 'GrugFar Paths (' .. source_kind .. '; <C-x> mark, <CR> fill)',
        choose = choose_one,
        choose_marked = choose_many,
      },
    }
    if source_kind == 'buffers' then
      MiniPick.builtin.buffers(nil, opts)
    else
      MiniPick.builtin.files(nil, opts)
    end
  end

  Config.new_autocmd('FileType', 'grug-far', function(ev)
    local buf = ev.buf
    local ok, grug = pcall(require, 'grug-far')
    if not ok then return end
    local inst = grug.get_instance(buf)
    if not inst then return end

    local utils = require('grug-far.utils')
    local render = require('grug-far.render')
    local custom_actions = {
      {
        text = 'Paths: Buffers',
        keymap = { n = '<localleader>u' },
        description = 'Fill Paths with <buflist> (all open listed buffers).',
        action = function()
          inst:update_input_values({ paths = '<buflist>' }, false)
        end,
      },
      {
        text = 'Paths: Quickfix',
        keymap = { n = '<localleader>Q' },
        description = 'Fill Paths with <qflist> (all files in the quickfix list).',
        action = function()
          inst:update_input_values({ paths = '<qflist>' }, false)
        end,
      },
      {
        text = 'Pick Path Files',
        keymap = { n = '<localleader>g' },
        description = 'Pick project files via mini.pick (<C-x> to mark multiple) and fill Paths.',
        action = function()
          pick_into_grug_paths(buf, 'files')
        end,
      },
      {
        text = 'Pick Path Buffers',
        keymap = { n = '<localleader>B' },
        description = 'Pick open buffers via mini.pick (<C-x> to mark multiple) and fill Paths.',
        action = function()
          pick_into_grug_paths(buf, 'buffers')
        end,
      },
      {
        text = 'Toggle Flags Help',
        keymap = { n = '<localleader>h' },
        description = 'Toggle --help in Flags to view ripgrep flag documentation in the results list.',
        action = function()
          inst:toggle_flags({ '--help' })
        end,
      },
    }

    inst:when_ready(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      for _, action in ipairs(custom_actions) do
        table.insert(inst._context.actions, action)
        utils.setBufKeymap(buf, action.text, action.keymap, action.action)
      end
      render(buf, inst._context)
    end)
  end, 'Extend grug-far with path pickers and flag help')
  require('diffview').setup({
    keymaps = {
      -- `<Leader>e` (Explore) and `<Leader>b` (Buffer) are whole prefix groups
      -- here; diffview's buffer-local focus/toggle-files would shadow them
      -- inside every diffview buffer. Disabled so the groups keep working.
      -- Deliberately kept: `<tab>` file cycling (NES-Tab yields inside diffs),
      -- `-`/`s` staging, `L` log, `S`/`U`/`X` stage-all/unstage/restore —
      -- the panel's own job. Press `g?` in any diffview buffer for its keys.
      view = {
        { 'n', '<leader>e', false },
        { 'n', '<leader>b', false },
      },
      file_panel = {
        { 'n', '<leader>e', false },
        { 'n', '<leader>b', false },
      },
      file_history_panel = {
        { 'n', '<leader>e', false },
        { 'n', '<leader>b', false },
      },
    },
  })

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
-- Use the VS Code One Dark Pro port, including its language-specific queries
-- and LSP semantic highlights, rather than the separate Atom One Dark theme.
Config.now(function()
  add({ 'https://github.com/olimorris/onedarkpro.nvim' })

  local theme_config = {
    options = { transparency = false, cursorline = true },
    styles = { comments = 'italic', parameters = 'italic' },
    highlights = {
      -- A visible, subdued divider for editor splits and the terminal dock.
      WinSeparator = { fg = '#4b5263' },

      -- Diff colours from delta's dark defaults (as in lazygit), so Neovim's
      -- diff mode (Octo reviews, diffview) reads the same. `fg = 'none'`
      -- keeps syntax highlighting on changed lines; DiffText is delta's
      -- word-level emphasis.
      DiffAdd = { fg = 'none', bg = '#002800' },
      DiffDelete = { fg = '#5c6370', bg = '#3f0001' },
      DiffChange = { fg = 'none', bg = '#2a2f38' },
      DiffText = { fg = 'none', bg = '#006000' },

      -- Active buffer tab text in function-name blue (mini.tabline only).
      ['MiniTablineCurrent'] = { fg = '${blue}' },
      ['MiniTablineModifiedCurrent'] = { fg = '${blue}' },

      -- Match the installed VS Code theme where this port's defaults differ.
      -- Modern queries split native tags from component tags; don't inherit
      -- Neovim's default blue for @tag.builtin.
      ['@tag.builtin'] = { link = '@tag' },
      ['@tag.tsx'] = { fg = '${yellow}' },
      ['@tag.builtin.tsx'] = { fg = '${red}' },
      ['@tag.attribute.tsx'] = { fg = '${orange}', italic = true },
      ['@type.builtin.tsx'] = { fg = '${yellow}' },
      ['@tag.javascript'] = { fg = '${yellow}' },
      ['@tag.builtin.javascript'] = { fg = '${red}' },
      ['@tag.attribute.javascript'] = { fg = '${orange}', italic = true },
    },
  }
  require('onedarkpro').setup(theme_config)
  vim.cmd('colorscheme onedark')

  Config.toggle_transparency = function()
    theme_config.options.transparency = not theme_config.options.transparency
    require('onedarkpro').setup(theme_config)
    vim.cmd('colorscheme onedark')
  end
end)
