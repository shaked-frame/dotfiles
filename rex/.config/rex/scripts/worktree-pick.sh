#!/bin/sh
# Pick a Git worktree of the current repo and open it as a Rex session
# (nvim | claude). Run by the `worktree_picker` action in a floating layer.
#
#   ● branch   a Rex session with that label is already open
#   ○ branch   not open yet; choosing it creates the session
#
# Typing a branch name that matches nothing creates the worktree with
# worktrunk (`wt switch --create`), so its hooks run as usual.
set -eu

pause() { printf '\n%s\n[press enter]' "$1"; read -r _; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 || pause "Not inside a Git repository: $(pwd)"

# branch<TAB>path, one per worktree.
worktrees() {
  git worktree list --porcelain | awk '
    /^worktree / { path = substr($0, 10) }
    /^branch /   { b = substr($0, 8); sub("^refs/heads/", "", b); print b "\t" path }
    /^detached/  { print "(detached)\t" path }'
}

open_sessions=$(rex ls --json | jq -r '.sessions[].label')

out=$(worktrees | awk -F '\t' -v open="$open_sessions" '
  BEGIN { n = split(open, a, "\n"); for (i = 1; i <= n; i++) o[a[i]] = 1 }
  { printf "%s %s\t%s\n", (($1 in o) ? "●" : "○"), $1, $2 }' |
  fzf --print-query --delimiter '\t' --with-nth 1 --prompt 'worktree> ' \
      --header 'enter: open  ·  new name: create with wt' --reverse) || true

query=$(printf '%s\n' "$out" | sed -n 1p)
choice=$(printf '%s\n' "$out" | sed -n 2p)

if [ -n "$choice" ]; then
  branch=$(printf '%s' "$choice" | cut -f1 | sed 's/^[^ ]* //')   # strip "● " / "○ "
  path=$(printf '%s' "$choice" | cut -f2)
elif [ -n "$query" ]; then
  wt switch --create "$query" --no-cd || pause "wt switch --create failed"
  branch=$query
  path=$(worktrees | awk -F '\t' -v b="$branch" '$1 == b { print $2 }')
  [ -n "$path" ] || pause "Created $branch but could not find its worktree"
else
  exit 0
fi

rex do worktree_open path="$path" branch="$branch" >/dev/null || pause "rex do worktree_open failed"
