# CONTEXT.md — dotfiles

Domain glossary for this repo. Skills must use these terms exactly; don't drift to synonyms.

## Terms

- **source**: a file under `home/`, in chezmoi's naming (`dot_config/nvim/init.lua`, `dot_gitconfig.tmpl`). The only copy to edit.
- **target**: where chezmoi places a **source** in `$HOME` (`~/.config/nvim/init.lua`). A symlink to the source for plain files; a rendered copy for templates and executables.
- **machine type**: `work` or `personal`, chosen at `chezmoi init` and stored in `~/.config/chezmoi/chezmoi.toml`. Templates branch on it (`.machine`).
- **frame root**: nearest ancestor directory (up from cwd) holding `frontend/apps/web`. Covers `~/frame` and any `~/worktrees/frame/<name>/frame` checkout. Resolved by `Config.frame_root()` (`home/dot_config/nvim/init.lua`); nil outside frame repos.
- **frontend**: `<frame root>/frontend` — the web monorepo (apps, packages). Resolved by `Config.frontend()`; nil outside frame repos, where each user picks its own fallback. Scoped finders (`<Leader>fe` files, `<Leader>fE` grep) fall back to cwd; Oil bookmarks (`'a` web app, `'f` frontend, `'p` packages) also try the directory Oil shows; Tailwind v4 CSS resolution (`after/lsp/tailwindcss.lua`) falls back to `~/frame/frontend`.
- **host**: the terminal multiplexer Neovim runs in: Rex, Herdr, or none. When Herdr runs nested in Rex, Herdr wins: it is the multiplexer the pane actually sits in. Pane focus at a split edge, pane resize, agent panes and worktrees all go to the host. Every `rex` / `herdr` call from Neovim goes through `home/dot_config/nvim/lua/config/host.lua`.
- **Rex host**: the **host** is Rex (a Rex pane, not inside Herdr).
- **agent adapter**: the **host**'s agent panes or the sidekick CLI chat (`home/dot_config/nvim/plugin/45_sidekick.lua`), behind the single `<Leader>a*` seam (`home/dot_config/nvim/plugin/44_agent.lua`). Inside Herdr, always Herdr's panes. Inside the **Rex host**, an open sidekick chat wins, then an agent in a Rex pane; with neither, sidekick. Outside a host, sidekick.
- **claimed terminal**: a terminal buffer whose command belongs to another feature (sidekick agent chats, LazyGit). The terminal dock never adopts one, including after a session restore. Claims are by command, made by the owning feature.
- **ghost text**: an inline completion suggestion shown after the cursor. `<Tab>` accepts it whole, `<M-Tab>` / `<C-l>` one word at a time; a completion-menu item the user already selected comes first, and `<C-l>` jumps snippet tabstops during a snippet session.
- **open worktree**: a Git worktree that some pane is working in, in any tab of any Rex session. Where a worktree is open is decided by the panes' working directories (the longest matching worktree path), never by labels: agents and people rename sessions. Opening an open worktree returns to that tab instead of creating anything.
- **worktree session**: the Rex session created for a worktree that wasn't open anywhere, laid out as nvim beside an agent. Its label is for display only: the branch at creation, the folder name for a detached worktree.
- **attach**: stage editor context into the agent's input WITHOUT submitting; the agent UI is focused so more can be added and Enter pressed manually (`<Leader>af` file, `<Leader>at` location, `<Leader>av` selection).
- **send**: submit editor context to the agent immediately (`<Leader>aF` file, `<Leader>aT` location, `<Leader>aV` selection).
