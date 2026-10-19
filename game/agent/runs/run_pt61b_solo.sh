#!/usr/bin/env bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
ROOT=/Users/joelsartori/Development/sacproject/game
cd "$ROOT"
for f in convert_solo pump_kill carry_kill; do
  addons/agent_kit/cli.sh "$ROOT" flow --flow=rfc020e_$f.json --out=res://agent/out/pt61b --fail-on-error > agent/out/pt61b/$f.log 2>&1
  echo "$f exit $?" >> agent/out/pt61b/solo_exits.txt
done
