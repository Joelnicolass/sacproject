# RFC-054: Flora de los mapas

Estado: en curso. Hecho: 054a (F380). Cortes 054a–054g (F380–F386) y cierre 054z (F387).
Nota de IDs: RFC-053 §16 sumó el corte 053i como F379, así que este RFC usa F380–F387 (los IDs son append-only): 054a F380, 054b F381, 054c F382, 054d F383, 054e F384, 054f F385, 054g F386, 054z F387.
Decisiones de §14 (aceptadas por el usuario el 2026-10-19): celda de 8 m; importar los JAW1–5 reales (054d); un solo interruptor «Vegetación»; sin sombras de plantas; edición por rehorneado + `VegetationClear`; `trees.tres` nace vacío; 054g solo si el usuario lo pide.

**El problema.** En `widgets.json`, peaks, roads y winter_wonder tienen 13.029, 16.331 y 12.696 plantas. El bake no puede plantarlas: con un `MeshInstance3D` por planta salían `.tscn` de 3–5 MB, y se revirtió. High Noon y Peasantville sí tienen plantas, pero como 717 y 1530 nodos `Plant`, con modelos prestados de Persephone.

**Decisiones del usuario (2026-10-19):**
- **Posiciones aproximadas.** Las posiciones no tienen que ser exactas («No necesitamos que todo sea exactamente igual»). Manda la composición general del original.
- **Un motor, tres capas:** pasto, árboles y assets del original. Cada capa se ajusta por separado con su `.tres`, y una cuarta capa sería otra `.tres`.
- **Árboles que bloquean.** En el original, los árboles bloqueaban el paso. Si una capa bloquea, sus posiciones pasan a ser de simulación: tienen que ser deterministas, quedar horneadas y conocerlas también el dedicado.

Autoridad: PRD > FEATURES > RULES > VISUAL > este RFC. Reemplaza 018d (`widget_field`) y la parte de widgets de 022e2.

## 1. Objetivo (criterios de aceptación)

- **Los cinco mapas tienen plantas del original:** especies del mapa y densidad por celda de 8 m como el original, con ±1 por celda a escala 1,0.
- **Datos livianos:** ningún `.tscn` guarda plantas sueltas. Los datos por mapa pesan como mucho 16 KB.
- **Se ven en el editor:** al abrir `scenes/map/maps/<tag>/map.tscn` aparecen las plantas alrededor de la cámara del viewport, y un `VegetationClear` despeja en vivo.
- **Solo presentación:** nada en headless ni en el dedicado, y el banco `quick` no cambia.
- **Perillas por preset:** por capa (encendido, radio, densidad, sombras) en `VegetationQuality` dentro de `LookQuality`, más un interruptor «Vegetación» en Opciones → Gráficos.
- **Presupuesto medido en la M4, preset alto, en peaks y roads:**
  - frame: como mucho +0,6 ms de media y +1,0 ms en p95;
  - como mucho +150 draw calls;
  - como mucho +20 MB.
- **El pasto no empeora:** usa el mismo `CellRing` y se comporta igual; sigue apagado en los presets.

## 2. Relevamiento

### 2.1 Datos

`widgets.json` tiene la forma `{TAG: [[x, z, yaw_rad], ...]}` y solo lo lee el bake.

| Mapa | Filas | Tags | Máx. por celda de 10 m |
|---|---|---|---|
| peaks | 13.029 | CAC3, CAC4, CAF1-3, CAH1-3, CAP1, CPL2, CPL3 | 32 |
| roads | 16.331 | PYA1-4 | 10 |
| winter_wonder | 12.696 | SAW1-3, SAW6-9 | 11 |
| high_noon | 720 | JAW1-5 | 7 |
| peasantville | 1532 | JAW1-5 | 6 |

- **Modelos importados:** peaks, roads y winter_wonder ya tienen sus modelos importados (c95abc5a). Son de 2 a 88 triángulos y miden de 0,15 a 2,5 m.
- **JAW1–5:** no están importados, pero existen en `james_a.wad` (`JA_A.LAND`).
- **Materiales:** `BodyCatalog.mesh(tag)` + `OriginalMaterial.for_label` dan malla y material compartidos, y `BodyCatalog.pose(tag, false)` corrige la pose.

### 2.2 Cómo se plantan hoy

- **Bake:** `bake_map_layout.gd` (`_plan_plants`, líneas 167–199) crea un nodo `Plant` (`BodyVisual`, sin sombra) por cada fila. Usa `WIDGET_MODELS` (JAW→PC*) y saltea los agujeros y los claros alrededor del altar (40 m) y del manantial (6 m).
- **Headless:** `MapProps._ready` libera `plants_root`.
- **Navegación:** `bake_nav.gd:99` libera `Plants`, que no entran en `NavFingerprint`.

### 2.3 Colisión en el original (sacengine, leído y no copiado)

`placeWidgets` (state.d ~31346) pone cada fila como `FixedObject` sin hitbox. Solo se dibujan, no se serializan y no bloquean.

### 2.4 Árboles

Los árboles del original **no son widgets**: son estructuras BLDG del NTTS. En el port ya son `MapBuilding`, con caja de colisión, cortan el navmesh y están en el banco. **Ya bloquean.** Cantidades por mapa:

| Mapa | Árboles |
|---|---|
| high_noon | 31 cactus `jcc1–4` |
| peasantville | 38 `jcc*` y 46 `jct1–3` |
| peaks | 9 `car1` y 12 `cat3/5/7` |
| roads | 23 `pyt*`, 22 `plm*` y 22 `vbl*` |
| winter_wonder | 51 `sic*`, 12 `slp1` y 6 `sig1` |

### 2.5 Pasto

`GrassField` (740 líneas, `LookLayer @tool`).

- **Se extrae y se comparte:**
  - el anillo de celdas, los tiers con histéresis y los centros de cámara;
  - la salida en headless y la integración con el preset;
  - `VegetationClear`.
- **Queda solo en el pasto:** la ubicación procedural en el shader, el bake por `SubViewport`, la pintura del suelo y el pisoteo. Todo eso es específico de las briznas.

## 3. Decisión de arquitectura

**Un motor, dos «plantadores» y una `.tres` por capa.**

- **El motor compartido:**
  - `CellRing`: celdas, tiers y centros, con la cámara del editor o del juego;
  - la exclusión de headless y dedicado;
  - el contrato `LookLayer` y los presets (`VegetationQuality` por id de capa);
  - los claros.
- **Mallas (`MeshPlanter`), para los assets del original, los árboles y las capas futuras:**
  - por celda, en CPU y una sola vez: cuenta por especie según la densidad, aplica jitter con un hash determinista y toma el alto con `Terrain.ground_height`;
  - un `MultiMesh` por (celda, especie);
  - el LOD es un prefijo: `visible_instance_count`.
- **Briznas (`GrassField`), para el pasto:** sigue en su shader y solo pasa a usar `CellRing`.

No se usa `GrassField` con un segundo tipo de brizna, porque su ubicación, su bake y su pisoteo son propios de las briznas, y mezclarlos daría un nodo dios. `FloraField` es un `LookLayer` hermano, y lo compartido vive en `CellRing` y en los Resources.

## 4. Diseño

### 4.1 Datos horneados (`FloraMap`, uno por mapa)

- **`scenes/map/maps/<tag>/flora.res`:** `texel_m = 8.0`, `resolution = 320`, `tags` y `counts: Array[PackedByteArray]` (conteo por celda de 8 m, como mucho 255).
- **Lo escribe `tools/bake/bake_flora_map.gd`** desde `widgets.json` y el terreno, con los mismos claros que hoy. Se puede rehornear sin miedo, y `--check` lo compara contra el JSON.
- **Tamaño estimado:** menos de 10 KB por mapa, contra unos 200 KB si se guardaran transforms. Los conteos por celda conservan las manchas del original.

### 4.2 Ubicación determinista (`FloraPlacement`, funciones puras)

- `n = round_stochastic(count · density_scale)` por celda.
- Un hash de `(seed, tag, tx, tz, i)` da offset, giro y escala. No usa `randi()` ni el azar de la partida.
- Las instancias se ordenan por un hash de rango: cualquier prefijo es una muestra pareja, y eso es lo que permite el LOD.
- El alto sale de `Terrain.ground_height`. Se descarta lo que esté fuera del suelo o dentro de un `VegetationClear`.

### 4.3 Runtime (`FloraField`, `LookLayer @tool`)

- `@export var configs: Array[VegetationLayerConfig]`, con un `MeshPlanter` por config. Cada celda de 32 m tiene un `MultiMeshInstance3D` por especie.
- Construye como mucho `max_builds_per_frame` celdas por cuadro y guarda una caché LRU de 64.
- **LOD:** los tiers de la config cambian `visible_instance_count`, y además hay `visibility_range_end` con fundido.
- **Sombras:** por especie y apagadas por defecto. El preset puede apagarlas todas.
- **Datos del mapa:** el `FloraMap` llega por el socket `LookRig.flora_map`, que se fija en cada `map.tscn`.
- **`density_source`:**
  - `MAP_TAGS`: cada tag dibuja el prop con su mismo nombre;
  - `MAP_TAG`: un solo tag;
  - `NONE`: la capa no dibuja nada;
  - `BAKED` (054g): posiciones horneadas;
  - más `model_substitutes`.
- **Claros:** `VegetationClear` avisa al grupo `vegetation_field`, y solo se reconstruyen las celdas afectadas.
- **Headless y dedicado:** el `LookRig` se libera y `FloraField` sale si está en headless.

### 4.4 Presets y Opciones

`VegetationQuality` define, por capa: `layer_id`, `enabled`, `radius_scale`, `density_scale`, `shadows` y `max_builds_per_frame`. `LookQuality.vegetation` es un `Array[VegetationQuality]`.

Valores de `original_plants` por preset:

| Preset | Radio | Densidad | Sombras |
|---|---|---|---|
| Bajo | 0,45 (72 m) | 0,6 | no |
| Medio | 0,7 (112 m) | 0,85 | no |
| Alto | 1,0 (160 m) | 1,0 | no |

- **Opciones → Gráficos:** un interruptor «Vegetación» (`GraphicsPrefs.vegetation_enabled`).
- **Editor:** `editor_quality` (preset medio por defecto).

### 4.5 Edición en el editor

1. **Ver:** el anillo sigue a la cámara del viewport.
2. **Despejar:** con un `VegetationClear`, en vivo.
3. **Rehornear:** «Hornear flora» en el plugin, o `bake_flora_map.gd --map=<tag>`.

El pincel de densidad y `FloraPatch` quedan para otro RFC.

### 4.6 Árboles

- **Los árboles del original no se tocan.** Ya bloquean como `MapBuilding` (§2.4), y pasarlos a MultiMesh haría perder su caja, su perfil de cuerpo a cuerpo y su lugar en el banco.
- **`trees.tres` nace vacío** (`density_source = NONE`).
- **054g (opcional, con OK): árboles horneados que bloquean, para bosques nuevos o mapas propios.**
  - **Posiciones:** `TreePlacement.res` guarda `(x, z, yaw, scale, species)`. Lo escribe `bake_trees.gd` desde una densidad y una semilla.
  - **Colisión:** `TreeObstacles` es un nodo del mapa, fuera del `LookRig`, y existe también en el dedicado. Usa `PhysicsServer3D` con un cilindro por árbol y un cuerpo por celda, sin miles de nodos.
  - **Navegación:** `bake_nav` llama a `add_projected_obstruction` por cada árbol, y `NavFingerprint` incluye el hash.
  - **Dibujo:** con `density_source = BAKED`.
  - **Banco:** se regraba una vez para los mapas afectados, con una línea de causa.

### 4.7 Migración del pasto

- **054b:** `GrassField` pasa a usar `CellRing`. Es la misma aritmética, movida de lugar.
- **Prueba:** un golden de claves y tiers, grabado antes de mover el código.
- **Los campos `grass_*`** pasan a `VegetationQuality` recién cuando vuelva el pasto, fuera de este RFC.

### 4.8 High Noon y Peasantville

- **Modelos:** se importan los JAW1–5 de `james_a.wad`.
- **Layouts:** salen los nodos `Plants` (717 y 1530, unos 270 KB y 580 KB).
- **`bake_map_layout`** deja de plantar y desaparece `WIDGET_MODELS`.
- **`MapProps`** deja de usar `plants_root`.
- **`bake_nav`** pierde la línea 99; el hash no cambia.
- **`editor_capture`** cuenta la flora.

## 5. Escena de prueba

`res://debug/look/flora_lab.tscn` + `flora_lab.gd`.

- **Qué instancia:** el `map.tscn` real, con su flora, más una cámara y un `Label` de métricas.
- **Atajos:** se definen como `FloraLabSetup` `.tres`, con poses fijas: `peaks_high`, `roads_low` y `high_noon_high`.
- **Uso:** `check_tick` pasa a la pose siguiente; la última es aérea, a 120 m.
- **Sin ventana:** `res://debug/look/flora_cases.tscn` (watchdog de 20 s) y `cell_ring_cases.gd`.

## 6. Árbol de archivos

```text
game/
├── scenes/look/vegetation/          N  motor compartido (README.md)
│   ├── cell_ring.gd                 N  CellRing
│   ├── vegetation_layer_config.gd   N  VegetationLayerConfig (Resource)
│   ├── vegetation_species.gd        N  VegetationSpecies (Resource)
│   ├── vegetation_quality.gd        N  VegetationQuality (Resource)
│   ├── flora_map.gd                 N  FloraMap (Resource)
│   ├── flora_placement.gd           N  funciones puras
│   ├── mesh_planter.gd              N  MeshPlanter
│   ├── flora_field.gd               N  FloraField (LookLayer @tool)
│   └── flora_layer.tscn             N
├── scenes/look/grass/grass_field.gd       M  054b: CellRing; grupo vegetation_field
├── scenes/look/grass/vegetation_clear.gd  M  avisa a vegetation_field
├── scenes/look/look_quality.gd            M  vegetation, vegetation_for()
├── scenes/look/look_rig.gd/.tscn          M  socket flora_map; Layers/Flora
├── scenes/map/props/map_props.gd          M  054d: sin plants_root
├── scenes/map/maps/<5>/flora.res          N  FloraMap horneado
├── scenes/map/maps/<5>/map.tscn, layout.tscn  M
├── scenes/ui/options/graphics_prefs.gd, graphics_tab.*  M  054f: «Vegetación»
├── data/look/vegetation/original_plants.tres, trees.tres  N
├── data/look/quality_{low,medium,high}.tres  M
├── tools/bake/bake_flora_map.gd           N
├── tools/bake/bake_map_layout.gd, bake_nav.gd  M  054d
├── tools/import/sac_formats/props.py      M  054d: james_a.wad (JAW1-5)
├── addons/sacrifice_tools/plugin.gd       M  054f: «Hornear flora»
├── agent/editor/editor_capture.gd         M  054d
└── debug/look/flora_lab*, flora_cases*, cell_ring_cases.gd, look_bench.gd (M)
```

## 7. Responsabilidades

| Pieza | Responsabilidad | Dueño del estado |
|---|---|---|
| `CellRing` | Qué celdas existen y en qué tier | Las claves y tiers de su anillo |
| `FloraPlacement` | Instancias de una celda (función pura) | — |
| `MeshPlanter` | De celdas a `MultiMeshInstance3D`, con caché y tiers | Sus nodos internos |
| `FloraField` | Contrato `LookLayer` hacia los planters | Las configs activas y el preset efectivo |
| `FloraMap` | Densidad de un mapa | El `.res` (solo lo escribe el bake) |
| `VegetationLayerConfig`, `VegetationSpecies` | Cómo se ve una capa | Su `.tres` |
| `VegetationQuality` | Cuánto dibuja una capa en un preset | Su preset |
| `TreeObstacles` (054g) | Colisión de los árboles horneados | Sus RID de física |

## 8. Presupuesto (054e, con ventana)

- **Cómo se mide:** `look_bench` con los casos `flora_peaks` y `flora_roads`, preset alto, sin vsync, con flora y sin flora.
- **Qué mide:** frame (media y p95), draw calls, primitivas, VRAM, RSS, instancias y el peor cuadro de construcción.
- **Criterios:**
  - frame: como mucho +0,6 ms de media y +1,0 ms en p95;
  - como mucho +150 draw calls;
  - como mucho +20 MB;
  - construcción: como mucho 1,0 ms por cuadro.
- **Si sobran draw calls:** `merge_cells`, un MultiMesh por especie para todo el anillo.

## 9. Determinismo y red

- **Plantas y pasto:** son solo presentación, sin colisión, sin RPC y sin azar compartido.
- **Banco `quick`:** no cambia entre 054a y 054f.
- **054g:** es lo único que cambia la simulación, y solo en los mapas con árboles nuevos.

## 10. Cortes

Comando headless común: `godot --headless --path game res://debug/look/flora_cases.tscn` → `FLORA CASES PASS`, en menos de 20 s.

- **054a: FloraMap y bake.** Sin ventana.
  - Hace: `FloraMap`, `FloraPlacement`, `bake_flora_map` y los `flora.res` de los cinco mapas.
  - Criterios:
    - `total()` coincide con la cuenta de `_plan_plants`;
    - cada `.res` pesa como mucho 16 KB;
    - con la misma semilla salen los mismos bytes;
    - la escala 0,5 da la mitad, ±1;
    - el prefijo sale parejo.
- **054b: `CellRing` para el pasto.** Sin ventana.
  - Golden del anillo grabado antes.
  - `quick` igual.
- **054c: `FloraField` en peaks, roads y winter_wonder.** Con ventana.
  - Sin ventana y con `--dedicated` no queda ningún `MultiMeshInstance3D`.
  - Playtest con `flora_lab_peaks_high`: plantas sobre el suelo, claro en el manantial y celdas que aparecen sin saltos.
  - El editor muestra las plantas.
- **054d: JAW1–5 y migración de High Noon y Peasantville.** Con ventana.
  - Pruebas: `bake_map_layout --check`, `bake_nav --check` (hash igual) y `quick` igual.
  - `total()` da 717 en high_noon y 1530 en peasantville (medido en 054a; antes decía 718 y 1531).
  - Captura comparada contra la de antes.
- **054e: presupuesto.** Con ventana; los criterios son los de §8.
- **054f: Opciones y plugin.** Con ventana corta.
- **054g: árboles horneados que bloquean.** Solo con el OK del usuario. Con ventana y con review.
  - En el dedicado: hay cuerpos de física y no hay MultiMesh.
  - Un `ShapeCast3D` choca contra un árbol.
  - El navmesh tiene el hueco.
  - Se regraba el banco.
- **054z: cierre.** `all` da igual, salvo lo que cambie 054g. READMEs, FEATURES y limpieza de los flows viejos.

## 11. Cómo lo verifica un humano

1. Abrir `scenes/map/maps/peaks/map.tscn` y mover la cámara: se ven las plantas. Mover un `VegetationClear`: despeja en vivo.
2. `Look/Layers/Flora` → `configs[0]`: los cambios se ven en vivo.
3. F6 sobre `debug/look/flora_lab.tscn`, recorrer las poses con `check_tick` y leer las métricas en el `Label`.
4. F5 en roads: con Opciones → Gráficos → «Vegetación» se apaga y se prende. En preset Bajo, el radio se achica.
5. `high_noon/layout.tscn` queda sin `Plants` y pesa unos 270 KB menos.

## 12. Riesgos

- **Bordes de agujeros:** se resuelve con `is_on_ground`.
- **Costo de `ground_height` por instancia:** se mide en 054e.
- **Draw calls en peaks:** si se pasan, `merge_cells`.
- **Editor pesado:** preset medio y límite de construcción por cuadro.
- **Importar JAW necesita `SAC_INSTALL`:** sin la instalación, se usa `model_substitutes`.
- **Flows viejos que miran `Plants`:** se limpian en 054z.

## 13. Fuera de alcance

- Encender el pasto.
- Viento y flores CC0 (022e2).
- Pincel de densidad.
- Pasar los árboles NTTS a MultiMesh.
- Port web.
- 054g sin el OK del usuario.

## 14. Preguntas abiertas (con recomendación)

1. **¿Una capa de árboles que bloquean?** Los del original ya bloquean como `MapBuilding`. **Recomendación:** `trees.tres` vacío, y 054g solo si se quieren bosques nuevos.
2. **Celda de densidad:** **8 m** (recomendado) o 16 m.
3. **High Noon y Peasantville:** **importar JAW1–5 reales** (recomendado) o seguir con las plantas de Persephone.
4. **Opciones:** **un solo interruptor «Vegetación»** (recomendado) o uno por capa.
5. **Edición:** **rehornear + `VegetationClear`** (recomendado). El pincel queda para otro RFC.
6. **Sombras de las plantas en el preset alto:** **apagadas** (recomendado) o solo en las especies de más de 1 m.
