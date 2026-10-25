#!/usr/bin/env bash
# MpWorld in the real Godot editor (headless): a scene with a bare MpWorld is opened, and an MpWorld is added the way
# the Add Child dialog does; each must build its pieces, owned by the scene, and the saved .tscn must keep them.
# Uses the lab-only plugin addons/lab_editor_check (it does nothing without MPKIT_EDITOR_CHECK).
# Prints PASS / FAIL lines and MPKIT EDITOR PASS / FAIL (exit 0 / 1).
. "$(dirname "$0")/lib.sh"
net_group 1 "$@"
TAG="MPKIT EDITOR"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/mpkit_editor.XXXXXX")"
SCENE_DIR="$ROOT/scratch"
SCENE="$SCENE_DIR/editor_world.tscn"
mkdir -p "$SCENE_DIR"
cat > "$SCENE" <<'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/mp_kit/nodes/mp_world.gd" id="1"]

[node name="World" type="Node2D"]

[node name="MpWorld" type="Node" parent="."]
script = ExtResource("1")
TSCN
MPKIT_EDITOR_CHECK="res://scratch/editor_world.tscn" "$GODOT" --headless --editor --path "$ROOT" > "$OUT/editor.log" 2>&1 &
EDITOR=$!
for _ in $(seq 1 1200); do kill -0 "$EDITOR" 2>/dev/null || break; sleep 0.1; done
kill -0 "$EDITOR" 2>/dev/null && { echo "FAIL the editor did not finish in 120 s"; kill "$EDITOR"; }
wait "$EDITOR" 2>/dev/null
grep -E "^EDITOR (PASS|FAIL)" "$OUT/editor.log" | sed 's/^EDITOR //'
FAILS=0
check() { if eval "$1"; then echo "PASS $2"; else echo "FAIL $2"; FAILS=$((FAILS + 1)); fi; }
check 'grep -q "^EDITOR CHECK PASS" "$OUT/editor.log"' "the editor built every piece"
check '[ "$(grep -c "^\[node name=\"Players\"" "$SCENE")" = 2 ]' "the saved scene keeps the pieces of both MpWorlds"
check 'grep -q "name=\"MpSync\" type=\"MultiplayerSynchronizer\" parent=\"MpWorld/State\"" "$SCENE"' "the saved state keeps its synchronizer"
check '! grep -q "^SCRIPT ERROR" "$OUT/editor.log"' "no script errors"
echo "--- verdict (logs in $OUT) ---"
if [ "$FAILS" = 0 ]; then echo "$TAG PASS"; exit 0; fi
echo "$TAG FAIL: $FAILS"
exit 1
