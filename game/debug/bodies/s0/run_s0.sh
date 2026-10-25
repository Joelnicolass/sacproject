#!/usr/bin/env bash
# 055s s0 (disposable probes, branch that never merges). Runs in order, every Godot through agent/harness/godot_run.sh (FIFO queue):
#   1 fixtures + placeholder (4 modes)   2 float32 roundtrip   4 AnimationTree vs RESET   5 cost of what the strip removes
#   3 export plugin on a small scratch project (base / strip / skip), then each pack is run and measured
# Usage: bash debug/bodies/s0/run_s0.sh [only]     only = placeholder | float32 | reset | cost | export (default: all)
# Environment: GODOT_BIN (see agent/harness/env.sh); S0_BASE_MS, S0_BASE_MB (baseline of the exported dedicated on main, for the
# estimate of question 5); S0_KEEP=1 keeps the scratch folders.
# Output: only the `S0 ...` lines and engine errors on screen; the full log of every step in agent/out/055s/s0/.
# Last line: `S0 SUMMARY steps=N failed=M` (exit code 1 if any step printed a FAIL/ERROR/TIMEOUT verdict or exited non-zero).
# Never touches export_presets.cfg: the export probe has its own project and preset in a scratch folder.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../../agent/harness/env.sh"
RUN="bash $ROOT/agent/harness/godot_run.sh"
S0DIR="$ROOT/debug/bodies/s0"
TMP="$S0DIR/tmp"
LOGDIR="$ROOT/agent/out/055s/s0"
EXP="$(mktemp -d "${TMPDIR:-/tmp}/s0_export_probe.XXXXXX")"
ONLY="${1:-all}"
mkdir -p "$LOGDIR"
STEPS=0
FAILED=0

cleanup() {
  if [ -z "${S0_KEEP:-}" ]; then
    [ -n "$TMP" ] && rm -rf "$TMP"
    [ -n "$EXP" ] && rm -rf "$EXP"
  fi
}
trap cleanup EXIT

# step <name> <godot args...>: runs it, keeps the whole log, shows the S0 lines and the engine errors.
step() {
  local name="$1"; shift
  local log="$LOGDIR/$name.log"
  STEPS=$((STEPS+1))
  echo "S0 --- step $name"
  $RUN "$GODOT_BIN" "$@" >"$log" 2>&1
  local code=$?
  grep -E "^S0 |ERROR|SCRIPT ERROR|Parse Error|Failed to" "$log"
  if [ $code -ne 0 ] || grep -qE "^S0 VERDICT .*(FAIL|ERROR|TIMEOUT)" "$log"; then
    FAILED=$((FAILED+1))
    echo "S0 step $name exit=$code NOT OK (log: $log)"
  fi
}

want() { [ "$ONLY" = all ] || [ "$ONLY" = "$1" ]; }

rm -rf "$TMP"

if want placeholder; then
  step fixtures --headless --path "$ROOT" --script res://debug/bodies/s0/s0_fixtures.gd
  for mode in placeholder plain editstate spawner; do
    step "placeholder_$mode" --headless --path "$ROOT" --script res://debug/bodies/s0/s0_placeholder.gd -- "$mode"
  done
fi
if want float32; then
  step float32 --headless --path "$ROOT" --script res://debug/bodies/s0/s0_float32.gd
fi
if want reset; then
  step reset_tree --headless --path "$ROOT" --script res://debug/bodies/s0/s0_reset_tree.gd
fi
if want cost; then
  step strip_cost --headless --path "$ROOT" --script res://debug/bodies/s0/s0_strip_cost.gd
fi

if want export; then
  python3 "$S0DIR/exp_src/make_exp_proj.py" "$EXP" "$S0DIR/exp_src" || { echo "S0 VERDICT export ERROR cannot write the scratch project"; FAILED=$((FAILED+1)); }
  step export_assets --headless --path "$EXP" --script res://make_assets.gd
  step export_import --headless --path "$EXP" --import
  for mode in base strip skip; do
    S0_MODE="$mode" step "export_$mode" --headless --path "$EXP" --export-pack s0 "$EXP/out_$mode.pck"
    mkdir -p "$EXP/run_$mode"
    pushd "$EXP/run_$mode" >/dev/null
    step "pack_$mode" --headless --main-pack "$EXP/out_$mode.pck"
    popd >/dev/null
  done
  size() { wc -c < "$1" 2>/dev/null | tr -d ' '; }
  SB=$(size "$EXP/out_base.pck"); SS=$(size "$EXP/out_strip.pck"); SK=$(size "$EXP/out_skip.pck")
  echo "S0 3 pack sizes bytes: base=$SB strip=$SS skip=$SK"
  XB="$LOGDIR/export_base.log"; XS="$LOGDIR/export_strip.log"
  grep -q "S0 export plugin enter_tree" "$XS" && echo "S0 3 the editor plugin runs in a headless --export-pack: yes" || echo "S0 3 the editor plugin runs in a headless --export-pack: NO"
  A=$(grep -c "customize_resource class=AudioStream" "$XB"); N=$(grep -c "customize_resource class=Animation" "$XB")
  echo "S0 3 _customize_resource saw (base run): audio streams=$A animations=$N"
  grep -E "customize_resource class=(AudioStream|Animation)" "$XB" | sort -u | head -8
  grep -E "export_file path=" "$XB" | sort -u | head -8
  RA=$(grep -c "REPLACED res://audio" "$XS"); RN=$(grep -c "REPLACED res://clips" "$XS")
  echo "S0 3 _customize_resource replaced (strip run): audio=$RA animations=$RN"
  echo "S0 3 pack contents read back: base -> $(grep '^S0 pack audio files' "$LOGDIR/pack_base.log")"
  echo "S0 3 pack contents read back: strip -> $(grep '^S0 pack audio files' "$LOGDIR/pack_strip.log")"
  echo "S0 3 pack contents read back: skip -> $(grep '^S0 pack ' "$LOGDIR/pack_skip.log" | tr '\n' ';')"
  OK=1
  [ "$A" -ge 1 ] && [ "$N" -ge 1 ] || OK=0
  [ "$RA" -ge 1 ] && [ "$RN" -ge 1 ] || OK=0
  [ -n "$SB" ] && [ -n "$SS" ] && [ "$SS" -lt "$SB" ] || OK=0
  grep -q "empty=4" "$LOGDIR/pack_strip.log" && grep -q "tracks=0" "$LOGDIR/pack_strip.log" || OK=0
  if [ $OK -eq 1 ]; then
    echo "S0 VERDICT export PASS _customize_resource sees the imported audio and the Animations in a headless export and the empty ones land in the pack (base $SB -> strip $SS bytes)"
  else
    echo "S0 VERDICT export FAIL _customize_resource does not do the whole job (see lines above; skip mode shows the _export_file alternative: skip=$SK bytes). Plan B of risk 9"
    FAILED=$((FAILED+1))
  fi
fi

echo "S0 SUMMARY steps=$STEPS failed=$FAILED (full logs in $LOGDIR)"
[ $FAILED -eq 0 ]
