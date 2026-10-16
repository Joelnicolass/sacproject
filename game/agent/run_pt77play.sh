#!/usr/bin/env bash
# usage: [STRICT=] run_pt77play.sh FLOW (STRICT= empty drops --fail-on-error) [extra --key=value...] -- one windowed Godot at 60 fps; log in agent/out/pt77play/FLOW.log; RSS watchdog 2.5 GB.
ROOT=/Users/joelsartori/Development/sacproject/game
export GODOT="$ROOT/agent/harness/godot60.sh"
FLOW="$1"; shift
OUT="$ROOT/agent/out/pt77play"
mkdir -p "$OUT"
cd "$ROOT"
addons/agent_kit/cli.sh "$ROOT" flow --flow="$FLOW.json" --out=res://agent/out/pt77play ${STRICT---fail-on-error} "$@" > "$OUT/$FLOW.log" 2>&1 &
RUN=$!
PEAK=0
while kill -0 $RUN 2>/dev/null; do
  for P in $(pgrep -f "Godot.*agent=flow"); do
    R=$(ps -o rss= -p $P 2>/dev/null | tr -d ' ')
    [[ -n "$R" && "$R" -gt "$PEAK" ]] && PEAK=$R
    if [[ -n "$R" && "$R" -gt 2600000 ]]; then echo "RSS $R kB > 2.5 GB, killing $P"; kill $P; fi
  done
  sleep 2
done
wait $RUN; CODE=$?
echo "$FLOW exit $CODE peak_rss_kB $PEAK"
grep -h "AGENT_CALL\|AGENT_FAIL\|SCRIPT ERROR\|ia slot" "$OUT/$FLOW.log" | cut -c1-400
