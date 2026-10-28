# Rendimiento de la deformación del terreno: diagnóstico (2026-10-26)


Sólo medí. No arreglé nada. La instrumentación con `Time.get_ticks_usec` que puse en `scenes/` era temporal y ya la revertí (`git status` de `game/scenes` está limpio), y borré `debug/tmp_perf/`.

**Cómo medí:**
- Mac M4 con Godot 4.7.2, en `debug/spells/cast_terrain.tscn` (High Noon).
- Corridas: una headless, cuatro con ventana y Erupt, Volcano, Bore y Bombardment lanzados por `SpellSpawner`.
- Un sello sintético del tamaño de Volcano (34×34 vértices) cada tick, con y sin la colisión conectada.
- El reloj físico va a 60 ticks/s.

**Límites de la medición:**
- La ventana queda trabada en unos 90 fps: no pude apagar el vsync.
- El tiempo de GPU da 0 en Metal, así que la subida de la textura sólo está medida en CPU.
- `Performance.TIME_*` da el peor valor de cada segundo, no un promedio.
- En `cast_terrain` no se aplica ningún preset de calidad, y sin preset la flora no se arma. Para medirla forcé `quality_high`.

### 1. Costos ordenados (hilo principal)

| # | Costo | Por llamada | Llamadas/s | ms/s | Datos copiados |
|---|---|---|---|---|---|
| 1 | **Nav al cambiar la malla, durante Bore.** `NavRegions.build` en GDScript dentro de `swap` | **57 ms** | ~0,4 (cada ~2,5 s) | 23 | ~11 000 polígonos. **Frames de 70–79 ms** |
| 2 | **`TerrainCollision.flush`** con Volcano subiendo | 2,2–2,3 ms (5 ms en headless) | 18,8 | 42 | 23–26 trozos × ~88 triángulos (unos 2 100) por flush. `_faces_of` tarda 58 µs/trozo y `set_faces` 28 µs/trozo. Con Erupt: 0,7 ms × 20/s, unos 6 trozos |
| 3 | **`TerrainDeformer.set_live`**, Volcano subiendo | 0,75–0,78 ms | 54,6 | 42,5 | `field.refresh` 0,52–0,60 ms (1 077 vértices, 0,5 µs/vértice). `_standing` 0,08–0,10 ms. `lift` 0,06–0,12 ms. Señal `changed` 0,02 ms. Con Erupt: 0,33–0,45 ms × **72/s** (un `set_live` por sello) |
| 4 | **Flora.** `VegetationPatch._plant` | 2,15 ms por parche | 4 (cada `replan_every_s` = 0,25 s) | 8,7 por parche | Replanta **todos** los parches del mapa aunque estén lejos: el parche estaba a ~100 m del sello. `MeshPlanter` pasa de 200 a 350 µs/frame (+13 ms/s); `replan` en sí tarda 67 µs |
| 5 | **`TerrainDeformTexture._upload`** | ~75 µs (`to_byte_array` 25–34 µs + `set_data` 4 µs + `update` 45–55 µs) | 55–60 (cada frame con cambio) | 4,5 | **La imagen entera de 512 KB cada frame** (RGF, 256²×2 float32), unos 30 MB/s de subida |
| 6 | `GroundField.snapshot()` (duplica `texels`) | **2,5–3,3 µs** | 55 (una por versión) | **0,15** | 524 288 B. Sí copia las 65 536×2 floats por cambio, pero en el M4 es un memcpy y no pesa |
| 7 | `height_at` | 4,5 µs | baseline 40–90/s; Erupt ~1 000/s; Volcano activo **~6 000/s** con ventana | hasta 27 | `StampCarry` hace 2 llamadas por cuerpo en cada `set_live`. Volcano: estimo que el grueso son las búsquedas por ángulo de `VolcanoLook` (volcano_look.gd:88-94, sólo presentación), pero no lo instrumenté |

**Peor tick de física:**
- baseline: 1,3 ms;
- sello sintético con todo conectado: 4,2–4,5 ms;
- el mismo sello sin colisión: 1,8–1,9 ms.

O sea, la colisión explica unos 2,6 ms del peor tick.

**Bench que queda versionado** (`debug/perf/terrain_deform_bench.tscn`, valores de antes):
- baseline: tick 0,42 ms;
- sello vivo: tick 1,14 ms (p95 2,80) más 0,74 ms por llamada, es decir **+1,5 ms por tick en promedio y +3,2 ms en p95**;
- agujeros: **peor frame 70 ms**.

**Bytes por red:**
- `set_live` no viaja: cada par lo arma con su propio reloj, así que son 0 B.
- `commit` (cráter, abolladura): 212–312 B; el monte entero, ~4,3 KB.
- `set_removed`: 32 B, a 3–5 por segundo durante Bore.
- El snapshot de un par que entra tarde es `permanent` (256 KB) comprimido con zstd.

**Quién escucha `changed` y qué hace:**
- **TerrainCollision:** marca trozos sucios y los rearma cada `refresh_s`.
- **TerrainDeformTexture:** marca la textura sucia y la sube entera.
- **FloraGroundWatch:** junta las áreas que se movieron, replanifica y además llama a todos los parches.
- **NavService:** escucha **sólo `holes_changed`** (nav_service.gd:84). Confirmado: Erupt, Volcano y Dent no rehacen la nav.
- **GroundScars, el minimapa y GrassField** no escuchan.
- **StampCarry** corre dentro de cada `set_live`/`commit`.

### 2. Causas, con archivo y línea

1. **Nav** (*nav_mesh_backend.gd:56-58* y *:188-190*, *nav_regions.gd:25-60*): `swap` llama a `_index`, y `_index` llama a `NavRegions.build`, que es GDScript con diccionarios recorriendo ~11 000 polígonos, en el hilo principal.
   - Además el horneado es del mapa entero (~1 s en un worker).
   - `parse_source_geometry_data` corre en el hilo principal pero cuesta poco: 1–3 ms (nav_rebake.gd:31-43).
2. **Colisión, armado de caras** (*terrain_collision.gd:80-89*): `_faces_of` arma todas las caras desde cero en GDScript y crea un `Array` por triángulo (línea 84).
   - Sigue a los sellos vivos a 20 Hz (líneas 117-120).
   - El costo es por triángulo: ~1 µs en GDScript más 0,33 µs de `set_faces`. Así que `chunk_cells=8` no es el problema: el total es proporcional al área del sello.
   - Rearma trozos de más: hay 1 celda de margen y el rango incluye un trozo extra (líneas 102-109). También se rearman las esquinas del rect donde el sello vale 0, que son ~21 % del cuadrado. Igual, no rearma nada fuera del rect.
3. **Campo** (*ground_field.gd:105-118*): `refresh` recalcula cada vértice del rect sumando **todos** los sellos vivos, con `has_point` y armando un `Vector2i` por vértice.
   - *terrain_stamp.gd:99-118*: cada sello llama a `set_live` en cada tick. `min_step_m` sólo está puesto en el monte de Volcano.
   - *terrain_deformer.gd:43-46*: cada llamada repite su propio refresh, su propio `changed` y su propio StampCarry, así que no hay agrupado por tick. Erupt, con 3 sellos, da 72 llamadas/s.
4. **StampCarry** (*stamp_carry.gd:15-26*): recorre `get_nodes_in_group` de `unit` y `wizard` enteros en cada llamada, y llama a `height_at` por cuerpo. Con 5 cuerpos cuesta 0,08–0,1 ms; escala lineal con las unidades del mapa.
5. **Flora:**
   - *flora_ground_watch.gd:36*: `call_group(VegetationPatch.GROUP, "field_changed")` le llega a todos los parches.
   - *vegetation_patch.gd:98*: la firma del parche incluye `surface.version()`, que cambia en cada tick, así que nunca coincide y el parche replanta siempre.
   - *flora_ground_watch.gd:27-36* junto con *mesh_planter.gd:315-327*: se replanifica también con los cambios vivos.
   - *mesh_planter.gd:385*: llama a `sampler()` en cada frame mientras haya celdas pendientes (93/s).
6. **Textura** (*terrain_deform_texture.gd:54-58*): `to_byte_array` del campo entero, `Image.set_data` e `ImageTexture.update` con la imagen completa en cada frame con cambio. El formato es RGF.
7. **Snapshot** (*ground_field.gd:73-77*): copia todo por cada versión, y la versión sube en cada tick vivo. Hoy pesa 0,15 ms/s; es un problema de diseño, no de rendimiento.
   - **Quién lo pide:** `sampler()`, que llaman `MeshPlanter._start_plans` y `PatchPlanner.plan`.
   - **Quién no:** las unidades usan `height_at`, no `sampler()`.

### 3. Diseño o ajuste

**Diseño:**
- Un `set_live` por sello sin agrupado por tick: un refresh, un `changed` y un StampCarry por sello.
- La suma de todos los sellos por vértice.
- La colisión que se rearma desde cero en GDScript y sigue a los sellos vivos.
- La flora que reacciona a cambios vivos, a todos los parches y a la versión en la firma.
- La subida de la textura entera.
- El snapshot entero por versión (menor).
- `NavRegions.build` en el hilo principal y el horneado del mapa entero.
- StampCarry recorriendo todos los cuerpos.

**Ajuste:** `refresh_s`, `chunk_cells`, `replan_every_s`, `min_step_m` (Erupt tiene 0) y `holes_rebake_s`.

### 4. Propuesta por arreglo (encaja con el `Terrain` único del 063D)

- **F1 · Agrupar por tick en `Terrain`** (S2b).
  - `stamp()`/`unstamp()` sólo guardan el sello (`key`, perfil, centro, alcance, pico, `at_s`).
  - Un solo `_physics_process` de `Terrain` evalúa los sellos que cambiaron y aplica cada uno como diferencia (`texels += nuevo − viejo` en su rect, sin recorrer los demás sellos).
  - Corre StampCarry una vez sobre la unión y emite `changed` **una vez por tick** con la unión.
  - Pasa el umbral de `min_step_m` a `Terrain` para todos los sellos.
  - **Meta:** campo + StampCarry ≤ 0,25 ms/tick con Volcano y ≤ 0,15 ms con Erupt (hoy 0,78 y 0,4 × 3).
- **F2 · Dos señales: `changed` (vivo) y `settled(rect)` (lo que queda)** (S2b). `settled` sale con commit, unstamp o agujeros.
  - La textura y la colisión escuchan `changed`.
  - Flora, nav, marcas y pasto escuchan sólo `settled`.
  - Un parche replanta sólo si su círculo toca el rect, y se saca `version()` de la firma.
  - **Meta:** 0 replantados durante un sello vivo, ≤ 1 por parche tocado en cada commit y 0 fuera del rect.
- **F3 · Colisión** (S3b).
  - Precalcular por trozo las caras base (`PackedVector3Array`), los ids de red de cada vértice (`PackedInt32Array`) y la máscara de agujeros por triángulo.
  - Rearmar = duplicar la base y sumar la altura en un bucle sin `Array`.
  - Saltear los trozos cuyos vértices no cambiaron.
  - Con sólo sellos vivos, `refresh_s` 0,1; en commit o agujeros, al instante.
  - `chunk_cells=8` se queda como está. `HeightMapShape3D` no reproduce la diagonal ni las paredes de la sopa, así que no lo propongo.
  - **Meta:** flush con Volcano ≤ 0,6 ms y ≤ 10 por segundo; peor tick de física ≤ baseline + 1 ms (hoy +2,6).
- **F4 · Textura** (S2b/S3b).
  - Según lo que sé de la API 4.x, `RenderingServer.texture_2d_update` y `RenderingDevice.texture_update` reciben la capa entera, sin región. No lo comprobé en esta corrida.
  - Por eso: una textura chica `terrain_live_map` (RGF) del tamaño de la unión de los sellos vivos, con un uniform `terrain_live_rect`, que el shader suma a la grande.
  - La de 256² se sube sólo con commit, agujeros o al soltar un sello.
  - **Meta:** ≤ 10 KB por frame durante un sello vivo (Volcano: 8,7 KB contra 512 KB) y ≤ 20 µs de CPU.
- **F5 · Snapshot y `sampler()`**: el snapshot se toma sobre la versión asentada (`rev` + agujeros), no en cada tick vivo. Si hiciera falta, copia por trozo de 16×16 con versión por trozo.
  - **Meta:** 0 copias por tick vivo y ≤ 1 por commit.
- **F6 · Nav** (fuera del terreno; puede ir junto a S3b).
  - Primero, `NavRegions.build` pasa a `nav_rebake._work`: es sólo datos, se arma en el worker y `swap` cambia la referencia.
  - Después, regiones de navegación por tiles (160 m, `filter_baking_aabb` con borde) y horneado sólo de los tiles con agujeros. No lo medí.
  - Corrección aparte: hoy los montes y cráteres que quedan no actualizan la nav.
  - **Meta:** peor frame de Bore ≤ 20 ms (hoy 70–79) y ≤ 2 ms de hilo principal por re-horneado.
- **F7 · StampCarry**: una consulta espacial (`intersect_shape` con una caja sobre el rect) una vez por tick sobre la unión, en vez de recorrer los grupos en cada llamada.
  - **Meta:** ≤ 50 µs por tick con 200 unidades.
- **F8 (fuera de alcance)**: `VolcanoLook` hace unas 5 000 llamadas a `height_at` por segundo. Puede cachear por versión asentada o usar `sampler()`.

**Meta global**, medida con `debug/perf/terrain_deform_bench.tscn`: un hechizo que deforma suma ≤ 1 ms por tick en el M4 (tick_ms + call_ms; hoy +1,5 en promedio y +3,2 en p95) y ningún frame pasa de 20 ms (hoy 70).

### Prioridades del coordinador
1. **Snapshot:** las cifras no lo confirman como urgente. Copia las 65 536×2 floats por versión, pero tarda 2,5–3,3 µs y suma 0,15 ms/s. Sólo lo piden la flora (`MeshPlanter` en cada frame mientras haya pendientes, `PatchPlanner`) y las pruebas; las unidades no. Lo resuelve F5.
2. **Textura:** confirmado. Sube entera en cada frame con cambio, RGF de 512 KB. En CPU son ~75 µs; la GPU no se pudo medir. F4.
3. **Colisión:** confirmado que sólo rearma los trozos sucios cada `refresh_s` y nunca fuera del rect. El costo está en el GDScript por triángulo y en seguir a los sellos vivos, no en el tamaño del trozo. F3.
4. **Flora y nav:**
   - **Flora:** confirmado que reacciona a cada cambio vivo y a todos los parches (2,15 ms por parche cada 0,25 s). F2 la limita a los trozos tocados y a cambios que quedan.
   - **Nav:** confirmado que sólo reacciona a `holes_changed`; el corte está en el `swap` de 57 ms. F6, con tiles como segundo paso.

Bench: `debug/perf/terrain_deform_bench.tscn` (F6 con ventana).
