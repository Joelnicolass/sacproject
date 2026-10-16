#!/usr/bin/env bash
# F143 playtester runner. Call it through agent/harness/godot_run.sh (one Godot at a time).
#   run_pt143p.sh FLOW[+] ...      windowed flows one after another (60 fps cap, 1280x720, --fail-on-error).
#                                  FLOW+ runs with --user-settings=user://pt143p_settings.cfg; plain FLOW is sandboxed.
#   run_pt143p.sh --net PORT "SERVER FLAGS" C1 C2 DELAY
#                                  headless dedicated (--max-fps 60) + client flow C1, then C2 DELAY s later; server
#                                  stops when both clients end.
# RSS watchdog 2.5 GB on every Godot. Out: agent/out/pt143/.
set -u
ROOT=/Users/joelsartori/Development/sacproject/game
export GODOT="$ROOT/agent/harness/godot60_res.sh"
export PT_RES=1280x720
OUT="$ROOT/agent/out/pt143"; mkdir -p "$OUT"; cd "$ROOT"
watch_rss() { # $1 pid to follow, $2 log
  ( while kill -0 "$1" 2>/dev/null; do
      for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
        r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) $g rss=$r" >> "$2.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill $g" >> "$2"; kill -9 $g; }
      done; sleep 2; done ) &
}
if [ "${1:-}" = "--net" ]; then
  PORT="$2"; FLAGS="$3"; C1="$4"; C2="$5"; DELAY="$6"
  /Applications/Godot.app/Contents/MacOS/Godot --headless --max-fps 60 --path "$ROOT" -- --dedicated --mp-port="$PORT" $FLAGS > "$OUT/net_server.log" 2>&1 &
  SV=$!
  for _ in $(seq 1 160); do grep -q "listo puerto" "$OUT/net_server.log" && break; sleep 0.25; done
  "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$C1.json" --out=res://agent/out/pt143 --fail-on-error --mp-port="$PORT" > "$OUT/$C1.log" 2>&1 &
  P1=$!; watch_rss "$P1" "$OUT/$C1.log"
  sleep "$DELAY"
  "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$C2.json" --out=res://agent/out/pt143 --fail-on-error --mp-port="$PORT" > "$OUT/$C2.log" 2>&1 &
  P2=$!; watch_rss "$P2" "$OUT/$C2.log"
  wait "$P1"; echo "$C1 exit $?"
  wait "$P2"; echo "$C2 exit $?"
  sleep 1; kill "$SV" 2>/dev/null; wait "$SV" 2>/dev/null; echo "server stopped"
  exit 0
fi
for spec in "$@"; do
  f="${spec%+}"; extra=()
  [ "$spec" != "$f" ] && extra=(--user-settings=user://pt143p_settings.cfg)
  "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$f.json" --out=res://agent/out/pt143 --fail-on-error ${extra[@]+"${extra[@]}"} > "$OUT/$f.log" 2>&1 &
  P=$!; watch_rss "$P" "$OUT/$f.log"
  wait "$P"; echo "$f exit $?"
done
