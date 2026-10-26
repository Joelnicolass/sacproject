#!/usr/bin/env bash
. "$(dirname "$0")/../harness/env.sh"
# usage: run_pt59b.sh PORT  -- dedicated + client A (slot 1, casts Desecrate) + client B (slot 2, watches, Rock on the doctor)
set -u
GODOT="$GODOT_BIN"
export GODOT
PORT="$1"
OUT="$ROOT/agent/out/pt59b"
WORLD=res://debug/sacrifice/desecrate_carry.tscn
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --start-seats=2 --mp-port="$PORT" --world=$WORLD > "$OUT/net7_server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/net7_server.log" && break; sleep 0.25; done
launch() { # flow log
  addons/agent_kit/cli.sh "$ROOT" flow --flow="$1" --out=res://agent/out/pt59b --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/$2.log" 2>&1 &
  LP=$!
}
launch pt59b_net_a4.json net7_a; A=$LP; sleep 6
launch pt59b_net_b4.json net7_b; B=$LP
echo "a $A b $B server $SERVER"
wait $B; echo "b exit $?"
wait $A; echo "a exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
