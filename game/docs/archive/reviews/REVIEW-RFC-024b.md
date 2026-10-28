# Review RFC-024 · corte 024b (F72: navegación, visión por bando y elección de blanco)

Revisor: studio-reviewer, una pasada, sin implementar. Plan: `docs/archive/rfcs/RFC-024-single-player-ai.md` (§1.2, §3.1–3.3, §5, §6 «024b», riesgos 2–3), adenda de poblados, `RULES.md` («Datos», «IA»). Proyecto de juego: checks de SQL/XSS/auth N/A.

## Veredicto

| Dimensión | Veredicto |
|---|---|
| Criterios de aceptación del RFC (024b) | PASS (regresión de flows en red pendiente) |
| Fidelidad a sacengine (desvío 1) | PASS |
| Composición (PathFollower quitable, sin god-node) | PASS |
| Movimiento con el motor, sin integrador paralelo | PASS |
| Determinismo | PASS |
| Red (solo donde se simula) | PASS |
| Conducta del jugador / órdenes de guardia | NEEDS WORK (1 bloqueante) |
| Alcance / extras | PASS con notas |

**Se puede cerrar el RFC 024b: NO todavía.** Un bloqueante (B1, guardia con jitter). El resto son notas. Después de la corrección, falta el playtest con ventana y los flows de red (pt60/pt64/f78_online_a) que el developer declaró sin correr.

## Lo que corrí (headless, `--fixed-fps 60`, un solo Godot, RSS < 2,5 GB; editor pid 9527 intacto)

| Corrida | Resultado mío | Declarado |
|---|---|---|
| `rules_suite` | `RULES SUITE PASS`, 0 FAIL; `target_score_*` (6), `target_pick_*`, `target_vision_*`, `target_attacker_wiring`, `target_pacifist`, `nav_*` (7) todos PASS; 3,9 s | PASS |
| `nav_cross` | `ok:true`, 117,7 s, límite 140,8, `max_still_s` 0, `path_m` 968,1 (recto 697,5), `grid_ms` 54, `find_path` media 0,93 ms, peor 3,7 ms | 117,7 s / 140,8 / 52–57 ms / ≤3,7 ms |
| `nav_wizard` | `ok:true`, llega en 12,8 s (límite 15,9), `max_still_s` 0 | 12,8 s |
| `nav_wizard -- --nofollow` | `ok:false`, `timeout` a 400 s, `max_still_s` 390, queda a 34,7 m (atasco de F57 reproducido) | se clava como F57 |
| `target_pick` | `ok:true`, elige DruidNear (0,9031 contra 0,4538 del lejano con «le pegó primero»); el de 150 m fuera de la visión del bando no entra a la tabla ni se toca | n/a |
| `ai_match` seed 7, 2 min, corrida 1 y 2 | digest `d0cd72835a86791a8bfa4a899d1fb460b660f4be81b9364eff27fe66ac645214` en las dos; los JSON difieren solo en tiempos de reloj (`mean/p99/max` de ms por tick) | `d0cd7283…` estable |
| Costo con 225 unidades (visión 0,75 ms/tick, picker 0,12) | NO re-medido (no hay banco de 225 en `debug/` que corra headless corto; el código es O(N) por bando por tick en visión y O(N) por pick) | declarado |
| Sonda propia de guardia (`--script` en el scratchpad, no entra al repo) | ver B1 | — |
| `rg -n "func agent_" scenes` | vacío (rc=1); el repo no tiene `src/` ni `glue/` | debe dar vacío |

Nota: `git diff` no sirve como prueba de alcance, porque el repo no tiene commit `HEAD` (todo está en el índice). Dejé `agent/out/ai/rev72_s7.json` regenerado por mi corrida.

## Criterios del RFC, con evidencia

- Trogg cruza a ≤ 5 m en ≤ 1,2 × camino / 8,25 s, sin quedar quieto > 2 s: PASS (`nav_cross`: 117,7 s ≤ 140,8; quieto 0 s). El límite se calcula con el propio largo del camino de A* (literal del RFC); el desvío es de 39 % sobre la recta (968 contra 697 m) y no hay referencia de sacengine para compararlo.
- Mago 2 en `match_defeat` llega al Druid solo con `order_units`: PASS (12,8 s; con `--nofollow` se traba, que es el control).
- Grilla ≤ 300 ms, `find_path` ≤ 5 ms: PASS (≈ 54 ms; peor 3,7 ms). Mide solo A*, sin carga; con la máquina cargada el peor caso tiene poco margen (3,7 de 5).
- Suite `target_score_*` a ±1e-4: PASS. Los valores esperados están escritos a mano en `debug/target_cases.gd` (p. ej. `0.3025*1.25*1.2`), no se calculan con la función bajo prueba.
- `target_pick`: PASS con la fórmula corregida (ver desvío 1).
- Enemigo fuera del alcance de vista de todo el bando no se elige: PASS (`unseen_*` en `target_pick`, `target_vision_side` en la suite).
- Regresión `f25_summon`, `f27_orders`, `pt60`, `pt64`: no la corrí (me pediste solo los comandos listados). El developer declara AGENT_OK en varios; `pt60`/`pt64` completos en red y `f78_online_a` están sin correr. Queda para el playtester.

## Desvíos que me pediste evaluar

1. **Fórmula de la rama lejana: el developer tiene razón.** `sacengine/source/state.d:12925-12941` (`updateTarget`/`targetScore`): `distance < refRange ? 1 - 0.75*(d/ref) : 0.25*(ref/d)`, luego `score *= score`, luego factor de peligro, luego (si no es edificio) ×1,25, ×1,2 si es el último atacante, ×1,3 si es el blanco actual. La rama lejana arranca en `d ≥ ref` y está elevada al cuadrado. El RFC escribió `0.25·(100/60)²` para 60 m, que mezcla las dos ramas y deja el 0,25 sin elevar (1,0417 contra el 0,4538 real). `TargetPicker.score` coincide línea por línea. La falta de `dangerFactor` está declarada («aprox.»). Nota menor: las líneas citadas en los comentarios (`12900-12913`, `12943`, `12954-12957`) están corridas unas 21 líneas respecto de este `state.d` (las reales son 12925-12941).
2. **`target_pick` emula «le pegó primero»: aceptable pero flojo.** `debug/target_pick.gd:81-82` llama `vision.reveal` y `picker.note_attacker` a mano; no hay golpe real. El camino real (`struck` → `_on_struck`) lo cubre `target_attacker_wiring` en la suite. Además, con la fórmula correcta el Druid de 60 m nunca gana, así que la escena no ejercita el caso «gana el que pegó primero» (lo cubre `target_pick_attacker_wins`). El resultado no está puesto en el `.tscn` (el Trogg arranca sin `idle_aggro`, se lo da `_release`): válido para el punto 7 del checklist.
3. **Umbral de guardia cerca de 0: confirmado, ver B1.**
4. **3 búsquedas por tick, avanzando recto mientras espera: aceptable.** `NavService.take_search_slot` es un contador por tick (no reloj), así que es reproducible; el orden es el del árbol. Con 150–225 unidades dando una orden juntas, las últimas caminan recto hasta ~1,25 s (≈ 10 m) antes de tener camino; sin riesgo de determinismo. Nota: no hay prioridad, las últimas del árbol siempre esperan más.
5. **«Aprox.»:**
   - Sin FOV ni línea de vista: documentado en el encabezado de `side_vision.gd` y en el RFC (riesgo 5). OK.
   - A*: `AStarGrid2D` con `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES` (8-conexo sin cortar esquinas) más enderezado; los componentes son los 4-conexos. La nota «4-conexo contra 8» aplica solo a las regiones, no al camino. OK.
   - Mago con W va recto: aceptable (no es una orden de caminar), pero «pathfinding también para el jugador» solo cubre clic derecho/`request_walk` y órdenes de unidades.
   - **Bloqueos solo al armar la grilla:** `NavService.build` corre una vez (`call_deferred` en `_ready`) con grupos `manafount` y `altar`. Un Manalith, Guardian o edificio construido después no entra: el camino lo atraviesa y el cuerpo se desliza por la colisión (como antes de F72; `PathFollower` rehace el camino cada 2 s si no avanza, pero con la misma grilla). No bloquea 024b; sí hay que resolverlo en 024c, cuando la IA construya Manaliths (rebuild parcial o `block_disc` incremental al spawnear).

## Bloqueante

**B1. Una orden de guardia hace jitter cuando el bando ve un blanco fuera de la vista de la unidad** (`scenes/world/units/unit_orders.gd:162-166` + `scenes/world/units/target_picker.gd:81-83,113-114`).
`_acquire` usa `threshold = min(100, d(cuerpo, ancla)) * 0.01`, que vale ~0 con la unidad en el ancla (así lo hace `patrolAround`, `state.d:13007`). Con umbral 0, `score_cutoff` devuelve `INF`, el radio de consulta queda en 5120 m y cualquier blanco visible para el bando con puntaje > 0 se elige, aunque esté a 150 m de la unidad. Antes de F72 solo se elegía lo que cae dentro del `sight_range`. Como la unidad con orden (`ordered`) persigue sin límite de vista, sale hacia el blanco; a los 0,25 s el umbral sube a ~0,02–0,05, el blanco deja de superarlo, `_hold` ve que no hay blanco y la manda de vuelta al ancla; al llegar, el umbral vuelve a ~0 y lo elige de nuevo.
Lo reproduje con una sonda (escena `target_pick` sin los Druid cercanos, Trogg con `Command.GUARD_AREA` en su posición, Druid a 150 m, `sight_range` 100 m, marca del bando renovada cada 1 s como si un explorador lo viera): en 30 s la unidad pasó 77 veces entre `CHASE` y `MOVE` y se alejó hasta 6,7 m del ancla, sin parar. Es el mismo comportamiento que sacengine en este punto del código, pero para el jugador es una regresión visible de guardia/escolta (antes quieta) y para la IA de 024c serían guardias temblando. La visión del bando se comparte entre todas las unidades y los edificios vistos quedan marcados para siempre, así que no es un caso raro en partidas con ejércitos separados.
Corrección pedida (una, sin iterar): acotar la elección de guardia por el alcance de vista de la unidad desde el ancla (por ejemplo, que `_acquire` o `pick` descarte lo que está a más de `sight_range` de `center` cuando hay leash, que es lo que ya hace `_in_sight` para el blanco actual), documentarlo como desvío de sacengine, y sumar un caso a la suite (guardia con un blanco visible para el bando a 150 m: la unidad no se mueve del ancla). `ADVANCE` (sin leash) puede quedar como está.

## Notas (no bloquean)

- N1. `struck` solo sale de `MeleeAttack` (`melee_attack.gd:173`). Un disparo, un hechizo o un golpe de mago no revelan al atacante ni cargan `last_attacker` (en sacengine `dealDamage` lo hace con todo daño). Un Druid que dispara desde fuera de la vista del bando no se ve. Declarar en «aprox.» o conectar el daño de rango.
- N2. `TargetPicker._on_struck` (`target_picker.gd:140-143`) busca `foe.get_node_or_null("TargetPicker")` y le llama `note_attacker`: el picker de uno entra al nodo del otro. Mejor que la víctima conecte su propia señal de daño recibido (señal hacia arriba, API hacia abajo). Cosmético hoy.
- N3. Retraso de reacción: un observador por bando por tick (fiel a sacengine). Con muchas unidades una amenaza puede tardar decenas de ticks en marcarse; cambia un poco la sensación de las unidades del jugador al auto-atacar. Anotarlo para el playtest.
- N4. Cobertura de la corrida: `ai_match` seed 7 termina por aniquilación en el tick 2096 con 13 unidades; el digest estable cubre poco movimiento largo. Sirve como cota de determinismo, no de la IA de 024c.
- N5. Los comentarios del código citan `state.d` con números de línea corridos (ver desvío 1).

## Determinismo, composición y red (checklist)

- Todo el estado corre en `_physics_process` (`NavService`, `PathFollower`, `SideVision`); `TargetPicker.pick` se llama desde `_idle` y `UnitOrders._think`, ya en física. No hay `randf/randi` en los cinco archivos nuevos. `Time.get_ticks_usec` solo alimenta contadores de informe (`last_us`, `total_us`, `last_find_us`, `build_ms`) que la simulación no lee. Los plazos usan `delta` fijo. El orden de iteración sale de `get_nodes_in_group` y de un `Dictionary` con claves insertadas en orden: reproducible (digest igual en 2 corridas headless).
- Sin integrador paralelo: `PathFollower` solo llama `begin_walk(waypoint)` y `steer_point()` devuelve un punto; la velocidad la sigue poniendo `UnitBody._move/_chase` y `move_and_slide`. `WizardBody.begin_walk` sigue siendo un tramo. Cumple `RULES.md` «Datos».
- Composición: `PathFollower` y `TargetPicker` son hijos de `unit.tscn` (`PathFollower` también de `wizard_body.tscn`), con `@export var body`, avisos de configuración y `get_node_or_null` en el cuerpo: si se quitan, camina recto / elige el más cercano (rama de reserva probada en el código). `SideVision` y `NavService` son servicios del mundo (`%Vision`, `%Nav`) encontrados por grupo; ninguno spawnea, puntúa ni cambia de escena. Los tunables están en `@export` (`repath_s`, `arrive_m`, `advance_m`, `margin_m`, `max_searches_per_tick`, pesos del puntaje). `UnitBody.is_valid_foe_of` estático evita que visión y picker diverjan.
- Red: `NavService`, `SideVision` y `PathFollower` apagan `_physics_process` en un cliente (`is_networked() and not is_server()`); `NavService` no arma la grilla ahí; `UnitBody._should_simulate` ya impedía `_idle/_chase` en el cliente, así que el picker no corre. `WizardBody.request_walk` manda el RPC existente y `walk_to` corre en el servidor/solo. Sin RPC nuevo, sin tocar `addons/mp_kit`. En el cliente `_on_struck` podría conectarse y llamar `reveal` (inofensivo, sin simulación). No pude correr el dedicado ni `pt64`.
- IA (`RULES.md`): ningún atajo ni recurso nuevo; el pathfinding y la visión se usan igual para humano e IA.
- Agent kit: `rg "func agent_" scenes` vacío; los flows `f72_*` viven en `agent/flows/`.

## Pendiente para el orquestador

1. Una corrección (B1) del developer.
2. Playtester con ventana: `f72_nav_cross`, `f72_target_pick`, una guardia y una escolta del jugador (comprobar B1), y la regresión en red (`pt60`, `pt64`, `f78_online_a`) que quedó sin correr.
3. 024c: reconstruir/actualizar la grilla cuando haya Manaliths y Guardians (nota de alcance, no de este corte).
