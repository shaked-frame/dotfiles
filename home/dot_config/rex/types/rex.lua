---@meta
-- Type definitions for the `rex` global, for lua-language-server only: Rex
-- never loads this file. Written from the Lua API reference
-- (https://www.superlogical.com/rex/docs/reference/lua) and `rex api describe`.
-- Method arguments beyond what's listed here: `rex api describe session.<name>`.

---@class rex.Context
---@field session_id? string
---@field block_id? string
---@field client_id? string
---@field origin? "key"|"palette"|"cli"|"api"|"script"|"timer"
---@field server? string

---@class rex.KeyEvent
---@field keybinding string The key that was pressed.
---@field prefix? string[] For a sequence, the keys before it.

---@class rex.Binding
---@field key string The key or sequence, without its mode.
---@field mode? string
---@field action? string
---@field fn? function
---@field args? table
---@field source string Where it was bound, such as `keys.lua:3`.

---@class rex.ActionSpec
---@field name string Lowercase letters, digits and underscores; no dots.
---@field title string Shown in the command palette.
---@field run fun(ctx: rex.Context, args: table): any
---@field description? string
---@field category? string Palette group. Defaults to `Actions`.
---@field keywords? string
---@field args? table<string, string>|table Argument types (`"string?"` is optional), or a JSON Schema.
---@field repeats? boolean Run again while the key is held.

---@class rex.HostSpec
---@field label string
---@field endpoints? string[]
---@field endpoint? string
---@field id? string
---@field icon? string

---@class rex.LayoutNode

---@class rex.TerminalOptions
---@field command? string[] Program and arguments. Without it, an interactive shell starts.
---@field shell? string `none` starts `command` directly.
---@field cwd? string
---@field initial_input? string Typed into the terminal once it starts.
---@field exit? { on_completion: boolean }

---@class rex.BlockSpec
---@field flavor string Such as `com.superlogical.terminal.shell`.
---@field options? rex.TerminalOptions
---@field label? string

---@class rex.Layout
---@field block fun(spec: rex.BlockSpec): rex.LayoutNode
---@field horizontal fun(ratio: number, a: rex.LayoutNode, b: rex.LayoutNode): rex.LayoutNode Side by side; `ratio` is `a`'s share.
---@field vertical fun(ratio: number, a: rex.LayoutNode, b: rex.LayoutNode): rex.LayoutNode Stacked; `ratio` is `a`'s share.

--- A session method: takes an argument table (`session_id` is filled in) and
--- returns a result table, or nil and an error message. Never raises.
---@alias rex.SessionMethod fun(args?: table): table?, string?

---@class rex.Session
---@field view rex.SessionMethod Windows, layouts and blocks.
---@field list_blocks rex.SessionMethod Every block, placed or detached.
---@field list_clients rex.SessionMethod
---@field describe_block rex.SessionMethod
---@field new_window rex.SessionMethod `{ layout, window_label?, focus? }`
---@field new_split rex.SessionMethod `{ block_id, direction, side, layout, focus? }`
---@field new_block rex.SessionMethod
---@field new_layer rex.SessionMethod `{ bounds, layout, focus?, window_id? }`
---@field close_window rex.SessionMethod
---@field close_layer rex.SessionMethod
---@field move_block rex.SessionMethod `{ block_id, anchor_block_id, direction, side, ratio? }`
---@field swap_blocks rex.SessionMethod
---@field detach_block rex.SessionMethod `{ block_id }`
---@field float_block rex.SessionMethod `{ block_id, bounds }` (placed blocks only)
---@field zoom_block rex.SessionMethod `{ block_id, window_id?, zoom? }`
---@field resize_pane rex.SessionMethod `{ before_block_id, after_block_id, direction, ratio }`
---@field resize_layer rex.SessionMethod
---@field raise_layer rex.SessionMethod
---@field lower_layer rex.SessionMethod
---@field move_window rex.SessionMethod
---@field focus_block rex.SessionMethod `{ block_id }`
---@field focus_window rex.SessionMethod `{ window_id }`
---@field focus_direction rex.SessionMethod `{ direction, wrap? }`
---@field focus_next_pane rex.SessionMethod
---@field focus_previous_pane rex.SessionMethod
---@field focus_next_window rex.SessionMethod
---@field focus_previous_window rex.SessionMethod
---@field set_label rex.SessionMethod
---@field set_window_label rex.SessionMethod
---@field set_block_label rex.SessionMethod
---@field attach rex.SessionMethod
---@field detach rex.SessionMethod
---@field help rex.SessionMethod

---@class rex.Block
---@field call fun(creator: string, method: string, args?: table): table?, string? Call a block method; `block_id` defaults to the current block.

---@class rex.Client
---@field queue fun(name: string, args?: table) Ask the client to perform one of its actions. Raises when there is no client.

---@class rex.ExecOpts
---@field cwd? string
---@field env? table<string, string|false>
---@field clear_env? boolean
---@field stdin? string|boolean
---@field timeout? number Seconds until SIGTERM, then SIGKILL two seconds later.
---@field stdout? boolean|fun(chunk: string)
---@field stderr? boolean|fun(chunk: string)
---@field text? boolean
---@field detach? boolean `rex.exec.start` only: outlive the work that started it.

---@class rex.ExecResult
---@field code integer Exit status, or -1 if a signal ended it.
---@field signal? string
---@field stdout string
---@field stderr string
---@field timed_out boolean
---@field ok boolean `code` is 0 and it didn't time out.

---@class rex.ExecHandle
---@field pid integer
---@field wait fun(self: rex.ExecHandle, seconds?: number): rex.ExecResult?, string?
---@field write fun(self: rex.ExecHandle, data: string): boolean?, string?
---@field close_stdin fun(self: rex.ExecHandle)
---@field kill fun(self: rex.ExecHandle, signal?: string|integer)
---@field running fun(self: rex.ExecHandle): boolean

---@class rex.Exec
---@overload fun(argv: string[], opts?: rex.ExecOpts): rex.ExecResult?, string?
---@field start fun(argv: string[], opts?: rex.ExecOpts): rex.ExecHandle?, string?

---@class rex.Timer
---@field cancel fun(self: rex.Timer)
---@field active fun(self: rex.Timer): boolean

---@class rex.Json
---@field encode fun(value: any, opts?: { indent?: boolean }): string?, string?
---@field decode fun(text: string): any, string?

---@class rex.Server
---@field session rex.Session
---@field block rex.Block
---@field call fun(method: string, args?: table): table?, string?

---@class rex
---@field session rex.Session
---@field block rex.Block
---@field client rex.Client
---@field layout rex.Layout
---@field exec rex.Exec
---@field json rex.Json
---@field args table Script arguments (`rex do` only).
---@field session_id string The script's session (`rex do` only).
---@field block_id? string The script's block (`rex do` only).
rex = {}

--- Bind a key, sequence (`a>b`) or `mode/key` to an action by name, or a key
--- to a function `fn(ctx, ev)` that returns true when it handled the key.
---@param key string
---@param action string|fun(ctx: rex.Context, ev: rex.KeyEvent): boolean?
---@param args? table
function rex.bind(key, action, args) end

--- Remove a key's bindings (`mode/key` also blocks it in that mode), one
--- binding from `rex.bindings`, or a whole mode with `{ mode = name }`.
---@param key string|rex.Binding|{ mode: string }
---@param target? string|function
---@return integer removed
function rex.unbind(key, target) end

---@param name string
---@param options? { exclusive?: boolean }
function rex.mode(name, options) end

---@param filter? { key?: string, mode?: string, action?: string }
---@return rex.Binding[]
function rex.bindings(filter) end

---@return { name: string, exclusive: boolean, source: string }[]
function rex.modes() end

---@param spec rex.ActionSpec
function rex.action(spec) end

---@param name string
---@param args? table
---@return any result, string? err
function rex.invoke(name, args) end

--- Call any server method by its full name (`rex api list`). Unlike
--- `rex.session.*`, no `session_id` is filled in.
---@param method string
---@param args? table
---@return table?, string?
function rex.call(method, args) end

---@param spec rex.HostSpec
function rex.host(spec) end

---@return string[]
function rex.servers() end

---@param label string
---@return rex.Server
function rex.server(label) end

--- Scripts only (`rex do`): call `fn(ctx, ev)` each time `event` happens.
---@param event string
---@param fn fun(ctx: rex.Context, ev: table)
function rex.on(event, fn) end

--- Scripts only: block until `event` happens.
---@param event string
---@param filter? table|fun(ev: table, ctx: rex.Context): boolean
---@param timeout? number
---@return table? ev, rex.Context|string ctx_or_err
function rex.wait(event, filter, timeout) end

--- Scripts only.
---@param seconds number
function rex.sleep(seconds) end

--- Scripts only.
---@param code? integer
function rex.stop(code) end

--- Scripts only.
---@param seconds number
---@param fn fun(ctx: rex.Context)
---@return rex.Timer
function rex.after(seconds, fn) end

--- Scripts only.
---@param seconds number
---@param fn fun(ctx: rex.Context)
---@return rex.Timer
function rex.every(seconds, fn) end

---@param level_or_message string `debug`, `info`, `warn` or `error`, or the message.
---@param message? string
function rex.log(level_or_message, message) end
