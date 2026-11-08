# Palette and format contracts

## Palettes

Neovim runs Solarized Osaka; the terminal, multiplexer, Zed and git/delta stay
on One Dark. Changing a theme = walking this checklist, not archaeology:

| Tool | Value | Source |
| ---- | ----- | ------ |
| nvim | `solarized-osaka.nvim`, style `vivid`, transparent background (`<Leader>ob` toggles it); diff, CodeDiff and Octo review colours overridden in `on_highlights` | `home/dot_config/nvim/plugin/40_plugins.lua` |
| Ghostty | `Atom One Dark`, italics in Medium Italic | `home/dot_config/ghostty/config` |
| Herdr | `one-dark` | `home/dot_config/herdr/config.toml` |
| Zed | `One Dark` + Ioskeley Mono | `home/dot_config/zed/settings.json` |
| git/delta/lazygit | `TwoDark`, `tabs=4`, hyperlink formats | `home/dot_gitconfig.tmpl`, `home/dot_config/lazygit/config.yml` |

Because nvim is transparent, Ghostty's One Dark background shows behind
Solarized Osaka text. Moving Ghostty to a Solarized Osaka port is the next
step if the mix looks off.

## Format chain: who formats what

| Scope | Formatter | Owner |
| ----- | --------- | ----- |
| lua/js/ts/json/jsonc/toml in nvim | `oxfmt` via conform.nvim (LSP fallback) | `home/dot_config/nvim/plugin/40_plugins.lua`; triggered by `10_options.lua` BufWritePre, guarded by `Config.conform_ready` |
| diagnostics in nvim | `oxlint --lsp` as language server | `plugin/40_plugins.lua` `vim.lsp.enable` |
| per-language in Zed | Zed formatter map (`tsc` vs `typescript-ls` choice differs from nvim's `tsc`) | `home/dot_config/zed/settings.json` |

Known divergence: Zed and nvim chose different TypeScript servers. Unify only
with evidence it matters; until then this table is the contract.
