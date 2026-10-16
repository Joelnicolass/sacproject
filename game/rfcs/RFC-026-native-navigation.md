# RFC-026 — ¿Navegación nativa de Godot (NavigationServer3D) en lugar de NavGrid?

Estado: plan del tech lead (Opus). Decisiones abiertas tomadas por el orquestador por delegación del usuario (ver §8). Arquitectura **estándar**. MP online con dedicado: la navegación vive solo en quien simula. Autoridad: PRD > FEATURES > RULES > VISUAL > RFC-024 (+ adenda) > este RFC.

Pedido del usuario: «¿no es mejor que usemos un pathfinding nativo de Godot para esto?», sobre dos bugs de F75: (1) el mago trabado contra la casa `jhut` (1313, 1239) y (2) la escolta en guardia que empuja al mago hacia atrás.

Features tentativas: **F81** = 026a (medición, etapa 0), **F82** = 026b (spike nativo, condicional), **F83** = 026c (migración, condicional a «go» de 026b y OK del usuario).

## 0. Hechos que cambian la premisa (2026-10-15)

- **Bug (1): no era la grilla.** La caja de esa `jhut` mide 4×4 m y el mago estaba a 12,8 m; lo encerraba su escolta de Manahoars (= bug 2). El caso `nav_box_corner` de `rules_suite` (`debug/nav_cases.gd:58`, caja girada 45° con un camino que roza la esquina) **pasa con NavGrid**.
- **Bug (2): corregido en `BodySeparation.wizard_passes_own`** (prioridad de paso del mago sobre sus criaturas): `escort_jam` 6/6 con 0/4/8/12 escoltas; `ai_vs_trivial` 5/5. Desvío del port respecto de `positionAfterCollision` (state.d:14446-14564), anotado en F75.
- `PathFollower.retarget_m` (10 m): mueve el último tramo sin buscar de nuevo si el destino nuevo está cerca; los seguidores de la IA agotaban las 3 búsquedas por tick.
- **Consecuencia:** ningún bug abierto pide navegación nativa. La pregunta pasa a ser si NavigationServer3D gana por méritos propios contra el costo de migrar y el riesgo para el digest.

## 0.1 Contradicciones entre artefactos

| Choque | Dónde | Gana |
|---|---|---|
| «Pathfinding en grilla» | F72; RFC-024 §6 024b; sacengine PathFinder (state.d:675-880, 5 m) | **F72.** Un navmesh es un desvío del original; solo con «go» de 026b y OK del usuario. |
| Movimiento con el motor, sin integrador paralelo | RULES «Datos» | **RULES.** Un navmesh solo da puntos de paso. RVO modifica velocidades fuera de `move_and_slide` (un tick de demora): queda fuera (§2.2). |
| Reproducible con `match_seed` | RULES «IA», RFC-024 §5.1 | **RULES.** Cualquier opción que mueva el digest entre corridas iguales es no-go. |
| `BodySeparation` = port de `positionAfterCollision` | F73, F75 | Se conserva. |

## 1. Objetivo
- Decidir con números si la grilla alcanza (026a mide el dolor real de la grilla en las partidas existentes).
- Solo si 026a da rojo: spike nativo (026b) con go/no-go numérico.
- Solo con «go» y OK del usuario: migrar detrás de la misma API de `NavService` (`find_path`, `line_clear`, `component_at`, `same_region`, `is_ready`, `take_search_slot`) sin tocar consumidores.
- RVO fuera de los tres cortes.
- 026a no cambia ningún digest: solo mide.

## 2. Comparación

Leyenda: **[V-bin]** el nombre existe en el binario 4.7.2 (`strings`); **[I]** inferido de la doc de 4.x, lo comprueba 026b; **[P]** medido en el port.

### 2.1 NavGrid frente a NavigationServer3D

| Eje | NavGrid hoy [P] | NavigationServer3D |
|---|---|---|
| Bugs (1) y (2) | No eran de la grilla / ya corregido | Irrelevante; un navmesh no evita cuerpos |
| Fidelidad | Modelo del original (5 m, `isFree`, `blockingTolerance`, `sameRegion`) | Desvío: caminos más finos, regiones según radio |
| Construcción | Terreno libre ~40 ms; reconstrucción por estructura 52 → 7 ms (F75) | 2,56 km pide tiles (`set_baking_rect`, `set_border_size`, regiones, `use_edge_connections` [V-bin]); costo desconocido |
| Obstáculos dinámicos | Reconstrucción con demora fija en ticks: determinista, 7 ms | Re-hornear tiles; `NavigationObstacle3D.affect_navigation_mesh`/`carve_navigation_mesh` [V-bin] solo al hornear [I]; horneado asíncrono termina en tick variable → digest; hornear síncrono o aplicar en `T+K` fijo |
| Costo por búsqueda | ~100 µs por orden con camino; presupuesto 3/tick | Desconocido; `map_get_path`, `query_path`, `PATH_POSTPROCESSING_CORRIDORFUNNEL`, `set_simplify_path`, `path_search_max_polygons` [V-bin]; Recast/Detour probablemente más rápido [I] |
| `line_clear` (PathFollower, bench, retarget) | DDA barato | **No hay raycast sobre el navmesh en la API**; reemplazo = consulta de camino o shape-cast: costo oculto principal |
| `component_at`/`same_region` (IA) | Componentes exactos al original | Sin consulta pública de isla por punto (solo `INFO_ISLAND_COUNT` [V-bin]); conservar la grilla para regiones |
| Determinismo | Todo en física, sin hilos: digest estable | `map_use_async_iterations`/`region_use_async_iterations` [V-bin] encendidos por defecto [I] → apagar por mapa (`map_set_use_async_iterations`, `region_set_use_async_iterations` [V-bin]); `map_force_update` [V-bin] sin probar; `navigation/pathfinding/max_threads` [V-bin] |
| Dedicado headless | Sí | Sí [I]; fuente = colisión/caras (`PARSED_GEOMETRY_STATIC_COLLIDERS`, `NavigationMeshSourceGeometryData3D.add_faces`, `add_projected_obstruction` [V-bin]) |
| Memoria | Pocos MB | Con tiles, acotado; sin tiles a 0,5 m, cientos de MB [I] |
| `move_and_slide` | Puntos de paso + `begin_walk` | Igual |

### 2.2 RVO (avoidance de NavigationAgent3D)
Bug (1) no aplica; bug (2) ya corregido (podría haberse resuelto con `avoidance_priority` [V-bin] quitando `BodySeparation`, el port del original). Apiñamiento de 150 (13–17 Manahoar trabados, F72): único caso donde podría ganar, pero es choque cuerpo a cuerpo y RVO sería otra regla de movimiento ajena al original. Determinismo: `avoidance_use_multiple_threads`/`avoidance_use_high_priority_threads` [V-bin]; RVO2 sobre la foto del tick anterior [I]; `velocity_computed` un tick tarde [I]; sin verificar. **Fuera de RFC-026**; si se quiere, RFC aparte que compare RVO con mejoras dentro de `BodySeparation`.

## 3. Árbol de archivos (N = nuevo, M = modificado)

Total: **026a = 2 N / 3 M**, **026b = 4 N / 3 M**, **026c ≈ 0 N / 6 M**.

```
game/
├── debug/
│   ├── nav_load.tscn                 N 026a  etapa 0 (instancia high_noon.tscn)
│   ├── nav_load.gd                   N 026a  corredor: carga de búsquedas, NAV_LOAD {json}
│   ├── ai_match.gd                   M 026a  informe "nav": waits, starved, line_clear_us, search_us p50/p99
│   │                                 M 026b  --nav=grid|mesh (vía nav_backend_flag.gd)
│   ├── nav_native_spike.tscn         N 026b  spike nativo
│   ├── nav_native_spike.gd           N 026b  25 pares, determinismo, costos, NAV_SPIKE {json}
│   └── nav_backend_flag.gd           N 026b  static apply(world, args) según --nav=
├── data/nav/
│   └── navmesh_bake_high_noon.tres   N 026b  NavigationMesh solo con parámetros de horneado
├── scenes/world/
│   ├── terrain.gd                    M 026b  ground_faces(): triángulos del suelo
│   └── nav/
│       ├── nav_service.gd            M 026a  contadores (esperas, ranuras por tick, costo de line_clear)
│       │                             M 026b  @export mesh_planner: NavMeshPlanner (null = grilla)
│       ├── nav_mesh_planner.gd       N 026b  mapa propio síncrono, tiles, horneado, find_path, line_clear, rebake_area
│       ├── path_follower.gd          M 026a  contador de tramos «derecho por falta de ranura»
│       │                             M 026c  umbral de steer_point → @export
│       └── nav_grid.gd               —       se conserva; en 026c queda para regiones
└── rfcs/RFC-026-native-navigation.md N
```

Ningún archivo de `scenes/world/ai/*`, `unit_body.gd`, `wizard_body.gd`, `doctor_body.gd`, `stuck_guard.gd`, `map_building.gd`, `mana_source.gd` ni `body_separation.gd` cambia en ningún corte.

### 3.1 Responsabilidades
- `NavService` (`%Nav`): fachada única; elige grilla o `mesh_planner` para caminos; regiones siempre por grilla.
- `NavGrid`: regiones (`sameRegion`) y planificador por defecto.
- `NavMeshPlanner` (026b): mapa propio de NavigationServer3D con async apagado; hornea por tiles desde caras del suelo + obstrucciones de los mismos bloqueos de `NavService._blockers()`; re-hornea con aplicación en tick fijo; responde `find_path`/`line_clear`. Sin NavigationAgent3D ni RVO.
- `PathFollower`: sin cambio de conducta (contadores en 026a).
- Corredores: medir e imprimir JSON.

### 3.2 Resource / nodo / @export
Resource: `data/nav/navmesh_bake_high_noon.tres` (plantilla; `duplicate()` por tile). Nodos: `NavService`, `NavMeshPlanner`, `PathFollower`. `@export` en `NavMeshPlanner`: `bake`, `tile_m` (256), `apply_delay_ticks`, `postprocessing`, `use_async_iterations` (false, con aviso). En `NavService`: `mesh_planner`.

## 4. Cortes

### 026a — Etapa 0: ¿le duele algo a la grilla? (F81). Sin NavigationServer.
Escena `debug/nav_load.tscn`: `high_noon.tscn` con NPC, dos asientos IA (`ai_vs_trivial.tres`) y, como segunda configuración (`--load=crowd`), el banco de 150 de `selection_many`. Con ventana espera `check_tick` y muestra el contador; headless imprime `NAV_LOAD {json}`.

Mide: ticks con las 3 ranuras agotadas; caminantes en `_waiting` y su duración; tramos «derecho por falta de ranura» que terminan en `StuckGuard` o replanificación; `search_us` p50/p99/max; `line_clear_us` p50/p99; reconstrucciones y su ms.

**Umbrales rojo** (cualquiera abre 026b): R1 p99 de `find_path` > 1 ms o max > 5 ms; R2 > 5 % de búsquedas esperan ≥ 2 ticks o alguna > 30 ticks; R3 algún tramo sin ranura termina trabado > 2 s contra colisión estática; R4 reconstrucción > 16 ms; R5 un camino real que roce/atraviese colisión estática.

**Todo verde = no-go nativo, se cierra en 026a.** Si solo R2/R3 dan rojo, primero se arregla dentro de la grilla (presupuesto o prioridad al mago y órdenes humanas).

Comandos (un proceso a la vez):
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/joelsartori/Development/sacproject/game --fixed-fps 60 res://debug/nav_load.tscn -- --load=match --seed=1 --minutes=30 --out=agent/out/nav26/load_match_s1.json
… --load=match --seed=2..5
… --load=crowd --minutes=5 --out=agent/out/nav26/load_crowd.json
```
Cierre: el JSON trae R1–R5; `ai_match` seed 7 y `ai_vs_trivial` seed 1 dan el mismo digest que antes; `rules_suite` PASS.

### 026b — Spike nativo (F82). Solo si 026a dio rojo y no se arregló en la grilla.
Escena `debug/nav_native_spike.tscn` (69 casas, sin criaturas). (a) Correctitud: 25 pares sembrados + controles `jhut` y `nav_box_corner`; mismos pares con camino; largo ≤ 1,02 × grilla en la mediana; ningún segmento a < 0,6 m de una casa; área caminable ±10 %; `same_region` coincide en ≥ 99 % de 2000 puntos. (b) Determinismo: misma consulta 1000 veces idéntica; tick de mapa listo constante en 5 corridas; con `--nav=mesh` digest de seed 7 igual 2/2 headless + 1 con ventana, `ai_vs_trivial` seed 1 igual 2/2; control con async encendido (informativo); cualquier diferencia con async apagado = no-go. (c) Costo: horneado ≤ 3 s (o caché ≤ 300 ms); re-horneado de un tile ≤ 16 ms o aplicado en `T+K` fijo; `find_path` p50 ≤ 50 µs, p99 ≤ 0,5 ms; `line_clear` p99 ≤ 0,2 ms; RSS extra ≤ 150 MB. **Go** = (a)+(b)+(c) en verde, p99 nativo ≥ 3× menor que la grilla, y el rojo de 026a pasa a verde.

### 026c — Migración (F83). Solo con «go» de 026b y OK del usuario.
`%Nav` con `NavMeshPlanner` hijo; se conservan NavGrid (regiones y respaldo), PathFollower, `retarget_m`, `take_search_slot` (presupuesto como `@export`), BodySeparation con `wizard_passes_own`; nada de archivos borrados; umbral de `steer_point` a `@export`; no se hornea en clientes. Regresión: F72 (`nav_cross`, `nav_wizard`, `target_pick`, suite), F73 (`village*`, casa derribada re-horneada), F75 (`doctor_path`, `ai_vs_trivial` 5/5, `escort_jam` 6/6, libro exacto, 0 errores), digests nuevos reproducibles 2/2, `f25_summon`, `f27_orders`, `pt60`, `pt64`, dedicado.

## 5. Riesgos
Determinismo (async del mapa, horneado asíncrono, orden de regiones, defaults que cambian entre versiones; mitigación: mapa propio con async apagado por API); `line_clear` sin raycast nativo; grilla y navmesh discrepando en regiones angostas; caché vs mapa editable (RFC-018); fidelidad (caminos más ajustados cambian blancos vistos); costo de migrar (re-correr F72–F75). Fuera de alcance: RVO, cambiar BodySeparation, IA nueva, otros mapas.

## 6. Orden
1. 026a: contadores en `NavService`/`PathFollower` y campos `nav` del informe. 2. `nav_load`; semillas 1–5 y `crowd`; digests iguales. 3. Revisión con R1–R5: verde → cerrar F81 «no-go nativo»; R2/R3 rojo → arreglo dentro de la grilla primero. 4–5. 026b solo si sigue en rojo. 6. 026c solo con OK del usuario. Cada corte: developer → reviewer (re-corre comandos y digests) → playtester con ventana (`agent/out/pt26x/`).

## 7. Verificación en el editor
026a: `debug/nav_load.tscn`, F6, Enter; rótulo con búsquedas por tick y esperas; `max_searches_per_tick` = 3 en `%Nav`. 026b: `debug/nav_native_spike.tscn`, `Debug > Visible Navigation`, líneas roja (grilla) y azul (navmesh) sin tocar casas. 026c: partida contra la IA, derribar una casa y ordenar a un Trogg pasar por su lugar.

## 8. Preguntas abiertas → decisiones (orquestador, por delegación del usuario, 2026-10-15)
1. **Correr solo 026a y, si da verde, cerrar con «la grilla alcanza»:** SÍ (recomendado). Los dos bugs que motivaron la pregunta no eran de la grilla.
2. **Apiñamiento de 150 unidades (deuda F72):** dentro de `BodySeparation`, en un RFC aparte (recomendado); RVO no, por ser un desvío de conducta y con determinismo sin verificar en 4.7.2.

## Archivos citados
`scenes/world/nav/{nav_grid,nav_service,path_follower}.gd`; `scenes/world/body_separation.gd`; `debug/nav_cases.gd:58`; `debug/escort_jam.gd`, `nav_cross.gd`, `ai_match.gd`; `scenes/world/terrain.gd`; `scenes/world/map/map_building.gd`; `scenes/world/ai/perception/ai_perception.gd` (:170, :528); `scenes/world/high_noon.tscn`; RULES.md; FEATURES F71–F75; RFC-024 §5 y adenda; reviews REVIEW-RFC-024a/b/d.
