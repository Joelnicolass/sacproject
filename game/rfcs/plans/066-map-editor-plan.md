# Plan 066: editor de mapas (Mapa nuevo, pincel de flora, pincel de roles)

Estado: **propuesto**, espera el OK del usuario.

Este es el plan para tres herramientas en el editor: «Mapa nuevo», pintar flora y pintar roles del suelo. No toqué el repo y no corrí Godot. Una nota previa: `game/debug/terrain/edit_bed.tscn` hoy apunta al `ground_roles.png` de `test_flat`. Si alguien pinta roles en ese banco, sobrescribe el PNG de `test_flat`. Por eso el plan arma un banco nuevo con su propia imagen.

Lo leí todo: `CONVENTIONS.md` (§2b y §2c), el plan 063D, `scapex-terrain.md`, el addon `terrain_tools` completo, vegetación, suelo, mapa, catálogo y `check_map*`. También `scaffold_map.py`, `test_flat`, `edit_bed`, la sonda `terrain_brush_probe` y el lint, que hoy está verde.

Lo llamo **plan 066 (editor de mapas)**, porque el último plan es el 065.

---

## 0. Contradicciones y quién gana

| # | Choque | Gana | Por qué |
|---|---|---|---|
| 1 | Pedís un `void.png` plano en el template. Pero `MapImages` lee «sin `void.png`» como «sin vacío», y `TerrainHistory.save` borra `void.png` cuando no hay vacíos. | **MapImages (contrato de 063D S4)** | El template no trae `void.png`; aparece cuando pintás el primer hueco. Si viniera, el primer Ctrl+S lo borraría y ensuciaría el git (pregunta 1). |
| 2 | `MapCatalog.all_tags()` registra toda carpeta que tenga `<tag>/<tag>.tres`. | **El catálogo** | `_template/` no trae `_template.tres`: lo escribe la acción. Así el template no aparece en salas ni en `check_map`. Solo `debug/map/ground_dump.gd` recorre todas las carpetas: tiene que saltear las que empiezan con `_`. |
| 3 | `scaffold_map.py` arma la `MapDefinition` con `tiles` y `light` de `assets/original`. | **Portable y C13** | Un mapa nuevo no lee nada del original, igual que `test_flat.tres` (sin `tiles` ni `light`). El script queda solo para los mapas importados. De él reuso el diseño del árbol y del `.tres`, no el código: Python no corre portable dentro del editor. |
| 4 | El 063D (§11) decía «pintar roles: después», y en §13 dejaba fuera los tiles del original. | **Tu pedido** | Los roles no son los tiles del original. Lo que §13 excluye (`tiles.png`, pincel de luz) sigue fuera. |
| 5 | §4 de CONVENTIONS y el doc de `FloraLayer` dicen «pintá `density` en cualquier editor de imágenes». | **Conviven** | El PNG sigue siendo la única fuente: Krita y el pincel escriben el mismo archivo. Solo se actualiza el doc. |
| 6 | Pedís «la flora se replanta en vivo». Hoy `FloraLayer._changed()` llama a `FloraField.layers_changed()`, que sube `_density_version`: cambia la firma y se **reconstruyen todos los planters**. | **Tu pedido** | Hace falta un camino parcial nuevo (§6, «flora»): una copia nueva de la densidad y `replan(area)` con el mismo freno de `FloraGroundWatch`, sin rearmar los planters. |
| 7 | En el editor, los roles solo se ven con un `GodGround`, y hoy el único es `data/look/persephone.tres`. Con `Look.preview_god` vacío se ve el suelo clásico, que no lee `ground_roles`. | **Ninguno; hay que avisar** | El template trae `preview_god = Persephone` (pregunta 5). El tooltip de la herramienta lo dice. |
| 8 | `ground_roles.png` de los mapas importados sale de `bake_ground_roles.py`. | **La mano, una vez pintado** | Si se vuelve a correr el script, pisa lo pintado. Va un aviso en el README y en el doc del script (pregunta 12). |
| 9 | Según la memoria, los developers no corren Godot y todo se prueba al final. Pero hornear el navmesh y «Validar mapa» necesitan Godot. | **La memoria** | Esos criterios se verifican en la pasada final (§10). |

---

## 1. Objetivo

- **«Mapa nuevo…»** (Proyecto → Herramientas). Pide `tag` y nombre y crea `scenes/map/maps/<tag>/` desde `_template/`:
  - suelo plano (`heights.png`), roles «pasto» (`ground_roles.png`), `map.tscn` con `terrain.tscn`, dos `PlayerStart` (con altar y `WizardSpot`) y tres manantiales, `<tag>.tres` y `nav.res`;
  - después hornea, abre la escena y corre «Validar mapa», que tiene que dar PASS;
  - el catálogo lo ve sin editar ninguna lista.
- **Pincel de flora.** Con un `FloraLayer` seleccionado, pinta y borra (Shift) su densidad en el viewport.
  - Si la capa no tiene PNG, lo crea.
  - La flora se replanta en vivo, solo en la zona pintada.
- **Pincel de roles.** Con el `Terrain` seleccionado, pinta Pasto, Tierra, Roca y Camino en `ground_roles.png`, con vista previa en vivo.
- **Todo comparte un solo camino:**
  - el pincel (`TerrainBrush`), la barra (`brush_toolbar`), el cursor, la elección del punto en el suelo (`GroundPick`);
  - el trazo (`BrushStroke`) y el historial (`TerrainHistory`: deshacer con `EditorUndoRedoManager` y guardar con Ctrl+S);
  - cambia solo el «lienzo» (`BrushCanvas`).

---

## 2. Escenas de prueba

- **066b, mapa nuevo: sin escena de debug.** El criterio arranca en el menú del editor, que es lo que abre el humano. La verificación automática es la sonda `agent/editor/new_map_probe.gd`. Los casos puros van en `debug/terrain/new_map_cases.gd` (sin ventana).
- **066a, refactor del lienzo:** se reusan `debug/terrain/edit_bed.tscn`, `brush_cases.gd` y `terrain_brush_probe` sin cambios de comportamiento.
- **066c y 066d: un banco nuevo, `res://debug/terrain/paint_bed.tscn`** (lo crea 066a).
  - **Qué instancia:**
    - una raíz `MapRoot`;
    - `look_rig.tscn` con `preview_god = Persephone` y `preview_quality = data/look/quality_medium.tres`;
    - `terrain.tscn` con `heights = debug/terrain/edit_bed/heights.png` y `ground_roles = debug/terrain/paint_bed/ground_roles.png` (su propia copia, todo (255,0,0,0) y con su `.import`);
    - `MapProps/Starts/Start1` y un `Fount1`;
    - `Vegetation/Ferns` (`FloraLayer`) con una especie de `data/vegetation/species/persephone_*.tres` y **sin `density`**.
  - **Estado inicial:** suelo plano y todo pasto. Ferns no tiene imagen: el inspector avisa «Falta la imagen de densidad».
  - **Lo que todavía no está:** roca ni camino en el suelo, y ningún helecho.
  - **Acción del playtester:** no es del InputMap, es una herramienta del editor. Selecciona el nodo y la herramienta en la barra, y hace clic izquierdo y arrastra en el viewport 3D. Shift borra la flora. Ctrl+Z deshace, Ctrl+S guarda.
  - Un atajo de debug se arma con otro `.tres` de pincel (`TerrainBrush`), no con otro script.

---

## 3. Árbol de archivos

```
game/scenes/map/maps/_template/                  [+] dev template; no <tag>.tres, so the catalog ignores it
  map.tscn                                       [+] MapRoot tree of §4 (heights/roles point at _template/; NavRegion without navmesh)
  heights.png (+.import without uid)             [+] 256² 16-bit, all 100 (= 10 m), no void.png
  ground_roles.png (+.import)                    [+] 256² RGBA all (255,0,0,0); import: lossless, no mipmaps, fix_alpha_border=false, detect_3d 0
  README.md                                      [+] What/Not/Talks to/Edit/Check: "Proyecto → Herramientas → Mapa nuevo copies this"

game/addons/terrain_tools/
  plugin.gd                                      [~] _handles(Terrain or FloraLayer); tool menu «Mapa nuevo…»; resources_reimported → canvas.reloaded
  plugin.cfg                                     [~] description: + roles, flora, new map; version 0.3.0
  README.md                                      [~] new tools, how a human uses them, Check: paint_bed / probes
  terrain_history.gd                             [~] history of CANVASES: commit/write/save per BrushCanvas; registry lattice()/roles()/density(); keeps arrays/has_draft/rebuild/forget as delegates
  terrain_actions.gd                             [~] level_bases commits on history.lattice(terrain) (same steps)
  terrain_edits.gd                               [=] unchanged (still returns BrushStroke.Patch)
  map_images.gd, png16.gd                        [=] reused as they are
  brush/
    terrain_brush.gd                             [~] + flow (0..1) «Flujo», + density (0..1) «Densidad»
    default_brush.tres                           [~] flow = 0.5, density = 1.0
    brush_rules.gd                               [~] + static weight_at(brush, offset) (the _distance + _weight it already has), public
    paint_rules.gd                               [+] pure: pixel_rect, weights over pixel centres, toward (L8), add_role (RGBA, sum 255)
    brush_canvas.gd                              [+] BrushCanvas (base) + inner PixelPatch: what a stroke paints on
    lattice_canvas.gd                            [+] LatticeCanvas: heights + void (the BrushStroke.drag dispatch and TerrainHistory._drafts move here)
    roles_canvas.gd                              [+] RolesCanvas: ground_roles.png; preview = texture_2d_update on the imported texture's RID     (066c)
    density_canvas.gd                            [+] DensityCanvas: a FloraLayer's density PNG; creates it if missing; preview → FloraLayer   (066d)
    canvas_files.gd                              [+] static editor I/O: blank PNG, .import with fixed params, save_png, reimport
    brush_stroke.gd                              [~] begin(canvas, mode, brush, at) / drag / finish → {rect, before: Array, after: Array}; Patch stays (the lattice's)
    brush_painter.gd                             [~] paints any canvas; picks on the map Terrain's heights; ≤150 lines (target resolution goes out)
    brush_targets.gd                             [+] static: (selected node, tool) → canvas + mode + label; the Terrain of a FloraLayer (MapRoot.terrain)
    brush_toolbar.gd / .tscn                     [~] one bar, three groups: Relieve | Roles (Pasto, Tierra, Roca, Camino) | Flora (Pintar); Flujo/Densidad; show_for(kind)
    brush_cursor.gd, ground_pick.gd,
    editor_preview.gd, refresh_budget.gd         [=] reused
  new_map/
    new_map_files.gd                             [+] static, no UI: tag checks, copy the pictures (stripping uid), empty nav.res, scene from the template, definition
    new_map_action.gd                            [+] editor flow: dialog → files → import → bake → open → validate (reuses TerrainActions.validate)
    new_map_dialog.tscn / .gd                    [+] ConfirmationDialog: Tag, Nombre, live reason it refuses

game/scenes/map/nav/map_nav_region.gd            [~] + public bake_now() -> Error (the «Hornear navmesh» button calls it)
game/scenes/map/README.md                        [~] «Agregar un mapa nuevo» = menu; copying test_flat is no longer the way
game/scenes/look/vegetation/
  flora_layer.gd                                 [~] + show_painting(image, area_m) / stop_painting() / density_image(); doc: brush or any editor
  flora_density.gd                               [~] + layer_ids; from_layers reads density_image(); + with_layer_bytes(id, bytes)
  flora_field.gd                                 [~] + layer_painted(layer, area_m) (group); MUST stay ≤300 lines (C1b doesn't go up)
  flora_ground_watch.gd                          [~] + mark(area) (the same queue and brake as the ground)
  mesh_planter.gd                                [~] + set_flora(map) (swaps the snapshot, same groups)
  README.md                                      [~] Edit: flora brush; Check: paint_bed
game/debug/map/ground_dump.gd                    [~] skips folders that start with "_"
game/tools/import/bake_ground_roles.py           [~] header: re-baking overwrites the roles painted by hand
game/export_presets.cfg                          [~] exclude scenes/map/maps/_template/* (question 3)

game/debug/terrain/
  paint_bed.tscn + paint_bed/ground_roles.png    [+] bed for 066c and 066d (§2)
  paint_cases.gd                                 [+] headless: PaintRules (weights, toward, add_role sum 255)
  roles_cases.gd                                 [+] headless: RolesCanvas over an Image: dab, patch, restore exact          (066c)
  density_cases.gd                               [+] headless: DensityCanvas, FloraDensity.with_layer_bytes, MeshPlanter.set_flora+replan (066d)
  new_map_cases.gd                               [+] headless: tag refusal, uid stripping, scene rewrite in memory, definition
  brush_cases.gd                                 [~] builds strokes over LatticeCanvas.over(heights, mask) (same numbers)
game/agent/editor/
  terrain_brush_probe.gd                         [~] new BrushPainter/TerrainHistory API, same lines
  paint_probe.gd + agent/scripts/paint_probe.sh  [+] window: roles and flora on paint_bed (strokes, undo, save, times)
  new_map_probe.gd + agent/scripts/new_map_probe.sh [+] window: creates probe_new_map, bakes, validates, deletes it
```

**Mapa de responsabilidades.** Cada pieza dice qué hace y qué NO hace.

| Pieza | Hace | No hace |
|---|---|---|
| `BrushCanvas` | Grilla de celdas sobre el mapa, copia de trabajo, parches de un rect, vista previa, guardar a su archivo | Mouse, barra, deshacer |
| `LatticeCanvas` | Alturas y vacío: subir, suavizar, aplanar, hueco; borrador según `RefreshBudget` | Píxeles, imágenes |
| `RolesCanvas` | `ground_roles.png` RGBA: sumar un rol manteniendo la suma en 255; subir el resultado a la textura importada | El material (sigue siendo de `TerrainLayer`) |
| `DensityCanvas` | El PNG L8 de un `FloraLayer`: pintar hacia `density`, borrar a 0; crear el PNG si falta | Plantar (lo hacen `FloraField` y `MeshPlanter`) |
| `PaintRules` | Pesos sobre centros de píxel y aritmética de bytes (pura, sin ventana) | Archivos, editor |
| `CanvasFiles` | PNG en blanco, `.import` con parámetros fijos, `save_png`, reimportar | Qué significa un píxel |
| `BrushStroke` | Una pasada de prensa a soltar: modo, rect sucio, antes y después | Qué hace un toque (eso es del lienzo) |
| `BrushTargets` | Elige el lienzo y el modo según la selección y la herramienta | Pintar |
| `BrushPainter` | Mouse del viewport → cursor y trazo; elige el punto sobre las alturas del `Terrain` del mapa | Deshacer, guardar |
| `TerrainHistory` | Un paso deshacible por trazo y por lienzo; Ctrl+S guarda los lienzos sucios; registro de lienzos | Aritmética |
| `BrushToolbar` | Herramienta, perillas del pincel, grupos visibles según el nodo | Pintar |
| `FloraLayer` | Dueño de su densidad; en el editor muestra la imagen que se pinta hasta guardar | Plantar |
| `FloraField` | Ante una capa pintada: copia nueva de la densidad y replantar el área | Leer el mouse |
| `NewMapFiles` | Los archivos de un mapa nuevo desde `_template` | Importar, hornear, abrir |
| `NewMapAction` | El flujo del editor y los avisos | Escribir píxeles |
| `MapNavRegion.bake_now` | Hornear desde el editor (lo usan el botón y la acción) | Validar |

---

## 4. Árbol de nodos de un mapa nuevo

Lo que `_template/map.tscn` da, y por lo tanto lo que recibe `<tag>/map.tscn`. La disposición es la de `test_flat`, que ya pasa la validación, más dos manantiales.

```
Map (MapRoot)  terrain · nav_region · starts · look · minimap_bake · buildings · npcs · props
├── Look (look_rig.tscn)            terrain=../Terrain · preview_god=Persephone (editor only) · preview_quality=medium
├── Terrain (terrain.tscn)          heights=<tag>/heights.png · ground_roles=<tag>/ground_roles.png   (its Mesh/Live/Collision children come from terrain.tscn)
├── MapProps (MapProps)
│   ├── Starts
│   │   ├── Start1 (player_start.tscn, slot 1)  (1180, 10, 1300) — its altar + WizardSpot 30 m toward FountMiddle
│   │   └── Start2 (player_start.tscn, slot 2)  (1420, 10, 1300) — altar + WizardSpot
│   └── Founts
│       ├── FountMiddle (manafount.tscn)  (1300, 10, 1300)
│       ├── FountWest   (manafount.tscn)  (1000, 10, 1300)
│       └── FountEast   (manafount.tscn)  (1600, 10, 1300)
├── Buildings (Node3D)              empty: drag building scenes here
├── Npcs (Node3D)                   empty: NpcSpawn
├── Props (Node3D)                  empty: scenes/props/*
├── Vegetation (Node3D)             empty: add a FloraLayer and paint it
├── NavRegion (MapNavRegion)        navigation_mesh=<tag>/nav.res · bake_settings=data/nav/nav_bake.tres
└── MinimapBake (minimap_terrain_bake.tscn)  terrain=../Terrain
```

`<tag>.tres` es una `MapDefinition` con `tag`, `display_name`, `map_scene`, `nav` y `player_starts = 2`. `room_selectable` y `playable` quedan en true. No lleva `tiles`, `light` ni `native_ground`.

---

## 5. Resources contra nodos

| Cosa | Forma |
|---|---|
| El pincel (tamaño, caída, forma, fuerza, flujo, densidad) | **Resource** `TerrainBrush`; un preset es otro `.tres` |
| La especie de una capa | **Resource** `VegetationSpecies` (ya existe) |
| La definición del mapa | **Resource** `MapDefinition` (`<tag>.tres`) |
| Dónde crece una especie | **Nodo** `FloraLayer` + **PNG** (`density`) |
| Qué suelo hay dónde | **PNG** `ground_roles.png` en el `@export` `Terrain.ground_roles` |
| Altares, manantiales y `WizardSpot` | **Nodos** del `map.tscn`, movibles con el gizmo |
| El template | **Escena** `_template/map.tscn` y sus PNG, **no** un `.tres` |
| `cell_m` y `max_per_cell` | `@export` de instancia en el `FloraLayer` (ya existen) |
| Lienzos, trazos, historial | `RefCounted` del addon; nunca se guardan en una escena |
| Imagen de vista previa (flora y roles) | Estado del editor, no se guarda: `FloraLayer._painting` y la textura en GPU |

---

## 6. Contratos (firmas)

**Pincel compartido, campos nuevos de `TerrainBrush`:**

```gdscript
## Pictures (roles, flora): how far one dab moves a cell toward the paint (1 = all the way under the hard core).
@export_range(0.0, 1.0, 0.01) var flow := 0.5
## Flora: the density a full dab leaves (1 = the layer's max_per_cell, white).
@export_range(0.0, 1.0, 0.01) var density := 1.0
```

**`BrushRules` (se agrega):**

```gdscript
static func weight_at(brush: TerrainBrush, offset_m: Vector2) -> float   # weights() uses it too
```

**`PaintRules` (pura):**
- La celda `(i, j)` tiene su centro en `((i + 0.5) * cell_m, (j + 0.5) * cell_m)`. El rect queda recortado a `size`.

```gdscript
class_name PaintRules extends RefCounted
static func pixel_rect(center_m: Vector2, reach_m: float, cell_m: float, size: Vector2i) -> Rect2i
static func weights(brush: TerrainBrush, center_m: Vector2, rect: Rect2i, cell_m: float) -> PackedFloat32Array
## L8: v += (target - v) * w * flow, rounded; w * flow = 1 ends exactly at target.
static func toward(bytes: PackedByteArray, width: int, rect: Rect2i, weighted: PackedFloat32Array, target: int, flow: float) -> void
## RGBA8, a role per channel: c = c(1-a) + 255a, the others x(1-a), a = w * flow; the rounding residual goes to `channel`,
## so R+G+B+A stays 255 in every touched pixel.
static func add_role(rgba: PackedByteArray, width: int, rect: Rect2i, weighted: PackedFloat32Array, channel: int, flow: float) -> void
```

**Lienzo (base) y su parche:**

```gdscript
@tool
class_name BrushCanvas extends RefCounted
class PixelPatch extends RefCounted:      # rect + bytes of that rect (row by row, `channels` per pixel)
	var rect: Rect2i
	var bytes: PackedByteArray
func context() -> Node                         # the node the undo step belongs to (Terrain / FloraLayer)
func cell_rect(center_m: Vector2, reach_m: float) -> Rect2i
func begin(mode: int, brush: TerrainBrush, at_m: Vector2) -> void
func dab(at_m: Vector2, vertical_px: float) -> Rect2i  # what this dab touched
func copy() -> Variant                         # full copy of the working data (the stroke's "before")
func patch(rect: Rect2i, from: Variant = null) -> RefCounted   # of the current data, or of a copy()
func write(patches: Array) -> void             # undo/redo: writes, then preview (or draft)
func preview(rect: Rect2i) -> void
func is_dirty() -> bool
func save() -> String                          # "" or the error; writes the file and reimports
func label(mode: int) -> String                # name in the undo history, in Spanish
func reloaded() -> void                        # its file came back from a reimport: drop the preview
```

**Lienzos concretos:**
- Cada uno es `extends BrushCanvas`, con profundidad de herencia 1 (C11).
- Lo común de imágenes va en `CanvasFiles`, no en una clase intermedia.

```gdscript
class_name LatticeCanvas   # mode = BrushStroke.Mode
static func over(heights: PackedFloat32Array, mask: PackedByteArray) -> LatticeCanvas   # headless (brush_cases)
static func of(terrain: Terrain, budget: RefreshBudget) -> LatticeCanvas
func arrays() -> Array; func has_draft() -> bool; func rebuild() -> void; func forget() -> void
class_name RolesCanvas     # mode = channel 0 open(R) 1 earth(G) 2 rock(B) 3 path(A), the order of GodGround.roles()
static func of(terrain: Terrain) -> RolesCanvas
class_name DensityCanvas   # enum Mode { PAINT, ERASE }
static func of(layer: FloraLayer) -> DensityCanvas              # null without density
static func create_picture(layer: FloraLayer) -> String         # "" or error; <map>/flora/<snake_name>.png, side = ceili(TerrainGrid.SIZE_M / cell_m)
```

**Trazo:**

```gdscript
func begin(canvas: BrushCanvas, mode: int, brush: TerrainBrush, at: Vector2) -> void
func drag(at: Vector2, vertical_px: float) -> void
func dirty_rect() -> Rect2i
func finish() -> Dictionary   # {rect: Rect2i, before: Array, after: Array}
```

**Historial:**

```gdscript
signal written(canvas: BrushCanvas, rect: Rect2i)
func lattice(terrain: Terrain) -> LatticeCanvas
func roles(terrain: Terrain) -> RolesCanvas
func density(layer: FloraLayer) -> DensityCanvas
func commit(canvas: BrushCanvas, label: String, before: Array, after: Array) -> void
#   create_action(label, MERGE_DISABLE, canvas.context()); do = write(after), undo = write(before)
func write(canvas: BrushCanvas, patches: Array) -> void
func has_unsaved() -> bool
func save() -> String
static func reimport(folder: String) -> void   # unchanged
## Kept as delegates to lattice(terrain): arrays, has_draft, rebuild, forget (TerrainActions, the probe).
```

**Barra:**

```gdscript
enum Tool { NONE, RAISE, SMOOTH, VOID, ROLE_OPEN, ROLE_EARTH, ROLE_ROCK, ROLE_PATH, FLORA }
enum Kind { TERRAIN, FLORA }
func show_for(kind: Kind) -> void   # Terrain: Relieve + Roles; FloraLayer: Flora. Title «Terreno:» / «Flora:»
```

Flujo y Densidad solo se ven con una herramienta de pintura; Fuerza solo con Subir/Bajar.

**Flora:** una sola dueña del estado, que es la capa.

```gdscript
# FloraLayer (editor only; nothing of this is saved)
func show_painting(image: Image, area_m: Rect2) -> void   # holds the image, calls group FloraField.GROUP &"layer_painted"
func stop_painting() -> void                              # back to `density` (after the reimport)
func density_image() -> Image                             # L8 copy: the painting if any, else density
# FloraField
func layer_painted(layer: FloraLayer, area_m: Rect2) -> void
#   _density = _density.with_layer_bytes(layer.get_instance_id(), bytes); planter.set_flora(_density); _ground.mark(area_m)
#   does NOT bump _density_version (the planters are not rebuilt)
# FloraDensity
var layer_ids := PackedInt64Array()
func with_layer_bytes(layer_id: int, bytes: PackedByteArray) -> FloraDensity   # copy-on-write: the snapshot is still a snapshot
# MeshPlanter
func set_flora(map: FloraDensity) -> void      # same layers, same order: only the bytes change
# FloraGroundWatch
func mark(area: Rect2) -> void                 # = _on_moved; replans under replan_every_s
```

**Roles en vivo:**
- `RolesCanvas.preview` hace `RenderingServer.texture_2d_update(terrain.ground_roles.get_rid(), image, 0)`.
- No toca ningún nodo ni material: `TerrainLayer` sigue siendo el único que escribe el material.
- La reimportación al guardar recarga la textura desde el disco.

**Mapa nuevo:**

```gdscript
# NewMapFiles (static, headless-safe except load of imported files)
const TEMPLATE_DIR := "res://scenes/map/maps/_template"
static func refusal(tag: String, display_name: String) -> String   # "" = OK; ^[a-z][a-z0-9_]*$, not "_*", folder must not exist
static func write_pictures(folder: String) -> PackedStringArray     # copies heights/roles PNG + .import WITHOUT the uid line
static func write_nav(folder: String) -> String                     # ResourceSaver.save(NavigationMesh.new(), nav.res)
static func write_scene(folder: String) -> String                   # template.instantiate(GEN_EDIT_STATE_INSTANCE), rewires
                                                                     # Terrain.heights/ground_roles + NavRegion.navigation_mesh, pack, save
static func write_definition(folder: String, tag: StringName, display_name: String) -> String
# NewMapAction (editor)
func open() -> void                                    # shows the dialog
func make(tag: StringName, display_name: String) -> void   # await: files → EditorFileSystem import → bake_now → open_scene → validate
# MapNavRegion
func bake_now() -> Error
```

**Patrones de las referencias que tomo y cuáles no:**

| Patrón | Fuente | Decisión |
|---|---|---|
| Pintar sobre una imagen, que es la fuente | HTerrain (mapas = imágenes), Terrain3D (imágenes por región) | **Sí**: el PNG es la única fuente (063D). |
| Pintar en GPU con un shader en un Viewport y leer al soltar | HTerrain (`terrain_painter.gd`: «CPU image not updated during a stroke») | **No**: 256² y 320² son chicas. Un `PackedByteArray` por píxel cuesta ms y se prueba sin ventana. |
| Deshacer por parche del rect tocado, antes y después | HTerrain (bloques de `UNDO_CHUNK_SIZE`), Terrain3D (`backup_region`, `apply_undo`) | **Sí**: ya es `BrushStroke.Patch`. Para imágenes, `PixelPatch`. |
| `EditorUndoRedoManager.create_action(…, MERGE_DISABLE, context)` + `add_do_method`/`add_undo_method` | Terrain3D `editor_plugin.gd` (`create_undo_action`), docs de Godot | **Sí**, con el nodo como contexto: el paso cae en el historial de la escena. |
| `Image.blend_rect` contra escribir por píxel | — | **Por píxel**. `blend_rect` compone el alfa como opacidad (`Color.blend`), lo que rompe la A = camino de `ground_roles`. Además, la caída exige una estampa distinta por toque. |
| `Image.save_png` + escribir un `.import` por defecto si falta | HTerrain `hterrain_data.gd` (`_try_write_default_import_options`) | **Sí**, más nuestro `update_file` + `reimport_files`. **No** `ResourceSaver`: un `.res` no es el PNG que edita Krita. |
| `_forward_3d_gui_input`: prensa → empezar, movimiento → pintar, soltar → cerrar, `STOP` solo si se consumió | Terrain3D, HTerrain, docs de `EditorPlugin` | **Sí**: ya es `BrushPainter`. |
| Elegir el punto con profundidad de la GPU (`get_intersection`) | Terrain3D | **No**: el rayo sobre las alturas (`GroundPick`) anda sin física y ve los borradores. |
| Instancias guardadas en un octree, deshacer de colocaciones (`painting_changes.gd`) | Spatial Gardener | **No** el almacenamiento: nuestra flora es densidad más colocación determinista. **Sí** la idea: un trazo es un cambio con su deshacer, y la vista previa sigue al pincel. |

---

## 7. Cómo lo hace un humano (seis verbos y un bug)

| Verbo | Dónde mira y qué toca | Lugares |
|---|---|---|
| **Entender** | `addons/terrain_tools/README.md` («How a human uses it»); los tooltips de la barra; el árbol del `map.tscn` | 1 |
| **Modificar** la flora | Selecciona el `FloraLayer` en `Vegetation`, «Flora» en la barra, arrastra (Shift borra); Densidad y Flujo en la barra; Ctrl+S | 1 (viewport) |
| **Modificar** el suelo | Selecciona `Terrain`, «Pasto / Tierra / Roca / Camino», arrastra; Ctrl+S | 1 |
| **Agregar** una capa | Agrega un `FloraLayer` bajo `Vegetation`, arrastra una especie de `data/vegetation/species/` y pinta (el PNG se crea solo) | 1 |
| **Quitar** | Borra el `FloraLayer` (el PNG queda; se borra en el dock si sobra); para el suelo, pinta «Pasto» encima | 1–2 |
| **Crear** un mapa | Proyecto → Herramientas → «Mapa nuevo…», tag y nombre, Aceptar; queda abierto y validado | 1 |
| **Crear** un preset de pincel | Duplica `brush/default_brush.tres` y asígnalo a la barra | 1 |
| **Escalar** | Más mapas: el menú otra vez. Más especies: más `FloraLayer`. Otro rol: no (son 4 canales; fuera de alcance) | 1 |
| **Encontrar un bug** | (1) El dock **Salida** imprime cada guardado y reimport, y los fallos de «Mapa nuevo» con la ruta. (2) El **historial de deshacer** (Editor → Historial) nombra cada trazo («Roles: roca», «Flora: pintar»). (3) Las **advertencias del inspector** del `FloraLayer`, el `NavRegion` y el `MapRoot`. (4) «Validar mapa» lista cada problema con la ruta del nodo. (5) Sin ventana: `paint_cases`, `roles_cases`, `density_cases` y `new_map_cases` imprimen `… CASES PASS` o la línea que falla. | — |

---

## 8. Subcortes, criterios medibles y qué corre en paralelo

Los developers no corren Godot. Cada criterio se verifica en la pasada final (§10).

### 066a: lienzo común (refactor sin cambio visible)
- Archivos: `PaintRules`, `BrushCanvas`, `LatticeCanvas`, `CanvasFiles`, `BrushTargets`; `BrushStroke`, `BrushPainter`, `TerrainHistory` y `TerrainActions` sobre lienzos.
- La barra con los tres grupos (Roles y Flora visibles pero sin lienzo hasta 066c y 066d) y `paint_bed.tscn`.
- **Criterios:**
  1. `brush_cases` da la misma salida que antes, número por número.
  2. `terrain_brush_probe` imprime las mismas líneas (subir, deshacer, hueco y relleno, borrador pesado, guardar).
  3. `paint_cases`:
     - `weights` con caída 0 da 1 en las celdas con centro a ≤ `size_m`, y 0 fuera;
     - `toward` con flujo 1 llega exacto al objetivo;
     - `add_role` mantiene R+G+B+A = 255 en el 100 % de los píxeles tras 200 toques al azar con semilla fija.
  4. Lint: ningún conteo sube y ningún script nuevo pasa de 150 líneas.

### 066b: «Mapa nuevo» (no depende del pincel)
- Archivos: `_template/`, `new_map/*`, `bake_now`, menú, `ground_dump`, export.
- **Criterios:**
  1. Con `mi_mapa` / «Mi mapa», en ≤ 60 s (horneado incluido) aparecen `map.tscn`, `heights.png`, `ground_roles.png`, `nav.res` y `mi_mapa.tres`:
     - `heights.png` de 256², con las 65 536 muestras iguales a 100;
     - `ground_roles.png` de 256², con todos los píxeles en (255,0,0,0);
     - ningún `void.png`.
  2. `grep -r "_template" scenes/map/maps/mi_mapa` da 0, y ningún `uid` de `mi_mapa/*.import` es igual a uno de `_template`.
  3. `MapCatalog.shared().has(&"mi_mapa")` es true y `all_tags()` no contiene `_template`.
  4. `nav.res` tiene `get_polygon_count() > 0`; «Validar mapa» da PASS; `check_map.tscn -- --map=mi_mapa` da `CHECK MAP mi_mapa PASS`.
  5. El `map.tscn` guardado contiene `instance=` de `terrain.tscn`, dos de `player_start.tscn` y tres de `manafount.tscn`. Cada `WizardSpot` queda a 30 m ± 0,1 de su altar, mirando al manantial más cercano.
  6. Se rechazan sin escribir ningún archivo: un tag existente, `Mi-Mapa` y `_x`. El diálogo dice por qué.
  7. `git status scenes/map/maps/_template` queda limpio después de crear.
  8. F5 con `match.tscn -- --map=mi_mapa` en 1v1: dos magos en sus `WizardSpot`.

### 066c: pincel de roles
- Archivos: `RolesCanvas`, el cableado de los cuatro botones, `roles_cases`.
- **Criterios** (en `paint_bed`):
  1. «Roca», tamaño 50, caída 0, flujo 1, un clic en (1275, 1275): el píxel (127, 127) queda en (0,0,255,0). Los píxeles cambiados son los de centro a ≤ 50 m: 78 ± 8. Fuera no cambia ninguno.
  2. Vista previa: sin guardar, `RenderingServer.texture_2d_get(rid)` es byte a byte igual a la imagen de trabajo en el rect tocado.
  3. Ctrl+Z deja el checksum de la imagen igual al de antes; Ctrl+Shift+Z deja el de después.
  4. Ctrl+S escribe `paint_bed/ground_roles.png`, que al releerlo es igual a la imagen de trabajo. El `.import` no cambia (`fix_alpha_border=false`).
  5. Mediana de 50 toques de tamaño 200 m ≤ 4 ms, medida por la sonda.
  6. Captura con cámara fija antes y después de un trazo de Roca: ΔE medio > 10 dentro del círculo y < 1 fuera.

### 066d: pincel de flora
- Archivos: `DensityCanvas`; `FloraLayer`, `FloraField`, `FloraDensity`, `MeshPlanter` y `FloraGroundWatch` con su vista previa; `density_cases`.
- **Criterios:**
  1. Primer clic sobre Ferns sin `density`: se crea `paint_bed/flora/ferns.png`, de 320×320 L8.
     - Su `.import` es sin pérdida, sin mipmaps y con `detect_3d/compress_to=0`.
     - `density` queda asignada como un paso propio en el historial («Flora: imagen nueva») y la advertencia del inspector desaparece.
  2. Densidad 1, flujo 1, caída 0, tamaño 40 m en P: los píxeles con centro a ≤ 40 m valen 255 (78 ± 8) y el resto 0. Shift en el mismo lugar los deja en 0.
  3. Vivo: a ≤ 0,5 s del toque, `FloraField.instance_count()` pasa de 0 a > 0 sin guardar.
     - Los `MeshPlanter` son los mismos objetos (mismos `get_instance_id()`) y `_density_version` no cambia.
     - Solo se replanean las celdas de 32 m que tocan el rect.
  4. Ctrl+Z: los bytes vuelven exactos y las plantas se van en ≤ 0,5 s.
  5. Ctrl+S: el PNG en disco es igual a la imagen de trabajo. Tras la reimportación, `FloraDensity.tag_total` es igual al de antes de guardar, y `show_painting` quedó apagado.
  6. Ctrl+S sin haber pintado no escribe nada (`git status` limpio).
  7. `flora_field.gd` tiene ≤ 300 líneas, así que C1b sigue en 12.

### Qué corre en paralelo

```
066a  ─┬─> 066c ─┐
       └─> 066d ─┴─> pasada final de pruebas (Godot, de a uno)
066b  ───────────────┘
```

- 066a y 066b no comparten archivos.
- 066c y 066d tocan `terrain_history.gd` en funciones distintas (`roles()` / `density()`): se integran en ese orden y el merge es trivial.
- 066a deja armados la barra y el banco, así ninguno de los dos los toca.

**Orden dentro de cada subcorte:** puras y casos primero, después el lienzo, después la barra y el plugin, al final el README y el lint.

---

## 9. Verificación en el editor (la hace un humano)

- **066b:**
  1. Proyecto → Herramientas → «Mapa nuevo…», `mi_mapa`, Aceptar.
  2. Se abre la escena y sale «Validar mapa: PASS».
  3. En el FileSystem está la carpeta.
  4. En el inspector de `NavRegion` no hay advertencia.
  5. F5 con `--map=mi_mapa`.
- **066c:**
  1. Abre `debug/terrain/paint_bed.tscn` y selecciona `Terrain`.
  2. Elige «Roca» y arrastra: el suelo cambia en vivo.
  3. Ctrl+Z, Ctrl+Shift+Z, Ctrl+S.
  4. Reabre la escena: sigue igual.
- **066d:**
  1. Selecciona `Vegetation/Ferns` y elige «Flora».
  2. Clic: aparece el PNG en `paint_bed/flora/` y crecen helechos.
  3. Shift + arrastrar los borra.
  4. Ctrl+S y reabrir.

No hay tests automáticos más allá de los casos sin ventana y las sondas del editor, como pide RULES.

---

## 10. Tests

- Sin ventana: `paint_cases`, `roles_cases`, `density_cases`, `new_map_cases` y `brush_cases` (regresión).
- Ventana del editor, de a un Godot: `terrain_brush_probe` (regresión), `paint_probe` y `new_map_probe`, que crea `probe_new_map`, hornea, valida y borra la carpeta.
- Al cerrar: `check_map.tscn` en todos los mapas, con `mi_mapa` si quedó, y `bash tools/lint/conventions.sh`.
- Sin banco de determinismo (memoria).

---

## 11. Riesgos

1. **Formato de la textura importada.** NO VERIFICADO que `texture_2d_update` acepte la imagen de trabajo:
   - un import sin pérdida podría quedar en RGB8 o con otro formato;
   - el lienzo convierte la imagen al formato de `ground_roles.get_image()` antes de subirla;
   - si igual falla, el respaldo es `TerrainLayer.preview_roles(texture)`, solo para el editor, con `TerrainLayer` todavía como único escritor del material.
2. **`EditorFileSystem.update_file` en una carpeta nueva.** NO VERIFICADO que funcione en una carpeta que el editor aún no conoce. El respaldo es `scan()` y esperar `filesystem_changed`, con un tope de 10 s.
3. **`PackedScene.pack` del template.** NO VERIFICADO que conserve las instancias y los overrides de hijos editables (el `WizardSpot`, que es `index="1"` del `PlayerStart`). El criterio 066b.5 lo mide. El respaldo es copiar el texto con la ruta reescrita y sin `uid`.
4. **`uid` duplicados.** Si se copia un `.tscn` o un `.import` con su `uid`, Godot resuelve hacia el template. Por eso se sacan siempre.
5. **`fix_alpha_border`.** Por defecto vale true, y si se importa así corrompe el RGB donde A = 0, que es casi todo el mapa. Lo evita el `.import` fijo de `CanvasFiles` y del template.
6. **`detect_3d` puede recomprimir en VRAM** una densidad que se use en un material. El `.import` fijo lo apaga.
7. **`flora_field.gd` está en 298 líneas.** Si no entra, `_update_clears` y `_gather_clears` salen a un ayudante.
8. **Vista previa invisible.** Los roles no se ven sin un `GodGround`, y hoy solo Persephone tiene uno.
9. **El flujo depende de la velocidad del mouse:** un toque por cada evento de movimiento. Espaciado por distancia queda fuera (pregunta 11).
10. **Contexto del deshacer:** si se borra el `FloraLayer`, su paso no tiene a quién volver. El lienzo comprueba `is_instance_valid` y no hace nada.
11. **`ground_dump.gd`** va a ver `_template` si no se ajusta.
12. **Overlay:** `_update_overlay` de `FloraLayer` vuelve a leer `density`; `show_painting` tiene que refrescarlo también.

**Fuera de alcance:**
- tiles del original, pincel de luz, cicatrices y pasto;
- un quinto rol;
- espaciado de toques y presión de tableta;
- dibujar el contorno del mapa en «Mapa nuevo» (tamaño fijo 256²);
- generar un mapa fractal (el «Steepness» de Scapex).

---

## 12. Referencias

- HTerrain, pintor (en GPU, el CPU se actualiza al soltar, deshacer por bloques): https://github.com/Zylann/godot_heightmap_plugin/blob/master/addons/zylann.hterrain/tools/brush/terrain_painter.gd
- HTerrain, guardado (`save_png` y `.import` por defecto; la reimportación quedó como TODO): https://github.com/Zylann/godot_heightmap_plugin/blob/master/addons/zylann.hterrain/hterrain_data.gd
- Terrain3D, plugin (`_forward_3d_gui_input`, `start/operate/stop_operation`, `create_action(…, MERGE_DISABLE, terrain)`): https://github.com/TokisanGames/Terrain3D/blob/main/project/addons/terrain_3d/src/editor_plugin.gd
- Terrain3D, API del editor (`backup_region`, `apply_undo`, `set_brush_data`): https://terrain3d.readthedocs.io/en/latest/api/class_terrain3deditor.html
- Terrain3D, pintar texturas: https://terrain3d.readthedocs.io/en/latest/docs/texture_painting.html
- Spatial Gardener (`arborist/painting_changes.gd`, octree de instancias): https://github.com/dreadpon/godot_spatial_gardener · https://godotengine.org/asset-library/asset/2037
- Godot `EditorPlugin` (`_forward_3d_gui_input`, `AFTER_GUI_INPUT_*`, `_save_external_data`): https://docs.godotengine.org/en/stable/classes/class_editorplugin.html
- Godot `EditorUndoRedoManager`: https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html · `Image`: https://docs.godotengine.org/en/stable/classes/class_image.html · `EditorFileSystem`: https://docs.godotengine.org/en/stable/classes/class_editorfilesystem.html

---

## 13. Preguntas, cada una con mi recomendación

1. **¿El template trae `void.png`?** Recomiendo que **no**: falta = sin vacío, y el primer Ctrl+S lo borraría igual.
2. **¿Dónde va «Mapa nuevo»?** Recomiendo **Proyecto → Herramientas** ahora, y clic derecho sobre `scenes/map/maps` en el FileSystem más adelante.
3. **¿El template en `scenes/map/maps/_template/` (como pediste) o en el addon?** Recomiendo **donde lo pediste**, más una exclusión en `export_presets.cfg`, así no viaja con el juego.
4. **¿Disposición del template?** Recomiendo **la de `test_flat`**, que ya pasa la validación: suelo a 10 m (deja margen para bajar), altares a 240 m y tres manantiales.
5. **¿`preview_god = Persephone` en el template?** Recomiendo que **sí**: es el bioma tutorial y el único con `GodGround`, y sin él los roles no se ven.
6. **Shift con los roles.** Recomiendo **nada en este corte**: sin borrar ni cuentagotas. Pintar «Pasto» ya es borrar.
7. **¿Borrar flora con Shift o con un botón?** Recomiendo **Shift**, igual que Hueco/Rellenar y Suavizar/Aplanar, y lo dice el tooltip.
8. **¿Perillas nuevas (`flow`, `density`) o reusar «Fuerza»?** Recomiendo **nuevas**: «Fuerza» es metros por píxel y mezclar dos unidades en una perilla confunde.
9. **¿Nombre del PNG nuevo?** Recomiendo `<mapa>/flora/<nombre_del_nodo_en_snake>.png`, con `_2`, `_3`… si ya existe.
10. **¿El `map.tscn` nuevo sale de `pack()` o de copiar el texto?** Recomiendo **`pack()`**, que es la API de Godot, y la copia de texto solo si 066b.5 falla.
11. **¿Espaciado de toques por distancia, como Krita?** Recomiendo **después**, si el flujo se siente desparejo en la pasada.
12. **Roles pintados en mapas importados.** Recomiendo **solo avisar** en `bake_ground_roles.py` y en el README que rehornear pisa lo pintado, sin bloquear el script.
13. **¿Hornear y validar automáticamente al crear el mapa?** Recomiendo que **sí**: unos segundos, y el diálogo dice PASS o los problemas.

Archivos que hay que leer para implementar (rutas absolutas):
- `/Users/joelsartori/Development/sacproject/game/addons/terrain_tools/plugin.gd`
- `/Users/joelsartori/Development/sacproject/game/addons/terrain_tools/terrain_history.gd`
- `/Users/joelsartori/Development/sacproject/game/addons/terrain_tools/terrain_actions.gd`
- `/Users/joelsartori/Development/sacproject/game/addons/terrain_tools/brush/brush_painter.gd`
- `/Users/joelsartori/Development/sacproject/game/addons/terrain_tools/brush/brush_stroke.gd`
- `/Users/joelsartori/Development/sacproject/game/addons/terrain_tools/brush/brush_rules.gd`
- `/Users/joelsartori/Development/sacproject/game/addons/terrain_tools/brush/brush_toolbar.gd`
- `/Users/joelsartori/Development/sacproject/game/addons/terrain_tools/brush/brush_toolbar.tscn`
- `/Users/joelsartori/Development/sacproject/game/addons/terrain_tools/brush/terrain_brush.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/vegetation/flora_layer.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/vegetation/flora_field.gd` (298 líneas)
- `/Users/joelsartori/Development/sacproject/game/scenes/look/vegetation/flora_density.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/vegetation/mesh_planter.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/vegetation/flora_ground_watch.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/ground/terrain_layer.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/ground/ground_roles.gdshaderinc`
- `/Users/joelsartori/Development/sacproject/game/scenes/map/map_root.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/map/map_definition.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/map/nav/map_nav_region.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/core/catalog/map_catalog.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/map/maps/test_flat/map.tscn`
- `/Users/joelsartori/Development/sacproject/game/tools/audit/map_checks.gd`
- `/Users/joelsartori/Development/sacproject/game/tools/import/scaffold_map.py`
- `/Users/joelsartori/Development/sacproject/game/debug/terrain/edit_bed.tscn`
- `/Users/joelsartori/Development/sacproject/game/debug/terrain/brush_cases.gd`
- `/Users/joelsartori/Development/sacproject/game/agent/editor/terrain_brush_probe.gd`
- `/Users/joelsartori/Development/sacproject/game/debug/map/ground_dump.gd`