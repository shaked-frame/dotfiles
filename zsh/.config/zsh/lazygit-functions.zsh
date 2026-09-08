#!/usr/bin/env zsh
# Functions shared between an interactive shell and lazygit.
#
# lazygit sources this file (os.shellFunctionsFile in ~/.config/lazygit/config.yml)
# before running any shell command: the `:` prompt, custom commands, and editor
# open commands. It is deliberately NOT ~/.zshrc - that would re-run zinit,
# carapace and the rest of init on every `:` command.
#
# zsh caveat: aliases do not expand in lazygit's non-interactive shell. Only
# functions work here. That is why the git shortcuts in ~/.zshrc stay as aliases
# (lazygit already does status/diff/push natively, so they buy nothing) and only
# the things worth reaching for from inside lazygit live in this file.
#
# Sourced from ~/.zshrc so both contexts get the same definitions.

# Bootstrap dependencies in a worktree. Creating and opening the worktree itself
# is herdr's job (`prefix+shift+g` to create, `prefix+shift+o` to open, or
# `herdr worktree create --branch <name>`), which also registers it as a
# workspace and honours `worktrees.directory` from ~/.config/herdr/config.toml.
#
# Useful from lazygit as `:worktree-setup` right after switching worktrees.
function worktree-setup() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print "Error: not inside a git worktree" >&2
    return 1
  fi

  pnpm i && pnpm setup:frontend
}

# Link .zed settings from main frame clone into a worktree (personal)
function link-worktree-zed() {
  local source_dir="$HOME/frame/.zed"
  local target_dir="$PWD/.zed"
  local source_settings="$source_dir/settings.json"
  local target_settings="$target_dir/settings.json"

  if [[ ! -f "$source_settings" ]]; then
    print "Error: $source_settings does not exist" >&2
    return 1
  fi

  mkdir -p "$target_dir"

  if [[ -e "$target_settings" && ! -L "$target_settings" ]]; then
    print "Error: $target_settings already exists and is not a symlink" >&2
    return 1
  fi

  ln -sfn "$source_settings" "$target_settings"
  print "Linked $target_settings -> $source_settings"
}

# Function form of the `pn` alias, so `:pn install` works at lazygit's prompt
# (aliases do not expand in lazygit's non-interactive shell; functions do).
#
# Verified safe despite `alias pn='pnpm'` in ~/.zshrc: zsh does NOT alias-expand
# the word after the `function` keyword, so this defines `pn`, not a recursive
# `pnpm`. Checked with:
#   zsh -f -c 'alias pn=pnpm; function pn() { : }; whence -w pnpm'  -> "command"
# Interactively the alias shadows this function; both resolve to pnpm.
function pn() {
  pnpm "$@"
}

# Find processes that are leaking zombie children.
#
# This is the usual cause of "fork failed: resource temporarily unavailable".
# macOS enforces kern.maxprocperuid across the whole UID, so one leaky parent
# eventually stops *every* process you own from forking - shell plugins,
# editors, agents - long after the real culprit stopped being obvious.
#
# Read-only. To fix, kill the parent PID it reports: the zombies get reparented
# to launchd and reaped immediately, reclaiming the slots.
function zombie-processes() {
  local total limit zcount count ppid cmd
  total=$(ps -u "$(id -u)" -o pid= | wc -l | tr -d ' ')
  limit=$(sysctl -n kern.maxprocperuid 2>/dev/null || print -r -- '?')
  zcount=$(ps -ax -o stat= | awk '$1 ~ /Z/' | wc -l | tr -d ' ')

  print -r -- "processes: ${total}/${limit}    zombies: ${zcount}"

  if (( zcount == 0 )); then
    print -r -- "no zombies"
    return 0
  fi

  print -r --
  printf '%6s  %-8s  %s\n' COUNT PPID PARENT
  # NOTE: `cmd` is declared above, not inside the loop. In zsh, `local cmd` on a
  # parameter that already exists in scope *prints* it, which leaked a stray
  # `cmd='...'` line on every iteration after the first.
  ps -ax -o stat=,ppid= \
    | awk '$1 ~ /Z/ { c[$2]++ } END { for (p in c) printf "%d %s\n", c[p], p }' \
    | sort -rn \
    | while read -r count ppid; do
        cmd=$(ps -p "$ppid" -o command= 2>/dev/null)
        [[ -n "$cmd" ]] || cmd='<already exited>'
        printf '%6s  %-8s  %s\n' "$count" "$ppid" "${cmd:0:110}"
      done

  print -r --
  print -r -- "to reclaim: kill -TERM <PPID>   (zombies are reaped on reparent)"
}
