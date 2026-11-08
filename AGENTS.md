## Agent skills

### Issue tracker

Issues live as local markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary, label strings equal role names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`CONTEXT.md` + `docs/adr/`). See `docs/agents/domain.md`.

## Dotfiles layout

chezmoi manages this repo; read `README.md` "Daily use" before adding or moving files. Edit files under `home/` (the source), never their copies in `$HOME`. A new file needs `chezmoi add <target path>`; a changed template (`*.tmpl`) or executable (`executable_*`) needs `chezmoi apply`. `chezmoi status` must be empty when you finish. Why chezmoi: `docs/adr/0001-chezmoi-over-stow.md`.

## Checks

After changing `home/dot_config/nvim/` or `scripts/`, run `sh scripts/test.sh`. Writing or debugging a test or headless probe: read `scripts/README.md` first.
