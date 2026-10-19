#!/usr/bin/env bash
# RFC-052 052a (F360): the audio cases in every gate mode, headless, each one through the Godot queue (a few seconds each):
#   open    --audio-probe on an isolated settings file (user://t_audio.cfg): gate, AudioPrefs and SoundBus cases;
#   closed  plain headless, --dedicated and --room-server (both with --no-flow: the flow would host or load a world): nothing built nor loaded;
#   lab     the audio lab (debug/audio/f360_audio_lab.tscn) with each lab_<cut>.tres, with the original's sets and without them
#           (--audio-no-original: SoundLibrary sees only the fixtures and an empty root);
#   052i    the bake of your own sounds (bake_sound_sets, new_creature) on two fixture files, then lab_052i.
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

lab() { # RFC-052 052c+: the audio lab with a lab_<cut>.tres, then the user args after --
  local name="$1" script="$2"; shift 2
  bash "$RUN" "$GODOT_BIN" --headless --path "$ROOT" res://debug/audio/f360_audio_lab.tscn --fixed-fps 600 --quit-after 30000 -- \
    --audio-probe --audio-script="$script" "$@" > "$OUT/$name.log" 2>&1
  local code=$?
  local line; line=$(grep -E "^AUDIO_LAB DONE" "$OUT/$name.log" | tail -1)
  echo "$name: ${line:-sin resultado} (exit $code)"
  grep -E "^AUDIO_LAB FAIL|SCRIPT ERROR|ERROR:|WARNING:" "$OUT/$name.log" | head -20
  [ "$code" = 0 ] && [ "$line" = "AUDIO_LAB DONE PASS" ] || FAIL=1
}
lab lab_052c res://debug/audio/lab_052c.tres
lab lab_052c_no_original res://debug/audio/lab_052c.tres --audio-no-original
lab lab_052d res://debug/audio/lab_052d.tres
lab lab_052d_no_original res://debug/audio/lab_052d.tres --audio-no-original
lab lab_052e res://debug/audio/lab_052e.tres
lab lab_052e_no_original res://debug/audio/lab_052e.tres --audio-no-original
lab lab_052f res://debug/audio/lab_052f.tres
lab lab_052f_no_original res://debug/audio/lab_052f.tres --audio-no-original
lab lab_052g res://debug/audio/lab_052g.tres
lab lab_052g_no_original res://debug/audio/lab_052g.tres --audio-no-original
lab lab_052h res://debug/audio/lab_052h.tres
lab lab_052h_no_original res://debug/audio/lab_052h.tres --audio-no-original

# RFC-052 052i (F368): your own sounds, with nothing of the original. Two fixture .wav files
# (debug/audio/fixtures/custom_sounds/creatures/testmonster/death_1.wav, swing_1.wav) -> bake_sound_sets (as «Hornear sonidos»,
# --only=custom, --force into user://bake_052i/) -> the lab plays them (lab_052i.tres looks in user://bake_052i/ first, then in the
# committed bake debug/audio/fixtures/custom_baked/). new_creature bakes the same folder for testmonster (into user://, nothing
# of the repo changes: the creature's files exist and are kept).
tool() { # name, expected line (grep -E), then the args after --path
  local name="$1" expect="$2"; shift 2
  bash "$RUN" "$GODOT_BIN" --headless --path "$ROOT" "$@" > "$OUT/$name.log" 2>&1
  local code=$?
  local line; line=$(grep -E "$expect" "$OUT/$name.log" | tail -1)
  echo "$name: ${line:-sin resultado} (exit $code)"
  grep -E "SCRIPT ERROR|ERROR:" "$OUT/$name.log" | head -20
  [ "$code" = 0 ] && [ -n "$line" ] || FAIL=1
}
tool bake_052i "^bake_sound_sets: wrote user://bake_052i/creatures/testmonster.tres$" \
  --script res://tools/bake/bake_sound_sets.gd -- --only=custom --force \
  --custom=res://debug/audio/fixtures/custom_sounds/ --out-custom=user://bake_052i/
tool new_creature_052i "^NEW_CREATURE sounds (wrote|kept[^:]*): user://new_creature_052i/creatures/testmonster.tres$" \
  --script res://tools/bake/new_creature.gd -- testmonster --no-icon \
  --sounds=res://debug/audio/fixtures/custom_sounds/ --sounds-out=user://new_creature_052i/
lab lab_052i res://debug/audio/lab_052i.tres
lab lab_052i_no_original res://debug/audio/lab_052i.tres --audio-no-original
echo "logs: $OUT"
if [ "$FAIL" = 0 ]; then echo "AUDIO RUN PASS"; else echo "AUDIO RUN FAIL"; fi
exit $FAIL
