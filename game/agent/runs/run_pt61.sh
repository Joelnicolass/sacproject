#!/usr/bin/env bash
# usage: run_pt61.sh PORT  -- dedicated + client A (slot 1) en debug/sacrifice/convert_ritual.tscn: Convert completo en red
set -u
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT
ROOT=/Users/joelsartori/Development/sacproject/game
PORT="$1"
OUT="$ROOT/agent/out/pt61"
WORLD=res://debug/sacrifice/convert_ritual.tscn
mkdir -p "$OUT"
cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world=$WORLD > "$OUT/net_server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/net_server.log" && break; sleep 0.25; done
addons/agent_kit/cli.sh "$ROOT" flow --flow=rfc020e_convert_a.json --out=res://agent/out/pt61 --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/net_a.log" 2>&1
echo "a exit $?"
sleep 1
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null
echo "server stopped"
