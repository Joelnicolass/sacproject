#!/usr/bin/env bash
# usage: run_pt76.sh FLOW [extra --key=value...] -- waits until no other Godot runs (godot_busy.sh, 3 checks),
# then one windowed Godot at 60 fps with --fail-on-error; log in agent/out/pt76/FLOW.log; RSS watchdog 2.5 GB.
. "$(dirname "$0")/../harness/env.sh"
export GODOT="$ROOT/agent/harness/godot60.sh"
FLOW="$1"; shift
OUT="$ROOT/agent/out/pt76"
mkdir -p "$OUT"
cd "$ROOT"
until agent/harness/godot_busy.sh >/dev/null; do sleep 10; done
addons/agent_kit/cli.sh "$ROOT" flow --flow="$FLOW.json" --out=res://agent/out/pt76 --fail-on-error "$@" > "$OUT/$FLOW.log" 2>&1 &
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
grep -h "AGENT_OK\|AGENT_FAIL\|AGENT_STEP_ERROR\|AGENT_ERRORS\|SCRIPT ERROR\|unmapped" "$OUT/$FLOW.log" | cut -c1-400
