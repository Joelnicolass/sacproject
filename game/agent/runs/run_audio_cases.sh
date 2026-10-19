#!/usr/bin/env bash
# RFC-052 052a (F360): the audio cases in every gate mode, headless, each one through the Godot queue (a few seconds each):
#   open    --audio-probe on an isolated settings file (user://t_audio.cfg): gate, AudioPrefs and SoundBus cases;
#   closed  plain headless, --dedicated and --room-server (both with --no-flow: the flow would host or load a world): nothing built nor loaded.
# Each run has the scene watchdog (20 s real time) and --quit-after 30000 frames as a second stop.
# Usage: bash agent/runs/run_audio_cases.sh [GODOT_BIN]
# Prints each mode's AUDIO CASES line, the AudioStreamRandomizer finding and AUDIO RUN PASS / FAIL (exit 0 / 1).
set -u
. "$(dirname "$0")/../harness/env.sh"
GODOT_BIN="${1:-$GODOT_BIN}"
RUN="$ROOT/agent/harness/godot_run.sh"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/audio_cases.XXXXXX")"
FAIL=0

mode() { # name, then the user args after --
  local name="$1"; shift
  bash "$RUN" "$GODOT_BIN" --headless --path "$ROOT" res://debug/audio/audio_cases.tscn --fixed-fps 600 --quit-after 30000 -- "$@" \
    > "$OUT/$name.log" 2>&1
  local code=$?
  local line; line=$(grep -E "^AUDIO CASES (PASS|FAIL)" "$OUT/$name.log" | tail -1)
  echo "$name: ${line:-sin resultado} (exit $code)"
  grep -E "^AUDIO_RNG_FINDING" "$OUT/$name.log"
  grep -E ": FAIL$|^  \{|SCRIPT ERROR|ERROR:" "$OUT/$name.log" | head -20
  [ "$code" = 0 ] && [ -n "$line" ] && [ "${line#AUDIO CASES PASS}" != "$line" ] || FAIL=1
}

mode open --audio-probe --user-settings=user://t_audio.cfg --expect-gate=open
mode headless --expect-gate=closed
mode dedicated --dedicated --no-flow --mp-port=7895 --expect-gate=closed
mode room_server --room-server --no-flow --expect-gate=closed
echo "logs: $OUT"
if [ "$FAIL" = 0 ]; then echo "AUDIO RUN PASS"; else echo "AUDIO RUN FAIL"; fi
exit $FAIL
