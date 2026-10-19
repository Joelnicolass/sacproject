#!/usr/bin/env bash
# F135 playtest runner. Call it through agent/harness/godot_run.sh (one Godot run at a time).
#   run_pt135.sh flows FLOW...   windowed flows one after another (60 fps cap, 1280x720, --fail-on-error)
#   run_pt135.sh net PORT        headless dedicated (--max-fps 60 --level=9) + client A (pt135_net_a);
#                                client B (pt135_net_b) starts only once A's log shows Ikarus FLYING (late join).
# RSS watchdog 2.5 GB on every Godot. Out: agent/out/pt135/.
set -u
. "$(dirname "$0")/../harness/env.sh"
BIN="$GODOT_BIN"
export GODOT="$ROOT/agent/harness/godot60_res.sh"
export PT_RES=1280x720
OUT="$ROOT/agent/out/pt135"; mkdir -p "$OUT"; cd "$ROOT"

watch_rss() { # $1 = tag; runs while any pid in $2.. lives
  local tag="$1"; shift
  ( while :; do alive=0; for p in "$@"; do kill -0 "$p" 2>/dev/null && alive=1; done; [ $alive = 1 ] || break
      for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
        r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) $g rss=$r" >> "$OUT/$tag.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill $g" >> "$OUT/$tag.log"; kill -9 $g; }
      done; sleep 2; done ) &
}

flow() { # $1 flow  [extra cli args]
  local f="$1"; shift
  "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$f.json" --out=res://agent/out/pt135 --fail-on-error "$@" > "$OUT/$f.log" 2>&1 &
  LAST=$!
}

mode="$1"; shift
if [ "$mode" = flows ]; then
  for f in "$@"; do
    flow "$f"; P=$LAST; watch_rss "$f" "$P"; wait "$P"; echo "$f exit $?"
  done
elif [ "$mode" = net ]; then
  PORT="$1"
  $BIN --headless --max-fps 60 --path "$ROOT" -- --dedicated --mp-port="$PORT" --level=9 > "$OUT/net_server.log" 2>&1 &
  S=$!
  for _ in $(seq 1 160); do grep -q "listo puerto" "$OUT/net_server.log" && break; sleep 0.25; done
  flow pt135_net_a --mp-port="$PORT"; A=$LAST
  watch_rss net "$S" "$A"
  for _ in $(seq 1 240); do grep -q "Ikarus1 FLYING" "$OUT/pt135_net_a.log" && break; kill -0 "$A" 2>/dev/null || break; sleep 0.25; done
  echo "B launch at $(date +%s) after: $(grep -m1 'Ikarus1 FLYING' "$OUT/pt135_net_a.log")"
  flow pt135_net_b --mp-port="$PORT"; B=$LAST
  watch_rss net "$B"
  wait "$B"; echo "b exit $?"
  wait "$A"; echo "a exit $?"
  sleep 1; kill "$S" 2>/dev/null; wait "$S" 2>/dev/null; echo "server stopped"
fi
