# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). The repo lives at
`~/dotfiles`; `.chezmoiroot` points chezmoi at `home/`, so `docs/`, `scripts/`
and the agent files stay outside the managed tree.

## New machine

```sh
brew install chezmoi
git clone git@github.com:shakedhagag/dotfiles.git ~/dotfiles
chezmoi init --source ~/dotfiles --apply   # asks once: work or personal
```

`chezmoi init` renders `home/.chezmoi.toml.tmpl` into
`~/.config/chezmoi/chezmoi.toml`, which holds `sourceDir`, `mode = "symlink"`
and the machine type. To change the answer later, run
`chezmoi init --source ~/dotfiles --promptChoice "Machine type=personal"`.

## Daily use

`mode = "symlink"` makes each plain file in `$HOME` a symlink into `home/`, so
editing `~/.config/nvim/init.lua` edits the repo, as with Stow. Three cases
still need chezmoi:

| Change | Do |
| --- | --- |
| Edit an existing plain file | Nothing; it is live. Commit from `~/dotfiles`. |
| New file in a managed dir (e.g. a new `plugin/*.lua`) | `chezmoi add <path>`, then `chezmoi apply` to swap it for a symlink |
| Template (`*.tmpl`) or executable (`executable_*`) | Edit it in `home/`, then `chezmoi apply`; these are copied, not linked |
| A tool replaced a symlink with a regular file | `chezmoi re-add` (shows up in `chezmoi status`) |

Check state with `chezmoi status` (empty when in sync), `chezmoi diff`, and
`chezmoi verify`.

Source names follow chezmoi's conventions: `dot_config/` is `.config/`,
`dot_zshrc` is `.zshrc`, `executable_` sets the exec bit, `.tmpl` is rendered
with the machine data.

## Tool versions (mise)

chezmoi only places config files. Language runtimes and CLI versions are
mise's job: `~/frame` pins its toolchain in its own `mise.toml`. No global mise
config is managed here yet; see `docs/adr/0001-chezmoi-over-stow.md` for where
it would go.

## Managed

| Target | Source |
| --- | --- |
| `~/.zshrc`, `~/.config/zsh` | `home/dot_zshrc`, `home/dot_config/zsh` |
| `~/.gitconfig` | `home/dot_gitconfig.tmpl`: work email, signing key and personal-repo `includeIf`s on `work`, personal email on `personal` |
| `~/.config/git/ignore` | `home/dot_config/git/ignore` |
| `~/.config/nvim` | `home/dot_config/nvim` ([picker shortcuts and tests](docs/nvim-pickers.md)) |
| `~/.config/{atuin,ghostty,herdr,lazygit,rex,starship.toml,worktrunk,yazi,zed,zellij}` | `home/dot_config/...` |
| `~/.atuin/permissions.ai.toml` | `home/dot_atuin/permissions.ai.toml` |

On the work Mac, `~/.gitconfig` includes the untracked `~/.gitconfig-personal`
for `~/personal/` and `~/dotfiles/`, so commits here use the personal email and
push with the personal SSH key.

## Never add these

**This repo is public.** These live in `$HOME` and must never be `chezmoi add`ed — they hold
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
chezmoi links into this repo:

```
~/Library/Application Support/lazygit/config.yml
  -> ~/.config/lazygit/config.yml
  -> ~/dotfiles/home/dot_config/lazygit/config.yml
```

If lazygit ever starts ignoring its config, check that first hop still exists;
chezmoi does not manage it. Verify with `lazygit --print-config-dir`.

`zed.yml` in the same directory is a partial config layered on top of `config.yml`
by the Zed task in `home/dot_config/zed/tasks.json`, via
`LG_CONFIG_FILE="…/config.yml,…/zed.yml"`.
