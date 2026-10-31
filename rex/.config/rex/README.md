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
- **Notifications**: `scripts/notify.lua` sends a macOS notification when an
  agent is blocked, finishes or fails while Rex isn't frontmost. launchd keeps
  it running (`launchd/com.shakedhagag.rex-notify.plist`):
  ```sh
  ln -s ~/.config/rex/launchd/com.shakedhagag.rex-notify.plist ~/Library/LaunchAgents/
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.shakedhagag.rex-notify.plist
  # remove: launchctl bootout gui/$(id -u)/com.shakedhagag.rex-notify
  ```
  Log: `~/Library/Logs/rex-notify.log`.
- **Theme**: `themes/Atom One Dark` is Ghostty's theme with the `#282c34`
  background from `ghostty/config`. Import it once:
  `rex -C <client> do client.theme.import path="$HOME/.config/rex/themes/Atom One Dark"`
  (or "Import Theme File" in the command palette), then pick it as the dark theme.
