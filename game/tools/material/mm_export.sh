#!/usr/bin/env bash
# Exporta .ptex de assets/mm/src/ a assets/mm/<nombre>/{albedo,normal,orm}.png con Material Maker (consola).
# Uso: tools/material/mm_export.sh [--size N] nombre [nombre2 ...]    (nombre sin .ptex, o ruta a .ptex)
#   --size N : resolución (potencia de 2: 256..4096). Reescribe el parámetro "size" (log2) del nodo
#              Material en una copia temporal; el .ptex fuente no se toca. Sin --size sale lo que diga el grafo.
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
[[ ${#NAMES[@]} -gt 0 ]] || { echo "mm_export: falta nombre de .ptex (ej: persephone_grass)" >&2; exit 2; }
[[ -x "$MM" ]] || { echo "mm_export: no encuentro Material Maker en '$MM' (variable MM_BIN)" >&2; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
for n in "${NAMES[@]}"; do
  f="$SRC/${n%.ptex}.ptex"; [[ -f "$n" ]] && f="$n"
  name="$(basename "${f%.ptex}")"
  [[ -f "$f" ]] || { echo "mm_export: no existe $f" >&2; exit 1; }
  work="$TMP/$name"; mkdir -p "$work"; cp "$f" "$work/$name.ptex"
  if [[ -n "$SIZE" ]]; then
    python3 - "$work/$name.ptex" "$SIZE" <<'PY'
import json,sys,math
p,s=sys.argv[1],int(sys.argv[2]); lg=int(round(math.log2(s)))
assert 2**lg==s and 8<=lg<=13, "size debe ser potencia de 2 entre 256 y 8192"
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
  # espera con timeout (180 s); mata si se cuelga
  for _ in $(seq 1 180); do kill -0 $pid 2>/dev/null || break; sleep 1; done
  if kill -0 $pid 2>/dev/null; then kill $pid; echo "mm_export: timeout con $name" >&2; exit 1; fi
  wait $pid || true
  dest="$OUT/$name"; mkdir -p "$dest"
  for m in albedo normal orm; do
    src="$work/out/${name}_$m.png"
    [[ -s "$src" ]] || { echo "mm_export: FALLO: falta ${name}_$m.png (log: $(tail -n 5 "$work/log.txt" | tr '\n' ' '))" >&2; exit 1; }
    cp "$src" "$dest/$m.png"
  done
  echo "mm_export: OK -> $dest/{albedo,normal,orm}.png"
done
