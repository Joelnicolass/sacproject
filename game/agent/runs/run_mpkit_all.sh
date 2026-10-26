#!/usr/bin/env bash
# Every MpKit lab check (mpkit_lab/run/all.sh), through this project's Godot queue.
HERE="$(cd "$(dirname "$0")/../harness" && pwd)"
export GODOT_RUN_NS="${GODOT_RUN_NS:-sacproject}" MPKIT_GODOT_GROUP="$HERE/godot_group.sh" MPKIT_GODOT_RUN="$HERE/godot_run.sh"
exec bash "$HERE/../../../mpkit_lab/run/all.sh" "$@"
