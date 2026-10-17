#!/usr/bin/env bash
# F137 playtest runner. Call it through agent/harness/godot_run.sh (one Godot run at a time).
#   run_pt137.sh FLOW[:extra,args] ...   windowed flows one after another (60 fps cap, 1280x720, --fail-on-error).
# RSS watchdog 2.5 GB. Out: agent/out/pt137/.
set -u
ROOT=/Users/joelsartori/Development/sacproject/game
export GODOT="$ROOT/agent/harness/godot60_res.sh"
export PT_RES=1280x720
OUT="$ROOT/agent/out/pt137"; mkdir -p "$OUT"; cd "$ROOT"
for spec in "$@"; do
  f="${spec%%:*}"; extra=()
  [ "$spec" != "$f" ] && IFS=',' read -r -a extra <<< "${spec#*:}"
  "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$f.json" --out=res://agent/out/pt137 --fail-on-error "${extra[@]+"${extra[@]}"}" > "$OUT/$f.log" 2>&1 &
  P=$!
  ( while kill -0 "$P" 2>/dev/null; do
      for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
        r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) $g rss=$r" >> "$OUT/$f.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill $g" >> "$OUT/$f.log"; kill -9 $g; }
      done; sleep 2; done ) &
  wait "$P"; echo "$f exit $?"
done
