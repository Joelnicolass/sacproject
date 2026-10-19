#!/usr/bin/env bash
# usage: run_pt60.sh PORT  -- dedicated + client A (slot 1, casts Desecrate) + client B (slot 2, watches, Rock on the doctor)
set -u
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT
ROOT=/Users/joelsartori/Development/sacproject/game
PORT="$1"
OUT="$ROOT/agent/out/ptperf/net"
WORLD=res://debug/sacrifice/desecrate_ritual.tscn
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world=$WORLD > "$OUT/full_server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/full_server.log" && break; sleep 0.25; done
launch() { # flow log
  addons/agent_kit/cli.sh "$ROOT" flow --flow="$1" --out=res://agent/out/ptperf/net --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/$2.log" 2>&1 &
  LP=$!
}
launch pt60_full_a.json full_a; A=$LP; sleep 6
launch pt60_full_b.json full_b; B=$LP
echo "a $A b $B server $SERVER"
wait $B; echo "b exit $?"
wait $A; echo "a exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
