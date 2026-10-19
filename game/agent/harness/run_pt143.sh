#!/usr/bin/env bash
# F143 playtest runner (copy of run_pt139.sh). Call it through agent/harness/godot_run.sh (one Godot at a time).
#   run_pt143.sh FLOW[@res://rules.tres] ...   windowed flows one after another (60 fps cap, 1280x720, --fail-on-error)
# Flows named pt143dev_* run with --user-settings=user://pt143_settings.cfg (their own file; the player's is never
# touched), deleted before pt143dev_a. Other flows run sandboxed (AgentKit: defaults, nothing written).
# PT_EXTRA="--no-friendly-fire" adds user args to every flow. RSS watchdog 2.5 GB on every Godot. Out: agent/out/pt143/.
set -u
. "$(dirname "$0")/../harness/env.sh"
export GODOT="$ROOT/agent/harness/godot60_res.sh"
export PT_RES=1280x720
OUT="$ROOT/agent/out/pt143"; mkdir -p "$OUT"; cd "$ROOT"
if [ "${1:-}" = "--net" ]; then
  PORT="$2"; FLAGS="$3"
  "$GODOT_BIN" --headless --max-fps 60 --path "$ROOT" -- --dedicated --mp-port="$PORT" $FLAGS > "$OUT/net_server.log" 2>&1 &
  SV=$!
  for _ in $(seq 1 160); do grep -q "listo puerto" "$OUT/net_server.log" && break; sleep 0.25; done
  "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/pt143dev_net.json" --out=res://agent/out/pt143 --fail-on-error --mp-port="$PORT" > "$OUT/pt143dev_net.log" 2>&1 &
  P=$!
  ( while kill -0 "$P" 2>/dev/null; do
      for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
        r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && [ "$r" -gt 2500000 ] && { echo "RSS $r kill $g" >> "$OUT/pt143dev_net.log"; kill -9 $g; }
      done; sleep 2; done ) &
  wait "$P"; echo "client exit $?"
  sleep 1; kill "$SV" 2>/dev/null; wait "$SV" 2>/dev/null; echo "server stopped"
  exit 0
fi
PT_CFG="$HOME/Library/Application Support/Godot/app_userdata/Sacrifice/pt143_settings.cfg"
for spec in "$@"; do
  f="${spec%%@*}"; extra=()
  [ "$spec" != "$f" ] && extra=(--rules="${spec#*@}")
  [ "$f" = pt143dev_a ] && rm -f "$PT_CFG"
  case "$f" in pt143dev_*) extra+=(--user-settings=user://pt143_settings.cfg) ;; esac
  "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$f.json" --out=res://agent/out/pt143 --fail-on-error ${extra[@]+"${extra[@]}"} ${PT_EXTRA:-} > "$OUT/$f.log" 2>&1 &
  P=$!
  ( while kill -0 "$P" 2>/dev/null; do
      for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
        r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) $g rss=$r" >> "$OUT/$f.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill $g" >> "$OUT/$f.log"; kill -9 $g; }
      done; sleep 2; done ) &
  wait "$P"; echo "$f exit $?"
done
# Net mode (F143 criterion 4/5): run_pt143.sh --net PORT "SERVER FLAGS" -- a headless dedicated (--max-fps 60) with those
# flags, then the client flow pt143dev_net; the server stops when the client ends.
