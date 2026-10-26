#!/usr/bin/env bash
# RFC-063 063-2a: the criteria of the static free-mesh ground on scenes/map/maps/mesh_test, one step at a time or all.
#   bash agent/runs/run_063_2a.sh import   import of ground.glb <= 10 s (the post-import prints its own time)
#   bash agent/runs/run_063_2a.sh cases    debug/map/mesh_ground_cases.gd: heights, the arch roof, walls, normals, sampler
#   bash agent/runs/run_063_2a.sh ray      debug/map/mesh_ground_ray.gd: GroundRay.surface_y = height_at +- 0.05 at 500 points,
#                                          Surface + Collision load <= 300 ms
#   bash agent/runs/run_063_2a.sh bake     bakes the navmesh of mesh_test from the ground collision (writes nav.res)
#   bash agent/runs/run_063_2a.sh ai       debug/map/mesh_ai_duel.tscn: two AIs for 3 min on mesh_test, FallCheck = 0 (needs bake)
#   bash agent/runs/run_063_2a.sh all      import, cases, ray, bake, ai in that order (the default)
# Each Godot goes through the machine queue (godot_run.sh) with its own wall-clock watchdog, which kills only ITS Godot by pid.
# Exit 0 when every step asked for passed, 1 otherwise. Needs the project imported once for every step but `import`.
. "$(dirname "$0")/../harness/env.sh"
GODOT="$GODOT_BIN"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mesh_063_2a.XXXXXX")"
IMPORT_LIMIT_MS="${IMPORT_LIMIT_MS:-10000}"
fail=0

# run_godot <limit_s> <log> <godot args...>: one Godot through the queue, killed by pid after limit_s. Returns its exit code.
run_godot() {
  local limit="$1" log="$2"
  shift 2
  bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" "$@" >"$log" 2>&1 &
  local pid=$!
  ( sleep "$limit"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watch=$!
  wait "$pid"
  local rc=$?
  kill "$watch" 2>/dev/null
  return $rc
}

verdict() { # <name> <exit code of the check>
  if [ "$2" -eq 0 ]; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi
}

step_import() {
  local log="$OUT/import.log"
  # A touched file with the same bytes is not imported again: drop the cached import of this one glb to force it.
  find "$ROOT/.godot/imported" -name 'ground.glb-*' -delete 2>/dev/null
  run_godot 900 "$log" --import
  local ms
  ms=$(grep -a "^ground import " "$log" | tail -1 | sed -E 's/.* ([0-9]+) ms$/\1/')
  grep -a "^ground import " "$log" | tail -1
  [ -n "$ms" ] && [ "$ms" -le "$IMPORT_LIMIT_MS" ]
  verdict "import of ground.glb: ${ms:-no time printed} ms (limit $IMPORT_LIMIT_MS)" $?
  grep -a -E "SCRIPT ERROR|Parse Error|ground import .*(no walkable|no triangles|could not)" "$log" | head -5
}

step_script() { # <name> <script> <PASS marker>
  local log="$OUT/$1.log"
  run_godot 300 "$log" --script "$2"
  grep -a -E "^mesh_ground_(cases|ray):" "$log"
  grep -a -q "$3" "$log"
  verdict "$1 ($log)" $?
}

step_bake() {
  local log="$OUT/bake.log"
  run_godot 900 "$log" res://tools/bake/bake_nav.tscn -- --map=mesh_test
  grep -a "^bake_nav:" "$log" | tail -3
  grep -a -q "bake_nav: written" "$log"
  verdict "navmesh of mesh_test baked ($log)" $?
}

step_ai() {
  local log="$OUT/ai.log"
  run_godot 1700 "$log" --fixed-fps 60 res://debug/map/mesh_ai_duel.tscn -- --map=mesh_test --minutes=3 --seed=1 --watchdog-s=1500
  grep -a "^MESH FALL" "$log"
  grep -a -q "^MESH FALL PASS" "$log"
  verdict "AI 1v1 for 3 min, FallCheck = 0 ($log)" $?
}

case "${1:-all}" in
  import) step_import ;;
  cases) step_script cases res://debug/map/mesh_ground_cases.gd "MESH GROUND CASES PASS" ;;
  ray) step_script ray res://debug/map/mesh_ground_ray.gd "MESH GROUND RAY PASS" ;;
  bake) step_bake ;;
  ai) step_ai ;;
  all)
    step_import
    step_script cases res://debug/map/mesh_ground_cases.gd "MESH GROUND CASES PASS"
    step_script ray res://debug/map/mesh_ground_ray.gd "MESH GROUND RAY PASS"
    step_bake
    step_ai ;;
  *) echo "usage: run_063_2a.sh [import|cases|ray|bake|ai|all]"; exit 2 ;;
esac
[ "$fail" -eq 0 ] && echo "063-2a PASS (logs in $OUT)" || echo "063-2a FAIL (logs in $OUT)"
exit "$fail"
