#!/usr/bin/env bash
# F118 playtest runner (copy of run_pt135.sh, flows mode). Call it through agent/harness/godot_run.sh.
#   run_pt118.sh flows FLOW...   windowed flows one after another (60 fps cap, 1280x720, --fail-on-error)
# RSS watchdog 2.5 GB on every Godot. Out: agent/out/pt118/.
set -u
ROOT=/Users/joelsartori/Development/sacproject/game
BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT="$ROOT/agent/harness/godot60_res.sh"
export PT_RES=1280x720
OUT="$ROOT/agent/out/pt118"; mkdir -p "$OUT"; cd "$ROOT"

watch_rss() { # $1 = tag; runs while any pid in $2.. lives
  local tag="$1"; shift
  ( while :; do alive=0; for p in "$@"; do kill -0 "$p" 2>/dev/null && alive=1; done; [ $alive = 1 ] || break
      for g in $(ps -axo pid=,comm= | awk '$2 ~ /(^|\/)Godot$/ {print $1}'); do
        r=$(ps -o rss= -p $g | tr -d ' '); [ -n "$r" ] && echo "$(date +%s) $g rss=$r" >> "$OUT/$tag.rss" && [ "$r" -gt 2500000 ] && { echo "RSS $r kill $g" >> "$OUT/$tag.log"; kill -9 $g; }
      done; sleep 2; done ) &
}

flow() { # $1 flow  [extra cli args]
  local f="$1"; shift
  "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow="$ROOT/agent/flows/$f.json" --out=res://agent/out/pt118 --fail-on-error "$@" > "$OUT/$f.log" 2>&1 &
  LAST=$!
}

mode="$1"; shift
if [ "$mode" = flows ]; then
  for f in "$@"; do
    flow "$f"; P=$LAST; watch_rss "$f" "$P"; wait "$P"; echo "$f exit $?"
  done
fi
