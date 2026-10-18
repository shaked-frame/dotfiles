-- ┌──────────────────────────────┐
-- │ Octo: GitHub PRs and reviews │
-- └──────────────────────────────┘
--
-- Agent review flow: the agent posts findings as a *pending* review (visible
-- only to you), `<Leader>gpr` opens it next to the diff, you edit or delete
-- comments there, then `<Leader>gpS` submits. Review commands use the PR of
-- the current branch, so run them from the PR's checkout.
--
-- Inside review buffers octo has its own maps: `]t`/`[t` thread,
-- `]q`/`[q` file, `<LocalLeader>ca` add comment, `<LocalLeader>cd` delete
-- comment, `<C-c>` close the review tab. `:Octo actions` lists everything.

Config.later(function()
  -- Snacks is loaded and configured in 'plugin/40_plugins.lua'.
  vim.pack.add({
    'https://github.com/pwntester/octo.nvim',
  })

  require('octo').setup({
    picker = 'snacks',
    enable_builtin = true,
    use_timeline_icons = false,
    -- Comment icon in the sign column on lines with review threads
    -- (yellow = pending). Off by default in octo.
    ui = { use_signcolumn = true },
    comment_icon = '\239\129\181', -- nf-fa-comment (U+F075)
    reviews = { show_virtual_text = false },
  })

  -- Review windows ship with `foldlevel = 0`, which collapses every fold, and
  -- the local right-side buffer keeps it in later windows. Keep folds open.
  require('octo.reviews.file-entry').FileEntry.winopts.foldlevel = 99

  -- octo clears a fresh buffer's undo history with `:normal`, which throws
  -- E565 when its async load lands while text is locked (typing in the
  -- `<Leader>gpl` picker). Retry until the lock is gone.
  local octo_utils = require('octo.utils')
  local clear_history = octo_utils.clear_history
  local function clear_history_when_unlocked(bufnr, attempts)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    local undolevels = vim.o.undolevels
    local ok, err = pcall(vim.api.nvim_buf_call, bufnr, clear_history)
    if ok then return end
    vim.o.undolevels = undolevels
    if attempts == 0 or not tostring(err):match('E565') then error(err) end
    vim.defer_fn(function() clear_history_when_unlocked(bufnr, attempts - 1) end, 50)
  end
  octo_utils.clear_history = function() clear_history_when_unlocked(vim.api.nvim_get_current_buf(), 20) end

  -- A line can carry several threads, and octo places all their signs at the
  -- same priority, so a resolved one can hide your pending comment. Place
  -- pending signs above the rest.
  local signs = require('octo.ui.signs')
  local place = signs.place
  signs.place = function(name, bufnr, line)
    if line and name:match('_pending$') and require('octo.config').values.ui.use_signcolumn then
      pcall(vim.fn.sign_place, 0, 'octo_ns', name, bufnr, { lnum = line + 1, priority = 20 })
      return
    end
    place(name, bufnr, line)
  end
end)

-- Review diff buffers ('octo://<repo>/review/<id>/file/<side>/<path>') get a
-- filetype, so language servers try to attach and fail on a 'file://.' root.
-- Octo already sets 'nofile' on the left side for this reason; do the right
-- side too. Runs before the LSP `FileType` autocmd, which is created later.
Config.new_autocmd('FileType', nil, function(ev)
  if vim.api.nvim_buf_get_name(ev.buf):match('^octo://.-/review/.-/file/') then
    vim.bo[ev.buf].buftype = 'nofile'
  end
end, 'Keep LSP off Octo review diff buffers')

-- Pending review comments of the current branch's PR in Trouble (quickfix).
-- A snapshot: run again after adding or deleting comments.
local pending_query = [[
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviews(states: PENDING, first: 5) {
        nodes {
          viewerDidAuthor
          comments(first: 100) { nodes { path line originalLine body } }
        }
      }
    }
  }
}]]

local gh_json = function(args, on_result)
  vim.system(vim.list_extend({ 'gh' }, args), { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify('gh: ' .. vim.trim(res.stderr), vim.log.levels.ERROR)
        return
      end
      on_result(vim.json.decode(res.stdout))
    end)
  end)
end

local show_pending_comments = function()
  local root = vim.fs.root(0, '.git') or vim.fn.getcwd()
  gh_json({ 'pr', 'view', '--json', 'number,url' }, function(pr)
    local owner, name = pr.url:match('github%.com/([^/]+)/([^/]+)/pull/')
    gh_json({
      'api', 'graphql',
      '-f', 'query=' .. pending_query,
      '-f', 'owner=' .. owner,
      '-f', 'name=' .. name,
      '-F', 'number=' .. pr.number,
    }, function(res)
      local items = {}
      for _, review in ipairs(res.data.repository.pullRequest.reviews.nodes) do
        if review.viewerDidAuthor then
          for _, c in ipairs(review.comments.nodes) do
            table.insert(items, {
              filename = vim.fs.joinpath(root, c.path),
              lnum = c.line ~= vim.NIL and c.line or c.originalLine,
              text = (c.body:gsub('%s+', ' ')),
            })
          end
        end
      end
      if #items == 0 then
        vim.notify(('No pending review comments on #%d'):format(pr.number))
        return
      end
      table.sort(items, function(a, b)
        if a.filename ~= b.filename then return a.filename < b.filename end
        return a.lnum < b.lnum
      end)
      vim.fn.setqflist({}, ' ', { title = ('Pending review #%d'):format(pr.number), items = items })
      require('trouble').open({ mode = 'qflist', auto_preview = false })
    end)
  end)
end

-- Octo fetches from GitHub before showing anything; keep a notification up
-- until the first octo:// buffer appears (or 30s pass, e.g. on an error).
local with_loading = function(cmd, message)
  return function()
    local id = MiniNotify.add(message)
    local done = false
    local finish = function()
      if done then return end
      done = true
      MiniNotify.remove(id)
    end
    vim.api.nvim_create_autocmd('BufWinEnter', { pattern = 'octo://*', once = true, callback = finish })
    vim.defer_fn(finish, 30000)
    vim.cmd(cmd)
  end
end

local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end

nmap_leader('gpp', with_loading('Octo pr', 'Loading PR…'),                          'PR for current branch')
nmap_leader('gpl', '<Cmd>Octo pr list<CR>',                                          'List PRs')
nmap_leader('gps', '<Cmd>Octo pr search<CR>',                                        'Search PRs')
nmap_leader('gpr', with_loading('Octo review resume', 'Loading pending review…'), 'Resume pending review')
nmap_leader('gpR', with_loading('Octo review start', 'Starting review…'),         'Start review')
nmap_leader('gpc', '<Cmd>Octo review comments<CR>', 'Pending review comments')
nmap_leader('gpq', show_pending_comments,           'Pending comments in Trouble')
nmap_leader('gpS', '<Cmd>Octo review submit<CR>',   'Submit review')
nmap_leader('gpX', '<Cmd>Octo review discard<CR>',  'Discard pending review')
