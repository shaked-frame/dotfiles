# Worktree flow

One flow, three owners. Create and open in Herdr, bootstrap in shell:

1. **Create** — Herdr `prefix+shift+g` (or `herdr worktree create --branch <name>`).
   Lands in `~/worktrees/<repo>/<branch-slug>` (see `[worktrees]` in
   `herdr/.config/herdr/config.toml`) and registers as a Herdr workspace.
2. **Open** — Herdr `prefix+shift+o`, or `<Leader>gw` from nvim
   (`plugin/60_herdr.lua`: focuses the existing workspace via
   `open_workspace_id` instead of opening a duplicate).
3. **Bootstrap deps** — `worktree-setup` (`pnpm i && pnpm setup:frontend`),
   from an interactive shell or from lazygit as `:worktree-setup`.
   Defined in `zsh/.config/zsh/lazygit-functions.zsh`.
4. **Link editor settings** — `link-worktree-zed` (symlinks
   `~/frame/.zed/settings.json` into the worktree). Same file.

Caveats:

- Creating a worktree from lazygit (or raw `git worktree add`) bypasses
  Herdr registration — re-open it via `prefix+shift+o` to register.
- Pre-existing checkouts under `~/frame/.worktrees/` are unaffected; the
  `[worktrees]` directory only decides where NEW ones land.
- Starship shortens `~/worktrees/frame` to `wt` (see
  `starship/.config/starship.toml`).
