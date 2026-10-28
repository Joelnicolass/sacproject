# Plan del terreno: la grilla de 256² como única fuente, con una sola API `Terrain`

> **Estado:** aprobado por el usuario el 2026-10-26. Reemplaza al plan 063 (malla libre).
>
> **Decisiones del usuario (2026-10-26, a las preguntas de §14):**
> 1. Renombres `GroundSurface` → `Terrain` y `Terrain` → `TerrainMesh`: sí.
> 2. Alturas bajo los vacíos: exactas desde el original en los 7 mapas y rellenadas por difusión en los de prueba.
> 3. Formato de intercambio: **PNG de 16 bits** (pasos de 0,1 m) por defecto, para Blender y para cualquier editor de imágenes. EXR no es el default.
> 4. El `.blend` no se versiona; la verdad es `heights.res`.
> 5. Pinceles: el conjunto mínimo justo después de S3.
> 6. La malla se rearma después de un trazo con **debounce o en otro hilo, sin trabar el editor**. La vista previa en vivo va por la textura.
> 7. Paredes en el borde de `test_flat` y `test_flat4`: se aceptan.
> 8. Roles en Blender como color por vértice: sí, opcional.
> 9. Tolerancia de «base a nivel»: 0,5 m.
>
> **Enmienda aprobada (2026-10-26): la fuente versionada es la imagen, no un `.res`.**
> - Cada mapa guarda `scenes/map/maps/<tag>/heights.png`: PNG gris de 16 bits, valor × 0,1 m = altura (techo de unos 6553 m sin signo). También guarda `void.png`: 1 bit o 8 bits, blanco = vacío; la altura de abajo se conserva en `heights.png`.
> - Un `EditorImportPlugin` (`terrain_heights_importer`) importa el par como `TerrainHeights`. Es automático, como cualquier textura, y el multiplicador de altura está en el dock Import. El `.res` resultante vive en `.godot/imported`, no en git. Si `void.png` falta, no hay vacíos.
> - Un mapa de un usuario es copiar las dos imágenes a la carpeta del mapa, sin botón ni paso extra. Blender, los pinceles y cualquier editor de imágenes leen y escriben esos mismos PNG.
> - Para eso el códec PNG16 (`png16.gd`, lectura y escritura) sube de S4 a S3b. «Importar imágenes» deja de ser un paso aparte. Lo que queda en el inspector es «Abrir en Blender», «Traer de Blender» y «Suelo plano nuevo», y todos escriben los PNG.
> - Los `heights.res` commiteados en 81d3d6a4 se reemplazan por los PNG. El conversor desde el original escribe PNG.
>
> **Prioridad del usuario:** primero S1–S3 (la fuente única `heights.res`, la API clara y las constantes en un solo lugar). Evitar código poco claro, repeticiones y cualquier cosa que impida escalar. Guardar la sopa de triángulos derivada como fuente «tuvo que ser inaceptable desde el primer momento».

No toqué el repo. Corrí `bash tools/lint/conventions.sh` y todas las reglas están en OK contra la base (C1a 84, C12 70, C18 12, C21 1…).

**Qué leí:**
- `CONVENTIONS.md`, `RULES.md`, el plan 063 y la investigación de Scapex.
- Todo `scenes/map/terrain/`, incluido `mesh/`.
- Los que llaman al terreno: `hole_cutter`, `drop_dent`, `zone_erupt`, `zone_stamp_stop`, `volcano_look`, `volcano_zone.tscn`, `nav_service`, `map_nav_region`, `nav_fingerprint`, `bake_nav`, `minimap_terrain_bake`, `terrain_deform_texture` y su `.gdshaderinc`, `flora_field`, `flora_ground_watch`, `ground_snap`, `map_root`, `map_definition`.
- Las herramientas: `terrain_import.gd`, `bake/terrain_glb_export.gd`, `bake/import_terrain.gd`, `bake/make_flat_terrain.gd`, `ground_import.gd`, `tools/ground/*`, `tools/blender/*`, `tools/import/sac_formats/terrain.py`, `import_map.py` y `scaffold_map.py`.
- El addon `addons/sacrifice_tools` (`plugin.gd`, `dedicated_strip.gd`) y `export_presets.cfg`.
- Las pruebas: `terrain_cases`, `bore_cases`, `dent_cases`, `terrain_late_join`, `ground_surface_cases`, `ground_dump`, `terrain_bed.tscn`.
- Los mapas `high_noon`, `test_flat` y `test_flat4`, y el commit `a5f2edec` (063-2a).

## 0. Lo que encontré y cambia el diseño

1. **`terrain.res` no es una grilla.** Es una sopa de triángulos (3 vértices por triángulo, sin soldar, con las paredes de los acantilados mezcladas) que se arma con `sac_formats/terrain.py:hntr()`. Esa sopa sale entera de dos datos por vértice de la red 256²: la altura y el bit de vacío.
   - `get_faces` arma 2 triángulos por celda y elige la diagonal según los huecos.
   - `edge_wall_exists` arma 8 tipos de pared por celda.
   - **Consecuencia:** guardamos solo `heights` (alturas) y `void` (vacíos), y la sopa se deriva al cargar con un port exacto a GDScript. `TerrainRules.index`, `TerrainCollision`, `HoleWalls` y `FallingChunk` siguen igual porque consumen la misma sopa.
   - Editar el `terrain.glb` actual en Blender es inútil: hay que mover 6 vértices duplicados por punto. El plano de 256² soldado reemplaza al glb, y el glb sale del juego.
2. **`TerrainMeshArrays` promedia las normales con un `Dictionary`** sobre unos 230 000 vértices. Si la malla se arma al cargar, hay que promediarlas por id de la red (arrays), no por diccionario.
3. **Las constantes de la grilla (10 m, 256) aparecen en unos 15 lugares**, no 7: `TerrainRules`, `GroundField`, `HoleRules`, `HoleWallRules`, `FallingChunkRules`, `GroundTiles`, `TerrainCollision`, `TerrainMeshArrays` (literales `10.0`, `255` y `256`), `TerrainStamp`, `StampRules`, `StampCarry`, `HoleCutter`, el shader `terrain_deform.gdshaderinc` (`DEFORM_CELL`, `255`) y las herramientas.
4. **Archivos que ya no usa nadie:**
   - `scenes/map/terrain/terrain_probe.gd`: ninguna escena lo usa y aporta 2 conteos a C14.
   - `tools/bake/bake_terrain_collision.gd.uid`: un `.uid` sin su `.gd`.
5. **Volcano ya sincroniza su `pattern`** con `GroundZone.synced_on_change = "Mound:pattern"`. No se toca.

## 1. Contradicciones y quién gana

| Contradicción | Gana |
|---|---|
| `RULES.md:40` dice «el terreno es `terrain.glb`»; la decisión del 2026-10-26 dice que es la grilla 256² | El usuario: es lo más reciente. Se cambia RULES en la etapa 3 |
| El plan 063 (malla libre y cuevas, aprobado el 2026-10-24) y la memoria «Terreno de malla libre» | Quedan reemplazados. El orquestador marca el plan como *superseded* y actualiza la memoria |
| 062 y 063 querían `ground_roles.png` proyectado en el mundo (`ground_size_m`) | Ya no hace falta: 256² y 1 px = 10 m vuelve a ser la regla |
| El usuario propuso `stamp(profile, center, radius, peak, time)` | Agrego `key` (para reemplazar o quitar un sello en vivo) y `pattern` (Volcano). Sin `key` no se puede soltar un sello |
| «Las herramientas de edición viven en las escenas reales» frente a «`scenes/` no nombra `res://tools`» | Los botones aparecen en el inspector del nodo `Terrain` real, pero el código va en un addon solo de desarrollo (`addons/terrain_tools/`, excluido del export). Así se cumplen las dos |
| C6 (sin búsquedas de grupo por texto) frente a `Terrain.of(node)` | No hay contradicción: usa `const GROUP` en la clase dueña, como hoy |

## 2. Decisión de la API: un solo nodo `Terrain` por mapa

El lugar donde mira un humano es el nodo `Terrain` del `map.tscn`:
- en el inspector ve las alturas, los roles, la luz, el estado en vivo y los botones;
- en el código hay un archivo con toda la API pública.

**Qué cambia:**
- `GroundSurface` y `TerrainDeformer` se funden en `Terrain`.
- El `Terrain` de hoy (la malla) pasa a llamarse `TerrainMesh`.

**Por qué no las alternativas:**
- Una fachada nueva sumaría una capa más.
- Dejar la API en `TerrainDeformer` mantiene dos dueños (el que responde y el que escribe).

**Partes internas, cada una con una sola tarea:**
- `GroundField`: los números.
- `TerrainNet`: el transporte de red.
- `TerrainRules`, `StampRules` y `HoleRules`: la aritmética pura.

**La regla del árbol:** las llamadas bajan y las señales suben. `TerrainNet` emite y `Terrain` aplica, así que nada fuera de `Terrain` escribe el estado.

## 3. Contrato (firmas)

```gdscript
@tool
class_name Terrain extends Node3D
## The ground of a map: the one place that says how high the land is, where it has holes, and how it moved in the match.
## Everyone asks it; whoever moves the ground asks it to; it tells `changed` after. Not: the look (Mesh), the body to stand
## on (Collision), the network transport (Net), what a spell is.
signal changed(rect: Rect2)          ## metres xz, every peer
signal holes_changed(rect: Rect2)    ## a vertex came or went (Collision flushes now, NavService re-bakes)
const GROUP := &"terrain"

@export var heights: TerrainHeights  ## S3 (in S2 it is still `data: MapTerrainData`)
@export var tiles: Image             ## replaces @export_file tiles_path (C21) and the MapCatalog fallback (C18)
@export var ground_roles: Texture2D  ## moves here from the old Terrain: all of the ground's data in one place
@export var light_map: Texture2D
@export var mesh: TerrainMesh        ## socket, with a warning
@export var net: TerrainNet          ## socket, with a warning
@export var show_view := false       ## turns on `view`
@export_group("Estado (solo lectura)")   # @export_custom(..., PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY), getters only
var rev: int  ·  var version: int  ·  var live_stamps: PackedStringArray  ·  var holes: PackedInt32Array  ·  var view: Texture2D
var index: TerrainRules.Index        ## read only (HoleWalls, FallingChunk, HoleRules)

static func of(node: Node) -> Terrain
func is_loaded() -> bool
func height_at(x: float, z: float) -> float          ## NAN over a hole or off the map
func normal_at(x: float, z: float) -> Vector3
func is_on_ground(x: float, z: float) -> bool
func bounds() -> Rect2                               ## Rect2(0, 0, 2560, 2560)
func lowest() -> float
func sampler() -> Callable                           ## WorkerThreadPool-safe
func is_authority() -> bool
func field() -> GroundField                          ## read only (TerrainDeformTexture, tests)
# Edits: only lattice math inside; nobody outside sees a rect or an id
func stamp(key: StringName, profile: StampProfile, center: Vector2, reach_m: float, peak_m: float, at_s: float, pattern := PackedFloat32Array()) -> void   ## live, every peer
func unstamp(key: StringName) -> void
func keep_stamp(key: StringName, profile: StampProfile, center: Vector2, reach_m: float, peak_m: float, pattern := PackedFloat32Array()) -> void   ## server: stays, same bytes to the clients
func stamp_pattern(profile: StampProfile, center: Vector2, reach_m: float, peak_m: float) -> PackedFloat32Array   ## server: picture/flatten stamp worked out once
func cut_hole(center: Vector2, radius_m := 0.0) -> PackedVector3Array    ## server; 0 = nearest vertex; HoleRules filters; returns the points taken (y = lattice height, never NAN)
func fill_hole(center: Vector2, radius_m := 0.0) -> PackedVector3Array   ## server; only holes opened during the match, never a void of the map
```

**Las piezas de apoyo:**
- `TerrainGrid` (estático, `terrain_grid.gd`), el único lugar de las constantes:
  - `const SIDE := 256`, `CELL_M := 10.0`, `SIZE_M := 2560.0`;
  - `vertex_id(x, z)`, `vertex_of(id) -> Vector2i`, `point_of(v) -> Vector2`, `vertex_near(p) -> Vector2i`, `vertex_rect(center, radius_m) -> Rect2i`, `area_of(rect) -> Rect2`.
  - En el shader queda **una sola** copia comentada, que el caso de suite `grid_constants` compara contra `TerrainGrid`.
- `TerrainNet` (nodo hijo `Net`), el único con `@rpc` y `MpKit` (C12 igual):
  - señales: `kept_received(rev, key, rect, delta)`, `hole_received(rev, id, removed)`, `snapshot_received(data)`, `snapshot_wanted(peer_id)`;
  - métodos: `send_kept(...)`, `send_hole(...)`, `push_snapshot(peer_id, data)`;
  - RPCs `rpc_commit` y `rpc_removed`, y `SNAPSHOT_KEY := "terrain"`. **El formato en el cable y el snapshot no cambian.**
- `TerrainHeights` (Resource, `heights.res` por mapa):
  - `heights_m: PackedFloat32Array` (65 536 valores, fila por fila: z·256 + x);
  - `void_mask: PackedByteArray` (1 = vacío; la altura de abajo se conserva);
  - `is_valid()`, `height(v)`, `is_void(v)`, `checksum()`. **Nunca muta en partida.**
- `TerrainStamp` sigue siendo el nodo de autor:
  - `_physics_process` llama a `terrain.stamp`, `unstamp` y `keep_stamp`;
  - nace `leave_now()` para los sellos `manual` (DropDent);
  - `vertex_rect()` y `values_at()` dejan de ser públicos.
- Los hechizos:
  - Erupt, Volcano y Bombardment pasan por su `TerrainStamp`.
  - Bore (`HoleCutter`) llama a `Terrain.cut_hole` y `fill_hole`.
  - Un hechizo futuro hace lo mismo y no conoce ni ids ni rects.

## 4. Etapas, criterios medibles y escenas de prueba

| Etapa | Qué | Tamaño |
|---|---|---|
| S1 | Borrar el camino de malla de 063-2a | S |
| S2 | Constantes en un lugar y API `Terrain` | M |
| S3 | `heights.res` como fuente, árbol final y malla armada de las alturas | M-L |
| S4 | Imágenes del mapa e ida y vuelta con Blender | M |
| S5 | Pinceles en el editor (conjunto mínimo) | M |
| S6 | Validación después de editar, aplanado de bases y refresco | S-M |

### S1 — Borrar el camino de malla (063D)

**Objetivo:** queda solo la grilla y se conserva lo que ganó 063-1 (`bounds`, `normal_at`, `version`, `GroundField.size`/`cell_m`).

**Criterios:**
1. `grep -rE "MeshGround|GroundCollision|mesh_data|ground_import|GroundBackend|GridGround|mesh_test|ground_soup|ground_chunks|ground_subdivide|export_ground|make_mesh_test|run_063_2a" scenes tools debug agent data .gitignore` da 0.
2. `ground_dump` es **igual bit a bit** contra un volcado tomado justo antes del corte (`ground_dump_before.json`). El orquestador lo toma antes de lanzar S1.
3. `rules_suite --only=terrain` da PASS y `terrain_late_join` da `TERRAIN NET PASS`.
4. El lint no sube, y C14 baja 2 por `terrain_probe`.

**Escena de prueba:** el criterio ya arranca en `debug/spells/cast_terrain.tscn` (F6). No se inventa otra.

### S2 — Grilla en un lugar y API `Terrain` (063D-2a/b/c)

**Criterios:**
1. `grep -rnE "TerrainRules\.(CELL|GRID)|GroundField\.(SIDE|COUNT)|vertex_rect\(|HoleRules\.vertex_near|TerrainDeformer|GroundSurface" scenes` da 0. Los literales `10.0`, `255` y `256` de la red solo quedan en `terrain_grid.gd` y en la copia del shader.
2. Fuera de `scenes/map/terrain/` no aparece `Rect2i` del terreno ni ids de vértice (grep en `scenes/spells` da 0).
3. `ground_dump` es igual bit a bit.
4. Pasan `terrain_cases`, `bore_cases` y `dent_cases` (reescritos a la API), y `terrain_late_join` da el mismo checksum.
5. El inspector remoto, con F5 en `cast_terrain` y Erupt lanzado, muestra:
   - en `live_stamps`, las 3 claves (Mound, Rebound, Wave) durante el hechizo;
   - después, `rev` igual a 1 + la cantidad de sellos que quedan.
6. El lint baja: C1a −1 (`hole_cutter` 152 → ~110), C18 −3, C21 −1, C15 −2 (`make_collision_body`), C9 −1.

**Escena de prueba:** `debug/spells/cast_terrain.tscn`, la que ya existe.
- **Estado inicial:** High Noon sin deformar y el mago en Start1.
- **Lo que todavía no está:** el montículo.
- **El playtester** pulsa `spell_N` (Erupt) y hace clic en el llano. Se verifica con el Remote → `Terrain`.

### S3 — `heights.res` es la fuente y el árbol final (063D-3a/b)

**Criterios:**
1. **Paridad de caras.** En los 7 mapas del original, la sopa derivada de `heights.res` tiene el mismo multiconjunto de triángulos que el `terrain.res` de hoy, comparando las posiciones redondeadas a 1e-4 y separando suelo y paredes. Además, `ground_dump` da igual bit a bit.
   - Excepción de `test_flat` y `test_flat4`: en `height_at`/`is_on_ground` dan igual, pero ganan paredes en el borde.
2. **Carga.** `Terrain`, `Mesh` y `Collision` listos en ≤ lo de hoy + 200 ms en `high_noon` y `winter_wonder` (el que más tierra tiene, 59 %).
3. **Dedicado.** El dedicado no arma malla (`Mesh.mesh == null` sin ventana) y su RSS queda ≤ la base de 379 MB.
4. **Grep.** `grep -rE "terrain\.glb|terrain\.res|terrain_import|terrain_glb_export|import_terrain|make_flat_terrain|MapDefinition.*terrain" scenes tools debug data` da 0.
5. **Navmesh.** El navmesh se rehornea en los 9 mapas: polígonos ±2 % y `bake_nav --check` reproducible.
6. **Capturas.** `match_shots` con cámara fija en `high_noon`: ≤ 0,5 % de píxeles con ΔE > 8 contra antes.

**Escena de prueba:** el mapa real `scenes/map/maps/high_noon/map.tscn`. Al abrirlo en el editor, el nodo `Terrain` muestra `heights` y la malla se ve. Con F6 se abre el mapa. La paridad corre sin ventana con `debug/terrain/faces_parity.gd`.

### S4 — Imágenes del mapa e ida y vuelta con Blender (063D-4a/b/c)

**Criterios:**
1. EXR → `heights.res`: el checksum es exacto.
2. PNG16 con multiplicador de 0,1 m: |Δ| ≤ 0,05 m.
3. `void.png`: igual bit a bit.
4. Blender sin editar (`.blend` → imágenes → `heights.res`): el checksum es igual.
5. **Fallos con nombre** (código de salida 1 y `heights.res` sin tocar):
   - un vértice movido en xz;
   - faltan vértices;
   - el objeto tiene transformación;
   - un `PlayerStart` o un manantial quedan sobre un vacío (se nombra la ruta, por ejemplo `MapProps/Starts/Start1`);
   - `heights.res` cambió en Godot después de exportar (guardia por hash).
6. Un comando o un botón por sentido.

**Escena de prueba:** `debug/terrain/edit_bed.tscn`.
- Instancea `scenes/map/terrain/terrain.tscn` con `debug/terrain/bed_heights.res`: una isla plana de 600 × 600 m a 10 m, sin huecos, con un `PlayerStart` y un `Manafount`.
- **Lo que todavía no está:** la loma, el hueco o el cráter que trae la vuelta.
- Es una herramienta de editor y no hay acción de InputMap: el humano aprieta los botones del inspector.

### S5 — Pinceles mínimos (063D-5a/b)

**Criterios** (`debug/terrain/brush_cases.gd`, sin ventana, sobre `bed_heights`):
1. Subir con un arrastre de +100 px a 0,1 m/px y tamaño 50 m: el centro sube +10 ± 0,01 m y en el borde del tamaño queda en 0.
2. Suavizar 10 pasadas: la varianza de una zona con ruido baja al menos un 50 %.
3. Shift + suavizar: los vértices con peso 1 quedan a la altura del punto de inicio ± 1e-4.
4. Pincel de hueco: `void_mask` es exactamente igual a la forma; Shift rellena y vuelve la altura de antes.
5. Deshacer (Ctrl+Z) deja el checksum exacto; rehacer da el mismo de después.
6. Rearmar la malla al soltar ≤ 300 ms. Si se pasa, se rearma al guardar (ver pregunta 6).

**Escena de prueba:** `edit_bed.tscn` en el editor. El humano selecciona `Terrain` y pinta.

### S6 — Validación y refresco (063D-6a/b/c)

**Criterios:**
1. «Validar mapa» da PASS en los 9 mapas.
   - Los objetos tienen que estar sobre tierra.
   - Los `GroundFootprint` tienen que estar a nivel: dispersión ≤ 0,5 m (NO VERIFICADO; lo ajusta el usuario).
   - Cada altar tiene que estar en el mismo componente del navmesh que cada manantial, con un camino de largo finito.
2. En `edit_bed`, con un vacío pintado bajo el manantial, falla nombrando el nodo.
3. «Aplanar bases»: el rango de alturas bajo cada footprint queda ≤ 0,05 m, y Ctrl+Z lo restaura exacto.
4. Después de un trazo, la flora del editor se replanta: cada planta queda a |y − `height_at`| ≤ 0,3.
5. El navmesh avisa «viejo» después de guardar alturas nuevas, porque `NavFingerprint` toma el hash de `heights.res`.
6. `debug/terrain/fall_duel.tscn` sobre `edit_bed` editado: 3 min de IA 1v1 con FallCheck = 0.

## 5. Árbol de archivos por etapa

### S1

```
game/scenes/map/terrain/
  [-] mesh/ground_collision.gd, mesh_ground.gd, mesh_ground_data.gd, mesh_ground_rules.gd (+ .uid)
  [-] ground_backend.gd, grid_ground.gd (+ .uid)     the backends go: the surface asks TerrainRules directly again
  [-] terrain_probe.gd (+ .uid)                       nobody uses it (C14 −2)
  [~] ground_surface.gd                               grid only (index + field + TerrainRules); without mesh_data or _reindex picking
  [~] README.md                                       drops the 063-2a block, «Add a mesh map» and the duplicated block (lines 7-11)
game/scenes/map/map_root.gd                    [~] `terrain: Terrain` again (it was Node3D for the mesh)
game/scenes/map/maps/mesh_test/                [-] the whole folder (ground.glb, .import, ground.res, map.tscn, mesh_test.tres, nav.res)
game/tools/ground_import.gd (+ .uid)           [-]
game/tools/ground/                             [-] ground_chunks, ground_soup, ground_subdivide (+ .uid)
game/tools/blender/                            [-] export_ground.py, make_ground_template.py, make_mesh_test.py  ([ ] make_test_creature.py stays)
game/tools/bake/bake_terrain_collision.gd.uid  [-] orphan uid
game/tools/README.md                           [~] lines 11-12
game/debug/map/                                [-] mesh_ai_duel.tscn, mesh_ground_cases.gd, mesh_ground_ray.gd (+ .uid), mesh_test_spec.json
game/debug/map/fall_watch.gd                   [~] stays (generic: counts bodies that fall); doc without «mesh map» (S6 reuses it)
game/debug/rules/ai_mesh_duel.tres             [~→] ai_duel_quiet.tres (2 AIs without NPCs; S6 reuses it)
game/debug/map/ground_dump.gd                  [~] drops the filter of maps with ground.glb
game/agent/runs/run_063_2a.sh                  [-]
game/.gitignore                                [~] drops `!scenes/map/maps/*/ground.glb.import`
game/rfcs/plans/063-mesh-ground-plan.md        [~] header «Reemplazado por 063D (2026-10-26)»
```

### S2

```
game/scenes/map/terrain/
  [+] terrain_grid.gd       TerrainGrid: SIDE, CELL_M, SIZE_M and the lattice math (id, vertex, point, rect, area). Static, the one place.
  [~→] terrain.gd → terrain_mesh.gd      TerrainMesh (MeshInstance3D): shows the ground; the material swap. Keeps the uid (first move).
  [~→] ground_surface.gd → terrain.gd    Terrain: the owner and the whole API (queries + edits + inspector). Keeps the uid of ground_surface (second move).
  [-] terrain_deformer.gd (+ .uid)       its API goes into Terrain, its transport into TerrainNet
  [+] terrain_net.gd        TerrainNet: @rpc commit/removed + MpKit snapshot; emits up, decides nothing
  [~] ground_field.gd       without SIDE/COUNT/vertex_rect (TerrainGrid); the rest the same
  [~] terrain_rules.gd      without CELL/GRID/vertex_id → TerrainGrid
  [~] terrain_stamp.gd      calls terrain.stamp/unstamp/keep_stamp/stamp_pattern; + leave_now(); rect and values private
  [~] stamp_rules.gd, stamp_carry.gd, hole_rules.gd (+ static parts_of(tree): the building parts, moved from HoleCutter)
  [~] hole_wall_rules.gd, falling_chunk_rules.gd, ground_tiles.gd (tiles: Image, without MapCatalog), terrain_collision.gd, terrain_mesh_arrays.gd   → TerrainGrid
  [~] hole_walls.gd, ground_scars.gd, falling_chunk.gd   socket `terrain: Terrain`; FallingChunk takes params {"at": Vector3}, not an id
  [~] README.md             What/Not/Talks to/Edit/Check with Terrain
game/scenes/spells/zones/hole_cutter.gd        [~] only cut_hole/fill_hole; signals hole_cut(at)/hole_filled(at); no ids or _building_parts
game/scenes/spells/drops/drop_dent.gd          [~] stamp.leave_now()
game/scenes/look/ground/terrain_deform.gdshaderinc   [~] comment «mirror of TerrainGrid» (one copy)
game/scenes/** (≈22) + debug/** + agent/** (≈60)      [~] GroundSurface.of → Terrain.of; sockets GroundSurface → Terrain (mechanical, separate commit)
game/scenes/map/map_root.gd, look/look_rig.gd, map/nav/nav_service.gd, ui/minimap/minimap_terrain_bake.gd   [~] one socket `terrain: Terrain` (MapRoot.ground disappears)
game/scenes/look/ground/terrain_layer.gd, look/grass/grass_field.gd, components/ground_snap.gd   [~] cast to TerrainMesh / Terrain.GROUP
game/scenes/map/maps/*/map.tscn (×9), debug/map/terrain_bed.tscn   [~] swap scripts: the Shape node now has terrain.gd, the glb node terrain_mesh.gd, Deformer → Net (interim tree)
game/debug/suite/terrain_cases.gd, bore_cases.gd, dent_cases.gd   [~] through the API; the net case drives Net the way the RPC does
game/debug/suite/grid_constants_cases.gd       [+] TerrainGrid against the shader include and against `bounds()`
```

### S3

```
game/scenes/map/terrain/
  [+] terrain_heights.gd    TerrainHeights (Resource): heights_m + void_mask 256², checksum. Never mutated in a match.
  [+] terrain_faces.gd      TerrainFaces (static): port of hntr() — land faces (get_faces) + walls (8 slots), in the same order → MapTerrainData in memory
  [+] terrain.tscn          the packed scene: Terrain + Mesh + Collision + Net + HoleWalls + GroundScars + Missing (a map only puts in its data)
  [~] terrain.gd            `heights` replaces `data`; derives faces + index once; in the editor again on heights.changed
  [~] terrain_mesh.gd       without glb: builds from terrain.faces(); nothing without a window; without editor_preview_recenter (moves to MapRoot)
  [~] terrain_mesh_arrays.gd   smooth normals by lattice id (arrays, no Dictionary)
  [~] map_terrain_data.gd   doc: derived in memory, never saved (C9 −1)
  [~] terrain_collision.gd  reads terrain.faces()
game/scenes/map/map_root.gd            [~] + editor_recenter (taken from TerrainMesh; the root moves itself)
game/scenes/map/map_definition.gd      [~] − `terrain` (and the line in the 9 <tag>.tres)
game/scenes/map/nav/nav_fingerprint.gd [~] a Terrain node puts the sha256 of its heights.res in (no more glb)
game/scenes/map/maps/<tag>/heights.res [+] ×9 (made once by the converter)
game/scenes/map/maps/*/map.tscn (×9)   [~] the Terrain subtree → an instance of terrain.tscn with heights/tiles/roles/light/material
game/assets/original/maps/<7 tags>/    [-] terrain.res, terrain.glb, terrain.glb.import   ·   scenes/map/maps/test_flat/terrain.res [-]
game/addons/sacrifice_tools/dedicated_strip.gd   [~] MESH_KEEP_DIRS without the map (the server no longer reads the ground mesh); doc
game/tools/terrain/heights_from_faces.gd   [+] one-shot converter terrain.res → heights.res (hidden heights: see question 2); deleted when S3 closes
game/tools/import/import_map.py, sac_formats/terrain.py   [~] `--heights-bin` (the raw grid, base subtracted from voids too); hntr/walls go out (the port is in GDScript)
game/tools/terrain_import.gd, bake/terrain_glb_export.gd, bake/import_terrain.gd, bake/make_flat_terrain.gd   [-] (+ .uid)
game/tools/import/scaffold_map.py      [~] writes heights.res (via the CLI) and instances terrain.tscn; without terrain.glb.import
game/agent/tools/terrain_asset.py      [~] reads heights.res (2 arrays) or [-] if nobody uses it (check the callers)
game/debug/suite/terrain_bake_cases.gd [-]   ·   debug/map/terrain_shape.gd/.tscn, terrain_normals_probe.gd, terrain_reference.res: [~] to heights or [-] if they only read the old soup
game/debug/terrain/faces_parity.gd     [+] headless: the soup derived from the 7 maps against terrain.res (runs BEFORE deleting them)
game/debug/map/terrain_bed.tscn        [~] instances terrain.tscn
game/RULES.md                          [~] «el terreno es la grilla 256² de `heights.res` (scenes/map/maps/<tag>/)»
```

### S4

```
game/addons/terrain_tools/              [+] new addon, dev only (added to exclude_filter and to editor_plugins)
  plugin.cfg, plugin.gd                 registers the inspector and (S5) the brush
  terrain_inspector.gd                  EditorInspectorPlugin: on Terrain, «Exportar imágenes», «Importar imágenes», «Abrir en Blender», «Traer de Blender», «Suelo plano nuevo»
  map_images.gd                         heights ↔ heights.exr (exact) / heights.png (16 bits × multiplier) / void.png / roles (ground_roles.png)
  png16.gd                              16-bit grey PNG codec (zlib through PackedByteArray.compress, CRC, the 5 filters): Godot reads 8 bits only
  terrain_import_check.gd               refuses with a name: lattice, finite heights, missing vertices, objects over a void, stale hash
  blender_bridge.gd                     Blender from $BLENDER or the PATH (without one: a message saying how); runs the scripts
game/tools/terrain/terrain_cli.gd       [+] headless: --map=<tag> --export-images | --import-images [--force] | --to-blend | --from-blend | --flat=<m>
game/tools/blender/terrain_common.py    [+] SIDE, CELL and axes (Blender X = x, Y = −z, Z = height): the one Python copy
game/tools/blender/terrain_make_blend.py     [+] images → terrain.blend: «Terrain» plane 256² vertices at 10 m, vertex group «void», color attribute «roles», «VoidPreview» GN modifier (hides void faces)
game/tools/blender/terrain_export_images.py  [+] .blend → images + manifest.json (hash, count); validates and fails with a message
game/scenes/map/maps/<tag>/terrain_work/     working folder with .gdignore, ignored by git (.gitignore [~])
game/debug/terrain/edit_bed.tscn, bed_heights.res   [+] the bed (S4 and S5)
game/debug/terrain/roundtrip_cases.gd        [+] exact EXR, PNG16 ±0.05, void, the named failures
game/agent/runs/run_terrain_blender.sh       [+] Blender round trip without edits (needs Blender)
```

### S5

```
game/addons/terrain_tools/brush/
  [+] terrain_brush.gd       TerrainBrush (Resource): size_m, falloff 0-1, shape (circle, square, cross), strength_m
  [+] default_brush.tres     the default brush; a preset = another .tres
  [+] brush_rules.gd         pure: weights(brush, center, rect), raise, smooth, flatten(target), paint_void/fill
  [+] brush_stroke.gd        one stroke: mode, start height, working copy, dirty rect, patch for undo
  [+] brush_cursor.gd        ring on the relief (RenderingServer, not a node of the scene)
  [+] brush_toolbar.tscn/.gd tools and knobs in CONTAINER_SPATIAL_EDITOR_MENU (labels in Spanish)
  [+] editor_preview.gd      during the stroke: the shift goes in the global terrain_deform_map in the editor (the shader already reads it)
  [~] plugin.gd              _handles(Terrain), _forward_3d_gui_input, _save_external_data (saves heights.res), EditorUndoRedoManager
game/debug/terrain/brush_cases.gd  [+]
```

### S6

```
game/scenes/map/props/ground_footprint.gd   [+] GroundFootprint (CollisionShape3D, Box): the base that must lie level; const GROUP
game/scenes/map/props/altar.tscn, manafount.tscn   [~] + GroundFootprint child (size by gizmo; NO VERIFICADO against BASE TILES 8×8)
game/addons/terrain_tools/terrain_inspector.gd     [~] + «Aplanar bases» (brush_rules.flatten, undoable), «Validar mapa»
game/tools/audit/check_map_starts.gd → check_map.gd   [~→] + objects over land, level footprints, altar↔fount reachability (NavRegions component + path)
game/scenes/look/vegetation/flora_field.gd          [~] follows Terrain in the editor too (replans on changed)
game/debug/terrain/fall_duel.tscn                   [+] FallWatch + ai_duel_quiet.tres on edit_bed
```

## 6. Árbol de nodos de un `map.tscn` al terminar

```
Map (MapRoot)  terrain → Terrain · editor_recenter
├── Look (LookRig)  terrain → ../Terrain
├── Terrain  [instance of scenes/map/terrain/terrain.tscn · group nav_source]   (Terrain)
│     heights = heights.res · tiles = tiles.png · ground_roles = ground_roles.png · light_map = light.png
│     Estado (solo lectura): rev · version · live_stamps · holes · view   |   (addon) Exportar/Importar imágenes · Abrir/Traer de Blender · Aplanar bases · Validar mapa
│   ├── Mesh (TerrainMesh, MeshInstance3D)   material_override = ground_classic.tres · smooth_ground
│   ├── Collision (TerrainCollision, StaticBody3D)   chunk_cells 8 · refresh_s 0.05
│   ├── Net (TerrainNet)
│   ├── HoleWalls (HoleWalls)
│   ├── GroundScars (GroundScars)
│   └── Missing (Label3D)
├── MapProps/Starts/StartN (PlayerStart) ── Altar ── GroundFootprint      · Founts/FountN (Manafount) ── GroundFootprint
├── Buildings · Npcs · Props · Vegetation/FloraLayer…
├── NavRegion (MapNavRegion)  «Hornear navmesh»
└── MinimapBake (MinimapTerrainBake)  terrain → ../Terrain
```

## 7. Responsabilidades: qué hace y qué no

| Pieza | Hace | No hace | Tipo |
|---|---|---|---|
| `Terrain` | Responde alturas; es el único que escribe; muestra el estado; emite `changed` | Dibujar, chocar, transportar por red | Nodo |
| `TerrainMesh` | Arma y muestra la malla; cambia el material | Responder alturas | Nodo |
| `TerrainCollision` | Rehace la colisión por trozos con `changed` | Decidir cómo se mueve el suelo | Nodo |
| `TerrainNet` | RPC y snapshot | Aplicar nada (emite hacia arriba) | Nodo |
| `TerrainStamp` | Cuándo y cuánto aprieta un sello (gizmo `Reach`) | Las cuentas de la red | Nodo |
| `HoleCutter` | La espiral de Bore y sus efectos | Ids, reglas del hueco | Nodo |
| `GroundFootprint` | La base que tiene que quedar a nivel (gizmo) | Aplanar sola en partida | Nodo |
| `TerrainHeights` | La forma del mapa | Cambiar en partida | Resource |
| `StampProfile` | Las curvas o la imagen de un sello | El tamaño (lo da `Reach`) | Resource embebido |
| `TerrainBrush` | Tamaño, caída, forma y fuerza del pincel | Pintar | Resource del addon |
| `GroundField` | Permanente, vivo, huecos, snapshot | Decidir quién escribe | RefCounted |
| `TerrainGrid`, `TerrainFaces`, `TerrainRules`, `StampRules`, `HoleRules`, `BrushRules` | Aritmética pura | Tocar el árbol | static |

**`@export` de instancia:**
- `Terrain`: `heights`, `tiles`, `ground_roles`, `light_map`, `show_view`.
- `Mesh`: `material_override`, `smooth_ground`.
- `Collision`: `chunk_cells`, `refresh_s`.
- Sello: `keep`, `start_s`, `min_step_m`, `manual`.
- Footprint: el tamaño de la caja.

Ningún `.tres` de `data/` guarda posiciones (C19).

## 8. Cómo lo hace un humano

| Verbo | Dónde mira o toca exactamente | Lugares |
|---|---|---|
| Entender | `map.tscn` → nodo `Terrain` → inspector (datos, estado, botones) · `scenes/map/terrain/README.md` · la API entera en `terrain.gd` | 1 |
| Modificar la forma | Seleccionar `Terrain` → pincel en la barra del 3D (S5), o «Abrir en Blender» / «Traer de Blender» o «Exportar / Importar imágenes» (S4) → «Hornear navmesh» en NavRegion | 1-2 |
| Modificar un sello | La escena del hechizo → `TerrainStamp`: el gizmo `Reach` y las curvas del `StampProfile` | 1 |
| Agregar | El suelo de un mapa nuevo: «Suelo plano nuevo» en el inspector (o `terrain_cli --flat`) y la instancia de `terrain.tscn` que ya pone `scaffold_map`. Un hechizo de terreno: un nodo `TerrainStamp` o `HoleCutter` en su zona, sin código | 1-2 |
| Quitar | Borrar el nodo del sello · pincel de hueco · vaciar `heights` (aparece `Missing`) | 1 |
| Crear | Un `StampProfile` nuevo (curvas o imagen) en el inspector · un preset de pincel = otro `.tres` | 1 |
| Escalar | Más mapas = más carpetas; más hechizos = más nodos. **Un mapa más grande que 256² no:** el tamaño es una constante en `TerrainGrid`, más la copia del shader, más los datos | — |
| Encontrar un bug | Remote → `Terrain` (`rev`, `live_stamps`, `holes`, `view`) · F6 en `debug/spells/cast_terrain.tscn` · `rules_suite --only=terrain` · `terrain_late_join` (checksum) · `ground_dump` (paridad) · «Validar mapa» | 1 |

## 9. Subcortes, dependencias y paralelo

Los developers no corren Godot. El orquestador prueba todo al final.

| Subcorte | Depende de | En paralelo con |
|---|---|---|
| S1 | — (primero, solo) | — |
| S2a (grilla) | S1 | S3a |
| S2b (API y renombres; dos movimientos de `.uid` en orden: primero `terrain` → `terrain_mesh`, después `ground_surface` → `terrain`) | S2a | S3a, S4b |
| S2c (renombres mecánicos de los que llaman; commit en `.git-blame-ignore-revs`) | S2b, mismo developer | — |
| S3a (`TerrainHeights`, `TerrainFaces`, convertidor, `faces_parity`; archivos nuevos solamente) | S1 | S2 |
| S3b (pasar la fuente, `terrain.tscn`, borrar el pipeline del glb) | S2c, S3a | S4a, S5a |
| S4a (`png16`, `map_images`, `import_check`, puros) | S3a | S3b, S5a |
| S4b (scripts de Blender, Python) | contrato de S3a | todo |
| S4c (inspector y CLI) | S3b, S4a | S5b |
| S5a (`brush_rules` y `TerrainBrush`, puros) | S3a | S4 |
| S5b (plugin, vista previa, deshacer) | S3b, S5a | S4c |
| S6a (`GroundFootprint` y aplanar) | S5a | S6b |
| S6b (`check_map`) | S3b | S6a |
| S6c (flora en el editor) | S3b | S6a |

**Pasada final del orquestador:**
1. Import una vez.
2. `ground_dump` (antes contra después).
3. `rules_suite --only=terrain`.
4. `terrain_late_join`.
5. `faces_parity`.
6. `roundtrip_cases`.
7. `brush_cases`.
8. `run_terrain_blender.sh`.
9. `check_map` × 9.
10. `bake_nav --check` × 9.
11. `fall_duel`.
12. `match_shots` en `high_noon`.
13. Dedicado (RSS).

## 10. Tests

**Existentes, adaptados:** `terrain_cases`, `bore_cases`, `dent_cases`, `terrain_late_join`, `ground_surface_cases` y `ground_dump`.

**Nuevos:**
- `grid_constants_cases`, `faces_parity`, `roundtrip_cases`, `brush_cases`.
- `check_map`, ampliado.
- `fall_duel`.

**Borrados:** `mesh_ground_cases`, `mesh_ground_ray` y `terrain_bake_cases`.

El banco de determinismo sigue pospuesto, según la memoria.

## 11. Pinceles en el editor: complejidad honesta

| Pieza | Tamaño |
|---|---|
| EditorPlugin con `_handles(Terrain)` y `_forward_3d_gui_input` | S |
| Rayo al suelo: marchar sobre el rayo de la cámara con `height_at` (sin física en el editor) | S |
| Recurso `TerrainBrush` y `BrushRules` (pesos, subir, suavizar, aplanar, vacío) | S |
| Trazo: arrastre vertical como en Scapex, Shift para aplanar a la altura del inicio, hueco con Shift para rellenar | M |
| Vista previa en vivo con el global `terrain_deform_map` del editor (no se rearma la malla por cada movimiento) | S-M, NO VERIFICADO que el material del editor lo lea |
| `EditorUndoRedoManager` por trazo: guarda solo el parche del rect | S |
| Guardar `heights.res` en `_save_external_data` | S |
| Refresco al soltar: reindexar y rearmar la malla (≤ 300 ms o al guardar) · flora (S6c) · aviso del navmesh (fingerprint). La colisión del editor no hace falta: el horneado la arma sin ventana desde `heights.res` | M |
| Cursor sobre el relieve | S |
| Barra de herramientas | S |
| Pintar roles en `ground_roles.png` (Image, reimportar, vista previa con textura) | M |
| Aplanar la huella de altares y manantiales | S (botón de S6) |
| Validar caminos | S (S6b) |

**Total:** el conjunto mínimo (subir y bajar, suavizar y aplanar, hueco y relleno, pincel compartido, deshacer) es **M**, unas 8 piezas y unas 700 líneas. Con roles y cursor pulido es **L**.

**Recomendación:**
- **Ahora,** el conjunto mínimo (S5), en paralelo con S4, apenas cierre S3b.
- **Después,** pintar roles: las imágenes y Blender ya lo cubren.
- Al terminar S5, «Probar sello aquí» (un `@export_tool_button` en `TerrainStamp`) sale barato porque usa la misma vista previa. Sin esa vista previa no lo es.

## 12. Riesgos

- **Renombrar unos 100 archivos.** Los dos movimientos de `.uid` van en orden, con `move_map.py --check --lint` en 0 después de cada uno.
- **Armar la malla al cargar.** El criterio es +200 ms. Si se pasa, el respaldo es una caché derivada `terrain_mesh.res` con el hash de las alturas.
- **EXR** en el binario sin ventana de 4.7.2: NO VERIFICADO. El respaldo es usar solo PNG16.
- **`compress(DEFLATE)`** como stream zlib válido para un PNG: NO VERIFICADO.
- **Blender 4.x:** pintar `color_attributes` y el modificador GN armado por script.
- **Alturas ocultas de los vacíos que ya existen** (pregunta 2).
- **`@export_custom` de solo lectura** en el inspector remoto: los números se ven, pero la vista previa de la textura `view` en remoto es NO VERIFICADO.
- **Navmesh viejo** después de editar, hasta que se rehornea: hay aviso y validación, pero el horneado no es automático.
- **`terrain.gd` cerca de 150 líneas.** Si se pasa, el bloque del estado sale a un hijo `Status` (`@tool`) que lee `Terrain`.

## 13. Fuera de alcance

- Cuevas y voladizos.
- Un SIDE o un CELL por mapa.
- Pintar los tiles del original (`tiles.png`) y el pincel de luz de Scapex.
- El pasto.
- LOD o malla por trozos.
- Unificar los huecos de Bore con los vacíos del archivo.
- Límites de cámara.

## 14. Preguntas al usuario (con mi recomendación)

1. **¿Renombramos `GroundSurface` → `Terrain` y el `Terrain` de hoy → `TerrainMesh`?** Son unos 100 archivos de cambio mecánico. **Recomiendo que sí:** «el terreno del mapa es el nodo `Terrain`» se entiende sin leer nada.
2. **Alturas ocultas bajo los vacíos de los 7 mapas.** O exactas desde el `.scp` (necesita el juego una sola vez; el resultado queda versionado), o rellenadas por difusión desde la tierra vecina (portable). **Recomiendo las exactas una vez, y difusión para los mapas de prueba.**
3. **Formato de intercambio.** **Recomiendo EXR por defecto** para Blender, porque es exacto, y PNG16 ×0,1 m para cualquier editor de imágenes.
4. **¿Versionamos el `.blend`?** **Recomiendo que no:** la verdad es `heights.res` y `terrain_work/` queda ignorada por git.
5. **¿Pinceles ahora?** **Recomiendo el conjunto mínimo justo después de S3b.** Roles y «Probar sello aquí», después.
6. **¿Rearmar la malla al soltar cada trazo?** **Recomiendo medirlo:** si tarda ≤ 300 ms, al soltar; si no, al guardar. La vista previa en vivo va siempre por la textura.
7. **`test_flat` y `test_flat4` van a ganar paredes de acantilado en el borde.** **Recomiendo aceptarlo.**
8. **¿Roles en Blender como color por vértice?** **Recomiendo que sí, opcional:** 1 vértice = 1 px de `ground_roles.png`.
9. **¿Tolerancia para «base a nivel»?** **Recomiendo 0,5 m.** Es NO VERIFICADO contra el original, que solo dice «los 4 pilares a nivel».
