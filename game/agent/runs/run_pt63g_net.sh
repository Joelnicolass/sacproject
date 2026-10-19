#!/usr/bin/env bash
# usage: run_f63_net.sh PORT -- dedicated + client A (casts Manalith then Guardian) + client B (watches) + late client C,
# all on debug/spells/guardian_manalith.tscn (RFC-021b).
set -u
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT
ROOT=/Users/joelsartori/Development/sacproject/game
PORT="$1"
OUT="$ROOT/agent/out/pt63g/net"
WORLD=res://debug/spells/guardian_manalith.tscn
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world=$WORLD > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/server.log" && break; sleep 0.25; done
launch() { # flow log
  addons/agent_kit/cli.sh "$ROOT" flow --flow="$1" --out=res://agent/out/pt63g/net --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/$2.log" 2>&1 &
  LP=$!
}
launch f63_client_a.json a; A=$LP; sleep 5
launch f63_client_b.json b; B=$LP
# B leaves once it has seen the beam; the late client takes its slot while the bond is already standing
wait $B; echo "b exit $?"
sleep 2
launch f63_client_late.json c; C=$LP
echo "a $A b $B c $C server $SERVER"
wait $C; echo "c exit $?"
wait $A; echo "a exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
