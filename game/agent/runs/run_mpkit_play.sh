#!/usr/bin/env bash
# The example in visible windows (mpkit_lab/run/play.sh dedicated|listen|rooms [--watch] [--relay]), through this project's Godot queue.
HERE="$(cd "$(dirname "$0")/../harness" && pwd)"
export GODOT_RUN_NS="${GODOT_RUN_NS:-sacproject}" MPKIT_GODOT_GROUP="$HERE/godot_group.sh" MPKIT_GODOT_RUN="$HERE/godot_run.sh"
exec bash "$HERE/../../../mpkit_lab/run/play.sh" "$@"
