# Rex keymap

Every key set in `init.lua`, plus the Neovim keys that work with Rex.
`Hyper` is the Voyager Hyper key (cmd+ctrl+alt+shift). Check what is loaded
with `rex keymap`.

No prefix key. `ctrl+alt` chords are the ones carried over from herdr;
`Hyper` covers everything herdr only had behind its prefix.

## Moving around

| Key | Does |
| --- | --- |
| `ctrl+h` / `j` / `k` / `l` | Focus the pane in that direction. In Neovim it moves between nvim splits first, then crosses into the next Rex pane at the edge |
| `ctrl+alt+h` / `j` / `k` / `l` | Focus the pane in that direction (skips the Neovim check) |
| `Hyper+tab` | Focus the next pane |
| `Hyper+up` / `Hyper+down` | Jump to the previous / next shell prompt in the scrollback |
| `Hyper+/` | Find in the terminal |

## Panes

| Key | Does |
| --- | --- |
| `Hyper+d` / `ctrl+alt+d` | Split right |
| `Hyper+-` / `ctrl+alt+shift+d` | Split down |
| `Hyper+x` | Close pane |
| `Hyper+z` / `ctrl+alt+z` | Zoom pane (toggle) |
| `Hyper+f` | Turn the pane into a floating pane |
| `Hyper+h` / `j` / `k` / `l` | Move the pane in that direction |
| `Hyper+6` / `7` / `8` / `9` | Resize: move the border left / up / down / right (hold to repeat). In Neovim it resizes nvim windows first, then the Rex pane when there's no nvim split that way |
| `Hyper+r` | Resize mode (see below) |

### Resize mode

`Hyper+r` enters it. Other keys do nothing until you leave.

| Key | Does |
| --- | --- |
| `h` / `j` / `k` / `l` | Resize toward that direction |
| `shift+h` / `j` / `k` / `l` | Resize in bigger steps |
| `=` | Make splits equal |
| `enter`, `q`, `escape` | Leave resize mode |

## Tabs

| Key | Does |
| --- | --- |
| `Hyper+c` / `ctrl+alt+c` | New tab |
| `Hyper+]` / `ctrl+alt+]` | Next tab |
| `Hyper+[` / `ctrl+alt+[` | Previous tab |
| `cmd+1` … `cmd+9` | Go to tab N (Rex default) |

## Sessions and worktrees

One session per Git worktree, named after the branch, opened as nvim | claude.

| Key | Does |
| --- | --- |
| `Hyper+w` / `ctrl+alt+w` | Worktree picker (floating fzf). `●` means a session is already open. Typing a new branch name creates the worktree with `wt` |
| `space g w` (Neovim) | The same worktree picker, inside Neovim |
| `Hyper+s` | Rex's session switcher |
| `ctrl+alt+n` / `ctrl+alt+p` | Next / previous session |
| `Hyper+b` / `ctrl+alt+b` | Toggle the sidebar |

## Floating tools

These keep running while hidden. Press once to show, again to hide, and from
another tab to bring it there. Each session has its own. Quitting the program
(`q`, `exit`) closes it, and the next press starts a fresh one.

| Key | Does |
| --- | --- |
| `Hyper+g` | lazygit |
| `Hyper+o` | Scratch shell |
| `Hyper+e` | Open this pane's screen and scrollback in Neovim (a new float each time) |

## Agents

| Key | Does |
| --- | --- |
| `Hyper+a` | Open Claude in a split to the right, in this pane's directory |
| `Hyper+v` / `ctrl+alt+v` | Move the agent between its own "Claude" tab and a split right of nvim in the "Vim" tab. It keeps running |
| `Hyper+m` / `ctrl+alt+m` | Zoom the editor so the agent runs out of sight (toggle) |

From Neovim, `space a *` sends to the agent. It goes to the sidekick chat if
one is open in this nvim tab, otherwise to a Rex agent pane, otherwise sidekick
opens.

| Key (Neovim) | Does |
| --- | --- |
| `space a a`, `cmd+r` | Focus the agent |
| `space a f` / `space a F` | Attach / send the current file |
| `space a t` / `space a T` | Attach / send the cursor location |
| `space a v` / `space a V` (visual) | Attach / send the selection |
| `space a p` | Type a prompt and send it |

Lowercase attaches without pressing Enter and moves you to the agent;
uppercase sends right away and keeps you in Neovim.

## Passed through to Neovim

Rex sends these to the pane as raw key codes for nvim's `H()` mappings.

| Key | Neovim |
| --- | --- |
| `Hyper+\` | Next diagnostic |
| `Hyper+p` | Next hunk |
| `cmd+left` / `cmd+right` | Start / end of line |

## Misc

| Key | Does |
| --- | --- |
| `Hyper+,` | Reload `init.lua` |
| `cmd+shift+p` | Command palette (Rex default). Every custom action above is in it too |
