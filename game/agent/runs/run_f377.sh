#!/usr/bin/env bash
# RFC-053 053h (F377): a structure on a manafount freed after the fount left the tree does not touch its emitters.
# One headless run of debug/fx/f377_fount_exit.tscn (scene watchdog 20 s real time, --quit-after as a second stop).
# Fails when the scene prints F377 FAIL or no verdict, or when the log contains `get_global_transform`.
# Usage: bash agent/runs/run_f377.sh [GODOT_BIN]. Prints F377 RUN PASS / FAIL (exit 0 / 1).
set -u
. "$(dirname "$0")/../harness/env.sh"
GODOT_BIN="${1:-$GODOT_BIN}"
LOG="$(mktemp "${TMPDIR:-/tmp}/f377.XXXXXX")"
bash "$ROOT/agent/harness/godot_run.sh" "$GODOT_BIN" --headless --path "$ROOT" res://debug/fx/f377_fount_exit.tscn \
  --fixed-fps 600 --quit-after 30000 > "$LOG" 2>&1
CODE=$?
grep -E "^F377 |SCRIPT ERROR|get_global_transform" "$LOG"
FAIL=0
[ "$CODE" = 0 ] || FAIL=1
grep -qE "^F377 PASS$" "$LOG" || FAIL=1
if grep -q "get_global_transform" "$LOG"; then echo "FAIL get_global_transform in the log"; FAIL=1; fi
if [ "$FAIL" = 0 ]; then echo "F377 RUN PASS"; rm -f "$LOG"; else echo "F377 RUN FAIL (log in $LOG)"; fi
exit "$FAIL"
