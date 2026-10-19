#!/usr/bin/env bash
# RFC-037 037c (risk R2): a dedicated + one headless client on agent/fixtures/f037c/stealth_net.tscn. The server puts the foe in
# stealth; the client flow f037c_stealth_net.json must see it first visible, then hidden (is_targetable false) with the 3D fade.
# Call: bash agent/harness/godot_run.sh bash agent/fixtures/f037c/run_stealth_net.sh [PORT]   (a dedicated + a client = 2 headless Godots)
set -u
. "$(dirname "$0")/../../harness/env.sh"
PORT="${1:-7791}"
OUT="$ROOT/agent/out/f037c"; mkdir -p "$OUT"
G="$GODOT_BIN"
WORLD=res://agent/fixtures/f037c/stealth_net.tscn
cd "$ROOT"
"$G" --headless --max-fps 60 --path "$ROOT" -- --dedicated --mp-port="$PORT" --world="$WORLD" > "$OUT/stealth.server.log" 2>&1 &
SERVER=$!
for _ in $(seq 1 80); do grep -q "dedicado listo" "$OUT/stealth.server.log" && break; sleep 0.25; done
GODOT="$G" addons/agent_kit/cli.sh "$ROOT" flow --flow=f037c_stealth_net.json --out=res://agent/out/f037c --fail-on-error --mp-port="$PORT" --world="$WORLD" > "$OUT/stealth.client.log" 2>&1 &
CLIENT=$!
( while kill -0 $CLIENT 2>/dev/null; do
    for p in $SERVER $CLIENT; do
      r=$(ps -o rss= -p $p 2>/dev/null | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill" >> "$OUT/stealth.client.log"; kill -9 $p; }
    done; sleep 2; done ) &
WATCH=$!
wait $CLIENT; CODE=$?
kill $WATCH 2>/dev/null
sleep 1; kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null
grep -E "STEALTH_NET" "$OUT/stealth.server.log" | head -3
grep -E "AGENT_(FAIL|ERROR|PRINT)|assert" "$OUT/stealth.client.log" | tail -8
if [ "$CODE" = 0 ] && grep -q "STEALTH_NET server set stealth" "$OUT/stealth.server.log"; then echo "STEALTH_NET PASS"; exit 0; fi
echo "STEALTH_NET FAIL (client exit $CODE)"; exit 1
