#!/usr/bin/env bash
# Exports .ptex files of assets/mm/src/ to assets/mm/<name>/{albedo,normal,orm}.png with Material Maker (console).
# Usage: tools/material/mm_export.sh [--size N] name [name2 ...]    (name without .ptex, or a path to a .ptex)
#   --size N : resolution (power of 2: 256..4096). Rewrites the "size" parameter (log2) of the Material
#              node in a temporary copy; the source .ptex is not touched. Without --size it is what the graph says.
set -euo pipefail
MM="${MM_BIN:-/Applications/Material Maker.app/Contents/MacOS/Material Maker}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/assets/mm/src"; OUT="$ROOT/assets/mm"
SIZE=""; NAMES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --size) SIZE="$2"; shift 2;;
    -h|--help) sed -n '2,6p' "$0"; exit 0;;
    *) NAMES+=("$1"); shift;;
  esac
done
[[ ${#NAMES[@]} -gt 0 ]] || { echo "mm_export: missing .ptex name (e.g. persephone_grass)" >&2; exit 2; }
[[ -x "$MM" ]] || { echo "mm_export: Material Maker not found at '$MM' (variable MM_BIN)" >&2; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
for n in "${NAMES[@]}"; do
  f="$SRC/${n%.ptex}.ptex"; [[ -f "$n" ]] && f="$n"
  name="$(basename "${f%.ptex}")"
  [[ -f "$f" ]] || { echo "mm_export: $f does not exist" >&2; exit 1; }
  work="$TMP/$name"; mkdir -p "$work"; cp "$f" "$work/$name.ptex"
  if [[ -n "$SIZE" ]]; then
    python3 - "$work/$name.ptex" "$SIZE" <<'PY'
import json,sys,math
p,s=sys.argv[1],int(sys.argv[2]); lg=int(round(math.log2(s)))
assert 2**lg==s and 8<=lg<=13, "size must be a power of 2 between 256 and 8192"
d=json.load(open(p))
for n in d["nodes"]:
    if n["type"]=="material": n["parameters"]["size"]=lg
    if n["type"]=="normal_map": n["parameters"]["param0"]=lg
json.dump(d,open(p,"w"),indent=1)
PY
  fi
  echo "mm_export: $name ..."
  mkdir -p "$work/out"
  "$MM" --no-header --export-material --target Godot -o "$work/out" "$work/$name.ptex" >"$work/log.txt" 2>&1 &
  pid=$!
  # waits with a timeout (180 s); kills it if it hangs
  for _ in $(seq 1 180); do kill -0 $pid 2>/dev/null || break; sleep 1; done
  if kill -0 $pid 2>/dev/null; then kill $pid; echo "mm_export: timeout with $name" >&2; exit 1; fi
  wait $pid || true
  dest="$OUT/$name"; mkdir -p "$dest"
  for m in albedo normal orm; do
    src="$work/out/${name}_$m.png"
    [[ -s "$src" ]] || { echo "mm_export: FAILED: ${name}_$m.png is missing (log: $(tail -n 5 "$work/log.txt" | tr '\n' ' '))" >&2; exit 1; }
    cp "$src" "$dest/$m.png"
  done
  echo "mm_export: OK -> $dest/{albedo,normal,orm}.png"
done
