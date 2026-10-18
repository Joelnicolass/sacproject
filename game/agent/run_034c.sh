#!/usr/bin/env bash
# RFC-034 034c: headless cases of MpLobbyRooms (no network, no processes: stub runner).
# Closes by itself (internal timeout 30 s); this script also kills the run and its descendants (by pid) at 120 s.
# Prints LOBBY CASES PASS / FAIL and exits 0 / 1. Needs `--import` once first (new class_names).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
LIMIT_S="${PROBE_LIMIT_S:-120}"

descendants() { # pid -> pid and all its descendants
  local p="$1" c
  echo "$p"
  for c in $(pgrep -P "$p" 2>/dev/null); do descendants "$c"; done
}

bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://debug/net/lobby_cases.tscn -- --no-flow &
RUN=$!
(
  sleep "$LIMIT_S"
  if kill -0 "$RUN" 2>/dev/null; then
    echo "LOBBY CASES FAIL: external timeout ${LIMIT_S}s"
    for p in $(descendants "$RUN" | sort -rn); do kill "$p" 2>/dev/null; done
  fi
) &
WATCH=$!
wait "$RUN"
CODE=$?
kill "$WATCH" 2>/dev/null
exit "$CODE"
