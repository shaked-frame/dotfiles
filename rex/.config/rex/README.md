# Rex

`init.lua` holds keys and actions. Font, theme and Remote Control are app
settings (`defaults read com.superlogical.rex`) and are set like this:

```sh
# Font: matches ghostty/config
defaults write com.superlogical.rex Workspace.terminalFontName -string "Ioskeley Mono"
defaults write com.superlogical.rex Workspace.terminalFontPointSize -float 14
defaults write com.superlogical.rex Workspace.terminalFallbackFontNames -array "IoskeleyMonoTerm Nerd Font"
# Line height (Ghostty adjust-cell-height = 17%): set in Settings > Terminal.
```

- **Remote Control** (Settings > Rex Server) must be on. `rex do worktree_open`
  switches the app's session from the CLI, which the app refuses otherwise.
- **Notifications**: Rex itself sends macOS notifications when a program
  (Claude Code included) reports blocked, done or error through the Program
  Status Protocol. Choose which states notify in its Settings. No script needed.
- **Theme**: `themes/Atom One Dark` is Ghostty's theme with the `#282c34`
  background from `ghostty/config`. Import it once:
  `rex -C <client> do client.theme.import path="$HOME/.config/rex/themes/Atom One Dark"`
  (or "Import Theme File" in the command palette), then pick it as the dark theme.
