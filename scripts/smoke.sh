#!/bin/sh
# Smoke: full nvim config + deferred Config.later() queue loads clean,
# no duplicate/overwritten keymaps, in every host: plain, Herdr, Rex, and Herdr
# nested in Rex. The host comes from the environment, so each run sets it
# explicitly instead of inheriting the terminal the script happens to run in.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"

for host in plain herdr rex herdr-in-rex; do
  case $host in
    plain)        herdr_env=0 rex_block= ;;
    herdr)        herdr_env=1 rex_block= ;;
    rex)          herdr_env=0 rex_block=block:smoke ;;
    herdr-in-rex) herdr_env=1 rex_block=block:smoke ;;
  esac
  out=$(HERDR_ENV="$herdr_env" REX_BLOCK="$rex_block" nvim --headless \
    --cmd "cd /tmp" \
    --cmd "lua dofile('$REPO/scripts/smoke-keymaps.lua')" \
    -c "lua SmokeVerify()" \
    -c "qa" 2>&1)
  echo "[$host] $out"

  if echo "$out" | grep -qE "E[0-9]{3,4}|Error|DUPLICATE|FAIL|Traceback"; then
    echo "SMOKE FAIL ($host)"
    exit 1
  fi
done

echo "SMOKE OK"
