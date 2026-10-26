#!/usr/bin/env bash
. "$(dirname "$0")/../harness/env.sh"
# usage: run_f63_net.sh PORT -- dedicated (two seats to start, RFC-068 gate) + client A (casts Manalith then Guardian) + client B
# (watches, leaves by the pause menu and comes back to its seat while the bond stands), all on debug/spells/guardian_manalith.tscn (RFC-021b).
set -u
GODOT="$GODOT_BIN"
export GODOT
PORT="$1"
OUT="$ROOT/agent/out/f63net"
WORLD=res://debug/spells/guardian_manalith.tscn
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --start-seats=2 --mp-port="$PORT" --world=$WORLD > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/server.log" && break; sleep 0.25; done
launch() { # flow log
  addons/agent_kit/cli.sh "$ROOT" flow --flow="$1" --out=res://agent/out/f63net --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/$2.log" 2>&1 &
  LP=$!
}
launch f63_client_a.json a; A=$LP; sleep 5
launch f63_client_rejoin.json b; B=$LP
# B leaves once it has seen the beam and comes back to its own seat (same process) while the bond is already standing
echo "a $A b $B server $SERVER"
wait $B; echo "b (rejoin) exit $?"
wait $A; echo "a exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
