#!/usr/bin/env bash
# usage: run_pt73.sh FLOW  -- one windowed Godot at 60 fps with the flow agent/flows/FLOW.json; log in agent/out/pt73/FLOW.log
. "$(dirname "$0")/../harness/env.sh"
export GODOT="$ROOT/agent/harness/godot60.sh"
FLOW="$1"
mkdir -p "$ROOT/agent/out/pt73"
cd "$ROOT"
addons/agent_kit/cli.sh "$ROOT" flow --flow="$FLOW.json" --out=res://agent/out/pt73 --fail-on-error > "agent/out/pt73/$FLOW.log" 2>&1
echo "$FLOW exit $?"
