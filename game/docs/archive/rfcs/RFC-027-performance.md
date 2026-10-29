# RFC-027 — Rendimiento con 150 criaturas

Estado: plan del tech lead (Opus), aprobado por el orquestador por delegación del usuario. Arquitectura estándar. Online = dedicado: el tick corre en quien simula; el render solo en clientes. Autoridad: PRD > FEATURES > RULES > VISUAL > RFC-022/024/025/026 > este RFC.

Features: **F85** = 027a (medición). **F86–F91** = 027b–027g, cada uno solo si la tabla de 027a lo justifica (si no, «descartado por medición» sin código).

## 0. Hechos e hipótesis
- Selección de 150 (F78, REVIEW-025a §5): frame de pared 411–544 ms, CPU de proceso ~49,8 ms, 248 draws, medido con otro Godot abierto. Cliente del dedicado: 16–21 ms.
- F66: 60 cuerpos 8,3 ms en medio. F73: grilla de BodySeparation 2,34 ms con 78. F75: IA p99 0,7–0,9 ms. RFC-022e: pasto ~+4 ms. Primera orden de 150 = 37 ms (`ClipPosePlayer._frame_mesh` arma con `ObjMesh.build` las mallas del clip «run» la primera vez).
- **H1 (acumulación de ticks):** `project.godot` no fija `physics_ticks_per_second` ni `max_physics_steps_per_frame` (60 y 8). Si el tick con 150 cuesta ~45 ms, cada frame corre hasta 8 ticks → ~360 ms + proceso + render. `TIME_PHYSICS_PROCESS` reporta un paso. Explica también los 16–21 ms del cliente. 027a la confirma o descarta contando ticks por frame.
- **H2 (contención):** el otro Godot competía. 027a corre solo.
- Metal: `viewport_get_measured_render_time_gpu` da 0 (F65); render por resta con el árbol en pausa.

### 0.1 Contradicciones
- Escenas de prueba en `res://agent/fixtures/` (AgentKit) en vez de `res://debug/` (precedente RFC-022e §12); instancian `debug/selection_many.tscn` sin cambiarla.
- Variantes 0/50/150 = escenas heredadas con override de `own_count`, sin script nuevo.
- RULES «reproducible con match_seed»: todo corte deja el digest igual salvo 027d, que lo declara.
- Radios de pasto aprobados (RFC-022e): 027g solo cambia `.tres` con OK del usuario.

## 1. Objetivo
- 027a: tabla de costos por subsistema que explica ≥ 80 % del frame (selection_many 0/50/150 quietas y en marcha; partida real con IA y NPC; 1280×720, medio, máquina libre); confirma o descarta H1 con ticks/frame.
- Meta final: 150 en marcha, 1280×720, medio: frame p95 ≤ 16,7 ms, 1,00 tick/frame, tick p99 ≤ 10 ms. Primera orden de 150 ≤ 12 ms. Digest igual salvo 027d. El dedicado no construye nada de render.

## 2. Escena de prueba
- `agent/fixtures/perf027_many.tscn`: instancia `debug/selection_many.tscn` + nodo `FrameBudget` (`agent/perf/frame_budget.gd`). `perf027_many_50.tscn` y `perf027_many_0.tscn` heredan y cambian `Group.own_count`.
- `agent/fixtures/perf027_match.tscn`: `debug/ai_match.tscn` con ventana (`--rules=res://debug/rules/ai_vs_trivial.tres --seed=1 --minutes=3`) + `FrameBudget`.
- Estado inicial: unidades quietas, `quality_medium.tres`, HUD visible, vsync apagado solo en el banco, 1280×720. Falta: el reparto del frame.
- Acción: `agent/flows/perf027_many.json` (reusa `f78_perf.json`: arrastra `select` sobre las 150, `order_units` lejos; mide «en marcha»). En la partida no hay input.

## 3. Árbol de archivos (N/M/D)
```
game/
├── agent/
│   ├── perf/frame_budget.gd                 N  027a  medición; reemplaza a perf_probe
│   ├── perf/perf_probe.gd / .tscn           D  027a  sus barridos pasan a frame_budget
│   ├── fixtures/perf027_many.tscn           N  027a
│   ├── fixtures/perf027_many_{0,50}.tscn    N  027a  heredan; solo own_count
│   ├── fixtures/perf027_match.tscn          N  027a
│   ├── flows/perf027_many.json              N  027a
│   ├── flows/perf027_first_order.json       N  027b  primera orden de 150 (Orders.last_apply_us)
│   └── run_perf027.sh                       N  027a  4 casos de a uno; aborta si godot_busy
├── scenes/world/
│   ├── components/clip_pose_player.gd       M  027b  precalentar por modelo; asignar malla solo al cambiar de cuadro
│   ├── unit_body.gd                         M  027c1 reposo (condicional)
│   ├── units/target_picker.gd               M  027c2 consulta por celdas (condicional)
│   ├── body_separation.gd                   M  027c2 consulta de celdas; 027d apiñamiento
│   ├── units/unit_health_bar.gd / .tscn     M  027e  escribe en el lote; respaldo sin lote
│   ├── units/health_bar_batch.gd / .tscn    N  027e  MultiMeshInstance3D único (%HealthBars)
│   ├── units/unit_health_bar.gdshader       M  027e  INSTANCE_CUSTOM
│   ├── high_noon.tscn                       M  027e  instancia HealthBarBatch
│   └── look/look_quality.gd                 M  027f  grupo «Bodies (027f)»
├── data/look/quality_{low,medium,high}.tres M  027f/027g  valores (con OK del usuario)
└── debug/rules/ + debug/*_cases.gd          M  027d  caso crowd_150 en rules_suite
```

### 3.1 Responsabilidades
- `FrameBudget` (harness, solo cliente con ventana): calienta y mide en ventanas de 120 frames: frame de pared (media, p95), ticks por frame (`Engine.get_physics_frames()`), `TIME_PROCESS`, tick de script (nodos con `process_physics_priority` mínima y máxima marcan inicio y fin), contadores existentes (`BodySeparation.sep_us`, `TargetPicker.total_us`, `AiSide.ai_ms`, `Orders.last_apply_us`), barridos por cuerpo (`move_and_slide`, `GroundGuard`, `_update_clip_state` + `advance`), render por resta con `SceneTree.paused` (base, sin pasto, sin barras, sin sombras del sol, sin mallas de cuerpos), draws, prims, objetos, VRAM, RSS. Escribe `PERF_TABLE <json>` y `agent/out/perf027/<caso>.md`. Corta si RSS + VRAM > 2,5 GB.
- `ClipPosePlayer`: reloj del clip en física (sin cambio); construye y asigna mallas solo en clientes.
- `HealthBarBatch`: un MultiMesh para todas las barras; datos en `_process` (presentación); inerte en headless.
- `UnitHealthBar`: misma API; con lote escribe su ranura; sin lote se dibuja sola.
- `LookQuality`: presupuesto visual por preset.

### 3.2 Resource / nodo / @export
Resource: `LookQuality` (knobs de 027f y valores de 027g). Nodos: `FrameBudget`, `HealthBarBatch`, `ClipPosePlayer`, `UnitHealthBar`. `@export`: en `FrameBudget` `warmup_frames`, `window_frames`, `cases`, `out_dir`, `rss_cap_mb`; en `HealthBarBatch` `max_bars`; en `UnitHealthBar` `batch`.

## 4. Cortes
Medida común: `run_perf027.sh`, máquina libre, un Godot, 1280×720, medio. Regresión mínima común: `ai_match ai_vs_trivial --seed=1 --minutes=3` headless con digest igual; `rules_suite`; `f78_many` y `f79_roster`; en cortes de render, captura de `selection_many` con diff ≤ 1 % fuera de lo cambiado.

- **027a — Medición (F85).** `FrameBudget` (absorbe y borra perf_probe), 4 fixtures, flow y script; correr 0/50/150 quietas y en marcha, la partida real y `--print-fps` de control. Criterio: tabla por caso; fila «explicado» = ticks/frame × tick + proceso + render base ≥ 80 % del frame en 150 en marcha; H1 confirmada o descartada con un número; `godot_busy` en 0 antes de cada corrida. Al cerrar, el orquestador ordena 027b–g.
- **027b — Clips precalentados (F86).** Independiente de la tabla, en paralelo con 027a. `ClipPosePlayer` construye las mallas de todos los roles la primera vez que ve un modelo (sin hacer nada si `BodyCatalog.loads_meshes()` es falso); `_apply_frame_mesh` asigna solo si cambió el cuadro o el rol; el reloj no se toca. Criterios: primera orden de 150 ≤ 12 ms (`perf027_first_order.json`); precalentado ≤ 40 ms por modelo; tick igual o menor; digest igual.
- **027c — Tick de simulación (F87), solo si H1 se confirma.** c1 reposo (si `move_and_slide` + `GroundGuard` ≥ 30 % del tick con 150 quietos): cuerpo IDLE en el piso, sin velocidad ni empuje, no llama `move_and_slide` ni `GroundGuard`; el reloj del clip sigue; si el digest cambia, revertir y consultar. c2 blancos por la grilla (si `TargetPicker.total_us` ≥ 30 %): `pick` por celdas de `BodySeparation` en el mismo orden relativo. Criterios: tick p99 ≤ 10 ms; 1,00 tick/frame; digest igual (seed 1 y 7). Si el primer renglón de la tabla es otro, el orquestador escribe c3.
- **027d — Apiñamiento en BodySeparation (F88).** Deuda F72 (RFC-026 §8, sin RVO). El cuerpo que no puede avanzar cede o se desliza; desvío documentado de `positionAfterCollision`. Criterios: caso `crowd_150` en `rules_suite` (orden a 80 m) con 0 trabadas > 2 s; `sep_ms` medio ≤ 3 ms; digest nuevo declarado y línea base re-sembrada. Si se estima > 2 h, partir en «caso + causa» y «arreglo».
- **027e — Barras en un MultiMesh (F89).** Solo si «sin barras» ≥ 1 ms o ≥ 100 draws. `INSTANCE_CUSTOM` (fracción, color/bando), billboard en el shader. Criterios: draws −N; resta ≤ 0,3 ms; captura diff ≤ 1 %; F6 de `unit.tscn` sigue mostrando la barra.
- **027f — Presupuesto de cuerpos por preset (F90).** Solo si «sin sombras» o «sin mallas de cuerpos» ≥ 2 ms. `LookQuality.body_cast_shadows`, `body_visibility_range_m` aplicados en `_bind_mesh`. Cambia el look: valores con OK del usuario.
- **027g — Pasto en calidad media (F91).** Solo si «sin pasto» ≥ 2 ms con 150. Solo `quality_medium.tres`, con OK del usuario. Criterio: resta ≤ 1,5 ms y sin regresión en capturas de 022e4.

Orden por impacto si H1 se confirma: c > b > d > f > e > g. Si se descarta: f, e, g antes que c.

## 5. Riesgos
Determinismo (nada de simulación en `_process`; reloj del clip, orden de iteración y RNG iguales; el digest es la puerta de cada corte); dedicado headless (precalentado y `HealthBarBatch` inertes; 027c/d se verifican con `ai_match` headless); medición en Metal (resta con pausa mezcla el compositor; repetir 2 veces, ±1 ms); la Mac (banco sin vsync solo y corto, tope 2,5 GB); no tocar `max_physics_steps_per_frame` (desincroniza el dedicado); `selection_many` es sintético (la meta se fija sobre el peor caso).

## 6. Fuera de alcance
Jolt o `HeightMapShape3D` (mueven el digest; RFC aparte con OK del usuario); física en hilos, RVO y NavigationServer3D (RFC-026); mallas LOD nuevas; invalidar cachés estáticas al re-hornear y materiales duplicados de `ghost_form`; `Selection._process`; F76/F77; rendimiento del dedicado más allá del tick.

## 7. Orden
1. 027a y 027b developers en paralelo (archivos disjuntos). 2. Corrida y review de 027a (la tabla); review y playtest de 027b. 3. El orquestador ordena 027c–g. 4. Un corte por vez: developer → reviewer (digest y `run_perf027.sh`) → playtester. 5. Godot de a uno; código en paralelo.

## 8. Verificación en el editor
027a: F6 en `agent/fixtures/perf027_many.tscn`, la tabla sale en la salida; Monitor del Debugger con `Physics Process` y `Draw Calls`; cambiar `Group.own_count` cambia el caso. 027b: F6 en `selection_many`, primera orden con `last_apply_us` ≤ 12 000. 027e: F6 en `unit.tscn` muestra la barra; `%HealthBars.instance_count` = cuerpos. 027f/g: editar `quality_medium.tres` y ver el cambio en `debug/look_gallery.tscn` (F3).

## Notas del código
`_apply_frame_mesh` reasigna la malla en cada tick aunque no cambie el cuadro (027b). `TargetPicker.pick` recorre los grupos completos incluidos los 69 edificios (027c2). El terreno choca contra un trimesh de todo el mapa (`terrain.gd:412`): si `move_and_slide` encabeza la tabla, la solución de fondo cambia el digest y queda fuera de alcance.

## Deuda observada en el playtest de F86 (2026-10-16)
- **Orden de atacar con 150 unidades seleccionadas:** tarda 16,5–17,5 ms, contra 6,4 ms de la orden a un punto vacío. Va a la tabla de 027a y a 027c.
- **Cuadro de render con 150 unidades:** 250–390 ms en ventana, mientras la CPU marca 35–175 ms. Es la hipótesis H1, que confirma 027a.
- **`selection_many`, preexistente:** varias Manahoar y Earthfling de las filas del fondo aparecen a y = 41,83 cuando el suelo está a ≈ 16, y bajan recién al llegar. Es un problema del banco, al apoyar a las criaturas en el suelo. Se arregla junto con 027c, o aparte si molesta antes.

## Orden de 027b–g según la tabla de 027a (orquestador, 2026-10-16)

La tabla de 027a confirma H1. Con 150 cuerpos corren 8 ticks por frame (el tope), y cada tick cuesta 28–30 ms; de eso, **BodySeparation se lleva 20–25 ms (74–82 %)**. Con 150 quietas, el `resolve` por grilla (23,8 ms) cuesta más que listar los obstáculos por fuerza bruta (15 ms).

Orden de los cortes:
1. **027c3 — Costo de BodySeparation (F87).** Lo especifico abajo.
2. **027d — Apiñamiento (F88),** en el mismo archivo y después de c3.
3. **027g — Pasto en calidad media (F91).** Ahorro medido en render de CPU (REVIEW-F85): ≈ 21 ms en la partida, 8 ms con 50 cuerpos y 7,6–13 ms con 0. Las restas en ms de pared estaban infladas porque, al acortarse el frame, también bajan los ticks por frame. Se justifica. Cambia el look: va con capturas al usuario antes de cerrar.
4. **027f — Sombras de cuerpos por preset (F90).** Ahorro medido en render de CPU: 6,5–7,1 ms con 50 en marcha y en la partida. Se justifica. Cambia el look: va con capturas al usuario.
5. **Descartados por medición:**
   - **027e (barras):** ahorra 0–1 draws y el render de CPU no baja.
   - **027c1 (reposo):** `move_and_slide` + GroundGuard pesan alrededor del 6 % del tick.
   - **027c2 (blancos por grilla):** TargetPicker pesa alrededor del 2 %.

### 027c3 — Costo de BodySeparation (F87)
- **Objetivo:** el mismo resultado de separación (las mismas posiciones, en el mismo orden de iteración y con los mismos flotantes) a una fracción del costo.
- **Pistas:** revisar por qué el `resolve` por grilla cuesta más que la fuerza bruta.
  - **Asignaciones por tick:** `Dictionary` o `Array` nuevos por celda o por cuerpo.
  - **Tamaño de celda** frente al radio.
  - **Pares repetidos:** cada par se procesa dos veces.
  - **Búsqueda de vecinos:** consulta de 9 celdas con alocación.
  - **Grilla rehecha:** se reconstruye entera en cada tick.
  - Llamadas a métodos o propiedades de nodos en el bucle interno.
  - Proponer arreglos que no cambien el resultado numérico.
- **Criterios:**
  1. Separación por tick ≤ 5 ms con 150 quietas y con 150 en marcha (`run_perf027.sh`, 2 corridas).
  2. Digest igual con seed 1 (`ai_vs_trivial`, 3 min) y con seed 7 (con y sin `--npcs`), en pares A/B sin tocar el árbol. Usar una copia en el scratchpad para el «antes».
  3. `rules_suite` PASS.
  4. Informar los ticks por frame y el frame con 150. La meta final (1,00 tick/frame) puede necesitar 027d.
- **Si un arreglo cambia el digest:** queda fuera de c3 y se anota para 027d.

### Notas de REVIEW-F85
- La métrica principal es «explicado (render medido)», que da 98–101 %.
- «En marcha» es una orden de ataque al Druid: los cuerpos convergen y paran dentro de la ventana. En 027c3 y 027d, la cifra «en marcha» se informa así para poder comparar, y se agrega una corrida con destino lejano.
- El límite de presentación de macOS es bimodal (hay cuadros de 3 ms), no un tope fijo de 120 Hz.
- `agent/perf/` es un instrumento de medición autorizado por el RFC y no un harness: no sirve de precedente para llamar al producto desde un harness.
- Los barridos de la partida pueden consumir `MatchSeed.separation` cuando hay empates. Si se vuelve a tocar el medidor, hay que saltear esos barridos o restaurar el estado.
- `debug/orders_group.gd` divide por cero con `own_count = 0`. Falta un guard; es tarea aparte.
- Primera medición de c3 (corrida del reviewer, 28 s después del cambio), con 150 quietas: separación 24,7 → 5,5 ms, tick 30 → 11,3 ms, frame 245 → 23,7 ms. Archivos en `agent/out/perf027/c3early_many150_r9.*`.
- **Hallazgos de F113 (030b):**
  - **Atasco:** en High Noon, cerca de (1488, 1511), las criaturas del slot 1 a veces quedan en CHASE con velocidad 0. Pasa también con la Trogg de nivel 1. Hay que revisarlo después de 027c3 y 027d (separación y apiñamiento) y, si sigue, abrir un corte de navegación (RFC-026).
  - **Convocatoria:** el primer cuadro de cualquier convocatoria cuesta 40–65 ms, aunque la preparación de modelos de F86 haga una malla por cuadro. El pico viene de la convocatoria en sí. Va a la tabla de 027.
- **027h propuesto: hornear los cuadros de clip a `.res` (playtest de F113).** La primera convocatoria de un modelo nuevo llega a picos de 99–121 ms y a unos 40 cuadros de más de 25 ms en 4 s. La causa es `ObjMesh.build`, que arma en GDScript los cuadros de clip siguientes al 0 la primera vez que aparecen (10–15 ms cada uno). Con las 51 criaturas de RFC-030 hay que resolverlo antes de que el nivel 9 sea el del producto (030c). Va después de 027d.
