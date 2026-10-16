# Materiales procedurales (Material Maker)

Flujo: editar `src/<nombre>.ptex` (Material Maker, o JSON a mano/script) -> `tools/mm_export.sh <nombre> [--size 1024]` -> `assets/mm/<nombre>/{albedo,normal,orm}.png` (Git LFS) -> se referencian desde el `.tres` de la capa de suelo.

- `orm.png`: R = oclusion (AO), G = rugosidad, B = metalico. Normal en convencion OpenGL (Godot).
- Resolucion: la define el parametro `size` (log2; 11 = 2048) del nodo `Material` y `param0` del nodo `normal_map`. `--size N` los reescribe en una copia temporal sin tocar el `.ptex`.
- Tileable: los nodos de ruido usan escalas enteras; no se verifico costura por costura, mirar con UV repetidas (`debug/mm_preview.tscn`).
- No usar el `.tres` que genera Material Maker (sintaxis Godot 3); el script solo toma los PNG.
- Licencia: los materiales son nuestros; Material Maker es MIT.
