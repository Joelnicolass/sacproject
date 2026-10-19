#!/usr/bin/env bash
. "$(dirname "$0")/../harness/env.sh"
# usage: run_pt63.sh PORT  -- dedicated + client A + client B on structure_siege, then late-join B2
set -u
GODOT="$GODOT_BIN"
export GODOT
PORT="$1"
OUT="$ROOT/agent/out/pt63"
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world=res://debug/map/structure_siege.tscn > "$OUT/server.log" 2>&1 &
SERVER=$!
echo "$SERVER" > "$OUT/server.pid"
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/server.log" && break; sleep 0.25; done
launch() { # flow log
  addons/agent_kit/cli.sh "$ROOT" flow --flow="$1" --out=res://agent/out/pt63 --fail-on-error --mp-port="$PORT" --world=res://debug/map/structure_siege.tscn > "$OUT/$2.log" 2>&1 &
  LP=$!
}
for TRY in 1 2 3; do launch pt63_client_a.json a; A=$LP; sleep 6; grep -q "click missed" "$OUT/a.log" || break; done
for TRY in 1 2 3; do launch pt63_client_b.json b; B=$LP; sleep 3; grep -q "click missed" "$OUT/b.log" || break; done
echo "a $A b $B server $SERVER"
wait $B; echo "b exit $?"
wait $A; echo "a exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
