# Worktree flow

Two ways to create a worktree, depending on whether you start from Herdr or from a shell or agent:

1. **Create from shell or agent** via `wt switch -c <branch>`.
   Lands in `~/worktrees/<repo>/<branch-slug>/<repo>` and runs `pre-start` hooks from `worktrunk/.config/worktrunk/config.toml` to link `.env.local` files, link `AGENTS.local.md`, run `pnpm i`, and generate `mkcert` certificates via `pnpm setup:certs`.
2. **Create from Herdr** via `prefix+shift+g` or `herdr worktree create --branch <name>`.
   Lands in the same `~/worktrees/<repo>/<branch-slug>` tree and registers as a Herdr workspace. Run `wt hook pre-start` inside the new checkout to run the bootstrap hooks.
3. **Open in Herdr** via `prefix+shift+o`, or `<Leader>gw` from nvim (`plugin/60_herdr.lua` focuses the existing workspace via `open_workspace_id` instead of opening a duplicate).

Manual helpers in `zsh/.config/zsh/lazygit-functions.zsh` and `~/.local/bin`:

- `link-worktree-env` symlinks `.env.local` files from `~/frame`.
- `link-worktree-zed` symlinks `~/frame/.zed/settings.json` into the worktree.
- `worktree-setup` runs `pnpm i && pnpm setup:frontend` from an interactive shell or from lazygit as `:worktree-setup`.

Caveats:

- Creating a worktree via `wt switch -c`, lazygit, or raw `git worktree add` bypasses Herdr registration. Open it via `prefix+shift+o` or `<Leader>gw` to register the workspace.
- Pre-existing checkouts under `~/frame/.worktrees/` are unaffected; `worktree-path` and `[worktrees].directory` only decide where new ones land.
- Starship shortens `~/worktrees/frame` to `wt` in `starship/.config/starship.toml`.
