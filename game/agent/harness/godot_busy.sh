#!/usr/bin/env bash
# Shim: lives in the kit (addons/agent_kit/determinism/harness/godot_busy.sh).
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/../../addons/agent_kit/determinism/harness/godot_busy.sh" "$@"
