# LazyGit return contract

Four doors into the same tool. Each door owns its lifecycle; the shared
contract is: **opening LazyGit must return you to your editor state**
(open file under cursor, restore cwd).

| Door | Opener | Return mechanism |
| ---- | ------ | ---------------- |
| nvim float | `<Leader>gg` (`<Leader>gG` file log) via `Snacks.lazygit` (`plugin/42_lazygit.lua`) | Neovim's own `$NVIM` server + generated `lazygit-nvim-remote.yml` overlay via `$LG_CONFIG_FILE`; its edit script calls `Config.lazygit_edit()` over `--remote-expr` (hide float, `:drop` in the editor window). Snacks theming off so the shared theme wins |
| shell | `lg()` in `home/dot_zshrc` | chdir-on-exit via `$TMPDIR/lazygit-chdir` |
| Herdr popup | `prefix+alt+g` | popup sizing in `home/dot_config/herdr/config.toml` |
| Zed task | `space g g` | Zed task reveal; `home/dot_config/lazygit/zed.yml` |

The tool itself (`home/dot_config/lazygit/config.yml`: Claude commit/PR custom
commands, branch-type prompts, delta renderers) is shared by all four doors.
Change the contract (what "return" means) once, here; change a door's
mechanics in its own file. Do not unify the doors — each context's access is
the value.
