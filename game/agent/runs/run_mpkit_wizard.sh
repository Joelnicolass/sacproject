#!/usr/bin/env bash
# MpKit setup wizard e2e: the wizard writes a fresh game into mpkit_lab/generated (WIZARD_3D=1 for 3D), the lab
# imports it, and that untouched game is played over the network: a dedicated server and a client that moves and scores.
# Prints PASS / FAIL lines and MPKIT WIZARD PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/../harness/net_e2e.sh"
net_group 2 "$@"
TAG="MPKIT WIZARD"
LIMIT_S="${PROBE_LIMIT_S:-180}"
PROC_MAX=3
PORT="${E2E_PORT:-7795}"
ROOT="$(cd "$ROOT/../mpkit_lab" && pwd)"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_wizard.XXXXXX")"
kill_all() { kill_pids; }
trap 'kill_all; net_stop' EXIT
net_guard
FLAGS=()
[ "${WIZARD_3D:-0}" = 1 ] && FLAGS=(--wizard-3d)
"$GODOT" --headless --path "$ROOT" --script res://probe/make_game.gd -- "${FLAGS[@]}" > "$OUT/make.log" 2>&1
"$GODOT" --headless --path "$ROOT" --import > "$OUT/import.log" 2>&1
grep -E "^\[|WIZARD" "$OUT/make.log"
gd "$OUT/server.log" res://generated/boot.tscn -- --server --mp-port="$PORT" --probe=watch --probe-min-move=0.5 --probe-linger-s=5
SERVER=$LAST_PID
sleep 0.5
gd "$OUT/client.log" res://generated/boot.tscn -- --client1 --mp-port="$PORT" --probe=basic --probe-linger-s=3
CLIENT=$LAST_PID
wait_line "$OUT/client.log" "^PROBE basic (PASS|FAIL)" "$CLIENT" 60
wait_line "$OUT/server.log" "^PROBE watch (PASS|FAIL)" "$SERVER" 10
for p in $CLIENT $SERVER; do kill_tree "$p"; done
for r in server client; do grep -E "^(PASS|FAIL|SCRIPT ERROR)" "$OUT/$r.log" | sed "s/^/$r: /"; done
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "^WIZARD OK" "$OUT/make.log"' "the wizard wrote the game"
check 'grep -q "^PROBE basic PASS" "$OUT/client.log"' "the generated game plays over the network (client)"
check 'grep -q "^PROBE watch PASS" "$OUT/server.log"' "the generated game's server saw the player move and score"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
