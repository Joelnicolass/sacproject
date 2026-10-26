#!/usr/bin/env bash
# MpKit lab e2e "web" (the script lives in mpkit_lab/run/web.sh, the same as in the kit repo), run through this
# project's Godot queue. Environment and output: see that script.
HERE="$(cd "$(dirname "$0")/../harness" && pwd)"
export GODOT_RUN_NS="${GODOT_RUN_NS:-sacproject}" MPKIT_GODOT_GROUP="$HERE/godot_group.sh" MPKIT_GODOT_RUN="$HERE/godot_run.sh"
exec bash "$HERE/../../../mpkit_lab/run/web.sh" "$@"
