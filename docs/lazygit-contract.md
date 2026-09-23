# LazyGit return contract

Four doors into the same tool. Each door owns its lifecycle; the shared
contract is: **opening LazyGit must return you to your editor state**
(open file under cursor, restore cwd).

| Door | Opener | Return mechanism |
| ---- | ------ | ---------------- |
| nvim float | `<Leader>gg` via `lazygit.nvim` (`plugin/42_lazygit.lua`) | RPC socket in `/tmp` + generated `lazygit-nvim-remote.yml` overlay; `$NVIM`/`$LG_CONFIG_FILE` juggling; `nvim --remote-send :drop` |
| shell | `lg()` in `zsh/.zshrc` | chdir-on-exit via `$TMPDIR/lazygit-chdir` |
| Herdr popup | `prefix+alt+g` | popup sizing in `herdr/.config/herdr/config.toml` |
| Zed task | `space g g` | Zed task reveal; `lazygit/.config/lazygit/zed.yml` |

The tool itself (`lazygit/.config/lazygit/config.yml`: pi commit/PR custom
commands, branch-type prompts, delta renderers) is shared by all four doors.
Change the contract (what "return" means) once, here; change a door's
mechanics in its own file. Do not unify the doors — each context's access is
the value.
