#!/usr/bin/env bash
# RFC-034 034b: headless probe of MpMatchLauncher + MpMatchAgent (1 real dedicated process + 1 client in the same Godot).
# Closes by itself (global timeout 90 s). Prints LAUNCHER PROBE PASS / FAIL and exits 0 / 1.
# Needs `--import` once first (new class_names). Uses ports 7800-7803 (UDP) and user://mp_matches/.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
exec bash "$ROOT/agent/harness/godot_run.sh" "$GODOT" --headless --path "$ROOT" res://debug/net/match_launcher_probe.tscn
