#!/usr/bin/env bash
# MpKit setup wizard e2e: the wizard writes a fresh game into mpkit_lab/generated (WIZARD_3D=1 for 3D), the lab
# imports it, and that untouched game is played over the network: a dedicated server and a client that moves and scores;
# then its online rooms: the same boot scene as a room server (everything from game.tres), two players create and
# join a room from the menu's Online rooms, the match runs, Mp.leave() goes back to the lobby and its Back to the boot.
# Prints PASS / FAIL lines and MPKIT WIZARD PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 4 "$@"
TAG="MPKIT WIZARD"
LIMIT_S="${PROBE_LIMIT_S:-180}"
PROC_MAX=5
LOBBY_PORT="${E2E_LOBBY_PORT:-7725}"
PORT="${E2E_PORT:-7795}"
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

mkdir -p "$OUT/matches"
gd "$OUT/rooms.log" res://generated/boot.tscn -- --room-server --lobby-port="$LOBBY_PORT" --match-port-min=7740 \
  --match-port-max=7749 --countdown-s=0.3 --matches-root="$OUT/matches" --heartbeat-s=0.5 --poll-s=0.1 --idle-no-players-s=20
ROOMS=$LAST_PID
wait_line "$OUT/rooms.log" "^rooms ready port" "$ROOMS" 30
gd "$OUT/Ana.log" res://generated/boot.tscn -- --probe=lobby --probe-lobby="127.0.0.1:$LOBBY_PORT" --probe-timeout-s=30 \
  --probe-name=Ana --probe-create=Room --probe-leave-to-boot
ANA=$LAST_PID
wait_line "$OUT/Ana.log" "^PASS took a seat" "$ANA" 30
gd "$OUT/Bea.log" res://generated/boot.tscn -- --probe=lobby --probe-lobby="127.0.0.1:$LOBBY_PORT" --probe-timeout-s=30 \
  --probe-name=Bea --probe-leave-to-boot
BEA=$LAST_PID
for p in $ANA $BEA; do wait "$p"; done
kill_tree "$ROOMS"
for r in Ana Bea; do grep -E "^(FAIL|SCRIPT ERROR)" "$OUT/$r.log" | sed "s/^/$r: /"; done
check 'grep -q "^PROBE lobby PASS" "$OUT/Ana.log" && grep -q "^PROBE lobby PASS" "$OUT/Bea.log"' "the generated game's online rooms: menu, lobby, match, leave, back to the boot"
check 'grep -q "^match for room" "$OUT/rooms.log"' "the generated room server launched the match"
check '! grep -q "^SCRIPT ERROR" "$OUT"/*.log' "no script errors"
net_stop
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
