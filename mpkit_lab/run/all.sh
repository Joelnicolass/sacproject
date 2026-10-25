#!/usr/bin/env bash
# Every MpKit lab check in a row (mpkit_lab/CASES.md lists them): the kit's own tests, solo, the session cases, and
# the relay's host rules, arena, rooms and private over ENet, WebSocket and the relay (rooms also over wss://), the
# relay's faults, a browser client over WebSocket and over the relay (Web export templates + a headless Chrome /
# Chromium; without a browser those two say SKIP; BROWSER=none skips them), instances, the wizard, and MpWorld + the
# wizard in the real editor (headless).
#   all.sh            the whole matrix (before a release candidate; about an hour with a shared queue)
#   all.sh --quick    one of each over ENet: tests, solo, relay rules, arena (dedicated + lag), rooms (public),
#                     private, wizard 2D (a few minutes, for every change)
# Prints one line per check with its time, and MPKIT ALL PASS / MPKIT ALL FAIL: n (exit 0 / 1).
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
QUICK=0
for a in "$@"; do [ "$a" = --quick ] && QUICK=1; done
FAILS=0
STARTED=$SECONDS
step() { # step <name> <command…>
  local name="$1"; shift
  local verdict t0=$SECONDS
  verdict="$("$@" 2>&1 | grep -E '^(MPKIT|PROBE)' | tail -n 1)"
  echo "$name: ${verdict:-no verdict} ($((SECONDS - t0)) s)"
  case "$verdict" in *PASS*|*SKIP*) ;; *) FAILS=$((FAILS + 1)) ;; esac
}
run_godot --headless --path "$LAB" --import > /dev/null 2>&1
step tests run_godot --headless --path "$LAB" --script res://addons/mp_kit/tests/mp_test_runner.gd
step solo run_godot --headless --path "$LAB" -- --probe=solo
step relay bash "$HERE/relay.sh"
if [ "$QUICK" = 1 ]; then
  step "arena enet" env SCENARIOS="dedicated lag" bash "$HERE/arena.sh"
  step "rooms enet" env SCENARIOS=public bash "$HERE/rooms.sh"
  step "private enet" bash "$HERE/private.sh"
  step "wizard 2d" bash "$HERE/wizard.sh"
else
  step session bash "$HERE/session.sh"
  for t in enet ws relay; do
    step "arena $t" env TRANSPORT=$t bash "$HERE/arena.sh"
    step "rooms $t" env TRANSPORT=$t bash "$HERE/rooms.sh"
    step "private $t" env TRANSPORT=$t bash "$HERE/private.sh"
  done
  step "rooms wss" env TLS=1 SCENARIOS=public bash "$HERE/rooms.sh"
  step "relay faults" bash "$HERE/relayfault.sh"
  ## The web client opens in a headless Chrome / Chromium; without one it says SKIP (a person can run web.sh by hand).
  if [ "${BROWSER:-}" != none ]; then
    step "web ws" env PROBE_LIMIT_S=500 WEB_NEED_BROWSER=1 bash "$HERE/web.sh"
    step "web relay" env PROBE_LIMIT_S=500 WEB_NEED_BROWSER=1 TRANSPORT=relay bash "$HERE/web.sh"
  fi
  step instances bash "$HERE/instances.sh"
  step "wizard 2d" bash "$HERE/wizard.sh"
  step "wizard 3d" env WIZARD_3D=1 bash "$HERE/wizard.sh"
  step editor bash "$HERE/editor.sh"
fi
echo "total: $((SECONDS - STARTED)) s"
if [ "$FAILS" = 0 ]; then echo "MPKIT ALL PASS"; exit 0; fi
echo "MPKIT ALL FAIL: $FAILS"
exit 1
