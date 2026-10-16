#!/usr/bin/env bash
# usage: run_pt75w.sh FLOW [extra --key=value...] -- one windowed Godot at 60 fps; log in agent/out/pt75w/FLOW.log
# A watchdog kills the run if RSS passes 2.5 GB.
ROOT=/Users/joelsartori/Development/sacproject/game
export GODOT="$ROOT/agent/harness/godot60.sh"
FLOW="$1"; shift
OUT="$ROOT/agent/out/pt75w"
mkdir -p "$OUT"
cd "$ROOT"
addons/agent_kit/cli.sh "$ROOT" flow --flow="$FLOW.json" --out=res://agent/out/pt75w --fail-on-error "$@" > "$OUT/$FLOW.log" 2>&1 &
RUN=$!
PEAK=0
while kill -0 $RUN 2>/dev/null; do
  for P in $(pgrep -f "Godot.*agent=flow" ); do
    R=$(ps -o rss= -p $P 2>/dev/null | tr -d ' ')
    [[ -n "$R" && "$R" -gt "$PEAK" ]] && PEAK=$R
    if [[ -n "$R" && "$R" -gt 2600000 ]]; then echo "RSS $R kB > 2.5 GB, killing $P"; kill $P; fi
  done
  sleep 2
done
wait $RUN; CODE=$?
echo "$FLOW exit $CODE peak_rss_kB $PEAK"
