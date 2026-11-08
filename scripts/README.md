# Regression scripts

`sh scripts/test.sh` runs them all (~10 s); `sh scripts/test.sh host theme`
runs `test-host.lua` and `test-theme.lua`. The pre-commit hook in `.githooks/`
runs it when a commit touches `home/dot_config/nvim/` or `scripts/` (enable per clone with
`git config core.hooksPath .githooks`). `test-rex-worktrees.sh` needs a live
Rex server and runs by hand.

## Two modes

The `-- Run:` header on line 1–2 picks the mode, and `test.sh` reads it:

- **Isolated** (`nvim --headless -u NONE -l`): no config, no plugins. The test
  prepends `home/dot_config/nvim` to `'runtimepath'`, sets `Config = {}`, and
  `dofile`s only the files it covers. Use for logic with a seam to stub.
- **Full config** (`nvim --headless -n -i NONE -c "lua dofile(...)"`): the real
  `~/.config/nvim` with every plugin. Wrap the body in `xpcall`, end with
  `cquit 1` on failure and `qa!` on success.

## Gotchas

- **Deferred setup.** Most plugins and LSP enablement load through
  `Config.later`. A full-config test or probe starts with
  `vim.wait(5000, function() return Config.later_pending == 0 end)`; a fixed
  sleep is not enough, and a language server still needs its own wait for
  `vim.lsp.get_clients({ bufnr = 0, method = ... })`.
- **Host environment.** The terminal running a test is often a Rex or Herdr
  pane, and `lua/config/host.lua` reads `REX_*`/`HERDR_*` from the
  environment. `test.sh` unsets them; a test that needs a host sets it
  itself (see `test-host.lua`, `smoke.sh`).
- **Temp paths.** macOS `TMPDIR` is under `/var`, a symlink to `/private/var`.
  `test.sh` exports the resolved path; compare paths after
  `vim.uv.fs_realpath`.
- **Notifications.** In the full config `mini.notify` takes `vim.notify`, so
  messages never reach `:messages`. Capture `vim.notify` to assert on them.
- **LSP kind names.** `mini.icons` prefixes `vim.lsp.protocol.SymbolKind` and
  `CompletionItemKind` names with an icon; match with `('(%a+)$')`.
- **Plugin sources.** `vim.pack` installs to
  `~/.local/share/nvim/site/pack/core/opt/<name>`; Mason tools live in
  `~/.local/share/nvim/mason/{bin,packages}`.
