# Shared environment for the agent scripts. Source it, do not run it:
#   . "$(dirname "$0")/../harness/env.sh"      (from agent/runs or agent/harness)
# Sets:
#   ROOT          the Godot project folder (computed from this file's location, never a personal path)
#   GODOT_BIN     $GODOT_BIN if set, else `godot` found in PATH, else the macOS default install
#   BLENDER_BIN   $BLENDER_BIN if set, else `blender` found in PATH, else the macOS default install
# The agent scripts do NOT need the original Sacrifice install (only tools/import/*.py do, see tools/README.md).
_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$_ENV_DIR/../.." && pwd)"
if [ -z "${GODOT_BIN:-}" ]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  else
    GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
  fi
fi
if [ -z "${BLENDER_BIN:-}" ]; then
  if command -v blender >/dev/null 2>&1; then
    BLENDER_BIN="$(command -v blender)"
  else
    BLENDER_BIN="/Applications/Blender.app/Contents/MacOS/Blender"
  fi
fi
export GODOT_BIN BLENDER_BIN
unset _ENV_DIR
