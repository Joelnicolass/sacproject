#!/usr/bin/env bash
# usage: run_probe73.sh CASE [extra args]  -- one headless Godot, the log in agent/out/pt73/CASE.log, a kill after 600 s.
ROOT=/Users/joelsartori/Development/sacproject/game
CASE="$1"; shift
mkdir -p "$ROOT/agent/out/pt73"
cd "$ROOT"
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$ROOT" --fixed-fps 60 res://agent/fixtures/pt73_probe.tscn -- --case="$CASE" "$@" > "agent/out/pt73/$CASE.log" 2>&1 &
PID=$!
for _ in $(seq 1 1200); do kill -0 $PID 2>/dev/null || break; sleep 0.5; done
kill -0 $PID 2>/dev/null && { kill $PID; echo "TIMEOUT $CASE"; }
grep -E "^PT73 |SCRIPT ERROR|^ERROR" "agent/out/pt73/$CASE.log" | cut -c1-3000
