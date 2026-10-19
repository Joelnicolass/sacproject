#!/usr/bin/env bash
# RFC-053: the headless cases of one cut, each through the Godot queue (a few seconds each), seed 1, --fixed-fps 600 and the
# bench's wall-clock watchdog (--watchdog-s, 20 s by default).
#   053a (F370)  debug/units/f370_targets.tscn with f370_guard_reacts, f370_indestructible and f370_futile_stun.
#   053b (F371)  debug/ai/f371_ai_targets.tscn with f371_wrath_blocker and f371_npc (the AI's line of fire, own splash, no spells on NPC).
#   053c (F372)  debug/ai/f372_ai_heal.tscn with f372_ai_heal (Heal only below the threshold, not on a summoning body; at most 2 in 30 s).
#   053d (F373)  debug/ai/f373_ai_finish.tscn with f373_ai_finish_{easy,normal,hard} (the finish: time to kill, the Rangers on the wizard
#                or the Charlotte, she falls first), 10 min each at most; then Easy >= Normal >= Hard in time to kill.
#   053h (F377)  agent/runs/run_f377.sh (the emitters outside the tree).
#   053a_sides   the SIDES line (SideRelations.stance(1|2, 0) and (1|2, 3)) on peaks and peasantville (diagnostic, no verdict).
# Usage: bash agent/runs/run_rfc053.sh CUT [GODOT_BIN]
# Prints each case's EXPECT lines and EXPECT DONE, then RFC053 <cut> PASS / FAIL (exit 0 / 1).
set -u
. "$(dirname "$0")/../harness/env.sh"
CUT="${1:-053a}"
GODOT_BIN="${2:-$GODOT_BIN}"
RUN="$ROOT/agent/harness/godot_run.sh"
WATCHDOG_S="${RFC053_WATCHDOG_S:-20}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/rfc053.XXXXXX")"
FAIL=0

case_run() { # name, scene, then the user args after --
  local name="$1" scene="$2"; shift 2
  local started=$SECONDS
  bash "$RUN" "$GODOT_BIN" --headless --path "$ROOT" --fixed-fps 600 "$scene" -- --seed=1 --minutes=0.5 \
    --watchdog-s="$WATCHDOG_S" "$@" > "$OUT/$name.log" 2>&1
  local code=$?
  local done_line; done_line=$(grep -E "^EXPECT DONE" "$OUT/$name.log" | tail -1)
  echo "--- $name (exit $code, $((SECONDS - started)) s) ---"
  grep -E "^(EXPECT |EXPECT_NOTE|SIDES)" "$OUT/$name.log"
  grep -E "SCRIPT ERROR|^ERROR:" "$OUT/$name.log" | head -10
  [ "$code" = 0 ] && [ "$done_line" = "EXPECT DONE PASS" ] || FAIL=1
}

sides_run() { # map tag
  bash "$RUN" "$GODOT_BIN" --headless --path "$ROOT" --fixed-fps 600 res://debug/units/f370_targets.tscn -- --seed=1 \
    --minutes=0.02 --map="$1" --watchdog-s="$WATCHDOG_S" --rules=res://debug/rules/f370_indestructible.tres > "$OUT/sides_$1.log" 2>&1
  grep -E "^SIDES" "$OUT/sides_$1.log" || echo "sides $1: sin linea SIDES"
}

case "$CUT" in
  053a)
    for variant in guard_reacts indestructible futile_stun; do
      case_run "f370_$variant" res://debug/units/f370_targets.tscn --rules="res://debug/rules/f370_$variant.tres"
    done
    ;;
  053b)
    for variant in wrath_blocker npc; do
      case_run "f371_$variant" res://debug/ai/f371_ai_targets.tscn --rules="res://debug/rules/f371_$variant.tres" ${RFC053_ARGS:-}
    done
    ;;
  053c)
    case_run f372_ai_heal res://debug/ai/f372_ai_heal.tscn --rules=res://debug/rules/f372_ai_heal.tres ${RFC053_ARGS:-}
    ;;
  053d)
    for variant in easy normal hard; do
      case_run "f373_$variant" res://debug/ai/f373_ai_finish.tscn --rules="res://debug/rules/f373_ai_finish_$variant.tres" --minutes=10 ${RFC053_ARGS:-}
    done
    kill_s() { grep -E "^EXPECT PASS mago_cae " "$OUT/f373_$1.log" | tail -1 | awk '{print $4}' | tr -d s; }
    E=$(kill_s easy); N=$(kill_s normal); H=$(kill_s hard)
    if [ -n "$E" ] && [ -n "$N" ] && [ -n "$H" ] && awk -v e="$E" -v n="$N" -v h="$H" 'BEGIN { exit !(e >= n && n >= h) }'; then
      echo "EXPECT PASS easy_normal_hard ${E}s >= ${N}s >= ${H}s"
    else
      echo "EXPECT FAIL easy_normal_hard easy=${E:-?} normal=${N:-?} hard=${H:-?}"
      FAIL=1
    fi
    ;;
  053h)
    bash "$ROOT/agent/runs/run_f377.sh" "$GODOT_BIN" || FAIL=1
    ;;
  053a_sides)
    sides_run peaks
    sides_run peasantville
    ;;
  *)
    echo "corte desconocido: $CUT (053a, 053a_sides, 053b, 053c, 053d, 053h)"
    exit 2
    ;;
esac
echo "logs: $OUT"
if [ "$FAIL" = 0 ]; then echo "RFC053 $CUT PASS"; else echo "RFC053 $CUT FAIL"; fi
exit $FAIL
