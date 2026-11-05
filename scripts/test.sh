#!/bin/sh
# Run the regression suite: every scripts/test-*.lua, test-lazygit-create-pr.py,
# then smoke.sh. Exits non-zero if anything fails.
#
#   sh scripts/test.sh                  # everything (~10 s)
#   sh scripts/test.sh host theme       # only test-host.lua and test-theme.lua
#
# A test's mode comes from its `-- Run:` header: `-u NONE -l` runs it isolated,
# anything else runs it inside the full config. test-rex-worktrees.sh needs a
# live Rex server and is left out. See scripts/README.md.
set -u
cd "$(dirname "$0")/.."

# Tests start outside any host; each sets the host it exercises itself. The
# shell running this is often an agent's Rex or Herdr pane, which must not leak.
unset REX_SERVER REX_SESSION REX_BLOCK REX_BIN_DIR \
  HERDR_ENV HERDR_PANE_ID HERDR_WORKSPACE_ID HERDR_BIN_PATH
# macOS TMPDIR lives under /var, a symlink to /private/var; tests compare
# resolved paths, so hand them the resolved one.
TMPDIR=$(cd "${TMPDIR:-/tmp}" && pwd -P)
export TMPDIR

limit() { if command -v timeout >/dev/null; then timeout 120 "$@"; else "$@"; fi; }

failed=0
run() { # name, command...
  name=$1
  shift
  if out=$(limit "$@" 2>&1); then
    echo "ok    $name"
  else
    echo "FAIL  $name"
    echo "$out" | tail -n 20 | sed 's/^/      /'
    failed=1
  fi
}

selected() { # name
  [ -z "$filter" ] && return 0
  for want in $filter; do [ "$1" = "test-$want" ] || [ "$1" = "$want" ] && return 0; done
  return 1
}
filter="$*"

for file in scripts/test-*.lua; do
  name=$(basename "$file" .lua)
  selected "$name" || continue
  if head -n 3 "$file" | grep -q -- '-u NONE -l'; then
    run "$name" nvim --headless -u NONE -l "$file"
  else
    # Passing tests quit themselves; reaching `cquit` means the file threw
    # (headless Neovim would otherwise sit there until the timeout).
    run "$name" nvim --headless -n -i NONE -c "lua dofile('$file')" -c 'cquit 1'
  fi
done

if selected test-lazygit-create-pr; then
  run test-lazygit-create-pr python3 scripts/test-lazygit-create-pr.py
fi
if selected smoke; then
  run smoke sh scripts/smoke.sh
fi

exit $failed
