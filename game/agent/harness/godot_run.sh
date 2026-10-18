#!/usr/bin/env bash
# Shim: the queue lives in the kit (addons/agent_kit/determinism/harness/godot_run.sh). Same locks as always (/tmp/sacproject_godot.*).
HERE="$(cd "$(dirname "$0")" && pwd)"
export GODOT_RUN_NS=sacproject
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
exec bash "$HERE/../../addons/agent_kit/determinism/harness/godot_run.sh" "$@"
