#!/usr/bin/env bash
# usage: run_pt61b_net.sh PORT  -- dedicado (dos asientos para arrancar, puerta RFC-068) + A (lanza Convert) + B (se sienta al arrancar,
# sale por la pausa cuando camina el doctor de A y vuelve a su asiento durante el acarreo; agent/scripts/mkflow_pt61b.py)

. "$(dirname "$0")/../harness/env.sh"; PORT="$1"; GODOT="$GODOT_BIN"; export GODOT
OUT="$ROOT/agent/out/pt61b/net2"; WORLD=res://debug/sacrifice/convert_ritual.tscn
mkdir -p "$OUT"; cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --start-seats=2 --mp-port="$PORT" --world=$WORLD > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/server.log" && break; sleep 0.25; done
addons/agent_kit/cli.sh "$ROOT" flow --flow=rfc020e_convert_a.json --out=res://agent/out/pt61b/net2 --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/a.log" 2>&1 &
A=$!
sleep 6
addons/agent_kit/cli.sh "$ROOT" flow --flow=pt61b_b.json --out=res://agent/out/pt61b/net2 --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/b.log" 2>&1 &
B=$!
wait $B; echo "b exit $?"; wait $A; echo "a exit $?"
sleep 1; kill $SERVER 2>/dev/null; wait $SERVER 2>/dev/null; echo "server stopped"
