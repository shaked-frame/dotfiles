# 0001: chezmoi instead of GNU Stow, mise kept for runtimes only

Date: 2026-11-08. Status: accepted.

## Context

Until now this repo was a set of GNU Stow packages (`nvim/.config/nvim`,
`zsh/.zshrc`, ...) linked into `$HOME`. It lives on the work Mac and is pushed
to the personal GitHub account (`shakedhagag/dotfiles`), so it has to serve
more than one machine. Stow has no way to vary a file per machine: the work
email and GPG key in `.gitconfig` would leak onto a personal laptop, and the
reverse.

## Decision

Manage the repo with chezmoi, fully converted to its source layout:

- The repo stays at `~/dotfiles`. `.chezmoiroot` points chezmoi at `home/`,
  which holds the source state (`dot_config/nvim/...`, `dot_zshrc`,
  `dot_gitconfig.tmpl`). `docs/`, `scripts/` and the agent files stay outside
  it.
- `mode = "symlink"`: every plain file in `$HOME` is a symlink into `home/`,
  so editing a config in place edits the repo, as Stow did. Templates and
  executables are copied, since chezmoi renders or chmods them.
- The machine type (`work` / `personal`) is asked once by `chezmoi init` from
  `home/.chezmoi.toml.tmpl`. `dot_gitconfig.tmpl` uses it to pick the email,
  the signing key and the personal-repo `includeIf`s.

## Consequences

- A new file in a managed directory needs `chezmoi add`; Stow picked it up
  through folded directory links. chezmoi links file by file, so runtime
  state (logs, sockets, approvals) now stays in `$HOME` instead of landing in
  the repo, and `.gitignore` no longer needs per-tool entries.
- A tool that saves by replacing a file breaks its symlink. `chezmoi status`
  shows it and `chezmoi re-add` pulls the change back.
- Paths in tests and docs moved from `<package>/.config/...` to
  `home/dot_config/...`.

## mise

mise installs tool versions; chezmoi places config files. They do not
overlap. `~/frame` already pins its toolchain in `mise.toml`, and that stays
per-project. No global mise config is managed here yet. If one is added, it
goes in `home/dot_config/mise/config.toml`, with a `run_onchange_` script that
runs `mise install` when it changes.
