#!/usr/bin/env bash
# RFC-034 034b: headless probe of MpMatchLauncher + MpMatchAgent (1 real dedicated process + 1 client in the same Godot).
# Closes by itself (internal timeout 90 s); this script also kills the probe and its descendants (by pid) at 120 s.
# Prints LAUNCHER PROBE PASS / FAIL and exits 0 / 1. Needs `--import` once first (new class_names).
# Uses ports 7800-7803 (UDP) and user://mp_matches/.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
LIMIT_S="${PROBE_LIMIT_S:-120}"

descendants() { # pid -> pid and all its descendants
  local p="$1" c
  echo "$p"
  for c in $(pgrep -P "$p" 2>/dev/null); do descendants "$c"; done
}

bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://debug/net/match_launcher_probe.tscn -- --no-flow &
RUN=$!
(
  sleep "$LIMIT_S"
  if kill -0 "$RUN" 2>/dev/null; then
    echo "LAUNCHER PROBE FAIL: external timeout ${LIMIT_S}s"
    for p in $(descendants "$RUN" | sort -rn); do kill "$p" 2>/dev/null; done
  fi
) &
WATCH=$!
wait "$RUN"
CODE=$?
kill "$WATCH" 2>/dev/null
exit "$CODE"
