# Rex

`init.lua` holds keys and actions; [`KEYMAP.md`](KEYMAP.md) lists every key.
Font, theme and Remote Control are app
settings (`defaults read com.superlogical.rex`) and are set like this:

```sh
# Font: Geist Mono for its ligatures (=> !== ->). It has only 5 of the 128
# box-drawing characters, so the Nerd Font build of Geist (all 128, plus icons,
# but no ligatures) comes first in the fallbacks: border corners then match
# Geist's lines instead of Ioskeley's.
defaults write com.superlogical.rex Workspace.terminalFontName -string "Geist Mono"
defaults write com.superlogical.rex Workspace.terminalFontPointSize -float 14
defaults write com.superlogical.rex Workspace.terminalFallbackFontNames -array "GeistMono Nerd Font Mono" "IoskeleyMonoTerm Nerd Font"
# Line height (Ghostty adjust-cell-height = 17%): set in Settings > Terminal.
```

Theme: import `~/.config/ghostty/themes/solarized-osaka-vivid` (a Ghostty theme
file generated from Neovim's colors by `scripts/gen-terminal-theme.lua`) in
Settings and pick it as the dark theme. Re-import after regenerating it.

- **Remote Control** (Settings > Rex Server) must be on. `rex do worktree_open`
  switches the app's session from the CLI, which the app refuses otherwise.
- **Notifications**: Rex itself sends macOS notifications when a program
  (Claude Code included) reports blocked, done or error through the Program
  Status Protocol. Choose which states notify in its Settings. No script needed.
- **Theme**: `themes/Atom One Dark` is Ghostty's theme with the `#282c34`
  background from `ghostty/config`. Import it once:
  `rex -C <client> do client.theme.import path="$HOME/.config/rex/themes/Atom One Dark"`
  (or "Import Theme File" in the command palette), then pick it as the dark theme.
