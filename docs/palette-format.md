# Palette and format contracts

## Palette: One Dark everywhere

Six configs name the same palette differently. Changing theme = walking this
checklist, not archaeology:

| Tool | Value | Source |
| ---- | ----- | ------ |
| nvim | `onedark.nvim` style `dark` + comment-brightening + JSX-blue highlights | `plugin/40_plugins.lua` |
| nvim italics | `ColorScheme` autocmd merging `italic` into Comment/Statement/Type | `plugin/30_mini.lua` |
| Ghostty | `Atom One Dark`, italics in Medium Italic | `ghostty/.config/ghostty/config` |
| Herdr | `one-dark` | `herdr/.config/herdr/config.toml` |
| Zed | `One Dark` + Ioskeley Mono | `zed/.config/zed/settings.json` |
| git/delta/lazygit | `TwoDark`, `tabs=4`, hyperlink formats | `git/.gitconfig`, `lazygit/.config/lazygit/config.yml` |

## Format chain: who formats what

| Scope | Formatter | Owner |
| ----- | --------- | ----- |
| lua/js/ts/json/jsonc/toml in nvim | `oxfmt` via conform.nvim (LSP fallback) | `plugin/40_plugins.lua`; triggered by `10_options.lua` BufWritePre, guarded by `Config.conform_ready` |
| diagnostics in nvim | `oxlint --lsp` as language server | `plugin/40_plugins.lua` `vim.lsp.enable` |
| per-language in Zed | Zed formatter map (`tsc` vs `typescript-ls` choice differs from nvim's `tsc`) | `zed/.config/zed/settings.json` |

Known divergence: Zed and nvim chose different TypeScript servers. Unify only
with evidence it matters; until then this table is the contract.
