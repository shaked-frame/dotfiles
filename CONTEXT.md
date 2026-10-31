# CONTEXT.md — dotfiles

Domain glossary for this repo. Skills must use these terms exactly; don't drift to synonyms.

## Terms

- **frame root**: nearest ancestor directory (up from cwd) holding `frontend/apps/web`. Covers `~/frame` and any `~/worktrees/frame/<name>/frame` checkout. Resolved by `Config.frame_root()` (`nvim/.config/nvim/init.lua`); nil outside frame repos.
- **frontend**: `<frame root>/frontend` — the web monorepo (apps, packages). Scoped finders (`<Leader>fe` files, `<Leader>fE` grep), explorer bookmarks (`'a` web app, `'f` frontend, `'p` packages), and Tailwind v4 CSS resolution (`after/lsp/tailwindcss.lua`) target it, falling back to cwd outside frame repos.
- **explorer adapter**: Oil (`stevearc/oil.nvim`) vs Miller-column `mini.files` behind the `Config.Explorer` seam (`nvim/.config/nvim/plugin/24_explorer.lua`), switched via `Config.explorer`.
- **agent adapter**: Herdr panes (`nvim/.config/nvim/plugin/60_herdr.lua`), Rex panes (`nvim/.config/nvim/plugin/61_rex.lua`) or sidekick CLI (`nvim/.config/nvim/plugin/46_sidekick_cli.lua`) behind the single `<Leader>a*` seam (`nvim/.config/nvim/plugin/44_agent.lua`). Inside the **Rex host**, an open sidekick chat wins, then an agent in a Rex pane; with neither, sidekick. Delete an adapter file and the dispatcher falls back to sidekick.
- **Rex host**: Neovim running in a Rex pane and not inside Herdr. When Herdr runs nested in Rex, Herdr wins: it is the multiplexer the pane actually sits in. Every Rex call from Neovim goes through `Config.Rex`.
- **worktree session**: the Rex session that belongs to one Git worktree, opened as nvim beside an agent. It is identified by where its panes' working directories are (the longest matching worktree path), never by its label: agents and people rename sessions. The label is for display only: the branch at creation, the folder name for a detached worktree.
- **attach**: stage editor context into the agent's input WITHOUT submitting; the agent UI is focused so more can be added and Enter pressed manually (`<Leader>af` file, `<Leader>at` location, `<Leader>av` selection).
- **send**: submit editor context to the agent immediately (`<Leader>aF` file, `<Leader>aT` location, `<Leader>aV` selection).
