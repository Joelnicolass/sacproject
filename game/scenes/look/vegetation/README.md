# scenes/look/vegetation/

Motor compartido de la vegetación (RFC-054): lo que usan el pasto y la flora de los mapas. Solo presentación: nada de esto existe en el dedicado ni en headless, y la simulación no lo lee.

- `flora_map.gd` (`FloraMap`, Resource): cuántas plantas de cada especie del original hay en cada celda de 8 m de un mapa (`counts`, una grilla de 320 × 320 por tag, tope 255). Uno por mapa en `scenes/map/maps/<mapa>/flora.res`, binario y comprimido (4–11 KB). Lo escribe solo `tools/bake/bake_flora_map.gd` (o «Sacrifice: Hornear flora» en Project > Tools) desde `widgets.json` y el terreno, con los mismos claros que `bake_map_layout` (40 m del altar, 6 m del manantial, fuera del suelo no). Se puede rehornear sin miedo; `--check` lo compara con el JSON.
- `flora_placement.gd` (`FloraPlacement`, funciones puras): dónde van las plantas de una celda. Con la misma semilla da siempre lo mismo, sin `randi()` ni el azar de la partida. Cualquier prefijo de la lista es una muestra pareja de la celda, así que el LOD dibuja un prefijo.
- `cell_ring.gd` (`CellRing`, RefCounted): qué celdas existen alrededor de la cámara (la del viewport en el editor, la del juego al jugar) y en qué tier, con histéresis. Solo guarda claves y tiers: `update` dice qué celdas aparecieron, se fueron o cambiaron de tier, y la capa crea, mueve o libera sus nodos. Lo usa `GrassField`; `FloraField` (054c) lo va a usar igual.
- Claros: `VegetationClear` (en `scenes/look/grass/`) avisa al grupo `vegetation_field`; cada capa de vegetación entra en ese grupo y responde `clears_changed()`.

Pruebas sin ventana: `res://debug/look/flora_cases.tscn` → `FLORA CASES PASS`.
