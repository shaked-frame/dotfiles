#!/bin/sh
# Smoke: full nvim config loads clean + no duplicate <Leader> mappings.
# See scripts/smoke-keymaps.lua and the cross-cutting note in the
# architecture review (docs/ has the per-area contracts this protects).
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"

out=$(nvim --headless --cmd "cd /tmp" \
  -c "lua dofile('$REPO/scripts/smoke-keymaps.lua')" -c "qa" 2>&1)
echo "$out"

if echo "$out" | grep -qE "E[0-9]{3,4}|Error|DUPLICATE|Traceback"; then
  echo "SMOKE FAIL"
  exit 1
fi
echo "SMOKE OK"
