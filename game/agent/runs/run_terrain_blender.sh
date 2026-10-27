#!/usr/bin/env bash
# Plan 063D S4b: a map's images through Blender and back without edits, headless (needs Blender, not Godot nor the original).
#   1. copies the map's heights.png, void.png and ground_roles.png (those it has) to a temp folder; the repo is never written;
#   2. terrain_make_blend.py -> terrain_work/terrain.blend, terrain_export_images.py -> the images again;
#   3. each image must come back byte-identical, or value-identical when only the compression differs;
#   4. two refusals must exit 1 and leave the images untouched: a vertex moved in X, and a source changed after the .blend.
# Without a map argument it takes the first scenes/map/maps/*/heights.png; if no map has one yet, a fixture made here
# (hills, a void patch, roles) with tools/blender/terrain_common.py.
# Usage: bash agent/runs/run_terrain_blender.sh [map dir] [BLENDER_BIN]
# Prints each step and TERRAIN BLENDER PASS / FAIL (exit 0 / 1).
set -u
. "$(dirname "$0")/../harness/env.sh"
BLENDER_BIN="${2:-$BLENDER_BIN}"
TOOLS="$ROOT/tools/blender"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/terrain_blender.XXXXXX")"
MAP="$WORK/map"
KEEP="$WORK/before"
mkdir -p "$MAP" "$KEEP"
FAIL=0

if [ ! -x "$BLENDER_BIN" ]; then
  echo "ERROR: no Blender at '$BLENDER_BIN': set BLENDER_BIN or put blender in the PATH"
  echo "TERRAIN BLENDER FAIL"
  exit 1
fi

SOURCE="${1:-}"
if [ -z "$SOURCE" ]; then
  first="$(ls "$ROOT"/scenes/map/maps/*/heights.png 2>/dev/null | head -1)"
  [ -n "$first" ] && SOURCE="$(dirname "$first")"
fi
if [ -n "$SOURCE" ]; then
  for name in heights.png void.png ground_roles.png; do
    [ -f "$SOURCE/$name" ] && cp "$SOURCE/$name" "$MAP/$name"
  done
  echo "map: $SOURCE"
else
  python3 -I - "$TOOLS" "$MAP" <<'PY'
import math, sys
sys.path.insert(0, sys.argv[1])
import terrain_common as tc
out = sys.argv[2]
units, voids, roles = [], [], []
for i in range(tc.COUNT):
    c, r = i % tc.SIDE, i // tc.SIDE
    units.append(500 + round(300 * math.sin(c / 17.0) * math.cos(r / 23.0)) + 300)
    voids.append(100 <= c < 120 and 60 <= r < 90)
    roles.append((c, r, (c * r) % 256, 255 if c % 7 else 0))
open(out + "/heights.png", "wb").write(tc.encode_heights(units))
open(out + "/void.png", "wb").write(tc.encode_void(voids))
open(out + "/ground_roles.png", "wb").write(tc.encode_roles(roles))
PY
  echo "map: fixture (no scenes/map/maps/*/heights.png yet)"
fi
cp "$MAP"/*.png "$KEEP"/

blender() { # log name, then Blender args
  local name="$1"; shift
  "$BLENDER_BIN" --background --factory-startup "$@" > "$WORK/$name.log" 2>&1
}

same_images() { # prints a line per image, returns 1 if any differs
  python3 -I - "$TOOLS" "$KEEP" "$MAP" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import terrain_common as tc
keep, now = Path(sys.argv[2]), Path(sys.argv[3])
readers = {tc.HEIGHTS_PNG: tc.read_heights, tc.VOID_PNG: tc.read_void, tc.ROLES_PNG: tc.read_roles}
bad = 0
for name, read in readers.items():
    if not (keep / name).is_file():
        continue
    if not (now / name).is_file():
        print(f"  {name}: missing after the round trip"); bad = 1; continue
    if (keep / name).read_bytes() == (now / name).read_bytes():
        print(f"  {name}: byte-identical"); continue
    a, b = read(keep / name), read(now / name)
    diff = sum(1 for x, y in zip(a, b) if x != y)
    print(f"  {name}: {'value-identical' if diff == 0 else f'{diff} values differ'}")
    bad |= diff != 0
sys.exit(bad)
PY
}

# 1-3. round trip without edits
blender make --python "$TOOLS/terrain_make_blend.py" -- --map="$MAP"
grep -E "^(TERRAIN BLEND|ERROR)" "$WORK/make.log"
BLEND="$MAP/terrain_work/terrain.blend"
blender export "$BLEND" --python "$TOOLS/terrain_export_images.py" -- --out="$MAP"
code=$?
grep -E "^(TERRAIN EXPORT|ERROR)" "$WORK/export.log"
if [ $code -ne 0 ] || ! same_images; then echo "round trip: FAIL"; FAIL=1; else echo "round trip: PASS"; fi
[ -f "$MAP/terrain_work/.gdignore" ] && echo "terrain_work/.gdignore: PASS" || { echo "terrain_work/.gdignore: FAIL"; FAIL=1; }

refusal() { # name, then the export args; the export must exit 1 and leave the images as they are
  local name="$1"; shift
  local before; before="$(cat "$MAP"/*.png | shasum)"
  blender "$name" "$@"
  local code=$?
  grep -E "^ERROR" "$WORK/$name.log" | head -3
  if [ $code -eq 1 ] && [ "$before" = "$(cat "$MAP"/*.png | shasum)" ] && ! ls "$MAP"/*.tmp >/dev/null 2>&1; then
    echo "$name: PASS"
  else
    echo "$name: FAIL (exit $code)"; FAIL=1
  fi
}

# 4a. a vertex moved in X (saved to a second .blend so the clean one stays)
blender move "$BLEND" --python-expr "import bpy; bpy.data.objects['Terrain'].data.vertices[300].co.x += 0.5; bpy.ops.wm.save_as_mainfile(filepath='$MAP/terrain_work/moved.blend')"
refusal refuse_moved "$MAP/terrain_work/moved.blend" --python "$TOOLS/terrain_export_images.py" -- --out="$MAP"
# 4b. heights.png changed after the .blend was made (one pixel, through the same writer)
python3 -I - "$TOOLS" "$MAP" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import terrain_common as tc
path = sys.argv[2] + "/heights.png"
units = tc.read_heights(path)
units[0] = (units[0] + 1) % (tc.MAX_UNIT + 1)
open(path, "wb").write(tc.encode_heights(units))
PY
refusal refuse_stale "$BLEND" --python "$TOOLS/terrain_export_images.py" -- --out="$MAP"

echo "logs: $WORK"
if [ $FAIL -eq 0 ]; then echo "TERRAIN BLENDER PASS"; exit 0; fi
echo "TERRAIN BLENDER FAIL"
exit 1
