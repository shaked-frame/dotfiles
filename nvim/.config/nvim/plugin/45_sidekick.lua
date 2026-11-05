-- ┌──────────────────────────────────────────┐
-- │ Sidekick: NES and the CLI agent adapter  │
-- └──────────────────────────────────────────┘
--
-- 'folke/sidekick.nvim', set up once here, provides:
-- - Next Edit Suggestions (NES) on Normal-mode `<Tab>`. Insert-mode accept
--   keys (ghost text, completion menu) live in 'lua/config/completion.lua'.
-- - The sidekick CLI agent adapter behind 'plugin/44_agent.lua': the agent
--   runs inside Neovim in sidekick's CLI terminal (`mux.enabled = false`)
--   whenever the host has no agent pane to drive (see "agent adapter" in
--   CONTEXT.md). Primary tool is opencode, matching '~/.config/opencode'
--   (MCPs, commands, skills); claude/codex are fallbacks.
--
-- Inside Herdr the dispatcher always uses Herdr's agent panes, so the
-- sidekick-only tool toggles (`<Leader>ao`, `<Leader>ac`, `<Leader>ax`,
-- `<Leader>as`, `<Leader>aP`) and chat-window autocmds are skipped there.

local term = require('config.term')
-- Herdr's agent panes replace the sidekick chat entirely ('lua/config/host.lua').
local panes_only = require('config.host').agent_panes_only()

local tools = {
  opencode = {}, -- primary: matches ~/.config/opencode (MCPs, commands, skills)
  claude = {}, -- fallback for hardest reasoning tasks
  codex = {},
}

-- Restored chat terminals belong to sidekick, not the terminal dock. The
-- configured tools are claimed now; once sidekick loads, every tool it knows
-- (built-ins included) is claimed by its command. The dock adopts restored
-- terminals only after that ('plugin/23_terminal.lua').
term.claim(vim.tbl_keys(tools))

--- Sidekick tool name by command executable (`claude` -> 'claude').
local tool_by_executable = function(SConfig)
  local map = {}
  for _, tool in pairs(SConfig.tools()) do
    if tool.cmd and tool.cmd[1] then map[vim.fn.fnamemodify(tool.cmd[1], ':t')] = tool.name end
  end
  return map
end

-- Equalize splits when the sidekick chat opens/closes ======================
-- Sidekick's terminal opens as a right split with `winfixwidth` set (see
-- `open_win()` in sidekick's `lua/sidekick/cli/terminal.lua`), so Neovim
-- steals its ~80 columns from the adjacent window only instead of
-- rebalancing. `wincmd =` afterwards keeps the chat at its fixed width and
-- shares the rest equally; same on close to reclaim the space. Tracked by
-- window id so manual hides (`q` in the chat, `:q`) are covered too, not
-- just `<Leader>aa` / `<D-r>`.
local sidekick_wins = {}

local equalize = function()
  vim.schedule(function()
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then vim.cmd('wincmd =') end
  end)
end

-- Adopt orphaned agent terminals (session restore) =========================
-- Sidekick tracks sessions only in memory, so after a restart a restored
-- chat pane is unknown to it: toggling then prompts for a tool and spawns a
-- duplicate. A restored terminal keeps its command ('lua/config/term.lua'),
-- so match it against known tool commands: live orphans are wrapped in a
-- Terminal object and attached (no prompt, no duplicate), dead ones are
-- dropped so the toggle starts fresh. Never touches terminals that don't match
-- a configured tool, nor a tool sidekick already tracks. Internal coupling
-- (`Terminal.new` + field assignment) is deliberate: there is no public "adopt
-- this buffer" interface; every step is guarded so a sidekick update can only
-- no-op, never break the keypress.
local function adopt_orphans(opts)
  opts = opts or {}
  local ok_t, Terminal = pcall(require, 'sidekick.cli.terminal')
  local ok_s, Session = pcall(require, 'sidekick.cli.session')
  local ok_c, SConfig = pcall(require, 'sidekick.config')
  if not (ok_t and ok_s and ok_c) or SConfig.cli == nil then return end
  if not pcall(Session.setup) then return end

  local tool_names = tool_by_executable(SConfig)

  local tracked = {}
  for _, t in pairs(Terminal.terminals) do
    if t.tool and t.tool.name then tracked[t.tool.name] = true end
  end

  local adopt_one = function(buf, tool_name)
    for _, t in pairs(Terminal.terminals) do
      if t.buf == buf then return 'tracked' end
    end
    local job = vim.b[buf].terminal_job_id
    if term.info(buf).running then
      local win = vim.fn.win_findbuf(buf)[1]
      local t = Terminal.new({ tool = tool_name, cwd = vim.fn.getcwd(), backend = 'terminal' })
      t.buf = buf
      t.win = (win ~= nil and vim.api.nvim_win_is_valid(win)) and win or nil
      if t.win then sidekick_wins[t.win] = true end
      t.job = job
      t.pids = { vim.fn.jobpid(job) }
      t.started = true
      t.timer = vim.uv.new_timer()
      t:bo() -- re-apply `sidekick_terminal` filetype + buffer opts
      t:keys() -- buffer-local maps (`q`, `<D-r>` hide, ...)
      if t.win then t:wo() end
      t:on_ready() -- start the send-queue drain timer `start()` would start
      Session.attach(t)
      tracked[tool_name] = true
      return 'adopted'
    elseif opts.cleanup then
      for _, w in ipairs(vim.fn.win_findbuf(buf)) do
        pcall(vim.api.nvim_win_close, w, true)
      end
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
      return 'cleaned'
    end
    return 'skipped'
  end

  local cleaned = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local info = term.info(buf)
    local tool_name = info and tool_names[info.executable]
    if tool_name ~= nil and not tracked[tool_name] then
      local ok, result = pcall(adopt_one, buf, tool_name)
      if ok and result == 'cleaned' then cleaned = true end
    end
  end
  if cleaned then equalize() end
end

if not panes_only then
  Config.new_autocmd('BufWinEnter', nil, function(ev)
    if vim.bo[ev.buf].filetype ~= 'sidekick_terminal' then return end
    for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
      sidekick_wins[win] = true
    end
    equalize()
  end, 'Equalize splits after sidekick opens')

  Config.new_autocmd('WinClosed', nil, function(ev)
    local win = tonumber(ev.match)
    if win == nil or not sidekick_wins[win] then return end
    sidekick_wins[win] = nil
    equalize()
  end, 'Equalize splits after sidekick closes')

  -- Proactive passes: after a session file is sourced the restored pane exists
  -- but sidekick (deferred via `later()`) may not be loaded yet. `pcall`
  -- guards make these safe no-ops until it is; the press-time pass below is
  -- the guarantee. Entering a restored chat also adopts it immediately, so
  -- `<D-r>`/`q` work inside it without toggling first.
  Config.new_autocmd('SessionLoadPost', nil, function() adopt_orphans() end, 'Adopt restored sidekick chat')
  Config.new_autocmd('BufEnter', nil, function(ev)
    if vim.bo[ev.buf].buftype ~= 'terminal' then return end
    adopt_orphans()
  end, 'Adopt restored sidekick chat on enter')
end

Config.later(function()
  vim.pack.add({ 'https://github.com/folke/sidekick.nvim' })

  require('sidekick').setup({
    cli = {
      mux = { enabled = false },
      picker = 'snacks',
      -- Custom prompt library, sent via `<Leader>aP`. Merged over sidekick's
      -- built-ins (`changes`, `diagnostics`, `explain`, `fix`, `optimize`,
      -- `review`, `tests`, ...).
      prompts = {
        find_bugs = 'Find bugs in {this}. For each bug give the file and line.',
        simplify = 'Simplify {this} without changing its behavior.',
        -- Opencode slash commands (`~/.config/opencode/command/`): sending
        -- `/name` as chat input runs the command, so the library can trigger
        -- them. `{this}` becomes the command's `$ARGUMENTS`.
        create_pr = '/create-pr {this}',
        explain_symbol = 'Explain {symbol}.',
        symbol = '{symbol}',
      },
      -- `{symbol}`: the LSP symbol around the cursor, e.g. "method `Foo.bar`
      -- in `src/foo.ts` (lines 3-9)" ('lua/config/symbol.lua', also behind
      -- `<Leader>as`). `ctx.win` is the code window, even from inside the chat.
      context = {
        symbol = function(ctx) return require('config.symbol').describe(ctx.win) end,
      },
      win = {
        keys = {
          -- `<D-r>` mirrors the global 'Focus agent' mapping
          -- ('plugin/44_agent.lua'), but that one is Normal-mode only so it
          -- never fires inside the chat terminal. This buffer-local variant
          -- closes the chat from Terminal and Normal mode.
          hide_cmd_r = { '<D-r>', 'hide', mode = 'nt', desc = 'Hide sidekick chat' },
          -- Focus-aware wheel forwarding in terminal-Normal mode.
          wheel_up = { '<ScrollWheelUp>', function()
            if vim.api.nvim_get_current_win() == vim.fn.getmousepos().winid then
              return '<Cmd>startinsert<CR><ScrollWheelUp>'
            end
            return ''
          end, mode = 'n', expr = true, desc = 'Forward wheel to agent' },
          wheel_down = { '<ScrollWheelDown>', function()
            if vim.api.nvim_get_current_win() == vim.fn.getmousepos().winid then
              return '<Cmd>startinsert<CR><ScrollWheelDown>'
            end
            return ''
          end, mode = 'n', expr = true, desc = 'Forward wheel to agent' },
        },
      },
      tools = tools,
    },
  })

  term.claim(vim.tbl_keys(tool_by_executable(require('sidekick.config'))))

  -- Normal-mode `<Tab>` jumps to / applies the Next Edit Suggestion. The
  -- fallback is `<C-i>`, not a literal `<Tab>`: they are the same keycode and
  -- Normal mode's default for it is jump-forward in the jumplist, which
  -- mapping `<Tab>` at all would otherwise shadow.
  --
  -- An accepted suggestion lands exactly as Copilot wrote it: the server
  -- re-indents inline completions to the buffer's `'expandtab'`/`'shiftwidth'`
  -- but not next edits, so they can miss the file's style. Once one is
  -- applied (sidekick's `User SidekickNesDone`):
  -- - if it left a syntax error in a buffer that parsed cleanly before, undo
  --   it (`<C-r>` takes it back);
  -- - otherwise format the buffer as a save would ('conform.nvim'), joined
  --   into the suggestion's undo step so one `u` reverts both.
  local syntax_ok = function(buf)
    local ok, parser = pcall(vim.treesitter.get_parser, buf)
    if not (ok and parser) then return nil end
    local tree = parser:parse()[1]
    return tree ~= nil and not tree:root():has_error()
  end
  local before -- the buffer as `<Tab>` found it

  vim.keymap.set('n', '<Tab>', function()
    local buf = vim.api.nvim_get_current_buf()
    before = { buf = buf, seq = vim.fn.undotree(buf).seq_cur, clean = syntax_ok(buf) }
    if require('sidekick').nes_jump_or_apply() then return end
    before = nil
    return '<C-i>'
  end, { expr = true, desc = 'Goto/Apply Next Edit Suggestion' })

  Config.new_autocmd('User', 'SidekickNesDone', function(ev)
    local buf, prev = ev.data and ev.data.buffer, before
    before = nil
    if not (prev and prev.buf == buf and vim.api.nvim_buf_is_valid(buf)) then return end

    if prev.clean and syntax_ok(buf) == false then
      -- Undo only when the suggestion is still the latest change.
      if vim.fn.undotree(buf).seq_cur == prev.seq + 1 then
        vim.api.nvim_buf_call(buf, function() vim.cmd('silent undo') end)
        vim.notify('Reverted the next edit suggestion: it left a syntax error (<C-r> keeps it)', vim.log.levels.WARN)
      else
        vim.notify('The next edit suggestion left a syntax error', vim.log.levels.WARN)
      end
      return
    end

    if Config.conform_ready then
      require('conform').format({ bufnr = buf, async = true, quiet = true, undojoin = true })
    end
  end, 'Format or revert an accepted next edit suggestion')

  local cli = require('sidekick.cli')

  -- Every chat action first adopts a restored chat (or drops a dead one).
  local with_chat = function(fn)
    return function(...)
      adopt_orphans({ cleanup = true })
      return fn(...)
    end
  end

  -- Adapter implementing the `Config.Agent` interface declared in
  -- 'plugin/44_agent.lua' (the unified `<Leader>a*` keymaps live there).
  -- Lowercase attach stages text WITHOUT submitting and focuses the panel
  -- so more can be added and Enter pressed manually; uppercase send submits
  -- immediately. `visible()` lets the dispatcher prefer an open chat.
  Config.Agent.register('sidekick', {
    visible = function()
      return vim.iter(vim.api.nvim_tabpage_list_wins(0)):any(function(win)
        return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'sidekick_terminal'
      end)
    end,
    focus = with_chat(function() cli.toggle() end),
    -- `send` already shows the panel and focuses its input (`State.with` with
    -- `show=true`, `focus=nil` means "do focus"). Do NOT add an explicit
    -- `cli.focus()` here: toggle semantics would see the focused chat and
    -- `blur()` straight back to the code.
    attach = with_chat(function(text) cli.send({ msg = text, submit = false }) end),
    send = with_chat(function(text) cli.send({ msg = text, submit = true }) end),
  })

  if panes_only then return end

  -- Explicit tool toggles (opencode primary). No Herdr equivalent by design:
  -- inside Herdr the agent is picked via the dispatcher (`<Leader>aa`).
  -- stylua: ignore start
  vim.keymap.set({ 'n', 'x' }, '<Leader>ao', with_chat(function() cli.toggle({ name = 'opencode' }) end), { desc = 'Opencode toggle' })
  vim.keymap.set({ 'n', 'x' }, '<Leader>ac', with_chat(function() cli.toggle({ name = 'claude' }) end),   { desc = 'Claude toggle' })
  vim.keymap.set({ 'n', 'x' }, '<Leader>ax', with_chat(function() cli.toggle({ name = 'codex' }) end),    { desc = 'Codex toggle' })
  -- Pick from installed CLI tools (`<Leader>as` attaches the symbol instead,
  -- 'plugin/44_agent.lua').
  vim.keymap.set('n', '<Leader>al', with_chat(function() cli.select({ filter = { installed = true } }) end), { desc = 'AI CLI select' })
  -- Prompt library picker (built-ins + custom `prompts` above). Lowercase
  -- `<Leader>ap` (dispatcher, 'plugin/44_agent.lua') asks for free text;
  -- uppercase here picks a canned prompt and sends it, matching the
  -- attach/send case convention.
  vim.keymap.set({ 'n', 'x' }, '<Leader>aP', with_chat(function() cli.prompt() end), { desc = 'AI prompt library' })
  -- stylua: ignore end
end)
