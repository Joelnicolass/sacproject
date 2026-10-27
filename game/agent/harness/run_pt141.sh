#!/usr/bin/env bash
# F141 playtest runner. Call it through agent/harness/godot_run.sh (one Godot run at a time).
#   run_pt141.sh flows FLOW...  windowed flows one after another (60 fps, 1280x720, --fail-on-error)
#   run_pt141.sh net PORT       headless dedicated (--max-fps 60 --start-seats=2) + clients A (pt141_net_a) and B (pt141_net_b),
#                               both seated before the start (RFC-068 gate: nobody joins a started match). B leaves by the
#                               pause menu once A's menu is open and comes back to its seat (the old late join, now a rejoin
#                               within rejoin_grace_s). RSS watchdog 2.5 GB. Out: agent/out/pt141/.
set -u
. "$(dirname "$0")/../harness/env.sh"
BIN="$GODOT_BIN"
export GODOT="$ROOT/agent/harness/godot60_res.sh"
export PT_RES=1280x720
OUT="$ROOT/agent/out/pt141"; mkdir -p "$OUT"; cd "$ROOT"

watch_rss() {
  local tag="$1"; shift
  ( while :; do alive=0; for p in "$@"; do kill -0 "$p" 2>/dev/null && alive=1; done; [ $alive = 1 ] || break
      for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
        r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) $g rss=$r" >> "$OUT/$tag.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill $g" >> "$OUT/$tag.log"; kill -9 $g; }
      done; sleep 2; done ) &
}

flow() {
  local f="$1"; shift
  "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$f.json" --out=res://agent/out/pt141 --fail-on-error "$@" > "$OUT/$f.log" 2>&1 &
  LAST=$!
}

mode="$1"; shift
if [ "$mode" = flows ]; then
  for f in "$@"; do
    flow "$f"; P=$LAST; watch_rss "$f" "$P"; wait "$P"; echo "$f exit $?"
  done
elif [ "$mode" = net ]; then
  PORT="$1"
  $BIN --headless --max-fps 60 --path "$ROOT" -- --dedicated --start-seats=2 --mp-port="$PORT" > "$OUT/net_server.log" 2>&1 &
  S=$!
  for _ in $(seq 1 160); do grep -q "listo puerto" "$OUT/net_server.log" && break; sleep 0.25; done
  flow pt141_net_a --mp-port="$PORT"; A=$LAST
  sleep 1
  flow pt141_net_b --mp-port="$PORT"; B=$LAST
  watch_rss net "$S" "$A" "$B"
  wait "$A"; echo "a exit $? at $(date +%s)"
  wait "$B"; echo "b exit $? at $(date +%s)"
  echo "A: $(grep -m1 'pt141p paused' "$OUT/pt141_net_a.log")"
  sleep 1; kill "$S" 2>/dev/null; wait "$S" 2>/dev/null; echo "server stopped"
fi
