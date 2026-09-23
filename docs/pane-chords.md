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
