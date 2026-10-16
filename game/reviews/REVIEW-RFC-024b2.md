# Revisión RFC-024 adenda 1 · corte 024b2 «Poblados y NPC» (F73)

Revisor: studio-reviewer, un pase, solo lectura (el único archivo escrito es este). Fecha: 2026-10-15.
Referencias: `rfcs/RFC-024-addendum-poblados.md` (§1.4, §1.5, §2, §3.1–3.3, §5.2, §6 «024b2», §7, §9, Adenda 1.1), `rfcs/research/poblados-npc.md`, `RULES.md` («Datos», «IA»). Decisiones del usuario respetadas: almas de NPC = matar + Convert; la IA no caza aldeanos.

Limitación de método: el repo no tiene ningún commit y el índice está desactualizado, así que `git diff` no da una línea base del corte. Leí los archivos tal como están y confronté con el informe del developer. No corrí vuelos con ventana ni los flows `.json` (f20/f22/f30/pt60/pt61b): solo lo pedido, en headless.

## Veredicto

| Dimensión | Veredicto |
|---|---|
| 1. Contrato §6 y honestidad de los desvíos | NEEDS WORK |
| 2. Nada del original en el repo | PASS (2 nits) |
| 3. Composición | PASS (nits) |
| 4. Determinismo | PASS |
| 5. Red | NEEDS WORK |
| 6. Las 59 escenas | PASS |
| 7. Supuestos de dos jugadores | PASS (nits) |
| 8. Sac Doctors sin pathfinding | NEEDS WORK, no bloquea F73, sí 024c/d |

El RFC se puede cerrar para F73 **después de una corrección** (B1 y B2). Sin bloqueantes de código; los dos son de contrato y de evidencia.

## Lo que volví a correr (headless, un Godot a la vez, el del usuario pid 9527 intacto; RSS máx. medido 316 MB)

| Comando | Resultado |
|---|---|
| `rules_suite` | `RULES SUITE PASS`, 0 FAIL. Los 7 casos nuevos PASS: `village_sides`, `village_sides_fallback`, `village_foe_rules`, `village_building`, `village_cower_flee`, `village_grudge_herd`, `village_separation_grid`. RSS 232 MB. |
| `run_probe73.sh load` | consola `npc farmer 26 slot 3 · taurock 6 slot 4 · edificios 69 · refugios 11`; error de posición de NPC 0,006 m, de edificios 0,0 m; 42 con colisión; ningún NPC dentro de un edificio; vida 500 / 1920; velocidad 7,25. |
| `passive` | 0 golpes de NPC en 120 s; Hunter conecta 31 golpes (mata al Farmer3 y encadena otros: el criterio «vida 500» solo se lee como vida máxima). |
| `souls` | Farmer: 1 alma, Taurock: 2, ambas `attached`, rojas para slot 1 y 2, `origin npc`; el mago encima 10 s: bolsa 0, el alma sigue ahí. |
| `house` | `jhut` (5000 de vida) cae en 44,4 s, 0 almas nuevas, `shelter` pasa de 11 a 10; `bld1` queda indestructible tras 20 s de ataque. |
| `ai_match` seed 7 `--npcs` (x2) | `085514300ec3867525062a3f08c5738dec39332b0b38c4814e7e3f275a68fdbf` las dos veces. |
| `ai_match` seed 7 sin NPC | `d0cd72835a86791a8bfa4a899d1fb460b660f4be81b9364eff27fe66ac645214` = el de F72. |
| Extra: `ai_npc_load` 1 min | grilla `sep_ms` medio 2,34 (p99 3,32, 78 cuerpos); lazo viejo (`--sep=brute`) 9,94 (p99 14,15). Cumple el criterio ≤ 4 ms. Los digests difieren (`f99ea0bf…` grilla vs `b9b504d0…` brute). |
| Extra: `flee`, `cower`, `grudge`, `taurock`, `convert`, `respawn`, `ground`, `cowerkill` | ver dimensión 1. |

Salida pedida en la regla 8: `rg -n "func agent_" scenes src glue` no encuentra nada en `scenes` (`src` y `glue` no existen en este proyecto). `git diff --stat` no es aplicable por la razón de arriba.

## 1. Contrato §6 y desvíos — NEEDS WORK

Criterios con evidencia propia (mis corridas): carga, pasivos, huida (se alejó 20,2 m en 3 s), encogerse (COWER, 0,0 m en 10 s), rencor (todos los Farmers a <= 80 m en 0,133 s, ninguno de más lejos), almas (rojas, pegadas, el mago encima no las junta), casas (0 almas, indestructible lo informa), sin reaparición (`farmers_alive_10min` 0 de 26), rendimiento (2,34 ms), libro de almas (`balanced true`, convertidas 3 = 1 + 2).

**B1 (bloqueante de contrato). Los desvíos del developer son honestos, pero el RFC sigue diciendo otra cosa.** `rfcs/RFC-024-addendum-poblados.md` §6 no se tocó. Hay que corregirlo con evidencia, no dejar la discrepancia en la descripción de `debug/village.tscn`:
- *Taurock a 80 m (desvío 1): el criterio del RFC está mal, el código está bien.* La fórmula de 024b (`TargetPicker.score`, `target_picker.gd:72-82`, sacengine `state.d:12925-12935`) con umbral de patrulla 0,25 y peso de criatura 1,25 da `s² · 1,25 > 0,25`, es decir `s > 0,447`, es decir distancia < 100·(1−0,447)/0,75 = **73,7 m**. Los 100 m son la vista, no el alcance de la elección. Medido por mí: a 80 m no elige blanco en 20 s; a 70 m elige en 0,12 s. Corregir §6 a «ataca desde <= 70 m (corte del puntaje 73,7 m [S]); a 80 m no».
- *«Ataca en <= 5 s»: ambigüedad no dicha.* A 70 m el Taurock **elige** blanco en 0,12 s pero el **primer golpe** llega a los 12,1 s (tiene que caminar 65 m). El informe del developer no lo menciona. El RFC debe decir cuál de las dos cosas mide el criterio; hoy solo se cumple la lectura «elige blanco».
- *Convert (desvío 2).* Se demuestra en `village_cower` (altar propio a 70 m, Farmer6 sin refugio), no en `village`. Mi corrida: 1 alma en 31,7 s (<= 60 s), Taurock +2 en 77,3 s (el RFC no fija tiempo para el Taurock, 4 rondas). Es honesto, pero corresponde moverlo al RFC («en `village_cower`»), y ver la dimensión 8: en `village` no hay forma práctica de convertir.
- *«Vida 500» en pasivos* es la vida máxima; el Farmer muere por Hunter. Aclarar el texto.

**B2 (bloqueante de evidencia). Criterio de red del propio §6 sin correr.** «En un cliente del dedicado la cantidad de `%Units` es la misma» está en la lista de carga y el developer lo declara no verificado, igual que `pt60_full`, `pt61b` y `f78` en red. Antes de cerrar: una corrida de dedicado + cliente (por ejemplo la familia `agent/run_f63_net.sh` o `run_pt72_f78_net.sh` con `spawn_creatures` encendido) que cuente 32 NPC y 69 casas en el cliente. Además, los flows de regresión del §6 (`f22_mana`, `f30_souls`, `pt61b`, `pt60`, `f20_solo`) pasan por `sacrifice_flow.gd:16` a `high_noon.tscn`, que ahora trae NPC; no los volví a correr, el orquestador debería exigirlos al playtester.

## 2. Nada del original en el repo — PASS

- `cache/` está en `.gitignore` (`git check-ignore -v cache/high_noon_ntts.json` lo confirma); `git ls-files -- cache` vacío; ningún `.wad`, `.scp`, `.obj`, `.res` de modelo ni `buildings.json` en el índice. `tools/export_high_noon_ntts.py` y `tools/export_stats.py` escriben solo bajo `cache/`.
- `SideRelations`, `MapPopulation`, `MapBuilding` leen todo de `cache/` y degradan con aviso si falta (verificado en `side_relations.gd:25-43`, `map_population.gd:50-54`, `map_building.gd:60-63`).
- Nit 1: `debug/village_rules.gd:12` y `debug/village.tscn` (descripción) llevan una posición del mapa (`1255,1214`). Es un dato derivado menor y el RFC ya la cita; si se quiere pureza, sacarla a un `@export` sin default y ponerla en el `.tres`... que también es del repo. No bloquea.
- Nit 2: `rfcs/research/poblados-npc.md` lista las posiciones de los 11 refugios y flags de BLDG. Es documentación de análisis, no recurso del juego; coherente con «nada del original» en el sentido de RULES (WAD, texturas, modelos).
- Nit 3: las suites dependen del caché local (`village_sides` falla sin `cache/high_noon_ntts.json`). Igual que las demás; no es nuevo.

## 3. Composición — PASS (nits)

- Sin god-node: `MapPopulation` (128 líneas) solo coloca; `MapBuilding` (174) modelo, vida y refugio; `PeasantBehavior` (146) decide; `GrudgeMemory` (98) guarda el rencor; `SideRelations` (96) es `RefCounted` estático. `peasant.tscn` hereda `unit.tscn` y suma los dos hijos: sin ellos es una unidad pasiva común, como pide §3.2. Sockets `@export` tipados (`body`, `grudge`, `health`, `unit_spawner`, `buildings_root`), `_get_configuration_warnings` presentes.
- Knobs con cita: `shelter_distance`/`scare_distance` (50, `state.d:13610-13611`) y `herd_range` (80, `state.d:13635`) citados como pide §3.3.
- `Mode.COWER` al final del enum (`unit_body.gd:31`): correcto por replicación entera. `mode` replica con `spawn = true` (`unit.tscn:45-47`).
- `Health.hit(amount, from_slot, was_full)` (`health.gd:13`, emitida en `_hit`) es una señal nueva sin cambio de firma de lo existente; no encontré otros conectores. No rompe llamadores.
- Nits (no bloquean):
  - `peasant_behavior.gd:26-27` (`flee_leg_m 30`, `think_interval_s 0.25`), `grudge_memory.gd:18` (`herd_interval_s 0.1`) y `map_building.gd` (`collision_inset 0.5`) son decisiones del port sin cita ni marca «aprox.». Agregar «decisión del port, no de sacengine».
  - `grudge_memory.gd:90` busca al vecino por nombre (`get_node_or_null("GrudgeMemory")`); mejor un meta o un grupo de memorias.
  - `map_building.gd:59`: **todo** `MapBuilding` entra en el grupo `structure`, incluidos los de flag `ground` (`bld*`, `bon*`, `jeg*`: sin colisión, vida 0, indestructibles). Eso los hace blanco de órdenes de ataque que nunca terminan (`health.gd` emite `died` aunque `is_dead()` sea falso con máximo 0) y bloquea el Manalith por `manalith_action.gd:93` (radio + 2 m de cualquier `structure`). Los decorados de suelo no deberían entrar en `structure`.
  - `MapBuilding` en la capa de colisión 1 (`map_building.tscn`, la misma del suelo): ya el rayo del cursor devuelve la casa en vez del suelo; está bien para el cursor, pero hay que tenerlo presente si algo más usa la máscara 1 como «suelo».

## 4. Determinismo — PASS

- Todo corre en `_physics_process`, con `MatchSeed`; `PeasantBehavior` y `GrudgeMemory` iteran grupos en orden de árbol; no hay `randf`/`randi` global nuevo (grep sobre `scenes/world/map`, `peasant_behavior.gd`, `grudge_memory.gd`: nada).
- Grilla (`body_separation.gd`): los candidatos se ordenan por índice de la lista original (`indices.sort()`, línea ~241), se leen en vivo, y se vuelve a archivar si cambia el número de miembros o el tick. El empate semilla (`MatchSeed.separation.randi() % 2`) solo se gasta en pares candidatos, no en todos los pares: eso es lo único que cambia y está dicho en el comentario de `body_separation.gd:20-24`.
- Mi verificación: digest de seed 7 con `--npcs` idéntico en dos corridas; sin NPC idéntico al de F72. La pelea densa (`ai_npc_load`) da digests distintos entre grilla y lazo viejo: **aceptable**, porque el empate sembrado no es un valor de sacengine sino un flujo propio, ambos modos son deterministas por separado, y el developer lo dejó escrito. Consecuencia a anotar: `--sep=brute` ya no sirve de oráculo de igualdad para peleas densas (solo de costo), y las bases de F66 con muchos cuerpos no son comparables bit a bit.
- Riesgo menor: `MOVE_MARGIN` de 2 m (`body_separation.gd:26`) supone <1 m por tick; un teletransporte (`warp_snap`, Teleport) dentro del mismo tick puede omitir un obstáculo un tick. Sigue siendo determinista.

## 5. Red — NEEDS WORK

Lo que el código garantiza (leído, no corrido en red):
- `MapPopulation._place_buildings` corre en todos los peers (nombres `Bld%03d_%s` estables, el índice avanza también en las etiquetas omitidas); `_place_creatures` solo si `_simulates()` (`map_population.gd:63-65`). Los NPC viajan por `UnitSpawner` con `spawn=true` y `npc`/`peasant` en los datos del spawn (`unit_spawner.gd:38-61`); `PeasantBehavior` y `GrudgeMemory` apagan su física en clientes.
- Sincronizador de vida solo si es destructible: `map_building.gd:75-76` libera `Sync` si `max_health <= 0`, en todos los peers por igual (los árboles coinciden).
- Cliente que se une tarde: los NPC los repone el `MultiplayerSpawner` con su estado inicial (posición, `mode`, vida). Las casas las crea el cliente desde su propio JSON de caché; si una casa ya cayó, el cliente la crea entera y depende de que `Health:current` (`replication_mode = 2`, `spawn = false`) le llegue al unirse. **No lo pude confirmar por lectura**: el modo ON_CHANGE puede no reenviar el estado a un peer nuevo si la propiedad no cambió después de su visibilidad. Hay un `debug/late_join.tscn` pero no una prueba con una casa destruida.
- Riesgo de dependencia: un cliente sin `cache/` (o con otro JSON) crearía otro conjunto de nodos y las rutas de los sincronizadores no coincidirían.

Pendientes:
- **B2** (arriba): sin corrida de red no hay evidencia.
- Debería agregarse a esa corrida: derribar una `jhut` en el dedicado y unir un tercer cliente, y comprobar que la casa figura caída (`visuals.visible == false`, fuera del grupo `shelter`).
- `NavService` construye el `NavGrid` una vez con los `map_building` (`nav_service.gd:19`); una casa que cae (`map_building.gd:164-172`) deja su caja como bloqueo de pathfinding para siempre. No afecta la física, pero deja paredes fantasma en las rutas. Debería reconstruirse la región o descontar el bloque en `destroyed`. No bloquea F73, sí 024c.

## 6. Las 59 escenas — PASS

`grep` sobre todos los `.tscn`: 59 coinciden con `[node name="Population" parent="HighNoon"]` + `spawn_creatures = false`, todas idénticas; la única con `spawn_creatures = true` es `scenes/world/high_noon.tscn:170`. `debug/ai_match.tscn`, `debug/village.tscn` y `agent/fixtures/pt024a/ai_match_cam.tscn` no tienen el flag porque lo fija el código (`ai_match.gd:61`, `village_rules`/`village.gd`), correcto. No pude demostrar «solo ese cambio» con `git diff` por la falta de línea base; la uniformidad del patrón y que ninguna escena de debug que instancie `high_noon.tscn` lo omita es la evidencia disponible.

## 7. Supuestos de dos jugadores — PASS (nits)

- Busqué `owner_slot ==`, `slot == 1/2`, `% 8`, `3 - slot`, `max_players` en `scenes/` y `addons/` (sin `scenes/world/ai/`): no hay dependencias de dos slots fuera de lo ya tratado. `MatchState.sides()` sale de los altares, así que los slots 3 y 4 no cuentan para victoria ni derrota (`defeat_rule.gd:65,121`); `Selection` filtra por `owner_slot == local_slot()` (`selection.gd:111`), así que los NPC no se seleccionan; `SoulSystem`/`Soul.color_for` los pinta rojos para ambos jugadores (probado en `souls`).
- `SideColors.side_color` consulta `SideRelations.is_npc_slot` (`side_colors.gd:27`): un slot 3 humano futuro quedaría gris si el JSON de High Noon está cargado. Aceptable para 1 humano + 1 IA; anotar para 3–4 jugadores (fuera de alcance según §2).
- `unit_mana_support.gd:62` itera `structure` con `node.get("spell_tag")`: no se rompe con `MapBuilding`.

## 8. Sac Doctors sin pathfinding — NEEDS WORK, no bloquea F73; bloquea la economía en 024c/d

Hecho comprobado por lectura: `doctor_body.gd` no usa `PathFollower` ni `NavService`; `StuckGuard` mata al Doctor tras `doctor_stuck_abort_s = 45` s sin progreso (`match_rules.gd:48`, `stuck_guard.gd`). Ahora hay 42 cajas de colisión nuevas (huts, `jwg1`, `jcc*`) entre el altar propio y cualquier aldea. Que el Doctor se atasque en pilares lo reporta el developer; yo no lo reproduje.

Por qué importa: la decisión del usuario es que las almas de NPC se consiguen con Convert. Hoy el criterio solo pasa con el altar a 70 m y sin obstáculos (`village_cower`); en High Noon real los altares están a cientos de metros de la aldea central. Si el Doctor muere en el camino, la ruta «matar + convertir» no funciona para el jugador ni para `ConvertPhase` (024d).

Recomendación: no bloquear el cierre de F73 (los criterios medidos pasan y el pathfinding de unidades es de 024b/024c), pero registrar como deuda **obligatoria antes de `ConvertPhase` (024d)** y, preferiblemente, ya en 024c: que `DoctorBody` use `PathFollower`. Agregar un criterio explícito: «un Doctor del altar propio llega a un alma de la aldea central de High Noon y completa Convert sin `stuck`». El orquestador debe contárselo al usuario porque afecta lo que pidió.

## Bloqueantes y no bloqueantes

Bloqueantes (una corrección, no un bucle):
1. B1: reescribir §6 de `rfcs/RFC-024-addendum-poblados.md`: Taurock <= 70 m (corte 73,7 m por la fórmula de 024b), «elige blanco» vs «primer golpe», Convert medido en `village_cower`, y «vida 500».
2. B2: correr y anotar el criterio de red (32 NPC y 69 casas en un cliente del dedicado) con la corrida de regresión de red, y comprobar una casa caída con cliente tardío.

No bloqueantes (para 024c o antes del playtest):
- Sacar de `structure` los `MapBuilding` con flag `ground` (`map_building.gd:59`).
- Reconstruir o descontar el bloqueo de `NavGrid` cuando una casa cae (`nav_service.gd:19`, `map_building.gd:164`).
- Citar o marcar como «decisión del port» los knobs de `peasant_behavior.gd:26-27`, `grudge_memory.gd:18`, `map_building.gd` (`collision_inset`).
- `PathFollower` para `DoctorBody` (dimensión 8).
- Anotar que `--sep=brute` ya no es oráculo de igualdad en peleas densas.

## Playtest que sigue pendiente (no lo da ni la suite ni los probes)

Capturas con ventana de la aldea con Farmers y casas, un Farmer huyendo y otro encogido, el alma roja sobre el cadáver y la conversión con «Almas 1»; el look de las casas (modelos MRMM de James) queda para `studio-visual`.

## ¿Se puede dar por cerrado el RFC?

No todavía. Con B1 y B2 resueltos y el playtest con ventana, F73 se cierra. El código del corte es coherente con el RFC y con las decisiones del usuario (matar + Convert, la IA no caza aldeanos); la evidencia que falta es de contrato y de red, no de lógica.
