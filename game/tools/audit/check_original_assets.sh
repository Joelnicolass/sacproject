#!/usr/bin/env bash
# Requiere el juego original instalado (SAC_INSTALL): compara assets/original/ con lo que salga de importar desde el original.
# Sin el original no se puede correr (jugar y el resto de las herramientas no lo necesitan). Ver tools/import/local.cfg.example.
# RFC-033 033h: parity of assets/original/ with the installation. Regenerates every family with its importer into a temporary
# folder and compares with the versioned files (diff -r, the .import files excluded: Godot rewrites them). Replaces the old
# tools/audit_original_assets.gd, which compared against the old extraction.
#   bash tools/audit/check_original_assets.sh            exit 0 = every family identical
# The terrain (a Godot Resource) is checked by import_terrain.gd, which writes nothing when the arrays are the same, and the
# icon file names by tools/audit/check_icon_files.gd; both go through agent/harness/godot_run.sh.
set -u
case "${1:-}" in -h|--help) head -n 3 "$0" | tail -n 2 | cut -c3-; exit 0 ;; esac
. "$(dirname "$0")/../../agent/harness/env.sh"
GODOT="${GODOT:-$GODOT_BIN}"
# Fails early (status 2) with the explanation in Spanish when the original install is missing or invalid.
python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import sac_formats.install' "$ROOT/tools/import" || exit 2
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
A="$ROOT/assets/original"
fail=0
cmp_dir() { # name, regenerated, versioned
  if diff -rq --exclude='*.import' --exclude='terrain.res' --exclude='terrain.glb' --exclude='sides.tres' "$2" "$3" >"$TMP/diff.txt" 2>&1; then echo "OK    $1"; else echo "DIFF  $1"; head -5 "$TMP/diff.txt"; fail=1; fi
}
cd "$ROOT"
python3 -I tools/import/import_textures.py --out="$TMP/textures" >/dev/null && cmp_dir textures "$TMP/textures" "$A/textures" || { echo "FAIL  textures"; fail=1; }
# The static bodies need the OBJ of sacengine's saveObj, which is no installation input: they are versioned data (023h).
python3 -I tools/import/import_props.py --out="$TMP/props" >/dev/null && for m in $(python3 -I tools/import/import_props.py --list-static); do cp "$A/props/$m.glb" "$TMP/props/"; done && cmp_dir props "$TMP/props" "$A/props" || { echo "FAIL  props"; fail=1; }
python3 -I tools/import/import_themes.py --out="$TMP/themes" >/dev/null && cmp_dir themes "$TMP/themes" "$A/themes" || { echo "FAIL  themes"; fail=1; }
python3 -I tools/import/import_map.py --out="$TMP/map" --terrain-bin="$TMP/terrain.bin" >/dev/null && cmp_dir map "$TMP/map" "$A/maps/high_noon" || { echo "FAIL  map"; fail=1; }
# RFC-050: the other imported maps (their ntts.json names the .scp they came from); their terrain.res is checked by import_terrain.gd below only for High Noon.
for ntts in "$A"/maps/*/ntts.json; do
  tag="$(basename "$(dirname "$ntts")")"
  [ "$tag" = high_noon ] && continue
  scp="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["map"][:-4])' "$ntts")"
  python3 -I tools/import/import_map.py --map="$scp" --tag="$tag" --out="$TMP/map_$tag" >/dev/null && cmp_dir "map $tag" "$TMP/map_$tag" "$A/maps/$tag" || { echo "FAIL  map $tag"; fail=1; }
done
python3 -I tools/import/import_ui.py --out="$TMP/ui" >/dev/null && { cmp_dir ui "$TMP/ui/ui" "$A/ui"; cmp_dir fx "$TMP/ui/fx" "$A/fx"; } || { echo "FAIL  ui/fx"; fail=1; }
python3 -I tools/import/export_stats.py --out "$TMP/data" >/dev/null 2>&1 && cmp_dir data "$TMP/data" "$A/data" || { echo "FAIL  data"; fail=1; }
if bash agent/harness/godot_run.sh "$GODOT" --headless --path "$ROOT" --script res://tools/bake/import_terrain.gd -- --bin="$TMP/terrain.bin" 2>&1 | grep -q "0 written, 1 unchanged"; then echo "OK    terrain.res"; else echo "DIFF  terrain.res"; fail=1; fi
python3 -I tools/import/import_ui.py --icon-files="$TMP/icons.tsv"
if bash agent/harness/godot_run.sh "$GODOT" --headless --path "$ROOT" --script res://tools/audit/check_icon_files.gd -- --list="$TMP/icons.tsv" 2>&1 | grep -q " 0 failures"; then echo "OK    icon file names (GDScript = Python)"; else echo "DIFF  icon file names"; fail=1; fi
[ $fail = 0 ] && echo "ASSETS PARITY PASS" || { echo "ASSETS PARITY FAIL"; exit 1; }
