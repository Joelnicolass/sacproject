#!/usr/bin/env bash
. "$(dirname "$0")/../harness/env.sh"
# usage: run_pt19c_net.sh PORT  -- dedicated (two seats to start, RFC-068 gate) + client A + client B on structure_siege; B leaves by
# the pause menu after the Manalith and comes back to its seat (pt19c_net_rejoin: nobody joins a started match from zero)
set -u
GODOT="$GODOT_BIN"
export GODOT
PORT="$1"
OUT="$ROOT/agent/out/pt19c/net"
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --start-seats=2 --mp-port="$PORT" --world=res://debug/map/structure_siege.tscn > "$OUT/server.log" 2>&1 &
SERVER=$!
echo "$SERVER" > "$OUT/server.pid"
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/server.log" && break; sleep 0.25; done
launch() { # flow log
  addons/agent_kit/cli.sh "$ROOT" flow --flow="$1" --out=res://agent/out/pt19c/net --fail-on-error --mp-port="$PORT" --world=res://debug/map/structure_siege.tscn > "$OUT/$2.log" 2>&1 &
  LP=$!
}
for TRY in 1 2 3; do launch pt19c_net_a.json a; A=$LP; sleep 6; grep -q "click missed" "$OUT/a.log" || break; done
for TRY in 1 2 3; do launch pt19c_net_rejoin.json b; B=$LP; sleep 3; grep -q "click missed" "$OUT/b.log" || break; done
echo "a $A b $B server $SERVER"
wait $B; echo "b (rejoin) exit $?"
wait $A; echo "a exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
