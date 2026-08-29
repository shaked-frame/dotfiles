-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- This file contains definitions of custom general and Leader mappings.

-- General mappings ===========================================================

-- Use this section to add custom general mappings. See `:h vim.keymap.set()`.

-- Hyper key alias (ZSA Voyager sends <M-C-S-D-*>)
-- Define <H-*> as shorthand for <M-C-S-D-*>
local H = function(key) return '<M-C-S-D-' .. key .. '>' end

-- An example helper to create a Normal mode mapping
local nmap = function(lhs, rhs, desc)
  -- See `:h vim.keymap.set()`
  vim.keymap.set('n', lhs, rhs, { desc = desc })
end

-- Buffer picker that allows deleting a buffer with `<C-d>` without closing it
local list_buffer_picker_items = function(include_current, include_unlisted)
  -- `nvim_exec2` rather than the deprecated `nvim_exec`
  local cmd = 'buffers' .. (include_unlisted and '!' or '')
  local buffers_output = vim.api.nvim_exec2(cmd, { output = true }).output
  local cur_buf_id = vim.api.nvim_get_current_buf()
  local items = {}

  for _, l in ipairs(vim.split(buffers_output, '\n')) do
    local buf_str, name = l:match('^%s*%d+'), l:match('"(.*)"')
    local buf_id = tonumber(buf_str)
    if buf_id ~= nil and (include_current or buf_id ~= cur_buf_id) then
      table.insert(items, { text = name, bufnr = buf_id })
    end
  end

  return items
end

local pick_buffers = function()
  local pick = require('mini.pick')
  local local_opts = { include_current = true, include_unlisted = false }

  local delete_current = function()
    local matches = pick.get_picker_matches()
    local current = matches and matches.current or nil
    local bufnr = current and current.bufnr or nil
    if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return end

    MiniBufremove.delete(bufnr)

    if not pick.is_picker_active() then return end

    local items = list_buffer_picker_items(local_opts.include_current, local_opts.include_unlisted)
    if #items == 0 then return true end
    pick.set_picker_items(items)
  end

  pick.builtin.buffers(local_opts, {
    mappings = { delete_buffer = { char = '<C-d>', func = delete_current } },
  })
end

-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap('[p', '<Cmd>exe "iput! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "iput "  . v:register<CR>', 'Paste Below')

-- Buffer navigation (Zed: `H`/`L` = ActivatePrevious/NextItem)
nmap('H', '<Cmd>bprevious<CR>', 'Previous buffer')
nmap('L', '<Cmd>bnext<CR>', 'Next buffer')

-- Buffer picker (Zed: `space space` = tab_switcher::Toggle)
nmap('<Leader><Leader>', pick_buffers, 'Buffers')

-- Clear search highlight and LSP reference highlights
nmap('<Esc>', function()
  if vim.v.hlsearch == 1 then vim.cmd('nohlsearch') end
  vim.lsp.buf.clear_references()
end, 'Clear highlights')

-- Splits (Zed: `s s` SplitDown, `s v` SplitAndMoveRight, `s h`/`s l` move item)
nmap('ss', '<Cmd>split<CR>', 'Split horizontally')
nmap('sv', '<Cmd>vsplit<CR>', 'Split vertically')
nmap('sl', '<Cmd>wincmd L<CR>', 'Move buffer to right split')
nmap('sh', '<Cmd>wincmd H<CR>', 'Move buffer to left split')

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

-- Make $ and ^ go to actual start/end of line (including whitespace)
vim.keymap.set({ 'n', 'v' }, '$', 'g_', { desc = 'End of line (last char)' })
vim.keymap.set({ 'n', 'v' }, '^', '0', { desc = 'Start of line (column 0)' })

-- Git hunk navigation (Zed: `f7`/`f8` in the diff view)
nmap('[h', '<Cmd>lua MiniDiff.goto_hunk("prev")<CR>', 'Previous hunk')
nmap(']h', '<Cmd>lua MiniDiff.goto_hunk("next")<CR>', 'Next hunk')

-- Window resizing with Hyper key (Zed: `ctrl-alt-cmd-^&*(` = ResizePane*)
nmap(H('8'), '<Cmd>vertical resize +5<CR>', 'Increase window width')
nmap(H('7'), '<Cmd>vertical resize -5<CR>', 'Decrease window width')
nmap(H('9'), '<Cmd>resize +3<CR>', 'Increase window height')
nmap(H('0'), '<Cmd>resize -3<CR>', 'Decrease window height')

-- Diagnostic navigation with Hyper key (Zed: `ctrl-alt-cmd-|` = GoToDiagnostic)
nmap(H('\\'), function() vim.diagnostic.jump({ count = 1, float = true }) end, 'Next diagnostic')

-- Toggle terminal with Ctrl-/
local toggle_terminal = function()
  local term_winid = nil

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == 'terminal' then
      term_winid = win
      break
    end
  end

  if term_winid then
    -- Terminal exists: close it if we are in it, otherwise focus it
    if vim.api.nvim_get_current_win() == term_winid then
      vim.api.nvim_win_close(term_winid, false)
    else
      vim.api.nvim_set_current_win(term_winid)
      vim.cmd('startinsert')
    end
  else
    vim.cmd('horizontal term')
    vim.cmd('resize 15')
  end
end

vim.keymap.set({ 'n', 't' }, '<C-/>', toggle_terminal, { desc = 'Toggle terminal' })

-- Navigate windows directly from Terminal mode with `<C-hjkl>`
-- (Zed: `ctrl-hjkl` = workspace::ActivatePane*)
vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-w>h]], { desc = 'Go to left window' })
vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-w>j]], { desc = 'Go to lower window' })
vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-w>k]], { desc = 'Go to upper window' })
vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-w>l]], { desc = 'Go to right window' })

-- Open the file explorer at the current file with `-`, like 'oil.nvim'/netrw.
-- Passing `true` makes 'mini.files' restore its previous state (including marks
-- and bookmarks) instead of opening fresh.
nmap('-', function()
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then
    MiniFiles.open()
    return
  end

  MiniFiles.open(path, true)
end, 'Explore at file')

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
  { mode = 'n', keys = '<Leader>l', desc = '+Language' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>r', desc = '+Replace' },
  { mode = 'n', keys = '<Leader>s', desc = '+Session' },
  { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },
  { mode = 'n', keys = '<Leader>x', desc = '+Trouble' },

  { mode = 'x', keys = '<Leader>a', desc = '+AI' },
  { mode = 'x', keys = '<Leader>g', desc = '+Git' },
  { mode = 'x', keys = '<Leader>l', desc = '+Language' },
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

nmap_leader('ba', '<Cmd>b#<CR>',                                 'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>',         'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
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
local explore_at_file = '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>'
local explore_quickfix = function()
  vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and 'cclose' or 'copen')
end
local explore_locations = function()
  vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and 'lclose' or 'lopen')
end

nmap_leader('eb', '<Cmd>Pick lsp scope="document_symbol"<CR>', 'Outline (symbols)')
nmap_leader('ed', '<Cmd>lua MiniFiles.open()<CR>',          'Directory')
nmap_leader('ef', explore_at_file,                          'File directory')
nmap_leader('ei', '<Cmd>edit $MYVIMRC<CR>',                 'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'),       'Keymaps config')
nmap_leader('em', edit_plugin_file('30_mini.lua'),          'MINI config')
nmap_leader('en', '<Cmd>lua MiniNotify.show_history()<CR>', 'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'),       'Options config')
nmap_leader('ep', edit_plugin_file('40_plugins.lua'),       'Plugins config')
nmap_leader('eq', explore_quickfix,                         'Quickfix list')
nmap_leader('eQ', explore_locations,                        'Location list')

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

-- Find files including hidden/ignored ones, and follow symlinks. `--follow` is
-- important for stow-managed dotfiles: '~/.config/*' are symlinks into
-- '~/dotfiles', which `rg` will not descend into by default.
local pick_files_all = function()
  local command = { 'rg', '--files', '--hidden', '--no-ignore', '--follow', '--glob', '!.git/**' }
  MiniPick.builtin.cli({ command = command }, { source = { name = 'Files (all)', cwd = vim.fn.getcwd() } })
end

nmap_leader('f/', '<Cmd>Pick history scope="/"<CR>',            '"/" history')
nmap_leader('f:', '<Cmd>Pick history scope=":"<CR>',            '":" history')
nmap_leader('fa', '<Cmd>Pick git_hunks scope="staged"<CR>',     'Added hunks (all)')
nmap_leader('fA', pick_added_hunks_buf,                         'Added hunks (buf)')
nmap_leader('fb', pick_buffers,                                 'Buffers')
nmap_leader('fc', '<Cmd>Pick git_commits<CR>',                  'Commits (all)')
nmap_leader('fC', '<Cmd>Pick git_commits path="%"<CR>',         'Commits (buf)')
nmap_leader('fd', '<Cmd>Pick diagnostic scope="all"<CR>',       'Diagnostic workspace')
nmap_leader('fD', '<Cmd>Pick diagnostic scope="current"<CR>',   'Diagnostic buffer')
nmap_leader('ff', '<Cmd>Pick files<CR>',                        'Files')
nmap_leader('fF', pick_files_all,                               'Files (hidden+ignored)')
nmap_leader('fg', '<Cmd>Pick grep_live<CR>',                    'Grep live')
nmap_leader('fG', '<Cmd>Pick grep pattern="<cword>"<CR>',       'Grep current word')
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

nmap_leader('ga', '<Cmd>Git diff --cached<CR>',             'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>',        'Added diff buffer')
nmap_leader('gb', '<Cmd>Git blame -- %<CR>',                'Blame buffer')
nmap_leader('gc', '<Cmd>Git commit<CR>',                    'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',            'Commit amend')
nmap_leader('gd', '<Cmd>Git diff<CR>',                      'Diff')
nmap_leader('gD', '<Cmd>Git diff -- %<CR>',                 'Diff buffer')
nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>',         'Log')
nmap_leader('gL', '<Cmd>' .. git_log_buf_cmd .. '<CR>',     'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>', 'Toggle overlay')
nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',  'Show at cursor')
nmap_leader('gu', '<Cmd>Git diff HEAD<CR>',                 'Uncommitted changes')

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
nmap_leader('lr', '<Cmd>IncRename <C-r><C-w><CR>',              'Rename')
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

-- r is for 'Replace' (project-wide search and replace via 'grug-far.nvim')
nmap_leader('rr', '<Cmd>GrugFar<CR>',             'Search and replace')
nmap_leader('rw', '<Cmd>GrugFar <C-r><C-w><CR>',  'Replace current word')

-- x is for 'Trouble' (diagnostics and list views)
nmap_leader('xx', '<Cmd>Trouble diagnostics toggle<CR>',              'Diagnostics')
nmap_leader('xX', '<Cmd>Trouble diagnostics toggle filter.buf=0<CR>', 'Diagnostics buffer')
nmap_leader('xq', '<Cmd>Trouble qflist toggle<CR>',                   'Quickfix')
nmap_leader('xl', '<Cmd>Trouble loclist toggle<CR>',                  'Location list')
nmap_leader('xr', '<Cmd>Trouble lsp_references toggle<CR>',           'References')

-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',    'Trim trailspace')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',          'Zoom toggle')

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

-- t is for 'Terminal'
nmap_leader('tT', '<Cmd>horizontal term<CR>', 'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>',   'Terminal (vertical)')

-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
-- - `<Leader>vc` - pick among all files with "core" label.
local make_pick_core = function(cwd, desc)
  return function()
    local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
    local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
    MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
  end
end

nmap_leader('vc', make_pick_core('',  'Core visits (all)'),       'Core visits (all)')
nmap_leader('vC', make_pick_core(nil, 'Core visits (cwd)'),       'Core visits (cwd)')
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>',    'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>',          'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>',       'Remove label')
-- stylua: ignore end
