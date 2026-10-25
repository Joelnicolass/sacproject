#!/usr/bin/env bash
# c1-0 probe (disposable): build -> load -> tree, each in its own headless Godot through the queue, a few seconds to a minute each.
# Every script quits by itself (a watchdog quits after 120 s); a missing C1_0 BUILD DONE / VERDICT line or a C1_0 FAIL is a failure.
# Usage: bash debug/creatures/c1_0/run_c1_0.sh [GODOT_BIN] [-- --models=auto|all|eorc,jnwr]
# The .glb must be imported (godot --headless --path game --import, alone) and be the real files, not Git LFS pointers.
set -u
. "$(dirname "$0")/../../../agent/harness/env.sh"
if [ -n "${1:-}" ] && [ "${1#--}" = "$1" ]; then GODOT_BIN="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
RUN="$ROOT/agent/harness/godot_run.sh"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/c1_0.XXXXXX")"
FAIL=0

step() { # name, script, then the user args after --
  local name="$1" script="$2"; shift 2
  bash "$RUN" "$GODOT_BIN" --headless --path "$ROOT" --script "res://debug/creatures/c1_0/$script" -- "$@" > "$OUT/$name.log" 2>&1
  local code=$?
  grep -E "^C1_0|SCRIPT ERROR|ERROR:" "$OUT/$name.log" | head -60
  [ "$code" = 0 ] && ! grep -q "^C1_0 FAIL" "$OUT/$name.log" || { echo "C1_0 STEP $name FAIL (exit $code)"; FAIL=1; }
}

step build c1_0_build.gd "$@"
[ "$FAIL" = 0 ] && step load c1_0_load.gd
[ "$FAIL" = 0 ] && step tree c1_0_tree.gd
echo "logs: $OUT"
if [ "$FAIL" = 0 ]; then echo "C1_0 RUN DONE"; else echo "C1_0 RUN FAIL"; fi
exit "$FAIL"
