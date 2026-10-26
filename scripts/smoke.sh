#!/bin/sh
# Smoke: full nvim config + deferred Config.later() queue loads clean,
# no duplicate/overwritten keymaps, and both HERDR_ENV adapter modes pass.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"

for herdr_env in 0 1; do
  out=$(HERDR_ENV="$herdr_env" nvim --headless \
    --cmd "cd /tmp" \
    --cmd "lua dofile('$REPO/scripts/smoke-keymaps.lua')" \
    -c "lua SmokeVerify()" \
    -c "qa" 2>&1)
  echo "[HERDR_ENV=$herdr_env] $out"

  if echo "$out" | grep -qE "E[0-9]{3,4}|Error|DUPLICATE|FAIL|Traceback"; then
    echo "SMOKE FAIL (HERDR_ENV=$herdr_env)"
    exit 1
  fi
done

echo "SMOKE OK"
