-- macOS notifications when a program in any Rex session needs you or finishes
-- while you are in another app. Rex shows the same states in its own tabs and
-- sidebar, so nothing is sent while Rex is frontmost.
--
-- Driven by the Program Status Protocol (OSC 7501), which Claude Code reports
-- (`app=claude-code`). Kept running by launchd:
--   launchd/com.shakedhagag.rex-notify.plist -> rex do notify.lua --all
-- Try it by hand with REX_NOTIFY_ALWAYS=1 to skip the frontmost check.

local ALWAYS = os.getenv("REX_NOTIFY_ALWAYS") == "1"

-- state -> what the notification says. `idle` only counts after `working`:
-- agents that never report `done` settle back to idle when a turn ends.
local VERBS = { blocked = "needs you", done = "finished", error = "failed" }

local last = {} -- "<block>/<record id>" -> previous state

local function rex_is_frontmost()
  local front = rex.exec({ "/usr/bin/lsappinfo", "front" }, { timeout = 2 })
  if front == nil or not front.ok then return false end
  local asn = front.stdout:gsub("%s+$", "")
  local r = rex.exec({ "/usr/bin/lsappinfo", "info", "-only", "name", asn }, { timeout = 2 })
  return r ~= nil and r.ok and r.stdout:find('"Rex', 1, true) ~= nil
end

local function notify(title, subtitle, body)
  rex.exec({
    "/usr/bin/osascript", "-e",
    string.format("display notification %q with title %q subtitle %q", body, title, subtitle),
  }, { timeout = 5 })
end

rex.on("terminal.program_status_changed", function(ctx, ev)
  local rec = ev.record or {}
  local key = (ctx.block_id or "?") .. "/" .. (ev.id or "")
  local prev = last[key]
  last[key] = rec.state

  local verb = VERBS[rec.state]
  if rec.state == "idle" and prev == "working" then verb = "finished" end
  if verb == nil or rec.state == prev then return end
  if not ALWAYS and rex_is_frontmost() then return end

  local view = rex.session.view{}
  local session = view and view.label or "Rex"
  local app = rec.app or "program"
  local body = (rec.msg and rec.msg ~= "") and rec.msg or (app .. " " .. verb)
  if rec.state == "blocked" and rec.kind then body = "[" .. rec.kind .. "] " .. body end
  rex.log(string.format("%s %s in %s: %s", app, verb, session, body))
  notify(app .. " " .. verb, session, body)
end)

rex.on("terminal.program_status_removed", function(ctx, ev)
  for _, id in ipairs(ev.ids or {}) do last[(ctx.block_id or "?") .. "/" .. id] = nil end
end)
