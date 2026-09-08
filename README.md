# dotfiles

GNU Stow packages, target `$HOME`. Run from this directory:

```sh
stow <package>          # link one package
stow -R <package>       # re-link after adding files to a package
stow -D <package>       # unlink
stow -n -v 2 <package>  # dry run
```

Layout mirrors the target tree: `<package>/.config/<name>/...` links to
`~/.config/<name>/...`, and `<package>/.zshrc` links to `~/.zshrc`.

## Packages

| Package | Links |
| --- | --- |
| `atuin` | `.config/atuin`, `.atuin` |
| `ghostty` | `.config/ghostty` |
| `git` | `.gitconfig`, `.config/git/ignore` |
| `herdr` | `.config/herdr/config.toml` |
| `lazygit` | `.config/lazygit` |
| `nvim` | `.config/nvim` |
| `starship` | `.config/starship.toml` |
| `yazi` | `.config/yazi` |
| `zed` | `.config/zed` |
| `zellij` | `.config/zellij/config.kdl` |
| `zsh` | `.zshrc`, `.config/zsh` |

## Never add these

**This repo is public.** These live in `$HOME` and must stay unstowed — they hold
live credentials or machine identity:

| Path | Contains |
| --- | --- |
| `~/.npmrc` | GitHub Packages `_authToken` |
| `~/.config/gh/hosts.yml` | `gh` OAuth token |
| `~/.config/github-copilot/` | `apps.json`, `auth.db` |
| `~/.config/frm/auth.json` | service auth |
| `~/.claude.json`, `~/.claude.json.backup` | project history |
| `~/.gitconfig-personal` | personal email + SSH key path |
| `~/.ssh`, `~/.gnupg`, `~/.aws` | keys |

Deliberately skipped as state rather than config: `.config/raycast` (~550MB of
extension state), `.config/opencode` (mixed config and a multi-MB local index),
`.config/{configstore,vercel-plugin,muse,tanstack,fresh,cliamp}` (session
stamps, telemetry IDs, generated types).

Also skipped because their installers own them and rewrite them on every
upgrade: `~/.zshenv` (rustup, Vite+), `~/.zprofile` (Homebrew, Obsidian),
`~/.profile`, `~/.bashrc`. Their `source` lines are unguarded, so versioning
them would error on every shell start on a machine where those tools are not
installed yet.

## Gotcha: lazygit on macOS

lazygit reads `~/Library/Application Support/lazygit/config.yml` by default, not
`~/.config`. That path is a symlink into `~/.config/lazygit/config.yml`, which
stow folds into this repo — a three-hop chain:

```
~/Library/Application Support/lazygit/config.yml
  -> ~/.config/lazygit/config.yml
  -> ~/dotfiles/lazygit/.config/lazygit/config.yml
```

If lazygit ever starts ignoring its config, check that first hop still exists;
it is not managed by stow. Verify with `lazygit --print-config-dir`.

`zed.yml` in the same package is a partial config layered on top of `config.yml`
by the Zed task in `zed/.config/zed/tasks.json`, via
`LG_CONFIG_FILE="…/config.yml,…/zed.yml"`.
