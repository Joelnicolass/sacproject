#!/usr/bin/env bash
# RFC-033 (033a): the fixed-camera captures that every cut compares against. One window run, 1280x720, 60 fps cap.
#   agent/runs/run_rfc033_shots.sh base     -> agent/out/033/base   (the "before": taken with the old extraction, not versioned)
#   agent/runs/run_rfc033_shots.sh after    -> agent/out/033/after  (diff against base with AgentKit: cli.sh . diff --a= --b=)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TAG="${1:-after}"
OUT="$ROOT/agent/out/033/$TAG"; mkdir -p "$OUT"
export GODOT="$ROOT/agent/harness/godot60_res.sh" PT_RES=1280x720
cd "$ROOT"
bash "$ROOT/agent/harness/godot_run.sh" "$ROOT/addons/agent_kit/cli.sh" "$ROOT" flow --flow=rfc033_shots.json \
  --out=res://agent/out/033/$TAG --fail-on-error > "$OUT/run.log" 2>&1
echo "exit $? (log: $OUT/run.log)"
