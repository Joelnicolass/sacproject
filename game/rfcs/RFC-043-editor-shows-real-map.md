# RFC-043 — El editor muestra el mapa real

Fuente: `docs/AUDIT-editor-first.md` (EF-03, EF-13, §5). Meta: lo que se ve en el editor es lo que pasa en partida.

## 043a — Rotación WYSIWYG

- El transform guardado del nodo es la verdad. `facing_deg` se migró una vez (`tools/migrate_layout_043.gd`) a la rotación de
  cada `MapBuilding` y `NpcSpawn` de `high_noon_layout.tscn`, y se borró de los scripts.
- `MapBuilding` es `@tool`: en el editor muestra los modelos de su `building` (las mismas partes que arma el juego, sin dueño, no se
  guardan) y no corre nada de juego. El gizmo de rotación sirve.
- `NpcSpawn.yaw()` lee el giro del propio marcador (`atan2` de la base, no `get_euler`, que se invierte pasados 90°).
- `NavFingerprint` ya no hashea `facing_deg`: la rotación va en el transform. El navmesh se re-horneó.
- Prueba: `res://tools/check_layout_transforms.tscn` compara 69 edificios y 32 spawns contra `tools/layout_transforms_baseline.json`
  (tomado con el código viejo) a 1e-4.

## 043b — Referencias tipadas

- `MapBuilding.building: BuildingType` y `NpcSpawn.creature: CreatureType` (arrastrar el `.tres` de `data/catalog/<tipo>/<tag>.tres`).
- `tag` pasó a propiedad derivada (`building.tag`). Su setter busca el tipo con `TypeRef` (primero el archivo del tipo, después la
  lista de `GameCatalog`), así que el código y las escenas viejas que nombran un tag siguen andando.

## Fuera

`UnitBody`, `DoctorBody` y `PlayerStart` (resto de EF-13), el botón «Hornear navmesh» (EF-15).
