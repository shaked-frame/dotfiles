# Neovim Pickers and UI Shortcuts

`<Leader>` is Space. Regular pickers use Snacks. The bindings live in
`home/dot_config/nvim/plugin/20_keymaps.lua`; scoped searches, visit history and
the guarded `vim.ui.select` provider live in `plugin/21_pickers.lua`.

## Files, Buffers, and Search

| Keys                      | Action                                                                 |
| ------------------------- | ---------------------------------------------------------------------- |
| `Space Space`, `Space fb` | Open buffers; `Ctrl-d` deletes a buffer from the picker                |
| `Space ff`                | Find files                                                             |
| `Space fF`                | Find hidden and ignored files, following symlinks and excluding `.git` |
| `Space fe`                | Find files under the frontend directory                                |
| `Space fg`                | Live project grep; in Visual mode, search the selected text literally  |
| `Space fG`                | Search the word under the cursor literally                             |
| `Space fE`                | Live grep under the frontend directory                                 |
| `Space bg`, `Space fl`    | Search lines across loaded, listed buffers, including unsaved text     |
| `Space fL`                | Search lines in the current buffer                                     |
| `Space fh`                | Help tags                                                              |
| `Space fH`                | Highlight groups                                                       |
| `Space f/`, `Space f:`    | Search history and command history                                     |
| `Space fr`                | Resume the last Snacks picker                                          |

Frontend searches use `<frame root>/frontend`, falling back to the current
working directory outside a frame repo. See [the glossary](../CONTEXT.md).

## Git and Review

| Keys                   | Action                                                                                                                  |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `Space gd`, `Space gD` | Staged and unstaged diff picker, grouped by file; uppercase limits it to the current file (untracked files: `Space mf`) |
| `Space ga`, `Space gA` | Staged diff picker, grouped by file; uppercase limits it to the current file                                            |
| `Space fm`, `Space fM` | Unstaged hunk picker; uppercase limits it to the current file                                                           |
| `Space fa`, `Space fA` | Staged hunk picker; uppercase limits it to the current file                                                             |
| `Space mf`             | Git status picker, including untracked files                                                                            |
| `Space fc`, `Space gl` | Commit picker                                                                                                           |
| `Space fC`, `Space gL` | Current-file commit picker, following renames                                                                           |
| `Space gu`             | Toggle CodeDiff (VS Code's diff editor and staged/unstaged explorer)                                                    |
| `Space gg`, `Space gG` | Open LazyGit through `Snacks.lazygit`; uppercase opens the current file's log                                           |

Diff pickers preview changes without opening CodeDiff. Git diff/status pickers
use Tab to stage or unstage; their `Ctrl-r` action restores changes, so use it
deliberately. Selecting a commit opens `Git show`; it does **not** check out the
commit. `Space gu` remains the dedicated full-review view.

## Language and Visit History

| Keys                          | Action                                                                                 |
| ----------------------------- | -------------------------------------------------------------------------------------- |
| `Space fd`, `Space fD`        | Workspace diagnostics and current-buffer diagnostics                                   |
| `grr`, `Space fR`, `Space lR` | LSP references                                                                         |
| `Space fs`                    | Live workspace symbols                                                                 |
| `Space fS`, `Space eb`        | Document symbols                                                                       |
| `Space fv`, `Space fV`        | Visited files across all directories and in the current working directory              |
| `Space vc`, `Space vC`        | Core-labeled visited files across all directories and in the current working directory |

Visits still use MiniVisits data and labels, displayed through Snacks. Global
`vim.ui.select` uses Snacks too, including LSP code actions. The wrapper rejects
actions from clients that have detached or restarted.

## Picker Controls and Exceptions

In regular Snacks pickers, Enter confirms, Escape cancels, and `Ctrl-n` /
`Ctrl-p` move through results. Tab selects items unless a source overrides it,
as Git diff/status does. `Ctrl-q` sends selected items, or all filtered results
when none are selected, to quickfix.

Custom worktree, agent, terminal-tab and Grug-Far path pickers still use MiniPick.
Their existing controls are unchanged. `Space fr` resumes Snacks pickers, not
those custom Mini pickers. Optional MiniExtra sources remain available via
`:Pick`.

## Other UI Shortcuts Added Alongside the Migration

| Keys            | Action                                                                                          |
| --------------- | ----------------------------------------------------------------------------------------------- |
| `Space eM`      | Native message history in ui2's pager; `q` closes it                                            |
| `Space en`      | MiniNotify history, separate from native messages                                               |
| `Space o Enter` | Open a line below without continuing a comment; Enter preserves the existing `Space o…` submenu |
| `Space O`       | Open a line above without continuing a comment                                                  |

The open-line mappings restore the buffer's `formatoptions` and enter Insert
mode. Native `dw` is unchanged.

## Verification

`sh scripts/test.sh` runs every regression script plus `smoke.sh`; see
[`scripts/README.md`](../scripts/README.md).

`smoke.sh` checks startup and keymap collisions in plain Neovim, Herdr, Rex and
Herdr nested in Rex.

`test-snacks-pickers.lua` checks picker routing, frontend and visit scopes,
unsaved buffer text, commit-selection safety, the CodeDiff binding and stale
LSP code-action protection. It also creates a disposable Git repo to exercise
the real staged/unstaged diff finder and exact current-file filtering. It does
not stage files in this repository.

The remaining scripts cover statusline rendering and theme reloads, native
CLI-error history, and comment-free line opening with option restoration.
