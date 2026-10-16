#!/usr/bin/env bash
# usage: run_pt74.sh FLOW -- one windowed Godot at 60 fps; log in agent/out/pt74/FLOW.log
ROOT=/Users/joelsartori/Development/sacproject/game
export GODOT="$ROOT/agent/harness/godot60.sh"
FLOW="$1"
mkdir -p "$ROOT/agent/out/pt74"
cd "$ROOT"
addons/agent_kit/cli.sh "$ROOT" flow --flow="$FLOW.json" --out=res://agent/out/pt74 --fail-on-error $EXTRA > "agent/out/pt74/$FLOW.log" 2>&1
echo "$FLOW exit $?"
