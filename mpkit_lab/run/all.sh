#!/usr/bin/env bash
# Every MpKit lab check in a row (mpkit_lab/CASES.md lists them): the kit's own tests, solo, the session cases, and
# the relay's host rules, arena, rooms and private over ENet, WebSocket and the relay (rooms also over wss://), a
# browser client over WebSocket and over the relay (Web export templates + a headless Chrome / Chromium; without a
# browser those two say SKIP; BROWSER=none skips them), instances and the wizard.
# Prints one line per check and MPKIT ALL PASS / MPKIT ALL FAIL: n (exit 0 / 1).
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
FAILS=0
step() { # step <name> <command…>
  local name="$1"; shift
  local verdict
  verdict="$("$@" 2>&1 | grep -E '^(MPKIT|PROBE)' | tail -n 1)"
  echo "$name: ${verdict:-no verdict}"
  case "$verdict" in *PASS*|*SKIP*) ;; *) FAILS=$((FAILS + 1)) ;; esac
}
run_godot --headless --path "$LAB" --import > /dev/null 2>&1
step tests run_godot --headless --path "$LAB" --script res://addons/mp_kit/tests/mp_test_runner.gd
step solo run_godot --headless --path "$LAB" -- --probe=solo
step session bash "$HERE/session.sh"
step relay bash "$HERE/relay.sh"
for t in enet ws relay; do
  step "arena $t" env TRANSPORT=$t bash "$HERE/arena.sh"
  step "rooms $t" env TRANSPORT=$t bash "$HERE/rooms.sh"
  step "private $t" env TRANSPORT=$t bash "$HERE/private.sh"
done
step "rooms wss" env TLS=1 SCENARIOS=public bash "$HERE/rooms.sh"
## The web client opens in a headless Chrome / Chromium; without one it says SKIP (a person can run web.sh by hand).
if [ "${BROWSER:-}" != none ]; then
  step "web ws" env PROBE_LIMIT_S=500 WEB_NEED_BROWSER=1 bash "$HERE/web.sh"
  step "web relay" env PROBE_LIMIT_S=500 WEB_NEED_BROWSER=1 TRANSPORT=relay bash "$HERE/web.sh"
fi
step instances bash "$HERE/instances.sh"
step "wizard 2d" bash "$HERE/wizard.sh"
step "wizard 3d" env WIZARD_3D=1 bash "$HERE/wizard.sh"
if [ "$FAILS" = 0 ]; then echo "MPKIT ALL PASS"; exit 0; fi
echo "MPKIT ALL FAIL: $FAILS"
exit 1
