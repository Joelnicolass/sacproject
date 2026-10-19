#!/usr/bin/env bash
# usage: run_pt61b_net.sh PORT  -- dedicado + A (lanza Convert) + B (se une tarde, durante el acarreo)

. "$(dirname "$0")/../harness/env.sh"; PORT="$1"; GODOT="$GODOT_BIN"; export GODOT
OUT="$ROOT/agent/out/pt61b/net2"; WORLD=res://debug/sacrifice/convert_ritual.tscn
mkdir -p "$OUT"; cd "$ROOT"
"$GODOT" --headless --path "$ROOT" -- --dedicated --mp-port="$PORT" --world=$WORLD > "$OUT/server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicated listo" "$OUT/server.log" && break; sleep 0.25; done
addons/agent_kit/cli.sh "$ROOT" flow --flow=rfc020e_convert_a.json --out=res://agent/out/pt61b/net2 --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/a.log" 2>&1 &
A=$!
# espera a que A haya lanzado Convert y el doctor esté acarreando (~ tras "o03_acarreo")
for _ in $(seq 1 400); do [ -f "$OUT/o01_camina.png" ] && break; sleep 0.5; done
sleep 1
addons/agent_kit/cli.sh "$ROOT" flow --flow=pt61b_b.json --out=res://agent/out/pt61b/net2 --fail-on-error --mp-port="$PORT" --world=$WORLD > "$OUT/b.log" 2>&1 &
B=$!
wait $B; echo "b exit $?"; wait $A; echo "a exit $?"
sleep 1; kill $SERVER 2>/dev/null; wait $SERVER 2>/dev/null; echo "server stopped"
