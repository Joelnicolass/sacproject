#!/usr/bin/env bash
# c1-0 probe, question 4 (disposable): can Godot's own .glb import split the actions by role and save one .res per clip?
# Copies eorc.glb to debug/creatures/c1_0/tmp/, writes an .import whose _subresources set, on the clip HUa1, save_to_file +
# keep_custom_tracks and a slice named `attack` (the role) with its own save_to_file; imports the copy (alone in the queue:
# --import takes the project lock), runs c1_0_import_check.gd, and deletes the copy and its imported cache.
# Usage: bash debug/creatures/c1_0/run_import_probe.sh [GODOT_BIN]
# Prints the C1_0 import lines, C1_0 VERDICT import ... and C1_0 IMPORT PROBE DONE / FAIL (exit 0 / 1).
set -u
. "$(dirname "$0")/../../../agent/harness/env.sh"
GODOT_BIN="${1:-$GODOT_BIN}"
RUN="$ROOT/agent/harness/godot_run.sh"
TMP="$ROOT/debug/creatures/c1_0/tmp"
RES="res://debug/creatures/c1_0/tmp"
SRC="$ROOT/assets/original/models/eorc.glb"

cleanup() { rm -rf "$TMP"; rm -f "$ROOT"/.godot/imported/eorc_split.glb-*; }
trap cleanup EXIT

if [ ! -f "$SRC" ] || [ "$(wc -c < "$SRC")" -lt 10000 ]; then
  echo "C1_0 FAIL eorc.glb missing or a Git LFS pointer (git lfs pull)"; exit 1
fi
mkdir -p "$TMP"
cp "$SRC" "$TMP/eorc_split.glb"
SUBRES="{\"animations\": {\"HUa1\": {\"settings/loop_mode\": 0, \"save_to_file/enabled\": true, \"save_to_file/path\": \"$RES/HUa1.res\", \"save_to_file/keep_custom_tracks\": true, \"slices/amount\": 1, \"slice_1/name\": \"attack\", \"slice_1/start_frame\": 0, \"slice_1/end_frame\": 24, \"slice_1/loop_mode\": 0, \"slice_1/save_to_file/enabled\": true, \"slice_1/save_to_file/path\": \"$RES/attack.res\", \"slice_1/save_to_file/keep_custom_tracks\": true}}}"
awk -v src="$RES/eorc_split.glb" -v subres="$SUBRES" '
  /^uid=|^path=|^dest_files=/ { next }
  /^source_file=/ { print "source_file=\"" src "\""; next }
  /^_subresources=/ { print "_subresources=" subres; next }
  { print }' "$SRC.import" > "$TMP/eorc_split.glb.import"

bash "$RUN" "$GODOT_BIN" --headless --path "$ROOT" --import > "$TMP/import.log" 2>&1
grep -E "ERROR|SCRIPT ERROR" "$TMP/import.log" | head -10
bash "$RUN" "$GODOT_BIN" --headless --path "$ROOT" --script res://debug/creatures/c1_0/c1_0_import_check.gd 2>&1 | grep -E "^C1_0|SCRIPT ERROR|ERROR:"
code=${PIPESTATUS[0]}
if [ "$code" = 0 ]; then echo "C1_0 IMPORT PROBE DONE"; else echo "C1_0 IMPORT PROBE FAIL (exit $code)"; fi
exit "$code"
