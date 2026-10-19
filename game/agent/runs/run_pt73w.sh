#!/usr/bin/env bash
# usage: run_pt73w.sh FLOW -- one windowed Godot at 60 fps; out in agent/out/pt73w
. "$(dirname "$0")/../harness/env.sh"
export GODOT="$ROOT/agent/harness/godot60.sh"
mkdir -p "$ROOT/agent/out/pt73w"; cd "$ROOT"
addons/agent_kit/cli.sh "$ROOT" flow --flow="$1.json" --out=res://agent/out/pt73w --fail-on-error > "agent/out/pt73w/$1.log" 2>&1
echo "$1 exit $?"
