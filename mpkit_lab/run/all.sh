#!/usr/bin/env bash
# Every MpKit lab check in a row: the kit's own tests, solo, and each e2e over ENet and WebSocket (rooms also over
# wss://). The web check needs a person (or an agent) to open the page it prints, so it is not here: run web.sh.
# Prints one line per check and MPKIT ALL PASS / MPKIT ALL FAIL: n (exit 0 / 1).
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
FAILS=0
step() { # step <name> <command…>
  local name="$1"; shift
  local verdict
  verdict="$("$@" 2>&1 | grep -E '^(MPKIT|PROBE)' | tail -n 1)"
  echo "$name: ${verdict:-no verdict}"
  case "$verdict" in *PASS*) ;; *) FAILS=$((FAILS + 1)) ;; esac
}
run_godot --headless --path "$LAB" --import > /dev/null 2>&1
step tests run_godot --headless --path "$LAB" --script res://addons/mp_kit/tests/mp_test_runner.gd
step solo run_godot --headless --path "$LAB" -- --probe=solo
for t in enet ws; do
  step "arena $t" env TRANSPORT=$t bash "$HERE/arena.sh"
  step "rooms $t" env TRANSPORT=$t bash "$HERE/rooms.sh"
  step "private $t" env TRANSPORT=$t bash "$HERE/private.sh"
done
step "rooms wss" env TLS=1 bash "$HERE/rooms.sh"
step instances bash "$HERE/instances.sh"
step "wizard 2d" bash "$HERE/wizard.sh"
step "wizard 3d" env WIZARD_3D=1 bash "$HERE/wizard.sh"
if [ "$FAILS" = 0 ]; then echo "MPKIT ALL PASS"; exit 0; fi
echo "MPKIT ALL FAIL: $FAILS"
exit 1
