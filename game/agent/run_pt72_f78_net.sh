#!/usr/bin/env bash
# usage: run_f78_net.sh PORT  -- dedicated + one client on debug/selection_many.tscn (RFC-025, F78).
# The client selects 150 creatures and orders a move; the server log must show "orden move 150"
# and "150 de 150 con orden".
set -u
GODOT=/Users/joelsartori/Development/sacproject/game/agent/harness/godot60.sh
export GODOT
ROOT=/Users/joelsartori/Development/sacproject/game
PORT="${1:-7777}"
OUT="$ROOT/agent/out/pt72/f78_net"
WORLD=res://debug/selection_many.tscn
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world="$WORLD" > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicado listo" "$OUT/server.log" && break; sleep 0.25; done
addons/agent_kit/cli.sh "$ROOT" flow --flow=f78_online_a.json --out=res://agent/out/pt72/f78_net --mp-port="$PORT" --world="$WORLD" > "$OUT/client.log" 2>&1 &
CLIENT=$!
echo "client $CLIENT server $SERVER"
wait $CLIENT; echo "client exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
grep -E "orden move|con orden|servidor:" "$OUT/server.log" | tail -8
