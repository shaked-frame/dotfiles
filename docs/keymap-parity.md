# Keymap parity: Zed ↔ nvim

These bindings are intentionally mirrored across editors. When changing one
side, update the other side and this file. (Snippets are deliberately NOT
unified — nvim is used as-is, Zed best-effort; that skip is a standing
decision, not an oversight.)

Rows marked ✓ verified in `zed/.config/zed/keymap.json`; rows marked ~
exist only as `Zed: …` comments in `nvim/.config/nvim/plugin/20_keymaps.lua`
and were not found in Zed's keymap — treat as unconfirmed.

| Zed | nvim | Notes |
| --- | ---- | ----- |
| ✓ `H` pane::ActivatePreviousItem | `H` previous buffer | nvim cycles buffers only; Zed is MRU items |
| ✓ `space space` tab_switcher::Toggle | `<Leader><Leader>` / `<Leader>fb` buffers | |
| ✓ `space f b` tab_switcher::Toggle | `<Leader>fb` buffers | second Zed chord, same target |
| ✓ `s s` pane::SplitDown | `ss` split | |
| ✓ `s v` pane::SplitAndMoveRight | `sv` split and move buffer right | nvim restores alt buffer; see `Config.Splits` |
| ✓ `s h` / `s l` MoveItemToPaneInDirection | `sh` / `sl` move buffer to split | nvim steps one slot via `wincmd h/l` swap |
| ✓ `g w` vim::HelixJumpToWord | `gw` MiniJump2d word start | |
| ✓ `g r r` editor::FindAllReferences | `grr` LSP references picker | `mini.operators` leaves `grr` unmapped in `30_mini.lua` (`gr_` replaces line) |
| ✓ `g r a` editor::ToggleCodeActions | `gra` code action (also `<Leader>la`) | `timeoutlen` pause after `gr` (replace operator); `graq`/`grai` still work typed fast |
| ✓ `space m` workspace::ToggleZoom | `<Leader>m` / `<Leader>M` / `<Leader>oz` zoom | nvim `mini.map` stays disabled to free `m` |
| ✓ `space m f` git::OpenModifiedFiles | `<Leader>mf` modified files | |
| ✓ `space g r` git::Restore | `<Leader>gr` / `gHgh` restore hunk | also works on visual selection (`<Leader>gr` / `gH`) |
| ✓ `alt-tab` editor::AcceptNextWordEditPrediction | `<C-l>` accept inline completion word | different chord, same idea |
| ✓ `ctrl-h/j/k/l` workspace::ActivatePane* | `<C-h/j/k/l>` window nav (mini.basics) | per-layer chords; see `docs/pane-chords.md` |
| ✓ `ctrl-alt-cmd-^&*(` ResizePane* | Hyper `8/7/9/0` resize window | different chord families |
| ✓ `ctrl-alt-cmd-\|` editor::GoToDiagnostic | Hyper `\` next diagnostic | different chord families |
| ✓ `ctrl-alt-cmd-shift-p` editor::GoToHunk | `Hyper+p` next hunk (also `[h`/`]h`) |
| ~ `space =` EqualizePanes | `<Leader>=` equalize windows | not found in Zed keymap — unconfirmed |
| ~ `space shift-m` Maximize | `<Leader>M` zoom | not found in Zed keymap — unconfirmed |
| ~ `f7`/`f8` diff hunk nav | `[h` / `]h` MiniDiff hunks | not found in Zed keymap — unconfirmed |
