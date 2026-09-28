# Pane-navigation chords: which layer owns what

Four layers each navigate "panes" with their own chord family. The seam is
chord-avoidance: never bind a chord one of the other layers already claims.
When changing any row, check the other three.

| Layer | Chords | Source |
| ----- | ------ | ------ |
| Herdr (multiplexer panes) | `prefix+h/j/k/l`, direct `ctrl+alt+h/j/k/l`, `prefix+a` last pane | `herdr/.config/herdr/config.toml` `[keys]` |
| Ghostty (splits) | `super+h/l` goto split | `ghostty/.config/ghostty/config` |
| nvim (windows) | `<C-h/j/k/l>` (mini.basics), `<M-h/j/k/l>` in insert/cmd, `<C-h/j/k/l>` from terminal mode | `plugin/30_mini.lua`, `plugin/20_keymaps.lua` |
| Zed (panes) | `ctrl-h/j/k/l` ActivatePane* | `zed/.config/zed/keymap.json` |

Standing surrenders (do not reclaim without updating all sides):
- `<C-a>` never reaches nvim inside Herdr (it is Herdr's prefix) — hence
  dial.nvim lives on `<C-Up>/<C-Down>` (`plugin/40_plugins.lua`).
- Ghostty's old byte-injecting `text:\x01h` chords are retired (comment in
  ghostty config) — they fired in apps with nothing to do with the multiplexer.
- `ctrl-h/j/k/l` means "nvim window" inside nvim and "Zed pane" inside Zed;
  Herdr panes use the `ctrl+alt-*` family instead, chosen as essentially
  unclaimed. `super+h/l` belongs to Ghostty splits.

## Hyper (Super+Ctrl+Alt+Shift)

Ghostty forces raw CSI-u for the six Hyper chords nvim maps (`Hyper+8/7/9/0`
resize, `Hyper+\` next diagnostic, `Hyper+p` next hunk) — Super has no legacy
encoding, so without this the chord arrives as nothing. See the Hyper section in
`ghostty/.config/ghostty/config`. Narrow by design: shells ignore CSI-u and
Herdr binds no Super chords, so unlike the retired byte-injecting chords these
cannot trigger multiplexer actions. Zed is a separate app and unaffected
(it reads macOS keys directly).
Decode rule (verified via Insert-mode `Ctrl-V`): nvim drops the Shift bit —
Shift folds into case for letters (map uppercase `H('P')`) and vanishes for
the rest (map `H('\\')`, digits as-is). The `H()` helper in
`plugin/20_keymaps.lua` already encodes this; map the decoded form.
