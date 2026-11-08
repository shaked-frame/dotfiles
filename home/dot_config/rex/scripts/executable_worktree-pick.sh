#!/bin/sh
# Pick a worktree of the current repo and open its worktree session
# (nvim | claude). Run by the `worktree_picker` action in a floating layer.
# Listing, session lookup and opening live in the `worktrees` and
# `worktree_open` actions in init.lua; this script only shows and chooses.
#
#   ● branch  [label]   a worktree session is open (its label, if renamed)
#   ○ branch            not open yet; choosing it creates the session
#
# Typing a branch name that matches nothing creates the worktree with
# worktrunk (`wt switch --create`), so its hooks run here, in a terminal.
set -eu

pause() { printf '\n%s\n[press enter]' "$1"; read -r _; exit 1; }

list=$(rex do worktrees cwd="$PWD" --json) || pause "Not inside a Git repository: $PWD"

out=$(printf '%s' "$list" | jq -r '.worktrees[] |
    (.branch // (.path | split("/") | last)) as $name |
    [ (if .session_id then "●" else "○" end) + " "
        + (if .detached then "(detached) " else "" end) + $name
        + (if .label and .label != $name then "  [" + .label + "]" else "" end),
      .path ] | @tsv' |
  fzf --print-query --delimiter '\t' --with-nth 1 --prompt 'worktree> ' \
      --header 'enter: open  ·  new name: create with wt' --reverse) || true

query=$(printf '%s\n' "$out" | sed -n 1p)
path=$(printf '%s\n' "$out" | sed -n 2p | cut -f2)

if [ -z "$path" ] && [ -n "$query" ]; then
  wt switch --create "$query" --no-cd || pause "wt switch --create failed"
  path=$(rex do worktrees cwd="$PWD" --json | jq -r --arg b "$query" '.worktrees[] | select(.branch == $b) | .path')
  [ -n "$path" ] || pause "Created $query but could not find its worktree"
fi
[ -n "$path" ] || exit 0

rex do worktree_open path="$path" >/dev/null || pause "rex do worktree_open failed"
