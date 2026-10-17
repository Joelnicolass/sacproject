#!/usr/bin/env bash
# F177 (030w-a): the A x B measurement of the melee tremor on one case (fixed clock, one Godot at a time through godot_run.sh).
#   agent/tools/f177_matrix.sh [CASE_RULES.tres] [MINUTES]     default: f177_melee_group, 0.3
# A = BodySeparation.share_push (--share-push turns it on), B = MeleeAttack.melee_moving (--melee-moving); both off by default.
# Out: agent/out/f177/<A>_<B>.{json,events,log}; prints the digest and melee_gap_expect for each of the four runs.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RULES=${1:-res://debug/rules/f177_melee_group.tres}
MIN=${2:-0.3}
OUT="$ROOT/agent/out/f177"
mkdir -p "$OUT"
run() { # name flags...
  local name=$1; shift
  bash "$ROOT/agent/harness/godot_run.sh" /Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path "$ROOT" \
    res://debug/ai_match.tscn -- --rules="$RULES" --seed=7 --minutes="$MIN" "$@" --out="$OUT/$name.json" --events="$OUT/$name.events" > "$OUT/$name.log" 2>&1
  echo "== $name  digest $(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))['digest'][:12])" "$OUT/$name.json")"
  python3 -I "$ROOT/agent/tools/melee_gap_expect.py" "$OUT/$name.log" | sed -e 's#/[^ ]*/##' | cut -c1-170 | head -14
  grep -o '"end_tick":[0-9]*' "$OUT/$name.log"
}
run A_off_B_off
run A_off_B_on --melee-moving
run A_on_B_off --share-push
run A_on_B_on --melee-moving --share-push
