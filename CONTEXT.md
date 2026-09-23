# CONTEXT.md — dotfiles

Domain glossary for this repo. Skills must use these terms exactly; don't drift to synonyms.

## Terms

- **frame root**: nearest ancestor directory (up from cwd) holding `frontend/apps/web`. Covers `~/frame` and any `~/worktrees/frame/<name>/frame` checkout. Resolved by `Config.frame_root()` (`nvim/.config/nvim/init.lua`); nil outside frame repos.
- **frontend**: `<frame root>/frontend` — the web monorepo (apps, packages). Scoped finders (`<Leader>fe` files, `<Leader>fE` grep) and explorer bookmarks (`'a` web app, `'f` frontend, `'p` packages) target it, falling back to cwd outside frame repos.
- **agent adapter**: Herdr panes (`nvim/.config/nvim/plugin/60_herdr.lua`) vs sidekick CLI (`nvim/.config/nvim/plugin/46_sidekick_cli.lua`) behind the single `<Leader>a*` seam (`nvim/.config/nvim/plugin/44_agent.lua`). The dispatcher branches on `HERDR_ENV` exactly once; delete one adapter file and it falls back to the other.
- **attach**: stage editor context into the agent's input WITHOUT submitting; the agent UI is focused so more can be added and Enter pressed manually (`<Leader>af` file, `<Leader>at` location, `<Leader>av` selection).
- **send**: submit editor context to the agent immediately (`<Leader>aF` file, `<Leader>aT` location, `<Leader>aV` selection).
