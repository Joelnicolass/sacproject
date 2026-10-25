#!/usr/bin/env bash
# MpKit lab e2e "session" (mpkit_lab/run/session.sh, the same as in the kit repo), through this project's Godot queue.
HERE="$(cd "$(dirname "$0")/../harness" && pwd)"
export GODOT_RUN_NS="${GODOT_RUN_NS:-sacproject}" MPKIT_GODOT_GROUP="$HERE/godot_group.sh" MPKIT_GODOT_RUN="$HERE/godot_run.sh"
exec bash "$HERE/../../../mpkit_lab/run/session.sh" "$@"
