#!/usr/bin/env bash
. "$(dirname "$0")/../harness/env.sh"
# usage: run_pt57.sh PORT  -- dedicated (two seats to start, RFC-068 gate) + client A + client B on match_defeat. With LATE=1 (default)
# B leaves by the pause menu after its defeat and comes back to its seat within the grace (pt57_client_rejoin): nobody joins a
# started match from zero, only a dropped seat returns.
set -u
GODOT="$GODOT_BIN"
export GODOT
PORT="$1"
OUT="$ROOT/agent/out/pt57"
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --start-seats=2 --mp-port="$PORT" --world=res://debug/match/match_defeat.tscn > "$OUT/server.log" 2>&1 &
SERVER=$!
echo "$SERVER" > "$OUT/server.pid"
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/server.log" && break; sleep 0.25; done
launch() { # flow log
  addons/agent_kit/cli.sh "$ROOT" flow --flow="$1" --out=res://agent/out/pt57 --fail-on-error --mp-port="$PORT" --world=res://debug/match/match_defeat.tscn > "$OUT/$2.log" 2>&1 &
  LP=$!
}
B_FLOW=pt57_client_b.json
[ "${LATE:-1}" = "1" ] && B_FLOW=pt57_client_rejoin.json
for TRY in 1 2 3; do launch pt57_client_a.json a; A=$LP; sleep 6; grep -q "click missed" "$OUT/a.log" || break; done
for TRY in 1 2 3; do launch "$B_FLOW" b; B=$LP; sleep 6; grep -q "click missed" "$OUT/b.log" || break; done
echo "a $A b $B ($B_FLOW) server $SERVER"
wait $B; echo "b exit $?"
wait $A; echo "a exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
