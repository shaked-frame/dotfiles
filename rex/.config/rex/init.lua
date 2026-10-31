-- =============================================================================
-- Rex configuration
-- Docs: https://www.superlogical.com/rex/docs/customize/config
-- Reload after editing: rex config reload  (or Hyper+,)
-- Inspect what loaded:  rex keymap
-- =============================================================================
--
-- Ported from ~/.config/herdr/config.toml. Terminology:
--
--   herdr workspace  ~  Rex session   (one per worktree, see `worktree_open`)
--   herdr tab        ~  Rex tab       (a session "window" in the API)
--   herdr pane       ~  Rex pane      (a "block" in the API)
--   herdr popup      ~  Rex floating layer (session.new_layer)
--
-- No prefix key. Two modifier families instead:
--   ctrl+alt+*  the direct chords carried over from herdr
--   Hyper+*     everything herdr only had behind its F12 prefix. Hyper is the
--               ZSA Voyager key, sent as cmd+ctrl+alt+shift. Hyper+7/8/9/0, \
--               and p are reserved for Neovim (see "Ghostty passthroughs").
--
-- Settings that are not Lua (font, theme, Remote Control) live in the app:
-- see README.md next to this file.

local T = "com.superlogical.terminal"
local SHELL = "com.superlogical.terminal.shell"
local H = "cmd+ctrl+alt+shift+"

-- Helpers =====================================================================

--- Name of the focused program in a terminal block, e.g. "nvim" or "claude".
--- `name` is not reliable on its own: Claude Code's native binary reports its
--- version ("2.1.312") as `name` while `argv0` is "claude".
local function fg_program(block_id)
  if not block_id then return nil end
  local p = rex.block.call(T, "process", { block_id = block_id })
  local fg = p and p.foreground
  if not fg then return nil end
  local n = fg.script or fg.argv0 or fg.name or ""
  return (n:gsub("^%-", ""):match("[^/]+$")), fg
end

--- Working directory of the focused program, read from the process rather than
--- the terminal's OSC 7 `pwd`: that is the shell's directory, which goes stale
--- once a program like nvim `:cd`s elsewhere.
local function fg_cwd(block_id)
  local _, fg = fg_program(block_id)
  return fg and fg.cwd
end

local AGENTS = { claude = true, codex = true }

local function active_window()
  local view, err = rex.session.view{}
  if not view then error(err, 0) end
  for _, w in ipairs(view.windows) do
    if w.window_id == view.active_window_id then return w, view end
  end
end

--- Every block in the tiled layer(s) of a window.
local function window_blocks(w)
  local out = {}
  for _, layer in ipairs(w and w.layers or {}) do
    if layer.kind == "tiled" then
      for _, b in ipairs(layer.blocks or {}) do table.insert(out, b) end
    end
  end
  return out
end

--- A shell that types `cmd` on start, so quitting the program leaves a shell
--- behind instead of closing the pane (herdr behaved the same way).
local function shell_running(cmd, cwd)
  return rex.layout.block{
    flavor = SHELL,
    options = { cwd = cwd, initial_input = cmd and (cmd .. "\n") or nil },
  }
end

--- The editor | agent layout every worktree session starts with.
local function dev_layout(cwd)
  return rex.layout.horizontal(0.55, shell_running("nvim", cwd), shell_running("claude", cwd))
end

--- Open `command` (nil = interactive shell) in a centered floating layer,
--- starting in the focused pane's directory. Closes when the program exits.
local function popup(ctx, command, w, h)
  local _, err = rex.session.new_layer{
    bounds = { (1 - w) / 2, (1 - h) / 2, w, h },
    focus = true,
    layout = rex.layout.block{
      flavor = SHELL,
      options = { command = command, cwd = fg_cwd(ctx.block_id) },
    },
  }
  if err then error(err, 0) end
end

--- Show or hide a named floating pane that keeps running while hidden.
--- Hiding detaches it from the tab (`detach_block`). A detached block can't be
--- floated directly, so showing places it as a split beside this tab's first
--- tiled pane and floats that. Floats are per session; the first toggle starts
--- `command` (nil = shell) in the focused pane's directory. Quitting the
--- program closes the pane, and the next toggle starts a fresh one.
local function toggle_float(ctx, name, command, w, h)
  local label = "float:" .. name
  local bounds = { (1 - w) / 2, (1 - h) / 2, w, h }
  local win = active_window()

  local found
  local list, err = rex.session.list_blocks{}
  if not list then error(err, 0) end
  for _, b in ipairs(list.blocks or {}) do
    if b.label == label then found = b end
  end

  if found == nil then
    local _, e = rex.session.new_layer{
      bounds = bounds,
      focus = true,
      layout = rex.layout.block{
        flavor = SHELL,
        label = label,
        options = { command = command, cwd = fg_cwd(ctx.block_id) },
      },
    }
    if e then error(e, 0) end
    return
  end

  -- Showing in this tab: hide it. Showing in another tab: bring it here.
  if found.placement ~= "detached" then
    rex.session.detach_block{ block_id = found.block_id }
    if found.window_id == win.window_id then return end
  end

  local anchor = window_blocks(win)[1]
  if anchor == nil then error("no tiled pane in this tab to place the float beside", 0) end
  local steps = {
    { "move_block", { block_id = found.block_id, anchor_block_id = anchor.block_id, direction = "horizontal", side = "after" } },
    { "float_block", { block_id = found.block_id, bounds = bounds } },
    { "focus_block", { block_id = found.block_id } },
  }
  for _, s in ipairs(steps) do
    local _, e = rex.session[s[1]](s[2])
    if e then error(s[1] .. ": " .. e, 0) end
  end
end

-- Panes =======================================================================

-- vim-herdr-navigation replacement: ctrl+h/j/k/l moves between Rex panes, but
-- is passed through to Neovim when it is the focused program. Neovim hands
-- focus back at a split edge by running `rex focus <dir>` (see
-- nvim/plugin/22_splits.lua). Returning false sends the key to the terminal.
for key, dir in pairs{ h = "left", j = "down", k = "up", l = "right" } do
  rex.bind("ctrl+" .. key, function(ctx)
    local prog = fg_program(ctx.block_id)
    if prog == "nvim" or prog == "vim" then return false end
    rex.session.focus_direction{ direction = dir }
    return true
  end)

  rex.bind("ctrl+alt+" .. key, "pane.focus", { direction = dir })
  rex.bind(H .. key, "pane.move", { direction = dir })
end

rex.bind("ctrl+alt+d", "pane.split.right")
rex.bind(H .. "d", "pane.split.right")
rex.bind("ctrl+alt+shift+d", "pane.split.down")
rex.bind(H .. "-", "pane.split.down")

rex.bind(H .. "x", "pane.close")
rex.bind("ctrl+alt+z", "pane.zoom")
rex.bind(H .. "z", "pane.zoom")
rex.bind(H .. "f", "pane.float")
rex.bind(H .. "tab", "pane.focus_next")

-- Resize mode (herdr prefix+r). Exclusive, so stray keys don't reach the shell.
rex.mode("resize", { exclusive = true })
rex.bind(H .. "r", "client.mode.enter", { name = "resize" })
for key, dir in pairs{ h = "left", j = "down", k = "up", l = "right" } do
  rex.bind("resize/" .. key, "pane.resize", { direction = dir })
  rex.bind("resize/shift+" .. key, "pane.resize", { direction = dir, amount = 15 })
end
rex.bind("resize/=", "pane.balance")

-- Hyper+6/7/8/9 resize like Neovim's `Config.Splits.resize`: move the focused
-- pane's border that way, its right/bottom one when a pane lies past it, else
-- its left/top one. The nearest split across that axis is the border; its
-- ratio moves by `step` of the window. With Neovim focused the key goes to
-- Neovim as CSI-u (its `H('6')`..`H('9')` maps), which resizes its own
-- windows and sends `rex=true` back here when it has none that way.
local NVIM_RESIZE_KEYS = { left = "\27[54;15u", up = "\27[55;15u", down = "\27[56;15u", right = "\27[57;15u" }

local function contains(node, id)
  if node.block_id then return node.block_id == id end
  return node.split ~= nil and (contains(node.split.before, id) or contains(node.split.after, id))
end

local function first_leaf(node)
  if node.block_id then return node.block_id end
  return first_leaf(node.split.before)
end

local function resize_border(block_id, dir, step)
  local axis = (dir == "left" or dir == "right") and "horizontal" or "vertical"
  local w = active_window()
  local border
  for _, layer in ipairs(w.layers or {}) do
    if layer.kind == "tiled" and layer.layout and contains(layer.layout, block_id) then
      local node = layer.layout
      while node.split do
        if node.split.direction == axis then border = node end
        node = contains(node.split.before, block_id) and node.split.before or node.split.after
      end
    end
  end
  if border == nil then return end

  local size = axis == "horizontal" and border.rect[3] or border.rect[4]
  local delta = step / size * ((dir == "left" or dir == "up") and -1 or 1)
  local ratio = math.max(0.05, math.min(0.95, border.split.ratio + delta))
  local _, err = rex.session.resize_pane{
    before_block_id = first_leaf(border.split.before),
    after_block_id = first_leaf(border.split.after),
    direction = axis,
    ratio = ratio,
  }
  if err then error(err, 0) end
end

rex.action{
  name = "resize",
  title = "Resize Pane",
  args = { direction = "string", rex = "boolean?" },
  repeats = true,
  run = function(ctx, args)
    if not args.rex then
      local prog = fg_program(ctx.block_id)
      if prog == "nvim" or prog == "vim" then
        rex.block.call(T, "write", { block_id = ctx.block_id, data = NVIM_RESIZE_KEYS[args.direction] })
        return
      end
    end
    resize_border(ctx.block_id, args.direction, args.direction:match("^[lr]") and 0.03 or 0.05)
  end,
}
for key, dir in pairs{ ["6"] = "left", ["7"] = "up", ["8"] = "down", ["9"] = "right" } do
  rex.bind(H .. key, "resize", { direction = dir })
end
rex.bind("resize/enter", "client.mode.exit")
rex.bind("resize/q", "client.mode.exit")

-- Tabs ========================================================================
-- cmd+1..9 are left to the app's defaults; Hyper digits belong to Neovim.

rex.bind("ctrl+alt+c", "client.tab.new")
rex.bind(H .. "c", "client.tab.new")
rex.bind("ctrl+alt+]", "client.tab.next")
rex.bind(H .. "]", "client.tab.next")
rex.bind("ctrl+alt+[", "client.tab.previous")
rex.bind(H .. "[", "client.tab.previous")

-- Sessions (herdr workspaces) =================================================

rex.bind(H .. "s", "session.switch")               -- Rex's own session picker
rex.bind("ctrl+alt+n", "session.next")
rex.bind("ctrl+alt+p", "session.previous")

-- Misc ========================================================================

rex.bind("ctrl+alt+b", "client.sidebar.toggle")
rex.bind(H .. "b", "client.sidebar.toggle")
rex.bind(H .. ",", "client.config.reload")
rex.bind(H .. "/", "client.find.open")

-- Jump between shell prompts in the scrollback. Needs the OSC 133 marks from
-- the Rex block in zsh/.zshrc.
rex.bind(H .. "up", "client.prompt.previous")
rex.bind(H .. "down", "client.prompt.next")

-- Ghostty passthroughs ========================================================
-- Rex is now the terminal, so the raw-byte keybinds from ghostty/config move
-- here. `write` injects bytes as if typed.

local function send(bytes)
  return function(ctx)
    if not ctx.block_id then return false end
    rex.block.call(T, "write", { block_id = ctx.block_id, data = bytes })
    return true
  end
end

-- Hyper -> CSI-u modifier 15, for nvim `H()` maps. Rex matches unshifted
-- keys, so this is `p` (Ghostty needed an uppercase `P`).
-- Hyper+6/7/8/9 reach Neovim through the `resize` action below.
rex.bind(H .. "\\", send("\27[92;15u"))
rex.bind(H .. "p", send("\27[112;15u"))

-- Line start/end like a macOS text field.
rex.bind("cmd+left", send("\27[H"))
rex.bind("cmd+right", send("\27[F"))

-- Floats ======================================================================

rex.action{
  name = "lazygit",
  title = "Toggle Lazygit",
  category = "Git",
  run = function(ctx) toggle_float(ctx, "lazygit", { "lazygit" }, 0.9, 0.9) end,
}
rex.bind(H .. "g", "lazygit")

rex.action{
  name = "scratch",
  title = "Toggle Scratch Terminal",
  run = function(ctx) toggle_float(ctx, "scratch", nil, 0.8, 0.8) end,
}
-- Not Hyper+t: that is the global hotkey that focuses Rex.
rex.bind(H .. "o", "scratch")

-- herdr `edit_scrollback`: dump the pane's screen + scrollback into nvim.
rex.action{
  name = "edit_scrollback",
  title = "Edit Scrollback in Neovim",
  run = function(ctx)
    local r, err = rex.block.call(T, "format", { block_id = ctx.block_id, format = "text", trim = true })
    if not r then error(err, 0) end
    local path = os.tmpname() .. ".txt"
    local f = assert(io.open(path, "w"))
    f:write(r.content or "")
    f:close()
    popup(ctx, { "nvim", "+", path }, 0.9, 0.9)
  end,
}
rex.bind(H .. "e", "edit_scrollback")

-- Agents ======================================================================

-- Open an agent to the right of the focused pane, in the same directory.
rex.action{
  name = "agent_split",
  title = "Open Agent Beside Pane",
  category = "Agents",
  args = { command = "string?" },
  run = function(ctx, args)
    local _, err = rex.session.new_split{
      block_id = ctx.block_id,
      direction = "horizontal",
      side = "after",
      focus = true,
      layout = shell_running(args.command or "claude", fg_cwd(ctx.block_id)),
    }
    if err then error(err, 0) end
  end,
}
rex.bind(H .. "a", "agent_split")

-- Agent panes in this session, those in the caller's tab first. Each entry has
-- `block_id`, `window_id`, `program` and `here` (same tab as the caller).
-- Read by Neovim's Rex agent adapter (nvim/plugin/61_rex.lua) through
-- `rex do list_agents --json`, which runs it against $REX_SESSION/$REX_BLOCK.
rex.action{
  name = "list_agents",
  title = "List Agent Panes",
  category = "Agents",
  run = function(ctx)
    local view, err = rex.session.view{}
    if not view then error(err, 0) end
    local here, elsewhere = {}, {}
    for _, w in ipairs(view.windows) do
      local blocks = window_blocks(w)
      local in_tab = false
      for _, b in ipairs(blocks) do
        if b.block_id == ctx.block_id then in_tab = true end
      end
      for _, b in ipairs(blocks) do
        local prog = fg_program(b.block_id)
        if AGENTS[prog or ""] then
          table.insert(in_tab and here or elsewhere,
            { block_id = b.block_id, window_id = w.window_id, program = prog, here = in_tab })
        end
      end
    end
    for _, a in ipairs(elsewhere) do table.insert(here, a) end
    return { agents = here }
  end,
}

-- Zoom the agent pane in this tab, or (with editor=true) zoom the first
-- non-agent pane so the agent keeps running out of sight. Press again to
-- restore. Replaces herdr's prefix+shift+a and prefix+shift+m commands.
rex.action{
  name = "zoom_agent",
  title = "Zoom Agent Pane",
  category = "Agents",
  args = { editor = "boolean?" },
  run = function(_, args)
    local w = active_window()
    for _, b in ipairs(window_blocks(w)) do
      local is_agent = AGENTS[fg_program(b.block_id) or ""] == true
      if is_agent ~= (args.editor == true) then
        rex.session.zoom_block{ window_id = w.window_id, block_id = b.block_id }
        return
      end
    end
  end,
}
rex.bind(H .. "m", "zoom_agent", { editor = true })
rex.bind("ctrl+alt+m", "zoom_agent", { editor = true })

-- Move the agent between its own "Claude" tab and a split right of nvim in the
-- "Vim" tab, keeping it running (herdr prefix+shift+v). In the Vim tab it goes
-- to Claude; anywhere else it joins Vim. Rex can't make a tab around an
-- existing block, so a missing Claude tab is created with a placeholder shell
-- that is closed once the agent is beside it. A tab whose last pane leaves
-- closes, like herdr's.
rex.action{
  name = "agent_move",
  title = "Move Agent: Claude Tab / Vim Split",
  category = "Agents",
  run = function(ctx)
    local view, err = rex.session.view{}
    if not view then error(err, 0) end

    local vim_w, claude_w, agent, agent_w
    for _, w in ipairs(view.windows) do
      local label = (w.label or ""):lower()
      if label == "vim" then vim_w = w elseif label == "claude" then claude_w = w end
      for _, b in ipairs(window_blocks(w)) do
        -- Prefer an agent in the active tab, else the session's first.
        if AGENTS[fg_program(b.block_id) or ""] and (agent == nil or w.window_id == view.active_window_id) then
          agent, agent_w = b, w
        end
      end
    end
    if agent == nil then error("no agent pane in this session", 0) end

    local function move_beside(anchor_id, ratio)
      local _, e = rex.session.move_block{
        block_id = agent.block_id, anchor_block_id = anchor_id,
        direction = "horizontal", side = "after", ratio = ratio,
      }
      if e then error(e, 0) end
    end

    if vim_w and agent_w.window_id == vim_w.window_id then
      local others = claude_w and window_blocks(claude_w) or {}
      if #others > 0 then
        move_beside(others[#others].block_id)
      else
        local w, e = rex.session.new_window{ window_label = "Claude", layout = rex.layout.block{ flavor = SHELL } }
        if not w then error(e, 0) end
        local placeholder = w.block_ids[1]
        move_beside(placeholder)
        rex.call("block.close", { session_id = ctx.session_id, block_id = placeholder })
      end
    else
      if vim_w == nil then error("no Vim tab in this session", 0) end
      local blocks = window_blocks(vim_w)
      local anchor = blocks[1]
      for _, b in ipairs(blocks) do
        if fg_program(b.block_id) == "nvim" then anchor = b break end
      end
      move_beside(anchor.block_id, 0.55)
    end
    rex.session.focus_block{ block_id = agent.block_id }
  end,
}
rex.bind(H .. "v", "agent_move")
rex.bind("ctrl+alt+v", "agent_move")

-- Worktrees ===================================================================
-- One Rex session per Git worktree, labelled with the branch and opened as an
-- nvim | claude split. Entry points:
--   Hyper+w            floating fzf picker (scripts/worktree-pick.sh)
--   nvim `space g w`   MiniPick picker (nvim/plugin/61_rex.lua)
-- Both end in `rex do worktree_open`, which needs Remote Control turned on in
-- the app (Settings > Rex Server) so the CLI can switch the app's session.

rex.action{
  name = "worktree_open",
  title = "Open Worktree Session",
  category = "Worktrees",
  args = { path = "string", branch = "string?" },
  run = function(_, args)
    local label = args.branch or args.path:match("[^/]+$")
    local list = rex.call("session.list")
    local id
    for _, s in ipairs(list and list.sessions or {}) do
      if s.label == label then id = s.session_id end
    end
    if not id then
      local r, err = rex.call("session.create", {
        label = label,
        initial_windows = { { window_label = "Vim", layout = dev_layout(args.path) } },
      })
      if not r then error(err, 0) end
      id = r.session_id
    end
    rex.client.queue("session.select", { session_id = id })
    return { session_id = id }
  end,
}

local CONFIG_DIR = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/rex"

rex.action{
  name = "worktree_picker",
  title = "Worktrees…",
  category = "Worktrees",
  run = function(ctx)
    popup(ctx, { "sh", CONFIG_DIR .. "/scripts/worktree-pick.sh" }, 0.6, 0.5)
  end,
}
rex.bind(H .. "w", "worktree_picker")
rex.bind("ctrl+alt+w", "worktree_picker")
