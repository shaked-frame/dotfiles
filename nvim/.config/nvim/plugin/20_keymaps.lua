-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

-- General mappings ===========================================================

-- Use this section to add custom general mappings. See `:h vim.keymap.set()`.

-- Hyper key alias (ZSA Voyager sends <M-C-S-D-*>).
-- NOTE: nvim decodes the Shift bit away (verified via Insert-mode `Ctrl-V`):
-- Shift folds into case for letters (`Hyper+p` arrives as `<M-C-D-P>`, so
-- pass an UPPERCASE letter) and is dropped for the rest (`Hyper+\` arrives
-- as `<M-C-D-\>`). Map the decoded form, not the sent form.
local H = function(key) return '<M-C-D-' .. key .. '>' end

-- An example helper to create a Normal mode mapping
local nmap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set('n', lhs, rhs, { desc = desc })
end

-- Picker and split mechanics live in 'plugin/21_pickers.lua'
-- (`Config.Pickers`) and 'plugin/22_splits.lua' (`Config.Splits`).
-- This file stays a thin keymap catalog.
-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap('[p', '<Cmd>exe "iput! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "iput "  . v:register<CR>', 'Paste Below')

-- Buffer navigation (Zed: `H`/`L` = ActivatePrevious/NextItem)
nmap('H', '<Cmd>bprevious<CR>', 'Previous buffer')
nmap('L', '<Cmd>bnext<CR>', 'Next buffer')

-- Buffer picker (Zed: `space space` = tab_switcher::Toggle)
nmap('<Leader><Leader>', function() Config.Pickers.buffers() end, 'Buffers')

-- Clear search highlight and LSP reference highlights
nmap('<Esc>', function()
  if vim.v.hlsearch == 1 then vim.cmd('nohlsearch') end
  vim.lsp.buf.clear_references()
end, 'Clear highlights')

-- Splits (Zed: `s s` SplitDown, `s v` SplitAndMoveRight, `s h`/`s l` move item)

-- Split mechanics live in 'plugin/22_splits.lua' (`Config.Splits`).

nmap('ss', '<Cmd>split<CR>', 'Split horizontally')
nmap('sv', function() Config.Splits.split_and_move('vsplit') end, 'Split and move buffer right')
nmap('sl', function() Config.Splits.move_to_side('l') end, 'Move buffer to right split')
nmap('sh', function() Config.Splits.move_to_side('h') end, 'Move buffer to left split')

-- Jump to a word (Zed: `g w` = HelixJumpToWord)
nmap('gw', function() MiniJump2d.start(MiniJump2d.builtin_opts.word_start) end, 'Jump to word')

-- LSP navigation. NOTE: `gr*` is used because `gr` alone is the "replace"
-- operator from 'mini.operators'. See `:h gra` for Neovim's built-in versions.
local pick_lsp_references = function()
  vim.cmd.cclose()
  vim.cmd.lclose()
  vim.cmd([[Pick lsp scope="references"]])
end

nmap('gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', 'Go to definition')
nmap('gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', 'Go to declaration')
nmap('gy', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', 'Go to type definition')
nmap('grr', pick_lsp_references, 'References')
nmap('gri', '<Cmd>lua vim.lsp.buf.implementation()<CR>', 'Go to implementation')
nmap('K', function()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local diagnostics = vim.diagnostic.get(0, { lnum = line })

  if #diagnostics > 0 then
    vim.diagnostic.open_float({ scope = 'line' })
  else
    vim.lsp.buf.hover()
  end
end, 'Show diagnostics or hover')
-- `gra` code action (Zed muscle memory, and Neovim's own default, see `:h gra`).
-- NOTE: `gr` alone is the "replace" operator from 'mini.operators', so after
-- typing `gr` there is a `timeoutlen` pause before `gra` fires. Longer `gr..`
-- sequences (`graq` replace-around-quote, `grai` replace-around-indent) still
-- work when typed without hesitation.
nmap('gra', '<Cmd>lua vim.lsp.buf.code_action()<CR>', 'Actions')

-- Make $ and ^ go to actual start/end of line (including whitespace)
vim.keymap.set({ 'n', 'v' }, '$', 'g_', { desc = 'End of line (last char)' })
vim.keymap.set({ 'n', 'v' }, '^', '0', { desc = 'Start of line (column 0)' })

-- Git hunk navigation (Zed: `f7`/`f8` in the diff view)
nmap('[h', '<Cmd>lua MiniDiff.goto_hunk("prev")<CR>zz', 'Previous hunk')
nmap(']h', '<Cmd>lua MiniDiff.goto_hunk("next")<CR>zz', 'Next hunk')
-- Hyper+p next hunk (Zed: `ctrl-alt-cmd-shift-p` GoToHunk)
nmap(H('P'), '<Cmd>lua MiniDiff.goto_hunk("next")<CR>zz', 'Next hunk')

-- Window resizing with Hyper key (Zed: `ctrl-alt-cmd-^&*(` = ResizePane*)
nmap(H('8'), '<Cmd>vertical resize +5<CR>', 'Increase window width')
nmap(H('7'), '<Cmd>vertical resize -5<CR>', 'Decrease window width')
nmap(H('9'), '<Cmd>resize +3<CR>', 'Increase window height')
nmap(H('0'), '<Cmd>resize -3<CR>', 'Decrease window height')

-- Diagnostic navigation with Hyper key (Zed: `ctrl-alt-cmd-|` = GoToDiagnostic)
nmap(H('\\'), function()
  vim.diagnostic.jump({ count = 1, float = true, wrap = true })
  vim.cmd('normal! zz')
end, 'Next diagnostic')

-- Toggle the persistent terminal dock with Ctrl-/. Mechanics live in
-- 'plugin/23_terminal.lua' (`Config.Terminal`).
vim.keymap.set({ 'n', 't' }, '<C-/>', function() Config.Terminal.toggle() end, { desc = 'Toggle terminal dock' })

-- Open compiler paths from terminal output without replacing the terminal.
-- Return the original mouse key outside paths so selection still works.
for _, key in ipairs({ '<2-LeftMouse>', '<C-LeftMouse>' }) do
  vim.keymap.set({ 'n', 't' }, key, function() return Config.TerminalLinks.mouse(key) end,
    { expr = true, desc = 'Open terminal file at mouse' })
end

-- Navigate windows and Herdr panes from Normal and Terminal mode with `<C-hjkl>`
-- (Zed: `ctrl-hjkl` = workspace::ActivatePane*). Walks Neovim splits first and
-- crosses into the adjacent Herdr pane at a split edge.
vim.keymap.set({ 'n', 't' }, '<C-h>', function() Config.Splits.navigate('h') end, { desc = 'Go to left window/pane' })
vim.keymap.set({ 'n', 't' }, '<C-j>', function() Config.Splits.navigate('j') end, { desc = 'Go to lower window/pane' })
vim.keymap.set({ 'n', 't' }, '<C-k>', function() Config.Splits.navigate('k') end, { desc = 'Go to upper window/pane' })
vim.keymap.set({ 'n', 't' }, '<C-l>', function() Config.Splits.navigate('l') end, { desc = 'Go to right window/pane' })

-- Open the active file explorer (`Config.explorer` in 'init.lua') at the
-- current file with `-`.
nmap('-', function() Config.Explorer.open_at_file() end, 'Explore at file')

-- Many general mappings are created by 'mini.basics'. See 'plugin/30_mini.lua'

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- Leader mappings ============================================================

-- Neovim has the concept of a Leader key (see `:h <Leader>`). It is a configurable
-- key that is primarily used for "workflow" mappings (opposed to text editing).
-- Like "open file explorer", "create scratch buffer", "pick from buffers".
--
-- In 'plugin/10_options.lua' <Leader> is set to <Space>, i.e. press <Space>
-- whenever there is a suggestion to press <Leader>.
--
-- This config uses a "two key Leader mappings" approach: first key describes
-- semantic group, second key executes an action. Both keys are usually chosen
-- to create some kind of mnemonic.
-- Example: `<Leader>f` groups "find" type of actions; `<Leader>ff` - find files.
-- Use this section to add Leader mappings in a structural manner.
--
-- Usually if there are global and local kinds of actions, lowercase second key
-- denotes global and uppercase - local.
-- Example: `<Leader>fs` / `<Leader>fS` - find workspace/document LSP symbols.
--
-- Many of the mappings use 'mini.nvim' modules set up in 'plugin/30_mini.lua'.

-- Create a global table with information about Leader groups in certain modes.
-- This is used to provide 'mini.clue' with extra clues.
-- Add an entry if you create a new group.
Config.leader_group_clues = {
  { mode = 'n', keys = '<Leader>a', desc = '+AI' },
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>e', desc = '+Explore/Edit' },
  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>gp', desc = '+Pull request' },
  { mode = 'n', keys = '<Leader>l', desc = '+Language' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>r', desc = '+Replace' },
  { mode = 'n', keys = '<Leader>s', desc = '+Session' },
  { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },
  { mode = 'n', keys = '<Leader>x', desc = '+Trouble' },

  { mode = 'x', keys = '<Leader>a', desc = '+AI' },
  { mode = 'x', keys = '<Leader>f', desc = '+Find' },
  { mode = 'x', keys = '<Leader>g', desc = '+Git' },
  { mode = 'x', keys = '<Leader>l', desc = '+Language' },
  { mode = 'x', keys = '<Leader>r', desc = '+Replace' },
}

-- Helpers for a more concise `<Leader>` mappings.
-- Most of the mappings use `<Cmd>...<CR>` string as a right hand side (RHS) in
-- an attempt to be more concise yet descriptive. See `:h <Cmd>`.
-- This approach also doesn't require the underlying commands/functions to exist
-- during mapping creation: a "lazy loading" approach to improve startup time.
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

-- b is for 'Buffer'. Common usage:
-- - `<Leader>bs` - create scratch (temporary) buffer
-- - `<Leader>ba` - navigate to the alternative buffer
-- - `<Leader>bo` - close all other listed buffers
-- - `<Leader>bw` - wipeout (fully delete) current buffer
local new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end
local close_other_buffers = function()
  local current = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.bo[buf].buflisted and vim.api.nvim_buf_is_loaded(buf) then
      MiniBufremove.delete(buf)
    end
  end
end

local close_clean_buffers = function()
  local closed = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' then
      local name = vim.api.nvim_buf_get_name(buf)
      local diff_data = _G.MiniDiff and MiniDiff.get_buf_data(buf) or nil
      local git_data = _G.MiniGit and MiniGit.get_buf_data(buf) or nil
      local has_hunks = diff_data and diff_data.hunks and #diff_data.hunks > 0
      local has_git_status = git_data and git_data.status and git_data.status ~= '  ' and git_data.status ~= '!!'
      local is_dirty = vim.bo[buf].modified or has_hunks or has_git_status
      if not is_dirty and (not git_data or git_data.status == nil) and name ~= '' then
        local res = vim.system({ 'git', '-C', vim.fs.dirname(name), 'status', '--porcelain', '--', name }, { text = true }):wait()
        is_dirty = res.code == 0 and vim.trim(res.stdout or '') ~= ''
      end
      if not is_dirty then
        MiniBufremove.delete(buf)
        closed = closed + 1
      end
    end
  end
  vim.notify(string.format('Closed %d clean buffer%s', closed, closed == 1 and '' or 's'), vim.log.levels.INFO)
end

nmap_leader('ba', '<Cmd>b#<CR>',                                 'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>',         'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
nmap_leader('bg', '<Cmd>Pick buf_lines scope="all"<CR>',         'Grep open buffers')
nmap_leader('bm', close_clean_buffers,                           'Only modified (git)')
nmap_leader('bn', '<Cmd>enew<CR>',                               'New file')
nmap_leader('bo', close_other_buffers,                           'Only current')
nmap_leader('bs', new_scratch_buffer,                            'Scratch')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>',        'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- e is for 'Explore' and 'Edit'. Common usage:
-- - `<Leader>ed` - open explorer at current working directory
-- - `<Leader>ef` - open directory of current file (needs to be present on disk)
-- - `<Leader>ei` - edit 'init.lua'
-- - All mappings that use `edit_plugin_file` - edit 'plugin/' config files
local edit_plugin_file = function(filename)
  return string.format('<Cmd>edit %s/plugin/%s<CR>', vim.fn.stdpath('config'), filename)
end
-- Sources a 'plugin/' config file by absolute path (not `%`), so it works
-- regardless of the current buffer or working directory.
local source_plugin_file = function(filename)
  return string.format('<Cmd>source %s/plugin/%s<CR>', vim.fn.stdpath('config'), filename)
end

nmap_leader('eb', '<Cmd>Pick lsp scope="document_symbol"<CR>', 'Outline (symbols)')
nmap_leader('ed', function() Config.Explorer.open_cwd() end,     'Directory')
nmap_leader('ef', function() Config.Explorer.open_at_file() end, 'File directory')
nmap_leader('ei', '<Cmd>edit $MYVIMRC<CR>',                 'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'),       'Keymaps config')
nmap_leader('em', edit_plugin_file('30_mini.lua'),          'MINI config')
nmap_leader('en', '<Cmd>lua MiniNotify.show_history()<CR>', 'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'),       'Options config')
nmap_leader('ep', edit_plugin_file('40_plugins.lua'),       'Plugins config')
nmap_leader('eq', function() require('quicker').toggle() end,                     'Quickfix list')
nmap_leader('eQ', function() require('quicker').toggle({ loclist = true }) end,   'Location list')
nmap_leader('eR', source_plugin_file('20_keymaps.lua'),     'Reload keymaps')

-- f is for 'Fuzzy Find'. Common usage:
-- - `<Leader>ff` - find files; for best performance requires `ripgrep`
-- - `<Leader>fg` - find inside files; requires `ripgrep`
-- - `<Leader>fh` - find help tag
-- - `<Leader>fr` - resume latest picker
-- - `<Leader>fv` - all visited paths; requires 'mini.visits'
--
-- All these use 'mini.pick'. See `:h MiniPick-overview` for an overview.
local pick_added_hunks_buf = '<Cmd>Pick git_hunks path="%" scope="staged"<CR>'
local pick_workspace_symbols_live = '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>'

-- File finders live in 'plugin/21_pickers.lua' (`Config.Pickers`).

nmap_leader('f/', '<Cmd>Pick history scope="/"<CR>',            '"/" history')
nmap_leader('f:', '<Cmd>Pick history scope=":"<CR>',            '":" history')
nmap_leader('fa', '<Cmd>Pick git_hunks scope="staged"<CR>',     'Added hunks (all)')
nmap_leader('fA', pick_added_hunks_buf,                         'Added hunks (buf)')
nmap_leader('fb', function() Config.Pickers.buffers() end,                 'Buffers')
nmap_leader('fc', '<Cmd>Pick git_commits<CR>',                  'Commits (all)')
nmap_leader('fC', '<Cmd>Pick git_commits path="%"<CR>',         'Commits (buf)')
nmap_leader('fd', '<Cmd>Pick diagnostic scope="all"<CR>',       'Diagnostic workspace')
nmap_leader('fD', '<Cmd>Pick diagnostic scope="current"<CR>',   'Diagnostic buffer')
nmap_leader('ff', '<Cmd>Pick files<CR>',                        'Files')
nmap_leader('fF', function() Config.Pickers.files_all() end,               'Files (hidden+ignored)')
nmap_leader('fg', '<Cmd>Pick grep_live<CR>',                    'Grep live')
nmap_leader('fG', '<Cmd>Pick grep pattern="<cword>"<CR>',       'Grep current word')
xmap_leader('fg', function()
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    vim.cmd('normal! \27') -- leave Visual so the '< '> marks are set
  end
  local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = vim.fn.visualmode() })
  local text = table.concat(lines, ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if text == '' then return end
  require('mini.pick').builtin.grep({ pattern = text })
end, 'Grep selection')
nmap_leader('fe', function() Config.Pickers.frontend_files() end,         'Files (frontend)')
nmap_leader('fE', function() Config.Pickers.frontend_grep() end,          'Grep (frontend)')
nmap_leader('fh', '<Cmd>Pick help<CR>',                         'Help tags')
nmap_leader('fH', '<Cmd>Pick hl_groups<CR>',                    'Highlight groups')
nmap_leader('fl', '<Cmd>Pick buf_lines scope="all"<CR>',        'Lines (all)')
nmap_leader('fL', '<Cmd>Pick buf_lines scope="current"<CR>',    'Lines (buf)')
nmap_leader('fm', '<Cmd>Pick git_hunks<CR>',                    'Modified hunks (all)')
nmap_leader('fM', '<Cmd>Pick git_hunks path="%"<CR>',           'Modified hunks (buf)')
nmap_leader('fr', '<Cmd>Pick resume<CR>',                       'Resume')
nmap_leader('fR', '<Cmd>Pick lsp scope="references"<CR>',       'References (LSP)')
nmap_leader('fs', pick_workspace_symbols_live,                  'Symbols workspace (live)')
nmap_leader('fS', '<Cmd>Pick lsp scope="document_symbol"<CR>',  'Symbols document')
nmap_leader('fv', '<Cmd>Pick visit_paths cwd=""<CR>',           'Visit paths (all)')
nmap_leader('fV', '<Cmd>Pick visit_paths<CR>',                  'Visit paths (cwd)')

-- g is for 'Git'. Common usage:
-- - `<Leader>gs` - show information at cursor
-- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
local git_log_buf_cmd = git_log_cmd .. ' --follow -- %'

local stage_buffer = function()
  local buf = vim.api.nvim_get_current_buf()
  local data = MiniDiff.get_buf_data(buf)
  if data and data.hunks and #data.hunks > 0 then
    MiniDiff.do_hunks(buf, 'apply')
    vim.notify('Staged buffer hunks', vim.log.levels.INFO)
  else
    vim.cmd('Git add -- %')
    vim.notify('Staged ' .. vim.fn.expand('%:.'), vim.log.levels.INFO)
  end
end

local restore_buffer = function()
  local ok, err = pcall(MiniDiff.do_hunks, vim.api.nvim_get_current_buf(), 'reset')
  if not ok then vim.notify(tostring(err), vim.log.levels.WARN) end
end

nmap_leader('ga', '<Cmd>Git diff --cached<CR>',             'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>',        'Added diff buffer')
nmap_leader('gb', '<Cmd>Git blame -- %<CR>',                'Blame buffer')
nmap_leader('gc', '<Cmd>Git commit<CR>',                    'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',            'Commit amend')
vim.keymap.set('x', '<Leader>gc', function() return MiniDiff.operator('apply') end, { expr = true, desc = 'Stage selection' })
nmap_leader('gd', '<Cmd>Git diff<CR>',                      'Diff')
nmap_leader('gD', '<Cmd>Git diff -- %<CR>',                 'Diff buffer')
vim.keymap.set('n', '<Leader>gh', function() return MiniDiff.operator('apply') .. 'gh' end, { expr = true, remap = true, desc = 'Stage hunk' })
vim.keymap.set('x', '<Leader>gh', function() return MiniDiff.operator('apply') end, { expr = true, desc = 'Stage selection' })
nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>',         'Log')
nmap_leader('gL', '<Cmd>' .. git_log_buf_cmd .. '<CR>',     'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>', 'Toggle overlay')
vim.keymap.set('n', '<Leader>gr', function() return MiniDiff.operator('reset') .. 'gh' end, { expr = true, remap = true, desc = 'Restore hunk' })
vim.keymap.set('x', '<Leader>gr', function() return MiniDiff.operator('reset') end, { expr = true, desc = 'Restore selection' })
nmap_leader('gR', restore_buffer,                           'Restore buffer')
nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',  'Show at cursor')
nmap_leader('gS', stage_buffer,                             'Stage buffer')
nmap_leader('gu', function()
  -- Toggle: close the view when open (`:q` alone cannot take it down).
  local ok, lib = pcall(require, 'diffview.lib')
  if ok and lib.get_current_view() then
    vim.cmd('DiffviewClose')
  else
    vim.cmd('DiffviewOpen')
  end
end, 'Uncommitted changes')

xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at selection')

-- l is for 'Language'. Common usage:
-- - `<Leader>ld` - show more diagnostic details in a floating window
-- - `<Leader>lr` - perform rename via LSP
-- - `<Leader>ls` - navigate to source definition of symbol under cursor
--
-- NOTE: most LSP mappings represent a more structured way of replacing built-in
-- LSP mappings (like `:h gra` and others). This is needed because `gr` is mapped
-- by an "replace" operator in 'mini.operators' (which is more commonly used).
nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>',     'Actions')
nmap_leader('ld', '<Cmd>lua vim.diagnostic.open_float()<CR>',   'Diagnostic popup')
nmap_leader('lf', '<Cmd>lua require("conform").format()<CR>',   'Format')
nmap_leader('li', '<Cmd>lua vim.lsp.buf.implementation()<CR>',  'Implementation')
nmap_leader('lh', '<Cmd>lua vim.lsp.buf.hover()<CR>',           'Hover')
nmap_leader('ll', '<Cmd>lua vim.lsp.codelens.run()<CR>',        'Lens')
-- inc-rename's recommended mapping: leave the cmdline open (no trailing
-- `<CR>`) so its live preview runs while typing. Auto-executing would
-- rename to the same name and skip the preview the plugin exists for.
vim.keymap.set('n', '<Leader>lr', function() return ':IncRename ' .. vim.fn.expand('<cword>') end,
  { expr = true, desc = 'Rename' })
nmap_leader('lR', pick_lsp_references,                          'References')
nmap_leader('ls', '<Cmd>lua vim.lsp.buf.definition()<CR>',      'Source definition')
nmap_leader('lt', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', 'Type definition')

xmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>',   'Actions')
xmap_leader('lf', '<Cmd>lua require("conform").format()<CR>', 'Format selection')

-- m is for zoom and modified files (Zed: `space m` ToggleZoom, `space m f`
-- OpenModifiedFiles). NOTE: 'mini.map' is intentionally disabled so that this
-- prefix is free. See 'plugin/30_mini.lua'.
nmap_leader('m',  '<Cmd>lua MiniMisc.zoom()<CR>',           'Zoom toggle')
nmap_leader('mf', '<Cmd>Pick git_files scope="modified"<CR>', 'Modified files')

-- Window sizing standalone mappings (Zed: `space =` EqualizePanes,
-- `space shift-m` Maximize). `M` is an uppercase alias for the same zoom
-- toggle as `<Leader>m` above, kept separate in case `m` group grows.
nmap_leader('=', '<Cmd>wincmd =<CR>',             'Equalize window sizes')
nmap_leader('M', '<Cmd>lua MiniMisc.zoom()<CR>', 'Maximize (zoom) window')

-- r is for 'Replace' (project-wide search and replace via 'grug-far.nvim')
nmap_leader('rr', '<Cmd>GrugFar<CR>', 'Search and replace')
xmap_leader('rr', function() require('grug-far').with_visual_selection() end, 'Search and replace selection')
nmap_leader('rw', function()
  require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') } })
end, 'Replace current word')
nmap_leader('rf', function()
  require('grug-far').open({ prefills = { paths = vim.fn.expand('%') } })
end, 'Replace in current file')
xmap_leader('rf', function()
  require('grug-far').with_visual_selection({ prefills = { paths = vim.fn.expand('%') } })
end, 'Replace selection in current file')
nmap_leader('rb', function()
  require('grug-far').open({ prefills = { paths = '<buflist>' } })
end, 'Replace in open buffers')
xmap_leader('rb', function()
  require('grug-far').with_visual_selection({ prefills = { paths = '<buflist>' } })
end, 'Replace selection in open buffers')
nmap_leader('rq', function()
  require('grug-far').open({ prefills = { paths = '<qflist>' } })
end, 'Replace in quickfix files')
xmap_leader('rq', function()
  require('grug-far').with_visual_selection({ prefills = { paths = '<qflist>' } })
end, 'Replace selection in quickfix files')

-- x is for 'Trouble' (diagnostics and list views)
nmap_leader('xx', '<Cmd>Trouble diagnostics toggle<CR>',              'Diagnostics')
nmap_leader('xX', '<Cmd>Trouble diagnostics toggle filter.buf=0<CR>', 'Diagnostics buffer')
nmap_leader('xq', '<Cmd>Trouble qflist toggle<CR>',                   'Quickfix')
nmap_leader('xl', '<Cmd>Trouble loclist toggle<CR>',                  'Location list')
nmap_leader('xr', '<Cmd>Trouble lsp_references toggle<CR>',           'References')

-- o is for 'Other'. Common usage:
-- - `<Leader>ob` - toggle transparent background
-- - `<Leader>oc` - toggle sticky treesitter context header
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
nmap_leader('ob', function() Config.toggle_transparency() end,        'Transparent background')
nmap_leader('oc', '<Cmd>TSContext toggle<CR>',                        'Treesitter context')
nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>',            'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',               'Trim trailspace')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',                     'Zoom toggle')

-- s is for 'Session'. Common usage:
-- - `<Leader>sn` - start new session
-- - `<Leader>sr` - read previously started session
-- - `<Leader>sR` - restart Neovim preserving current session
local session_new = 'vim.ui.input({ prompt = "Session name: " }, MiniSessions.write)'

nmap_leader('sd', '<Cmd>lua MiniSessions.select("delete")<CR>', 'Delete')
nmap_leader('sn', '<Cmd>lua ' .. session_new .. '<CR>',         'New')
nmap_leader('sr', '<Cmd>lua MiniSessions.select("read")<CR>',   'Read')
nmap_leader('sR', '<Cmd>lua MiniSessions.restart()<CR>',        'Restart')
nmap_leader('sw', '<Cmd>lua MiniSessions.write()<CR>',          'Write current')

-- t is for 'Terminal' ('plugin/23_terminal.lua')
nmap_leader('tt', function() Config.Terminal.toggle() end, 'Toggle dock')
nmap_leader('tn', function() Config.Terminal.new() end,    'New tab')
nmap_leader('tx', function() Config.Terminal.close() end,  'Close tab')
nmap_leader('tr', function() Config.Terminal.rename() end, 'Rename tab')
nmap_leader('tl', function() Config.Terminal.next() end,   'Next tab')
nmap_leader('th', function() Config.Terminal.prev() end,   'Previous tab')
nmap_leader('tf', function() Config.Terminal.pick() end,   'Pick tab')
nmap_leader('tv', function() Config.Terminal.toggle() end, 'Toggle dock')

-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
-- - `<Leader>vc` - pick among all files with "core" label.
nmap_leader('vc', function() Config.Pickers.core_visits('', 'Core visits (all)') end,  'Core visits (all)')
nmap_leader('vC', function() Config.Pickers.core_visits(nil, 'Core visits (cwd)') end, 'Core visits (cwd)')
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>',    'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>',          'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>',       'Remove label')
-- stylua: ignore end
