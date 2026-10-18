# RFC-035 — Mapa editable en el editor

Estado: plan del tech lead (Opus), pendiente de OK. Arquitectura **estándar**. MP **online con dedicado**: no hay RPCs nuevos. La red sigue con `MultiplayerSynchronizer` y la física con `CharacterBody3D`/`move_and_slide`.
- **Pedido del usuario (2026-10-18):** «NO veo el mapa en Godot desde el editor (imagino que desde que sacamos la caché). ¿Es posible que en lugar de construir el mapa de una forma tan compleja simplemente sea un glb? ¿Nos impide algo manejarlo así? La intención es que todo el port pueda ser fácilmente modificable; es prioridad que desde el editor se pueda cambiar prácticamente todo.»
- **Decisión del usuario (2026-10-18, vía orquestador): todo pasa a Godot y se edita en el editor.**
  - El terreno es un `.glb` y la colisión sale de su malla.
  - Edificios, props, árboles, manalitos, puntos de aparición y aldeas son nodos de la escena.
  - La navegación pasa a **`NavigationRegion3D` horneada en el editor** desde la escena del mapa y reemplaza a `NavGrid` (`scenes/world/nav/nav_grid.gd`, la grilla de 5 m de sacengine sobre `AStarGrid2D`). El usuario acepta perder fidelidad en los caminos a cambio de poder editarlos.
  - Condiciones:
    - las consultas de camino son deterministas;
    - la evasión de `NavigationAgent3D` va apagada (la separación es de `BodySeparation`);
    - los digests del banco cambian **una sola vez**, por la navegación y con la causa justificada (la primera línea distinta es un camino);
    - el navmesh horneado se versiona y lo usa también el dedicado.
- **Features:** F192–F201 (035a–035j), las asigna el orquestador.
- **Autoridad:** decisión del usuario 2026-10-18 > PRD > FEATURES > RULES > VISUAL > este plan.

### Contradicciones (gana la decisión del usuario del 2026-10-18)
- **RULES.md §Datos:** «sacengine aporta los datos y los números del juego (mapa, paso medido, órdenes)». Los caminos dejan de ser los de sacengine (`NavGrid`, F72/F88). Se edita RULES en 035j: la navegación es de Godot (`NavigationServer3D`) y la grilla de 5 m sale.
- **FEATURES F72/F88:** la línea base de digests desde F88 deja de valer. 035h la regraba una vez y con causa.
- **`terrain.gd`** (`_validate_property`, comentario) dice «a saved scene must not carry the original map or its textures (RULES.md)». RULES ya no dice eso: desde RFC-023/033 los assets finales van en `assets/original/`. Gana RULES. El `.glb`, los `.res` horneados y el navmesh son **archivos** referenciados como `ext_resource`, nunca `sub_resource` embebidos en un `.tscn`.
- **`.gitattributes`** solo manda a LFS `assets/cc0/**` y `assets/mm/**`, aunque RULES dice que `assets/original/` va por LFS (hoy `terrain.res` está en git normal). Se señala, no se toca.
- **Ruido ajeno:** `git status` trae `.import` de `themes/persephone/sky*.png` y `textures/*/M000.png` pasados de `compress/mode=0` a `2`, por un editor abierto. No son de este RFC, pero pueden cambiar el cielo (memoria «conservar el cielo original»). El orquestador decide si los revierte antes de 035a.

## 0. Diagnóstico: por qué el editor no muestra el mapa

Para este plan no se corrió Godot. El diagnóstico sale de leer el código, y 035a lo **mide** antes de tocar nada.

1. **El terreno es la única pieza que se ve en el editor, y no queda guardada.**
   - `terrain.gd` es `@tool`. En `_ready` arma `mesh` y `material_override` desde `MapTerrainData` (`terrain.res`), `tiles.png`, `light.png` y `themes/james/atlas.png`. `_validate_property` deja `mesh` y `material_override` fuera del guardado.
   - **Recarga de un script `@tool`.** Pasa cuando un agente lo edita, con un `git pull` o cuando el editor recupera el foco. La instancia se rehace solo con lo guardado: `mesh` se pierde y `_ready` no se vuelve a llamar. El terreno desaparece hasta reabrir la escena. Es la causa más probable con el flujo de este repo.
   - **Escena abierta durante el import.** Si la escena se abre mientras el editor todavía importa `assets/original/`, `load()` de los PNG importados como `Image` da `null`. Entonces `_apply_ground_texture` sale en silencio. `Missing` solo avisa si falta `data`.
   - Con caché o sin ella, el patrón es el mismo. RFC-033 cambió `FileAccess` de un `.bin` por `load()` de recursos importados, que dependen de cómo está el import del editor.
2. **El resto del mapa solo existe en runtime, por diseño.**
   - `MapPopulation` lee `ntts.json` en `_ready`: 76 estructuras y 32 criaturas, que salen por `UnitSpawner`.
   - `MapProps` lee `widgets.json` y pone 720 plantas con `RandomNumberGenerator(plant_seed)`. Solo lo hace si `BodyLibrary.loads_meshes()`.
   - `SideRelations` lee los lados del JSON.
   - En la escena solo hay nodos reales para `Starts` (2), `Founts` (5), el cielo y el rig.
3. **El material del suelo se arma por código.** `ThemeApplier.apply` y `LookRig.preview` llaman a `set_tileset_dir`, que crea un `ShaderMaterial` con `ImageTexture.create_from_image`. No se puede ver ni editar en el inspector.
4. **La vista previa se corre.** `editor_preview_recenter` mueve la raíz `HighNoon`. Sin malla, el corrimiento es 0 y la cámara del editor queda lejos de los nodos que sí hay, a unos 1300 m.

**Arreglo mínimo inmediato (035a).** Primero medir con la sonda del editor (§2). Después, guardar la malla visual como archivo: `assets/original/maps/high_noon/terrain_mesh.res`, una `ArrayMesh` horneada con el mismo código de hoy. Se asigna en `high_noon.tscn` como `ext_resource`. El editor la muestra siempre y la sim no cambia. En 035c este archivo pasa a ser el `.glb`.

## 1. Objetivo (criterios de aceptación)

- **Editor:** al abrir `high_noon.tscn` se ven el terreno con su material y todo el contenido del mapa como nodos: edificios, cercas, aldeas, plantas, founts, starts y puntos de NPC. Todo se puede mover y editar. Sigue visible después de recargar cualquier script.
- **Terreno = `.glb`** (`assets/original/maps/high_noon/terrain.glb`), editable en Blender. La colisión sale de su malla al importar. Las alturas de la sim (`ground_height`, `is_on_ground`, `ground_cell_counts`) salen de la misma malla importada, y **no cambian ningún digest**.
- **Tema por dios = material `.tres`** que se edita en el inspector. No se arman materiales por código.
- **Navegación = `NavigationRegion3D`** horneada en el editor desde la escena del mapa. El navmesh queda versionado y lo usa el dedicado. Las consultas son deterministas, la evasión está apagada y `NavGrid` se borra.
- **Banco:** los digests cambian **una sola vez** (035h), por la navegación. La primera diferencia es un camino, y queda documentada.
- **Calidad de caminos:** `rules_suite` de navegación, `crowd_150`, `crowd_tipi` (F88) y un caso de voladoras pasan con criterios numéricos (§7).

## 2. Escena de prueba

- **No hay escena de debug para el editor:** el criterio empieza en `res://scenes/world/high_noon.tscn` **abierta en el editor**. Para la navegación se usan las escenas que ya existen: `debug/rules_suite.tscn` (casos `nav_*` y `crowd_150`), `debug/crowd_tipi.tscn`, `debug/nav_cross.tscn` y `debug/nav_wizard.tscn`, todas con el mismo `high_noon.tscn`. Se suma un caso de voladoras, `debug/nav_flyer.tscn` (ver 035g). Usa el mismo `nav_cases.gd` con otro `.tres` de reglas (otros números), no otro `.gd`.
- **Sonda del editor (nueva, en `agent/`):**
  - `agent/editor/editor_capture.gd` es un autoload `@tool`. Solo existe durante la corrida, por un `override.cfg` temporal en `game/` (`[autoload] EditorCapture="*res://agent/editor/editor_capture.gd"`). `project.godot` no se toca.
  - La sonda:
    1. abre la escena (`EditorInterface.open_scene_from_path`) y espera N frames;
    2. encuadra el viewport 3D sobre el AABB del terreno;
    3. guarda `get_editor_viewport_3d(0).get_texture().get_image()` en `agent/out/035/editor_<paso>.png`;
    4. escribe `editor_<paso>.json` con: `terrain_mesh`, `vertex_count`, `aabb`, `material` (ruta), `navmesh` (ruta y cantidad de polígonos), y la cuenta de hijos de `Buildings`, `Plants` y `NpcSpawns`;
    5. con `--reload`, recarga `terrain.gd` y `map_building.gd` y repite;
    6. sale con `get_tree().quit()`.
  - `agent/editor_capture.sh` crea el `override.cfg`, lanza `"$GODOT" --editor --path game` con timeout de 120 s (un proceso, vsync y tope de memoria, como pide la memoria) y borra el `override.cfg` siempre (`trap`).
  - **Fallback:** si 4.7.2 no deja capturar el viewport del editor, queda el JSON más `screencapture -l` de la ventana. Lo decide el playtester y lo deja escrito.
- **Estado inicial:** editor cerrado, sin `override.cfg`.
- **Lo que todavía no existe:** el terreno después de recargar; el contenido como nodos; la `NavigationRegion3D`.
- **Acción:** ninguna del InputMap; la sonda corre sola. En los casos de navegación, las órdenes las da el script del caso, como hoy.

## 3. Árbol de archivos y responsabilidades

```
game/
├── assets/original/maps/high_noon/
│   ├── terrain.glb                 [+] 035c terreno (verdad), import con opciones fijas: sin LOD, sin sombra, sin optimizar
│   ├── terrain.glb.import          [+] 035c post-import = tools/terrain_import.gd
│   ├── terrain_mesh.res            [+] 035a ArrayMesh horneada (puente); [-] 035c reemplazada por el glb
│   ├── terrain.res                 [~] 035c MapTerrainData DERIVADO del glb al importar (el post-import lo escribe; nadie lo edita)
│   ├── tiles.png                   [=] Image (CPU): tile por celda
│   ├── light.png                   [~] 035b importer "texture", lossless, sin mipmaps
│   ├── sides.tres                  [+] 035d MapSides
│   └── ntts.json / widgets.json    [~] 035d solo entrada de tools/bake_map_layout.gd; el juego no los lee
├── assets/original/themes/<god>/
│   ├── atlas.png.import, edge.png.import  [~] 035b "texture", lossless, sin mipmaps (mismo píxel que hoy)
│   └── ground_classic.tres         [+] 035b ShaderMaterial sacrifice_ground por dios
├── data/themes/<god>.tres          [~] 035b `ground_material`
├── data/nav/high_noon_nav.res      [+] 035f NavigationMesh horneada (versionada; la carga el dedicado)
├── data/nav/nav_bake.tres          [+] 035f NavBakeSettings: radio, alto, pendiente, celda, tamaño de tile (fuente de los números)
├── scenes/world/
│   ├── terrain.gd                  [~] 035a/c: muestra la malla guardada; índice de celdas desde `data` (derivado del glb);
│   │                                    colisión = shape del glb; sin ShaderMaterial.new() (035b)
│   ├── theme_applier.gd            [~] 035b asigna theme.ground_material
│   ├── map_props.gd                [~] 035d sin widgets.json; reparte rules; libera `Plants` en headless
│   ├── high_noon.tscn              [~] 035c Terrain = instancia de terrain.glb; 035d instancia high_noon_layout.tscn;
│   │                                    035f NavRegion (NavigationRegion3D) con high_noon_nav.res
│   ├── map/
│   │   ├── high_noon_layout.tscn   [+] 035d Buildings/, Plants/, NpcSpawns/ (nodos con transform)
│   │   ├── npc_spawn.gd/.tscn      [+] 035d Marker3D @tool: tag, side, facing_deg, ntts_id; modelo de vista previa en el editor
│   │   ├── map_sides.gd            [+] 035d Resource de lados
│   │   ├── map_population.gd       [~] 035d spawnea desde los NpcSpawn en orden de árbol; no instancia edificios
│   │   ├── side_relations.gd       [~] 035d lee MapSides
│   │   └── map_building.gd         [~] 035d `facing_deg` exportado (R2); grupo `nav_source`
│   ├── nav/
│   │   ├── nav_service.gd          [~] 035g misma API (find_path, line_clear, crosses_box, component_at, same_region, take_search_slot)
│   │   │                                sobre NavigationServer3D.query_path; sin AStarGrid2D
│   │   ├── nav_regions.gd          [+] 035g componentes conexos del navmesh (flood fill por aristas, orden fijo) para same_region
│   │   ├── nav_box_blockers.gd     [+] 035g crosses_box sacado de nav_grid.gd (matemática de cajas, no depende del grid)
│   │   ├── nav_rebake.gd           [+] 035g re-horneado SÍNCRONO por tile en el servidor cuando entra o cae una estructura
│   │   ├── nav_grid.gd             [-] 035i
│   │   └── path_follower.gd        [~] 035g solo si cambia el formato de waypoints (no debería)
│   └── look/look_rig.gd            [~] 035b preview asigna el material del tema
├── project.godot                   [~] 035f navigation/world/map_use_async_iterations=false; navigation/avoidance/enable=false
├── tools/
│   ├── bake_terrain_mesh.gd        [+] 035a MapTerrainData → terrain_mesh.res
│   ├── terrain_glb_export.gd       [+] 035c MapTerrainData → terrain.glb (una vez; mantiene orden de vértices e índices y COLOR)
│   ├── terrain_import.gd           [+] 035c EditorScenePostImport: glb → MapTerrainData + trimesh; valida la grilla de 10 m
│   ├── bake_map_layout.gd          [+] 035d ntts/widgets → high_noon_layout.tscn + sides.tres, idempotente; no pisa ediciones sin --force
│   └── bake_nav.gd                 [+] 035f headless: re-hornea el navmesh desde la escena y compara con el versionado
├── agent/
│   ├── editor/editor_capture.gd    [+] 035a
│   ├── editor_capture.sh           [+] 035a
│   └── det_baseline.txt            [~] 035h regrabado UNA vez, con causa en FEATURES
├── debug/
│   ├── terrain_bake_cases.gd       [+] 035a/c horneado == runtime; glb ida y vuelta == original; grilla rota falla
│   ├── nav_cases.gd                [~] 035g casos sobre navmesh (mismo script, umbrales en .tres)
│   ├── nav_flyer.tscn              [+] 035g voladoras: cruzan un hueco o una pared sin pedir camino
│   └── rules/nav_*.tres            [+] 035g umbrales de los casos de navegación
└── RULES.md, FEATURES.md, assets/original/README.md  [~] 035j
```

| Pieza | Responsabilidad | No hace |
|---|---|---|
| `terrain.glb` | Forma y look base del suelo; se edita en Blender | — |
| `terrain_import.gd` | Deriva `MapTerrainData` y la colisión del glb; valida la grilla | Correr en partida |
| `MapTerrainData` (derivado) | Lo que leen `ground_height`, `is_on_ground` y `ground_cell_counts`, en CPU y sin GPU | Editarse a mano |
| `terrain.gd` | Muestra; arma el índice de celdas desde `data`; pone la colisión | Armar materiales ni leer temas |
| `ground_classic.tres` | Suelo clásico del dios | — |
| `high_noon_layout.tscn` | Qué hay en el mapa y dónde | Lógica |
| `NpcSpawn` | Dónde nace un NPC | Replicarse (eso es de `UnitSpawner`) |
| `NavigationRegion3D` + `high_noon_nav.res` | Superficie caminable horneada | Evasión |
| `NavService` | Única puerta de caminos y regiones (un dueño); cupo de búsquedas por tick | Mover cuerpos |
| `NavRegions` | Componentes conexos para `same_region` / `component_at` | — |
| `NavRebake` | Re-hornear el tile tocado, síncrono, en el servidor | Correr en el cliente |
| `BodySeparation` | Separar cuerpos (sin cambios) | — |

## 4. Resource de tipo, nodo, `@export` de instancia

- **Resources** (nunca se mutan en runtime): `terrain.glb` (escena importada); `MapTerrainData` (derivado); `ground_classic.tres` × 5; `GodTheme`; `MapSides`; `NavigationMesh` (`high_noon_nav.res`); `NavBakeSettings` (`nav_bake.tres`); los `.tres` de reglas de los casos.
- **Nodos:** `Terrain` (instancia del glb con `terrain.gd`); `HighNoonLayout`, más cada `MapBuilding`, `Plant` y `NpcSpawn`; `Starts` y `Founts`; `NavRegion` (`NavigationRegion3D`); `Nav` (`NavService`) con sus hijos `NavRegions` y `NavRebake`.
- **`@export` de instancia:**
  - `MapBuilding`: `tag`, `owner_slot`, `facing_deg`.
  - `Plant`: `model`.
  - `NpcSpawn`: `tag`, `side`, `facing_deg`, `ntts_id`.
  - `NavService`: `region`, `max_searches_per_tick`, `box_clearance_m`, `blocker_groups`.
  - `NavRebake`: `region`, `tile_size_m`.
  - `Terrain`: `smooth_ground`. Los niveles de luz pasan al `.tres` del material.

## 5. Diseño

### 5.1 Terreno como `.glb`
- **El glb es la verdad.** `terrain_glb_export.gd` lo escribe una vez desde el `MapTerrainData` actual, con el mismo orden de vértices e índices, las normales y el `COLOR` (tile id y uv local, alfa 0 en paredes).
- **Las opciones de import quedan fijas en `terrain.glb.import`:** sin LOD, sin malla de sombra, sin tangentes, sin optimizar el caché de vértices.
- **El post-import (`terrain_import.gd`):**
  1. lee los arrays de la malla importada;
  2. **valida la grilla:** las x/z de los vértices de suelo caen en múltiplos de 10 m (con tolerancia 1e-3), hay como mucho 2 triángulos de suelo por celda, y las paredes son verticales. Si algo no cumple, falla con un error que nombra la celda;
  3. escribe `terrain.res` (`MapTerrainData`) y la colisión (`ConcavePolygonShape3D`, con las caras en el orden de los índices, igual que `create_trimesh_shape` hoy).
- **Gate de 035c:** sin editar, lo derivado tiene que ser **igual array por array** a lo de hoy y `quick` tiene que dar los mismos digests. Si el importer reordena y no se puede evitar con opciones, el post-import reordena los triángulos por (celda, orden original guardado en `CUSTOM0`). Si tampoco alcanza, se para y se pregunta (P1). El cambio de terreno **no** puede sumarse al regrabado de navegación.
- **En Blender:**
  - se pueden mover las alturas (Y) y las paredes de borde;
  - mover en X/Z o cambiar la topología lo rechaza el import (R4);
  - el tile por celda se pinta en `tiles.png`, no en Blender (R5).
- **El dedicado** carga la escena importada y su `terrain.res` derivado, sin GPU, como hoy.

### 5.2 Contenido como nodos
- `bake_map_layout.gd` hace lo mismo que el código de hoy: el orden de `structures`, los nombres `Bld%03d_<tag>`, `ground_height` para la altura, `facing_deg` y la elección de modelo de planta con el mismo RNG. Lo guarda una vez y desde ahí la escena manda.
- Las plantas son presentación: en headless, `MapProps` libera `Plants`.
- Los NPC son `NpcSpawn`. Quien simula los convierte en unidades en orden de árbol, que es el orden del JSON.
- Los lados quedan en `sides.tres`.
- **Gate de 035d:** `quick` da los mismos digests.

### 5.3 Temas por dios
- `ground_classic.tres` por dios, con `Texture2D` sin pérdida y sin mipmaps: el mismo píxel que el `ImageTexture` de hoy.
- `GodTheme.ground_material` apunta al material. En el editor queda guardado el de `james`. `LookRig.preview_god` cambia la vista previa, y en runtime manda la semilla.
- La capa PBR no cambia (fuera de alcance).

### 5.4 Navegación con `NavigationRegion3D`
- **Fuente de horneado:** el grupo `nav_source` y `SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN`. Entran las colisiones estáticas del terreno (el trimesh derivado del glb) y las de los edificios, founts y altares del layout.
- **Parámetros en `nav_bake.tres`:**
  - `cell_size` de 0,5 m;
  - `agent_radius` = el radio de cuerpo más común + `box_clearance_m` (R7);
  - `agent_max_slope` alto, para que todo triángulo de suelo de `is_on_ground` sea caminable y no aparezcan regiones nuevas;
  - `agent_max_climb` = el escalón de `move_and_slide`;
  - región dividida en **tiles** (`filter_baking_aabb` por tile, 8×8 de 320 m).
- **Horneado:** en el editor con el botón de `NavigationRegion3D`, guardando a `data/nav/high_noon_nav.res`; o headless con `tools/bake_nav.gd`. El navmesh se versiona. `bake_nav.gd --check` vuelve a hornear y lo compara con el versionado. Si da distinto, falla, para detectar un navmesh viejo después de editar el mapa.
- **Consultas** (`NavService.find_path`): `NavigationServer3D.query_path` con `NavigationPathQueryParameters3D`.
  - Usa `PATH_POSTPROCESSING_CORRIDORFUNNEL`, `simplify_path=false`, `metadata_flags=NONE` y la capa de navegación fija.
  - Mismo mapa, mismo navmesh, mismas entradas: mismo camino. Es Recast/Detour en un solo hilo.
  - Se mantienen `take_search_slot` y `max_searches_per_tick`, que son un conteo y no un reloj.
- **Determinismo del servidor de navegación:**
  - `navigation/world/map_use_async_iterations=false`, para que la sincronización del mapa sea síncrona en el frame de física;
  - evasión apagada: `navigation/avoidance/enable=false` y ningún `NavigationAgent3D` con `avoidance_enabled`. `PathFollower` sigue entregando waypoints a `begin_walk`; no se usa `NavigationAgent3D` para moverse;
  - el navmesh se asigna en `_ready` y la primera consulta espera a `NavigationServer3D.map_changed`, o a un tick fijo después de la sincronización. El banco lo comprueba.
- **`same_region` / `component_at`:** `NavRegions` hace un flood fill por aristas compartidas sobre los polígonos del navmesh, en orden de índice, y da un id por componente. Se recalcula después de cada re-horneado.
- **`line_clear`:** es verdadero si `query_path` devuelve 2 puntos, o si el segmento queda dentro del corredor.
- **`crosses_box`:** queda igual, como matemática de cajas en `NavBoxBlockers`.
- **Estructuras de jugadores (manalitos) y edificios destruidos:** `NavRebake` vuelve a hornear **solo el tile tocado**, síncrono en el servidor (`NavigationServer3D.bake_from_source_geometry_data` en el hilo principal), con el mismo `rebuild_delay_frames` de hoy. Un tile de 320 m tiene que hornear en menos de 30 ms (criterio de 035g). Si no da, la alternativa es P3.
- **Voladoras:** hoy `flight.gd` decide si una criatura va por aire. Por aire no se pide camino al navmesh (va en línea recta, como hoy). Las híbridas que caminan usan el navmesh. `nav_flyer.tscn` lo comprueba.
- **Cliente:** como hoy, no consulta (`NavService` apaga la física en un cliente). La región se carga igual, pero no se usa.

## 6. Riesgos y límites

- **R1. Digests.**
  - 035a–035f no pueden mover ningún digest. Gate: `quick` contra `det_baseline.txt` al cerrar cada uno.
  - 035h regraba una vez. El informe muestra, en `s7`, el primer tick distinto y que la primera línea distinta del rastro es un camino. Para eso se compara un rastro de `find_path` (desde, hasta, waypoints) viejo contra nuevo, con un flag `--nav-trace` del caso. El rastro de caminos diverge **antes o en el mismo tick** que el primer digest distinto.
- **R2. Rotación de edificios guardada como base, con 1 ULP de diferencia.** `facing_deg` exportado y aplicado en `_ready` con la misma operación de hoy. La caja del nav lee `facing_deg`.
- **R3. Orden de `_ready`.** Los edificios ahora existen antes de `MapPopulation._ready`. El reporte `edificios 69 · refugios 11` y el digest de 035d lo verifican.
- **R4. Topología libre en Blender.** La rechaza la validación de grilla. `ground_height` y el tile por celda dependen de la grilla de 10 m. Mapas con otra forma necesitan otro RFC, que generalice la consulta de suelo (que ya no depende de la NavGrid después de 035i).
- **R5. Pintar el suelo** se hace en `tiles.png`, no en Blender. Un pincel `@tool` queda para otro RFC.
- **R6. Rendimiento con 150 cuerpos.** `query_path` sobre un navmesh de 2,5 km con tiles es más caro que A* en `AStarGrid2D` de 5 m en tramos cortos, y más barato en los largos.
  - Criterio: `crowd_150` de `rules_suite` con p95 de `find_path` ≤ 300 µs y tiempo total del caso ≤ +20 % contra hoy. `max_searches_per_tick` sigue en 3.
  - El re-horneado de un tile, < 30 ms.
  - Si no se cumple: un caché de caminos por (celda origen, celda destino) invalidado al re-hornear, en un corte aparte.
- **R7. Cuerpos atascados en edificios (el «tipi» de F88).** El corredor funnel pasa a `agent_radius` de las esquinas. Un cuerpo más grande que ese radio raspa la caja y `move_and_slide` no desliza de frente (`wall_min_slide_angle` de 15°).
  - Mitigación: radio de horneado = el radio de cuerpo más común + `box_clearance_m`. Si `crowd_tipi` falla con los grandes, dos mapas de navegación (cuerpo chico y grande, dos `NavigationMesh` versionados) y `NavService` elige por radio.
  - Criterio: `crowd_tipi` con 0 trabadas y todas llegan en ≤ 25 s (hoy 21,8 s). `crowd_rock` igual.
- **R8. Voladoras y huecos.** Una voladora por aire no puede quedar limitada al navmesh, y una híbrida que aterriza en un hueco no puede quedarse sin camino. `nav_flyer` lo cubre: cruza el hueco y llega, y la híbrida vuelve a tierra y llega.
- **R9. Regiones nuevas o perdidas.** La IA (`ai_perception`, `creature_brain`) depende de `same_region`. Si el navmesh separa zonas que la grilla unía (rampas finas, bordes erosionados), la IA cambia de decisión. Criterio: misma cantidad de componentes grandes (> 1 % del área) que reporta hoy `nav: grilla … N regiones`. La diferencia se explica.
- **R10. Navmesh viejo después de editar el mapa.** `bake_nav.gd --check` corre en el banco quick del orquestador. `NavRegion` muestra un warning (`_get_configuration_warnings`) si el hash de la fuente guardado en la metadata del navmesh no coincide.
- **R11. Importer de glTF.** Puede reordenar (gate de 035c) y cambiar con una versión de Godot. Las opciones quedan fijas en `.import` y `terrain_bake_cases` lo cubre.
- **R12. Tamaño.** `terrain.glb` pesa unos 1–2 MB, el navmesh unos 1–3 MB y `high_noon_layout.tscn` unos 200 KB. Si el editor tarda más de 2 s en abrir la escena (lo mide la sonda), `Plants` pasa a `MultiMesh` (P2).
- **R13. Reimportar del `.scp`** pisa las ediciones. `bake_*` y `terrain_glb_export` se niegan si el destino fue editado, salvo con `--force`.

**Fuera de alcance:** capa PBR y pasto como recursos; pincel de tiles; topología libre; otros mapas (el patrón queda listo, pero `OriginalAssets.HIGH_NOON_*` no se generaliza); evasión de Godot.

## 7. Cortes (en serie)

Los developers trabajan sin Godot. El orquestador corre lo headless y el playtester lo que tiene ventana, con comandos que cierran solos.

| Corte | Qué | Criterio medible | Quién verifica |
|---|---|---|---|
| **035a** | Sonda del editor (se corre **antes** del cambio y la causa queda en el F). Se hornea `terrain_mesh.res` y se asigna en la escena. | Antes: algún paso con `terrain_mesh=false`. Después, en `open` y `reload`: `terrain_mesh=true`, `vertex_count == data.vertices.size()`, AABB del mapa, PNG no uniforme. `terrain_bake_cases`: horneado == runtime. `quick` igual. | Orquestador; playtester (sonda) |
| **035b** | Atlas, edge y light pasan a textura sin pérdida y sin mipmaps; `ground_classic.tres` ×5; `GodTheme.ground_material`. | Captura a cámara fija por dios (5): ≤ 1/255 en el 99,9 % de los píxeles contra antes del corte. Sonda: `material` = `themes/james/ground_classic.tres`. `quick` igual. | Orquestador; playtester |
| **035c** | `terrain.glb` + post-import; `terrain.res` y colisión derivados; se quita `terrain_mesh.res`. | Ida y vuelta: arrays iguales y caras del trimesh iguales a las de hoy. Un vértice movido en X hace fallar el import nombrando la celda. Subir 5 m en Y cambia `ground_height` 5 m en esa celda (caso headless). **`quick` igual.** Sonda: `terrain_mesh=true` después de recargar. | Orquestador; playtester (sonda) |
| **035d** | `high_noon_layout.tscn`, `NpcSpawn`, `MapSides`, `facing_deg`; sin JSON en runtime. | Log: `npc farmer 26 slot 3 · taurock 6 slot 4 · edificios 69 · refugios 11`. Sonda: `NpcSpawns=32`, `Plants` = el número de hoy. `grep -r "ntts.json\|widgets.json" scenes/` vacío. **`quick` igual.** | Orquestador; playtester (sonda) |
| **035e** | **Cierre del mapa editable sin navegación:** pasada completa del banco (`all`) y playtest corto de partida. | `run_determinism.sh all` PASS contra la base de hoy. Playtest: partida de 2 min sin errores nuevos en el log. | Orquestador; playtester |
| **035f** | `NavigationRegion3D` en la escena; `nav_bake.tres`; `high_noon_nav.res` horneado y versionado; `bake_nav.gd --check`; ajustes de navegación en `project.godot`. **NavService todavía usa NavGrid.** | `bake_nav.gd --check` PASS dos veces seguidas (horneado reproducible). Sonda: navmesh con > 0 polígonos y su ruta. El dedicado lo carga (log headless `nav: navmesh N polígonos`). `quick` igual, porque nadie lo consulta todavía. | Orquestador; playtester (sonda) |
| **035g** | `NavService` sobre `query_path`, más `NavRegions`, `NavBoxBlockers`, `NavRebake` y `nav_flyer`. Detrás de un `@export var backend` (`grid` / `navmesh`) por un solo corte, para poder comparar en el mismo binario. | `rules_suite` casos `nav_*` PASS con `navmesh`. `crowd_150`: p95 ≤ 300 µs y total ≤ +20 %. `crowd_tipi`: 0 trabadas y llegada ≤ 25 s. `crowd_rock` PASS. `nav_flyer` PASS. Regiones grandes iguales a hoy, o la diferencia explicada (R9). Re-horneado de un tile < 30 ms. Dos corridas de `s7` con `navmesh` dan el mismo digest (determinismo interno). | Orquestador |
| **035h** | **Regrabado único.** `backend=navmesh` por defecto, con `--nav-trace` para el informe. | Informe en FEATURES: primer tick distinto en `s7`, `s1_quick` y `f139`, y la primera línea distinta del rastro es un `find_path`. `det_baseline.txt` regrabado una vez. `quick` PASS contra la base nueva en fixed, fixed2 y stress. | Orquestador; reviewer (lee el informe) |
| **035i** | Se borran `nav_grid.gd` y el `backend` (ya no hay dos dueños). | `grep -r "NavGrid\|AStarGrid2D" scenes/` vacío. `quick` PASS contra la base de 035h, **sin regrabar**. | Orquestador |
| **035j** | RULES (navegación de Godot), FEATURES F72/F88 (nota de reemplazo), README de `assets/original` (fuente de verdad y cómo editar en la escena, en Blender, en `tiles.png` y re-hornear el nav). Pasada final. | Sonda completa PASS. Playtest con ventana: 3 órdenes de mover a través del pueblo y del tipi; las criaturas llegan sin trabarse (capturas). `all` PASS. | Reviewer; playtester |

En cada corte: developer → review corta (fidelidad, un dueño) → orquestador headless → playtester solo si hay algo visible (035a, b, c, d, e, f, j).

## 8. Verificación humana en el editor

1. Abrir `high_noon.tscn`. Se ven el suelo, los edificios, las plantas, los founts y los puntos de NPC con su modelo.
2. Editar un script (un espacio) y guardar: todo sigue visible.
3. `Terrain`: es la instancia de `terrain.glb`. `Material Override` = `ground_classic.tres` (james). Cambiar un nivel de luz se ve al instante.
4. `Look → preview_god = pyro → Vista previa del bioma`: cambia el atlas. Al guardar, `git diff high_noon.tscn` queda vacío.
5. Mover un edificio con el gizmo, después `NavRegion → Bake NavigationMesh`: el navmesh rodea el edificio en su lugar nuevo. Con F5 los campesinos lo rodean. Deshacer las dos cosas.
6. Mover un `NpcSpawn` y F5: el NPC nace ahí.
7. Abrir `terrain.glb` en Blender, subir una loma, exportar y volver al editor (se reimporta solo). La loma se ve. F5: los cuerpos la suben. Re-hornear el nav.

No hay tests automáticos nuevos fuera de los casos headless de `debug/` y el banco, que ya son la regla del repo.

## 9. Preguntas abiertas (con recomendación)

- **P1. Si el importador de glTF reordena y ni las opciones ni `CUSTOM0` lo arreglan, ¿se acepta un segundo regrabado por el terreno?** Recomendación: **no**. Se para en 035c y se ofrece una ruta: el glb se edita en Blender pero entra al juego por `terrain_import.gd`, leyendo los buffers glTF con `GLTFDocument` sin `ImporterMesh`. Así se respeta «una sola vez».
- **P2. Plantas: ¿720 nodos o `MultiMesh`?** Recomendación: **nodos**, editables uno por uno. `MultiMesh` solo si la sonda mide más de 2 s al abrir la escena.
- **P3. Manalitos: si el re-horneado de un tile pasa de 30 ms, ¿qué se hace?** Recomendación: tiles más chicos (160 m) antes que dejar que los manalitos no bloqueen el camino. Que los resuelva `BodySeparation` o la colisión daría unidades trabadas.
- **P4. ¿Uno o dos navmesh por tamaño de cuerpo?** Recomendación: **uno**, y el segundo solo si `crowd_tipi` falla con los cuerpos grandes (R7).

## Decisiones del orquestador (2026-10-18, cola delegada)
Se aplican las recomendaciones de §P: P1 sin segundo regrabado (leer los buffers con `GLTFDocument` si el importador reordena); P2 plantas como nodos, `MultiMesh` solo si la escena tarda más de 2 s en abrir; P3 tiles más chicos si el re-horneado pasa de 30 ms; P4 un solo navmesh salvo que falle el tipi. Los `.import` pasados a VRAM por el editor ya se revirtieron (1748b773).

## Enmienda 2026-10-18 (RULES §Fidelidad y pruebas)

Se bajan los gates de digests. Donde el plan dice «`quick` igual», «no puede mover ningún digest» o «regrabado único con informe», vale esto: `quick` corre en cada corte, y si un digest cambia por el corte se regraba la base con una línea de causa en el F. Los cortes no necesitan una review separada salvo 035g (cambio de navegación). Se quitan P1 (ya no hace falta evitar un segundo regrabado), `--nav-trace` y el informe de 035h. Se mantienen los gates funcionales: mapa visible en el editor, ida y vuelta del glb, conteos de NPC y edificios, `bake_nav --check`, rendimiento y que no se traben las criaturas.

Ajuste del mismo día (usuario): **035a a 035e mantienen «`quick` igual»**. Es un refactor sin cambio de comportamiento, así que un digest movido ahí es un bug, no se regraba. La flexibilidad de regrabar vale solo para la navegación (035g a 035i).
