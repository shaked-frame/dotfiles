-- ┌────────────────────────────────────────┐
-- │ Sidekick CLI agent adapter             │
-- └────────────────────────────────────────┘
--
-- Implements the sidekick CLI agent adapter behind 'plugin/44_agent.lua'.
-- Outside Herdr there is no external agent pane to drive, so the agent runs
-- inside Neovim via 'sidekick.nvim' CLI terminal (`mux.enabled = false`).
-- Primary tool is opencode, matching '~/.config/opencode' (MCPs, commands,
-- skills); claude/codex are fallbacks.
--
-- The adapter is always registered so deleting 'plugin/60_herdr.lua' falls
-- back to sidekick even inside Herdr. Sidekick-only tool toggles (`<Leader>ao`,
-- `<Leader>ac`, `<Leader>ax`, `<Leader>as`, `<Leader>aP`) are only mapped when
-- Herdr is not active (`not Config.Agent.in_herdr()`).

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
-- duplicate. A restored terminal keeps its command in the buffer name
-- (`term://<cwd>//<pid>:<cmd>`), so match it against known tool commands:
-- live orphans are wrapped in a Terminal object and attached (no prompt, no
-- duplicate), dead ones are dropped so the toggle starts fresh. Never
-- touches terminals that don't match a configured tool, nor a tool sidekick
-- already tracks. Internal coupling (`Terminal.new` + field assignment) is
-- deliberate: there is no public "adopt this buffer" interface; every step is
-- guarded so a sidekick update can only no-op, never break the keypress.
local function adopt_orphans(opts)
  opts = opts or {}
  local ok_t, Terminal = pcall(require, 'sidekick.cli.terminal')
  local ok_s, Session = pcall(require, 'sidekick.cli.session')
  local ok_c, SConfig = pcall(require, 'sidekick.config')
  if not (ok_t and ok_s and ok_c) or SConfig.cli == nil then return end
  if not pcall(Session.setup) then return end

  local cmds = {}
  for _, tool in pairs(SConfig.tools()) do
    if tool.cmd and tool.cmd[1] then cmds[vim.fn.fnamemodify(tool.cmd[1], ':t')] = tool.name end
  end

  local tracked = {}
  for _, t in pairs(Terminal.terminals) do
    if t.tool and t.tool.name then tracked[t.tool.name] = true end
  end

  local adopt_one = function(buf, tool_name)
    for _, t in pairs(Terminal.terminals) do
      if t.buf == buf then return 'tracked' end
    end
    local job = vim.b[buf].terminal_job_id
    local alive = false
    if type(job) == 'number' and job > 0 then
      local ok_job, status = pcall(vim.fn.jobwait, { job }, 0)
      alive = ok_job and type(status) == 'table' and status[1] == -1
    end
    if alive then
      local win = vim.fn.win_findbuf(buf)[1]
      local term = Terminal.new({ tool = tool_name, cwd = vim.fn.getcwd(), backend = 'terminal' })
      term.buf = buf
      term.win = (win ~= nil and vim.api.nvim_win_is_valid(win)) and win or nil
      if term.win then sidekick_wins[term.win] = true end
      term.job = job
      term.pids = { vim.fn.jobpid(job) }
      term.started = true
      term.timer = vim.uv.new_timer()
      term:bo() -- re-apply `sidekick_terminal` filetype + buffer opts
      term:keys() -- buffer-local maps (`q`, `<D-r>` hide, ...)
      if term.win then term:wo() end
      term:on_ready() -- start the send-queue drain timer `start()` would start
      Session.attach(term)
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
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
      local tail = vim.api.nvim_buf_get_name(buf):match('.*:(.*)$')
      local cmd = tail and vim.fn.fnamemodify(tail:match('^(%S+)') or '', ':t')
      local tool_name = (cmd ~= nil and cmd ~= '') and cmds[cmd] or nil
      if tool_name ~= nil and not tracked[tool_name] then
        local ok, result = pcall(adopt_one, buf, tool_name)
        if ok and result == 'cleaned' then cleaned = true end
      end
    end
  end
  if cleaned then equalize() end
end

if not (Config.Agent and Config.Agent.in_herdr and Config.Agent.in_herdr()) then
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

local add = vim.pack.add
local later = Config.later

later(function()
  add({ 'https://github.com/folke/sidekick.nvim' })

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
      tools = {
        opencode = {}, -- primary: matches ~/.config/opencode (MCPs, commands, skills)
        claude = {}, -- fallback for hardest reasoning tasks
        codex = {},
      },
    },
  })

  local cli = require('sidekick.cli')

  -- Adapter implementing the `Config.Agent` interface declared in
  -- 'plugin/44_agent.lua' (the unified `<Leader>a*` keymaps live there).
  -- Lowercase attach stages text WITHOUT submitting and focuses the panel
  -- so more can be added and Enter pressed manually; uppercase send submits
  -- immediately. Removal: delete this file and the dispatcher falls back
  -- to Herdr.
  if Config.Agent and Config.Agent.register then
    Config.Agent.register('sidekick', {
      focus = function()
        adopt_orphans({ cleanup = true })
        cli.toggle()
      end,
      attach = function(text, _what)
        adopt_orphans({ cleanup = true })
        -- `send` already shows the panel and focuses its input
        -- (`State.with` with `show=true`, `focus=nil` means "do focus"). Do NOT
        -- add an explicit `cli.focus()` here: toggle semantics would see the
        -- focused chat and `blur()` straight back to the code.
        cli.send({ msg = text, submit = false })
      end,
      send = function(text, _what)
        adopt_orphans({ cleanup = true })
        cli.send({ msg = text, submit = true })
      end,
    })
  end

  if Config.Agent and Config.Agent.in_herdr and Config.Agent.in_herdr() then return end

  -- Explicit tool toggles (opencode primary). No Herdr equivalent by design:
  -- inside Herdr the agent is picked via the dispatcher (`<Leader>aa`).
  vim.keymap.set({ 'n', 'x' }, '<Leader>ao', function()
    adopt_orphans({ cleanup = true })
    cli.toggle({ name = 'opencode' })
  end, { desc = 'Opencode toggle' })
  vim.keymap.set({ 'n', 'x' }, '<Leader>ac', function()
    adopt_orphans({ cleanup = true })
    cli.toggle({ name = 'claude' })
  end, { desc = 'Claude toggle' })
  vim.keymap.set({ 'n', 'x' }, '<Leader>ax', function()
    adopt_orphans({ cleanup = true })
    cli.toggle({ name = 'codex' })
  end, { desc = 'Codex toggle' })
  -- Pick from installed CLI tools.
  vim.keymap.set('n', '<Leader>as', function()
    adopt_orphans({ cleanup = true })
    cli.select({ filter = { installed = true } })
  end, { desc = 'AI CLI select' })
  -- Prompt library picker (built-ins + custom `prompts` above). Lowercase
  -- `<Leader>ap` (dispatcher, 'plugin/44_agent.lua') asks for free text;
  -- uppercase here picks a canned prompt and sends it, matching the
  -- attach/send case convention.
  vim.keymap.set({ 'n', 'x' }, '<Leader>aP', function()
    adopt_orphans({ cleanup = true })
    cli.prompt()
  end, { desc = 'AI prompt library' })
end)
