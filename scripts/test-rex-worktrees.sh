#!/bin/sh
# Run (inside Rex, with ~/.config/rex/init.lua loaded): sh scripts/test-rex-worktrees.sh
# Exercise the `worktrees` / `worktree_open` actions against real git and the
# running Rex server: a temp repo with a branch worktree and a detached one,
# sessions whose panes sit in them, and a session renamed the way agents do.
# Never switches the app (select=false). Cleans up its sessions and repo.
set -eu

tmp=$(cd "$(mktemp -d)" && pwd -P)
sessions=""
cleanup() {
  for s in $sessions; do rex kill "$s" >/dev/null 2>&1 || true; done
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() { echo "FAIL: $1"; exit 1; }
ok() { echo "$1: OK"; }
json() { rex do "$@" --json; }

repo=$tmp/repo
git init -q "$repo"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
feat_dir=$repo/.worktrees/feat  # nested inside the main checkout, like ~/frame/.worktrees
git -C "$repo" worktree add -q "$feat_dir" -b feat
git -C "$repo" worktree add -q --detach "$tmp/det"
git -C "$repo" worktree add -q "$tmp/tabbed" -b tabbed

# A session whose first pane sits in the feat worktree, then renamed.
feat_session=$(rex new rex-wt-test -c "$feat_dir" --json | jq -r '.session_id')
sessions="$feat_session"
rex session rename "$feat_session" renamed-by-agent >/dev/null

# A session that starts outside any worktree and opens `tabbed` in its second
# tab, the way worktrees end up in tabs of a session you already work in.
mixed_session=$(rex new rex-wt-mixed -c "$tmp" --json | jq -r '.session_id')
sessions="$sessions $mixed_session"
tabbed_window=$(rex window new -s "$mixed_session" Work -c "$tmp/tabbed" --focus=false --json | jq -r '.window_id')
sleep 1

list=$(json worktrees cwd="$repo")
[ "$(printf '%s' "$list" | jq '.worktrees | length')" = 4 ] || fail "expected 4 worktrees: $list"
[ "$(printf '%s' "$list" | jq -r '.worktrees[0].path')" = "$repo" ] || fail "main checkout not first: $list"
ok "worktrees lists main, branch and detached worktrees"

tabbed=$(printf '%s' "$list" | jq -c --arg p "$tmp/tabbed" '.worktrees[] | select(.path == $p)')
[ "$(printf '%s' "$tabbed" | jq -r '.session_id')" = "$mixed_session" ] && [ "$(printf '%s' "$tabbed" | jq -r '.window_id')" = "$tabbed_window" ] ||
  fail "worktree open in a second tab not found: $tabbed"
back=$(json worktree_open path="$tmp/tabbed" select=false)
[ "$(printf '%s' "$back" | jq -r '.created')" = false ] && [ "$(printf '%s' "$back" | jq -r '.window_id')" = "$tabbed_window" ] ||
  fail "worktree_open did not return to the open tab: $back"
ok "a worktree open in another session's second tab is returned to, not recreated"

feat=$(printf '%s' "$list" | jq -c --arg p "$feat_dir" '.worktrees[] | select(.path == $p)')
[ "$(printf '%s' "$feat" | jq -r '.session_id')" = "$feat_session" ] || fail "renamed session not found by directory: $feat"
[ "$(printf '%s' "$feat" | jq -r '.label')" = renamed-by-agent ] || fail "label not reported: $feat"
ok "a renamed session is still found by its panes' directory"

[ "$(printf '%s' "$list" | jq -r --arg p "$repo" '.worktrees[] | select(.path == $p) | .session_id // "none"')" = none ] ||
  fail "main checkout claimed a session it does not own: $list"
ok "longest path wins: the main checkout doesn't claim the worktree session"

det=$(printf '%s' "$list" | jq -c --arg p "$tmp/det" '.worktrees[] | select(.path == $p)')
[ "$(printf '%s' "$det" | jq -r '.detached')" = true ] && [ "$(printf '%s' "$det" | jq -r '.branch // "none"')" = none ] ||
  fail "detached worktree misreported: $det"
ok "detached worktree has no branch"

opened=$(json worktree_open path="$feat_dir/" select=false)
[ "$(printf '%s' "$opened" | jq -r '.session_id')" = "$feat_session" ] && [ "$(printf '%s' "$opened" | jq -r '.created')" = false ] ||
  fail "worktree_open made a duplicate of the renamed session: $opened"
ok "worktree_open reuses the renamed session (trailing slash ignored)"

created=$(json worktree_open path="$tmp/det" select=false)
det_session=$(printf '%s' "$created" | jq -r '.session_id')
sessions="$sessions $det_session"
[ "$(printf '%s' "$created" | jq -r '.created')" = true ] || fail "detached worktree session not created: $created"
[ "$(rex ls --json | jq -r --arg s "$det_session" '.sessions[] | select(.session_id == $s) | .label')" = det ] ||
  fail "detached worktree session not labelled with its folder name"
ok "worktree_open creates the detached worktree's session, labelled det"

sleep 1
again=$(json worktree_open path="$tmp/det" select=false)
[ "$(printf '%s' "$again" | jq -r '.session_id')" = "$det_session" ] && [ "$(printf '%s' "$again" | jq -r '.created')" = false ] ||
  fail "second worktree_open created another session: $again"
ok "worktree_open is idempotent"

if json worktree_open path="$feat_dir/sub" select=false >/dev/null 2>&1; then fail "accepted a path that is not a worktree root"; fi
ok "worktree_open rejects a path that is not a worktree root"

echo "REX WORKTREES OK"
