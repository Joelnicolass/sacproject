# 063 — Terreno de malla libre (plan aprobado)

# Plan RFC-063: terreno de malla libre (convivencia con la grilla solo durante la transición, después se borra la grilla)

No toqué el repo. El lint de convenciones está verde y quedó igual que la base, todo en OK.

Ya incorporé el cambio de enfoque del orquestador: la convivencia es **solo una transición** de 4 etapas. Al final queda **un solo sistema**, la malla libre, y la grilla se borra.

**Contradicciones con lo que ya existe** (gana la decisión del usuario, que es la más reciente, sobre los planes anteriores):
- **062** fija `ground_roles.png` en 256² de 10 m dentro del shader. Hay que cambiarlo a una textura proyectada en coordenadas de mundo, con un uniform `ground_size_m` (en la grilla vale 2560). Así funciona igual en malla, sin otro camino.
- **061k** define el desplazamiento como una red fija de 256² cada 10 m (`TerrainDisplacement.SIDE`, `DEFORM_CELL`). Pasa a ser un campo con medidas y tamaño de celda propios.
- **RULES.md:40** dice que «el terreno es `terrain.glb`». Se mantiene: sigue siendo un glb, solo cambia quién lo importa.

---

> **Decisiones del usuario (2026-10-24):** plan aprobado. **Cuevas y voladizos jugables desde ya** (no decoración): la consulta de suelo pasa a ser 3D — `GroundSurface.height_below(pos: Vector3)` / `floor_at(x, y, z)` (el piso caminable más cercano por debajo de la posición del cuerpo, con la caché de cubetas filtrada por altura) y todos los consumidores (unidades, IA, navegación, flora, hechizos, cámara) preguntan con la posición 3D; `height_at(x, z)` queda solo como «superficie de arriba» para quien no tiene altura (vistas, minimapa). El navmesh se hornea con varios pisos (Godot lo soporta) y la deformación de una zona con techo y piso debe definirse (la columna se mueve junta o solo la superficie de arriba: el tech lead/developer lo propone en el corte 2b con criterio medible). **El usuario lo pasó al FINAL de todo el plan (después de la v2 del refactor y del contenido)**; mientras tanto se sigue con la grilla. Resolución de deformación por defecto **10 m, parametrizable** por mapa (`deform_cell_m` en las opciones de importación).

## 1. Objetivo (criterios de aceptación)
- **Un solo punto de entrada al suelo:** `GroundSurface.of(node)`. Responde altura, normal, si hay suelo, agujeros, límites, el sampler para hilos, `changed(rect)` y el campo de deformación. Ningún consumidor pregunta qué tipo de mapa es.
- **Un `.glb` de cualquier tamaño hecho en Blender** se importa y funciona solo: render en trozos con LOD, colisión por trozo, alturas exactas, navmesh, flora, roles del suelo, SCAR y red.
- **Los sellos de los hechizos** (`StampProfile`, `TerrainStamp`, `TerrainDeformer`) funcionan sin cambios en ambos sistemas, con los mismos RPC y el mismo snapshot.
- **Los 9 mapas del original pasan a malla libre con paridad medida** (§6, etapa 3).
- **La grilla se borra** según el registro 1 a 1 (§7). Al cerrar, el grep de símbolos de la grilla da 0.

## 2. Escena de prueba
- **Etapa 1:** el criterio ya empieza en las escenas actuales. No se inventa un debug nuevo. Se usan la suite `terrain_cases`, `debug/net/terrain_late_join.tscn` y `debug/look/flora_cases.tscn`, más un caso nuevo de paridad headless: `debug/map/ground_surface_cases.tscn`.
- **Etapa 2 en adelante:**
  - El mapa real es `scenes/map/maps/mesh_test/map.tscn`. Es una isla de 1200 × 800 m con loma, acantilado, arco con voladizo y pozo, generada con Blender CLI y sin datos del original.
  - La escena de prueba es `res://debug/spells/cast_terrain_mesh.tscn`. Es el mismo script y el mismo árbol que `cast_terrain.tscn`, pero instancea `mesh_test/map.tscn` en vez de HighNoon. No es otro `.gd`.
  - **Estado inicial:** suelo sin deformar y mago en Start1. Todavía no existe el cráter: ese es el resultado del criterio.
  - **El playtester** pulsa `spell_N` (Erupt) y hace clic en la loma.
  - `F5 -- --map=mesh_test` abre el mapa para jugar.

## 3. Árbol de archivos y responsabilidades

```
game/scenes/map/terrain/
  [~→] terrain_shape.gd → ground_surface.gd   GroundSurface (Node, CONCRETO, queda para siempre). Único dueño de los números del
                              suelo: grupo + of(), changed(rect), height_at, is_on_ground, normal_at [+], bounds() [+] (Rect2 xz, el
                              mapa vive en x,z ≥ 0), lowest, sampler(), field(), version(). `meshes: Array[GeometryInstance3D]` [+]
                              (quién lo dibuja, para la capa de look y el minimapa). `ground_roles`/`light_map` [+] (proyectados en
                              mundo, ver 062). Durante la transición elige el backend UNA vez en _reindex según el tipo de `data`
                              (MapTerrainData → TerrainRules; MeshGroundData → MeshGroundRules). Es el único `if` y vive en el dueño.
                              Se mueve el archivo conservando el .uid.
  [~→] terrain_displacement.gd → ground_field.gd   GroundField (RefCounted): el campo xz de desplazamiento y agujeros, con `size: Vector2i` y
                              `cell_m` (grilla: 256², 10 m; malla: bounds/deform_cell_m). shift_at(x,z) bilineal [+] (sobre un nodo de la
                              red es exacto, así la grilla da lo mismo que hoy). rect_around(center, r) reemplaza a vertex_rect estático.
                              commit/set_live/snapshot/rev quedan iguales.
  [~] terrain_deformer.gd     SIDE → field.size. RPC y snapshot sin cambios. Socket `surface: GroundSurface`.
  [~] terrain_stamp.gd        usa surface.field().rect_around y StampRules con field.cell_m.
  [~] stamp_rules.gd          values(..., rect, cell_m): el perfil está en metros, así que el mismo StampProfile vale con cualquier resolución.
  [ ] stamp_profile.gd        sin cambios (se reutiliza tal cual).
  [~] ground_scars.gd / ground_scar_rules.gd   GRID 256 → ceil(bounds/10 m): índice del tamaño del mapa.
  [ ] ground_ray.gd           sin cambios (lee la colisión, sirve para cualquier malla).
  --- solo transición (se borran en la etapa 4) ---
  [ ] terrain.gd, terrain_rules.gd, map_terrain_data.gd, terrain_mesh_arrays.gd, terrain_collision.gd, terrain_ground_material.gd
  --- malla libre ---
  [+] mesh/mesh_ground_data.gd   MeshGroundData (Resource .res, derivado en la importación, como terrain.res): vértices e índices en
                                 mundo, bounds, chunk_m, bucket_m, deform_cell_m. Nunca muta.
  [+] mesh/mesh_ground_rules.gd  MeshGroundRules (static, puro, apto para hilos): index(data) arma la caché de cubetas xz (CSR:
                                 bucket_start + bucket_tris, solo triángulos caminables), triangle_in/height_in/normal_in con el
                                 field. Regla de voladizos: gana el triángulo caminable MÁS ALTO. Las paredes (normal.y < cos(pendiente))
                                 tienen colisión pero no dan altura. Hueco: un triángulo cuyo vértice cae en un nodo del campo quitado.
  [+] mesh/ground_collision.gd   GroundCollision (StaticBody3D): un shape owner por trozo de chunk_m. Rehace solo los trozos que tocó
                                 `changed`, cada refresh_ticks, con los vértices + field.shift_at y sin los huecos. Copia terrain_chunk.tres
                                 (no usa .new() de nodos).
  [~] README.md                  What/Not/Talks to/Edit/Check con GroundSurface; `Debug:` → `Check:`.
game/scenes/look/ground/
  [~] terrain_deform.gdshaderinc   DEFORM_CELL y 255 → globals `terrain_deform_cell_m`, `terrain_deform_size`. Lectura bilineal (en la
                                   grilla da lo mismo). El descarte del hueco por triángulo queda igual.
  [~] terrain_deform_texture.gd    imagen de field.size. Socket rig.ground.
  [~] terrain_layer.gd             aplica el material a `ground.meshes` (todas: 1 en la grilla, N trozos en la malla).
  [~] (062) ground.gdshader        roles y light map por mundo xz / ground_size_m.
game/scenes/look/vegetation/  [~] flora_ground_watch.gd, patch_planner.gd, mesh_planter.gd, vegetation_patch.gd: tipo GroundSurface; version().
game/scenes/look/grass/       [~] grass_height.gd, grass_field.gd: MAP_M 2560 → ground.bounds() (el pasto sigue apagado).
game/scenes/look/look_rig.gd  [~] terrain: MeshInstance3D → ground: GroundSurface.
game/scenes/ui/minimap/minimap_terrain_bake.gd [~] dibuja ground.meshes y encuadra ground.bounds().
game/scenes/units/targeting/side_vision.gd [~] GRID 256 → celdas de 10 m sobre bounds().
game/scenes/map/map_root.gd   [~] terrain: Terrain → ground: GroundSurface (+ warning).
game/scenes/map/nav/nav_service.gd [~] terrain_shape → ground: GroundSurface.
game/scenes/** (≈30 consumidores) [~] TerrainShape.of → GroundSurface.of (mecánico; lista en el grep de §7).
game/scenes/map/maps/mesh_test/    [+] ground.glb (+ .import con post-import), ground.res (derivado), map.tscn, mesh_test.tres
                                   (room_selectable=false), nav.res, ground_roles.png (1 px = 10 m sobre bounds), flora/*.png
game/tools/ground_import.gd        [+] EditorScenePostImport, el ÚNICO camino de importación. Corre el glb a x,z ≥ 0, suelda, triangula,
                                   subdivide los triángulos caminables con borde > max_edge_m, parte en trozos de chunk_m (ImporterMesh +
                                   generate_lods por trozo), escribe ground.res (solo si cambió) y devuelve
                                   Terrain/{Chunks/Chunk_x_z, Surface, Collision}.
game/tools/blender/                [+] make_ground_template.py (escribe ground_template.blend: metros, Y-up, colección «Ground», un plano
                                   guía con el tamaño), export_ground.py (bpy.ops.export_scene.gltf con las opciones fijas),
                                   make_mesh_test.py (la isla de prueba, determinista). Blender se toma de $BLENDER o del PATH; sin rutas personales.
game/tools/import/scaffold_map.py  [~] `--from-glb=<ruta> --tag=<m>`: carpeta, .import con ground_import, map.tscn, MapDefinition,
                                   nav.res vacío y ground_roles.png del tamaño justo. No necesita el original.
game/debug/map/ground_surface_cases.gd/.tscn [+] etapa 1: paridad antes/después (headless).
game/debug/map/ground_parity.gd/.tscn        [+] etapa 3: grilla vs malla del mismo mapa (headless). Se borra en la etapa 4.
game/debug/spells/cast_terrain_mesh.tscn     [+] etapa 2 (la escena de prueba de §2).
```

**Árbol de nodos en el `map.tscn` (estado final; durante la transición la grilla conserva su `Terrain/Shape` actual):**
```
Map (MapRoot)  ground → Terrain/Surface
├── Look (LookRig)  ground → Terrain/Surface
├── Terrain (Node3D, instancia de ground.glb vía ground_import)
│   ├── Chunks/Chunk_0_0 … (MeshInstance3D con LOD automático)
│   ├── Surface (GroundSurface)  data = ground.res, meshes = Chunks/*
│   ├── Collision (GroundCollision)  surface
│   ├── Deformer (TerrainDeformer)  surface        ← en el map.tscn, como hoy
│   └── GroundScars                                 ← en el map.tscn, como hoy
├── MapProps/Starts/Start1 (+WizardSpot), founts, altares, Buildings, Npcs (gizmos en Godot)
├── Vegetation/FloraLayer … · NavRegion (MapNavRegion, «Hornear navmesh») · MinimapBake
```

**Quién habla con quién:**
- **Consultas:** todos preguntan a `GroundSurface.of(node)`.
- **Deformación:** un `TerrainStamp` llama a `TerrainDeformer` (con `set_live`, o `commit` solo en el servidor). El Deformer escribe en `surface.field()` y emite `surface.changed(rect)`.
- **Quién escucha `changed`:** `GroundCollision` (o `TerrainCollision` en la transición), `TerrainDeformTexture`, `FloraGroundWatch` y `NavService` (los agujeros disparan el re-horneado).

**Qué se ve en el editor:**
- Los trozos en el árbol, y la colisión con Visible Collision Shapes.
- El `Reach` de cada sello con su gizmo.
- `Surface` muestra `bounds`, `bucket_m`, `deform_cell_m` y la cantidad de triángulos, como propiedades de solo lectura.
- Las opciones de importación del glb en el dock Import, como knobs del post-import: `max_edge_m`, `chunk_m`, `deform_cell_m`, `walkable_deg`.

## 3b. Qué es Resource, qué es nodo y qué es `@export`
- **Resource:**
  - `MeshGroundData`, derivado y versionado, como `terrain.res`.
  - `StampProfile`, embebido y reutilizado tal cual.
  - `MapDefinition`.
- **Nodos:** GroundSurface, GroundCollision, TerrainDeformer, TerrainStamp, GroundScars, los trozos (`MeshInstance3D`), los Starts y los founts.
- **`@export` de instancia:**
  - Collision: `chunk_m`, `refresh_ticks`.
  - Surface: `meshes`, `ground_roles`, `light_map`.
  - Sello: `keep`, `start_s`.
- **Lo que no es Resource ni nodo:** `GroundField` (RefCounted) y las reglas (static puras). Tampoco hay `.tres` de posiciones (C19).

## 4. Hechizos en ambos sistemas
- El sello calcula en metros: es `StampRules` evaluado en cada nodo del campo de la superficie.
  - En la grilla, el campo es la red de vértices de hoy.
  - En la malla, el campo es una red de `deform_cell_m`: 5 m por defecto en mapas nuevos y 10 m en los mapas migrados, para tener paridad exacta.
- El render, la colisión y `height_at` leen el mismo `field.shift_at` bilineal, así que siempre coinciden.
- **La deformación mueve la columna entera en xz:** el techo de un voladizo baja junto con el piso, nunca se abren grietas y es determinista.
- Los agujeros quitan nodos del campo. Bore sigue usando `set_removed(id)` con ids de `field.size`.
- Red sin cambios:
  - Lo permanente viaja como bytes por `commit`, con `(rev, rect, delta)`.
  - Los agujeros viajan como `(rev, id)`.
  - El que entra tarde recibe el snapshot comprimido.
  - Los sellos vivos se calculan en cada peer con sus propios ticks.

## 5. Flujo humano
- **Blender (solo la forma):**
  1. Abrir `ground_template.blend`.
  2. Modelar en la colección «Ground». Se puede todo: cualquier tamaño, acantilados, arcos.
  3. Correr `blender --background ground.blend --python tools/blender/export_ground.py -- --out=<m>/ground.glb`, o exportar a glTF a mano con las mismas opciones.
- **Godot (todo lo demás):**
  1. `scaffold_map.py --from-glb=… --tag=isla`, o copiar el glb a la carpeta del mapa: la importación lo arma sola.
  2. Mover inicios, manantiales, altares, edificios y NPCs con el gizmo. Un botón `@tool` «Apoyar en el suelo» en `MapProps` usa `height_at`.
  3. Pintar `ground_roles.png` y la flora en cualquier editor de imágenes (1 px = 10 m, mundo visto desde arriba).
  4. Apretar «Hornear navmesh».
- **Mapa de grilla nuevo:** solo durante la transición, y no se recomienda (necesita el original). Al cerrar la etapa 4 deja de existir.

## 6. Orden en cortes chicos y criterios medibles

**Etapa 1 — un solo punto de entrada, grilla detrás, sin cambiar comportamiento (063-1)**
1. Renombrar TerrainShape → GroundSurface (se mueve el archivo y se conserva el .uid) y TerrainDisplacement → GroundField con `size`/`cell_m`.
2. Agregar `normal_at`, `bounds`, `meshes` y `version`.
3. Pasar los consumidores a `GroundSurface.of` y los sockets de MapRoot, LookRig, NavService y minimapa a GroundSurface.
4. Sacar los 2560/256 de pasto, minimapa, SCAR y visión.

Criterios:
- `ground_surface_cases`: `height_at`/`is_on_ground` **iguales bit a bit** en 10 000 puntos con semilla × 9 mapas, contra un volcado tomado antes del corte.
- Pasan `terrain_cases`, `terrain_late_join` (TERRAIN NET PASS) y `flora_cases`.
- El lint no sube.
- Ninguna captura cambia: match_shots con cámara fija en high_noon da diff 0.

**Etapa 2 — malla libre detrás del mismo punto de entrada (063-2a estática, 063-2b deformación, 063-2c look)**
- **2a:** ground_import, MeshGroundData/Rules, GroundCollision, la isla mesh_test y el navmesh.
  - `GroundRay.surface_y` = `height_at` ± 0,05 en 500 puntos.
  - En el arco, `height_at` da el techo (el triángulo de arriba).
  - IA 1v1 durante 3 min en mesh_test: FallCheck = 0.
  - Importación de mesh_test ≤ 10 s; carga de Surface + Collision ≤ 300 ms.
- **2b:** el campo sobre la malla, el include del shader y Erupt en `cast_terrain_mesh`.
  - En el centro, +15,0 ± 0,1 m a los 4,2 s.
  - Coherencia ray/altura ± 0,05 en la región.
  - `terrain_late_join -- --map=mesh_test` con checksum igual.
  - Captura: diff 0 fuera del rect deformado.
- **2c:** roles proyectados (062), SCAR, flora y minimapa en mesh_test.
  - Plantas con |y − height_at| ≤ 0,3.
  - Captura de cámara fija con media por rol dentro de la tolerancia de `measure_ground.py --roles`.

**Etapa 3 — migrar los 9 mapas del original con paridad.** El `terrain.glb` se importa con ground_import (`deform_cell_m` 10, `max_edge_m` 0). En `debug/map/ground_parity.tscn` se cargan los dos backends del mismo mapa en un solo proceso.

| Qué | Criterio |
|---|---|
| Alturas | 100 000 puntos por mapa: \|malla − grilla\| ≤ 1e-4 m donde hay suelo; diferencias de `is_on_ground` = 0; `lowest` ± 1e-4 |
| Colisión | 2000 rayos: malla vs grilla ± 0,01; ray vs `height_at` ± 0,05 |
| Deformación | Erupt, Volcano, Bore y Bombardment en `terrain_cases` con los dos backends: `field.texels` iguales byte a byte al final de cada caso, alturas ± 1e-4, misma cantidad de agujeros; después de Bore, `find_path` no cruza el agujero en ninguno |
| Rendimiento | 100 000 `height_at` (con la caché de cubetas): malla ≤ 1,5× el tiempo de la grilla; `sampler()` en el WorkerThreadPool igual; carga ≤ grilla + 20 %; memoria estática ≤ grilla + 25 %; pico de cuadro durante Erupt ≤ 4 ms sobre la línea base |
| Red | `terrain_late_join` en los 9 mapas: checksum igual en el servidor, en el cliente y en el que entró tarde; tamaño del snapshot ± 5 % |
| Navmesh | Re-horneado desde la colisión de malla: polígonos ± 2 %; largo del camino entre inicios ± 1 % |
| Look | match_shots con cámara fija por mapa: ≤ 0,5 % de píxeles con ΔE > 8 contra la grilla |

Si en rendimiento no se llega al 1,5×, se agrega una caché ráster de alturas (RGF a `cache_cell_m`) como camino rápido, y la cubeta queda como respuesta exacta.

**Etapa 4 — borrar la grilla.** Se hace con el registro de §7. Requiere que el shader de 062 (corte 2) esté integrado, porque el shader viejo lee los tile ids del COLOR_0 de la grilla.

**Rehorneado del navmesh por región:** solo si en mesh_test o en un mapa grande el horneado completo pasa de 2 s. En ese caso se hace por regiones con `border_size` (lo de las costuras está NO VERIFICADO en 4.7.2: se mide en un corte aparte).

## 7. Registro de lo que se borra en la etapa 4 (1 a 1)
- `scenes/map/terrain/`:
  - `terrain.gd`, `terrain_rules.gd`, `map_terrain_data.gd`, `terrain_mesh_arrays.gd`, `terrain_collision.gd` y `terrain_ground_material.gd` (si 062 ya le sacó el trabajo), cada uno con su `.uid`.
  - `terrain_probe.gd`: revisar quién lo usa y borrarlo si solo sirve a la grilla.
- `ground_surface.gd`: la rama de grilla (`TerrainRules`, `tiles_path`, `tile_ids`, `use_tiles`, `cell_counts`, `with_data(MapTerrainData)`, `_use_active_map_data`, que además está en C18).
- `scenes/look/ground/ground_material.gd`: el parámetro `tile_ids`.
- `scenes/look/grass/grass_height.gd`: el horneado desde MapTerrainData (pasa a `sampler()`).
- `scenes/map/map_definition.gd`: los campos `terrain` y `tiles`.
- En los 9 `map.tscn`: los nodos `Terrain` (script terrain.gd), `Terrain/Shape` y `Missing`, reemplazados por la instancia de ground_import. En los 9 `<m>.tres`, las referencias a terrain.res y tiles.
- `assets/original/maps/<m>/`, en los 9 mapas: `terrain.res` y `terrain.glb.import` (se reescribe con ground_import). `tiles.png(.import)` se borra solo si `bake_ground_roles.py` ya no lo lee; hay que verificarlo.
- `tools/`: `terrain_import.gd`, `bake/import_terrain.gd`, `bake/terrain_glb_export.gd` y `bake/make_flat_terrain.gd` (test_flat pasa a un plano de Blender). En `import/scaffold_map.py`, la escritura del `.import` de la grilla. `agent/tools/terrain_asset.py`: revisar.
  - `tools/import/sac_formats/terrain.py` **se queda**: es lo que lee el original y escribe el terrain.glb.
- `debug/`: `map/terrain_shape.gd/.tscn`, `map/terrain_reference.res`, `map/terrain_bed.tscn` y `map/terrain_normals_probe.gd` (si solo leen la grilla), `suite/terrain_bake_cases.gd` y `map/ground_parity.*`. En `agent/harness/match_shots/ground_grid.gd`, revisar si es una superposición de la grilla.

**Criterio de cierre:**
- `grep -rE "TerrainRules|MapTerrainData|TerrainMeshArrays|TerrainCollision|tile_ids|terrain\.res|DEFORM_CELL" scenes tools debug agent` da 0.
- Pasan todas las suites con malla en los 9 mapas.
- El lint baja C13 y C18.

## 8. Riesgos y fuera de alcance
- **Riesgos:**
  - **Memoria y tiempo de carga del índice** en mapas grandes subdivididos. Si la carga pasa de 300 ms, el índice CSR se guarda en `ground.res`.
  - **`ImporterMesh.generate_lods` desde el post-import:** está NO VERIFICADO en 4.7.2. Si falla, se usan trozos sin LOD con `visibility_range`.
  - **`parse_ms` del re-horneado** sobre muchos trozos (es en el hilo principal): hay que medirlo.
  - **Determinismo:** solo usa operaciones IEEE básicas sobre el mismo `.res`, sin rayos físicos en la simulación, y lo permanente viaja en bytes.
  - **Ramas en curso de Volcano y Bore:** dependen de `SIDE` y de ids de 256 (ver pregunta 2).
  - **Cuevas bajo zonas deformables:** el techo y el piso se mueven juntos (ver pregunta 1).
- **Fuera de alcance:**
  - Límites de cámara: hoy no hay; `bounds()` los habilita después.
  - El pasto: sigue apagado.
  - Terreno pintado o esculpido dentro de Godot.
  - LOD por clipmap.
- **¿Terrain3D?** No:
  - Es un heightmap con clipmap: no permite voladizos, cuevas ni una malla libre de Blender, que es justo lo que decidió el usuario.
  - Trae su propio formato y su propia colisión, con lo que habría dos dueños del suelo y la red quedaría en un addon.
  - Es una GDExtension nativa, y el port web (`../sacproject-web`) la complica.
  - Lo que sí se aprovecha de Godot: el import de glTF, `ImporterMesh` con LOD, `ConcavePolygonShape3D` por trozo y el horneado del navmesh desde la colisión.

## 9. Preguntas al usuario (con recomendación)
1. **¿Las cuevas y los voladizos se pueden jugar (unidades caminando adentro) o son decoración en la v1?** Recomiendo decoración: la colisión es completa, `height_at` responde la superficie de arriba y la deformación mueve la columna. Jugarlas exige preguntar la altura por (x, y, z) en todo el juego.
2. **¿El corte 063-1 va después de integrar Volcano y Bore (061k-2/3)?** Recomiendo que sí. Si no, esas ramas tendrían que rebasar con `SIDE` → `field.size` y los ids nuevos.
3. **¿Qué resolución de deformación por defecto para los mapas nuevos de malla?** Recomiendo `deform_cell_m` = 5 m con `max_edge_m` = 5 m: los cráteres quedan más finos que en el original a 4× la memoria del campo, y en un mapa de 2560 m el campo pesa unos 2 MB. Los mapas migrados quedan en 10 m para tener paridad exacta.

**Archivos leídos:**
- `game/CONVENTIONS.md`
- `game/scenes/map/terrain/` (todo)
- `game/scenes/look/ground/terrain_deform.gdshaderinc`, `terrain_deform_texture.gd`
- `game/scenes/map/nav/nav_rebake.gd`, `nav_service.gd`
- `game/scenes/map/map_definition.gd`, `map_root.gd`
- `game/scenes/map/maps/peaks/map.tscn`
- `game/scenes/units/movement/edge_clamp.gd`
- `game/tools/terrain_import.gd`, `tools/import/scaffold_map.py`
- `game/rfcs/plans/061k-terrain-plan.md`, `062-ground-roles-plan.md`
- `game/RULES.md`