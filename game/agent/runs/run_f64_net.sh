#!/usr/bin/env bash
. "$(dirname "$0")/../harness/env.sh"
# usage: run_f64_net.sh PORT -- dedicated + client A (casts Teleport) + client B (watches), on debug/spells/teleport_home.tscn (RFC-021c).
set -u
GODOT="$GODOT_BIN"
export GODOT
PORT="$1"
OUT="$ROOT/agent/out/f64net"
WORLD=res://debug/spells/teleport_home.tscn
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world=$WORLD > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/server.log" && break; sleep 0.25; done
launch() { # flow log
  addons/agent_kit/cli.sh "$ROOT" flow --flow="$1" --out=res://agent/out/f64net --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/$2.log" 2>&1 &
  LP=$!
}
launch f64_client_a.json a; A=$LP; sleep 5
launch f64_client_b.json b; B=$LP
echo "a $A b $B server $SERVER"
wait $B; echo "b exit $?"
wait $A; echo "a exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
