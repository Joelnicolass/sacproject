#!/usr/bin/env bash
# usage: run_pt80_net.sh PORT  -- dedicated + one client on debug/selection_many.tscn (RFC-025, F78).
# The client selects 150 creatures and orders a move; the server log must show "orden move 150"
# and "150 de 150 con orden".
set -u
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT=/Users/joelsartori/Development/sacproject/game/agent/harness/godot60.sh
ROOT=/Users/joelsartori/Development/sacproject/game
PORT="${1:-7777}"
OUT="$ROOT/agent/out/pt80"
WORLD=res://debug/selection_many.tscn
mkdir -p "$OUT"
cd "$ROOT"
/Applications/Godot.app/Contents/MacOS/Godot --max-fps 60 --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world="$WORLD" > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicado listo" "$OUT/server.log" && break; sleep 0.25; done
addons/agent_kit/cli.sh "$ROOT" flow --flow=pt80_net_client.json --out=res://agent/out/pt80 --mp-port="$PORT" --world="$WORLD" --fail-on-error > "$OUT/client.log" 2>&1 &
CLIENT=$!
echo "client $CLIENT server $SERVER"
wait $CLIENT; echo "client exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
grep -ciE "set_custom_mouse|SCRIPT ERROR|^ERROR: [^0-9]" "$OUT/server.log"; grep -E "CursorSkin|orden move|con orden|servidor:" "$OUT/server.log" | tail -8
