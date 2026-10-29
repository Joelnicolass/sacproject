# REVIEW RFC-024 corte 024c (F74): cerebro minimo del mago IA

Una pasada, sin implementar. Plan: `docs/archive/rfcs/RFC-024-single-player-ai.md` (§1.1, §3, §4, §5, §6, §9) y `docs/archive/rfcs/RFC-024-addendum-poblados.md` (§6 «024c», manda). Reglas: `RULES.md` «IA». Fuente: `sacengine/source/bots/shiny.d`.

## Veredicto: NEEDS WORK (sin bloqueantes; el corte se puede cerrar)

| Dimension | Veredicto |
|---|---|
| (1) Puerto unico y sin trampa | PASS con 2 observaciones (N1, N2) |
| (2) Fidelidad a shiny.d | PASS |
| (3) Desvios y NaN | NEEDS WORK (N3: el NaN rompe la guardia con 0 almas, reproducido) |
| (4) Regresiones (mana_pool, nav, orders, vision) | PASS (N4: costo de la reconstruccion para 024d) |
| (5) Red | PASS |
| (6) Composicion, knobs, AiSide quitable | PASS |
| Criterios del RFC | PASS (todos con evidencia propia, abajo) |

Bloqueantes: ninguno. Una correccion opcional antes del playtest: N3 (documentar o proteger).

## Lo que corri (un solo Godot a la vez; pid 9527 del editor intacto; sin look_bench; RSS visto 326 MB)

Todas con `--headless --fixed-fps 60`:

| Corrida | Resultado |
|---|---|
| `ai_summon` seed 1, 3 min, x2 | digest `85b020c7cfd0f0465ca5d3bb49959f235accb74c03ef496ec865470cbd3888d2` las dos veces. 12 convocatorias, rechazos `{}`, `unseen_leaks 0`, `ai_ms` mean 0,046-0,048 / p99 0,702-0,725 / max 5,1-5,3 |
| Convocatorias | primera en tick 2 (0,03 s). Cada una: costo de mana = mana antes - despues + ganado (300/300 Earthfling, 1/1 Manahoar); almas -1 por convocatoria (12 -> 0); libro de almas `balanced` |
| Sondas de `ai_summon` | `npc_dies` sale en 1 tick; `lone_foe` (600 m, t=60 s) `ever_tracked false`; `farmer_in_sight` ataque en 4 ticks; escaneo: 32/32 NPC y altar enemigo |
| `ai_no_souls` 1 min y 3 min | 0 convocatorias, rechazos `{}`, libro exacto (0/0), `unseen_leaks 0`, `ai_ms` 0,025/0,465 |
| `ai_defend` 1 min | hechizo `kcor` a Druid1 en tick 134 (2,2 s), 3 unidades en combate en tick 148 (2,47 s); criterio <= 10 s |
| `rules_suite` | 77 PASS, 0 FAIL, incluye `ai_port_only_exit`, `ai_apply_for_owner`, `nav_rebuild_structure`, `ai_rand_msvc`, `ai_profile_original`; "RULES SUITE PASS" |
| `ai_match` seed 7 `ai_duel_seeded`, sin `--npcs` | `d0cd72835a86...` end 2096 = F72 (`b2_final_s7_*`) |
| `ai_match` seed 7, con `--npcs` | `085514300ec3...` end 3159 = F73 |
| `structure_siege`, `guardian_manalith` (900 frames) | cargan, 0 errores de script, grilla 54 ms al arrancar |

Los informes quedaron en `agent/out/ai/rev74_*.json` (carpeta sin trackear).

## (1) Puerto unico y trampa

Evidencia (rg sobre `scenes/world/ai`, fuera de `command/ai_command_port.gd`): cero llamadas a `request_*`, `Orders`, `Caster.*`, `Summoner`, `apply_for`, `rpc`, `multiplayer`. Las unicas referencias a MpKit son `is_networked()/is_server()` (`ai_side.gd:53`, `perception/ai_perception.gd:47`). Las lecturas de nodos (`get_node("Caster")`, `Spellbook`, `SoulPurse`, `ManaPool`) son de solo lectura sobre el propio mago o sobre cuerpos rastreados; ninguna escribe.

Todo lo que sale va por `ai_command_port.gd`: `request_cast` / `request_summon` / `request_structure` (l.57-66), `Orders.apply_for` (l.182) y `request_walk` (l.164). El puerto no toca cuerpos, pools ni bolsa. Paga mana y almas, porque pasa por el `Caster` humano. `light_can_cast` (`brains/wizard_brain.gd:100`) usa los mismos umbrales del Caster (`MIN_MANA_COST`, `MANA_EPSILON`), por eso los rechazos de recursos son 0. No hay bonificacion: `mana_in` solo de fuentes (`other: 0.0`), libro de almas exacto.

`Orders.apply_for` (`scenes/world/orders.gd:47`) es `request` con el slot dado. Rechaza `slot <= 0` y, en red, no-servidor. Delega en `_apply` -> `_own_units` -> `_can_order` (`orders.gd:123-143`), que sigue comprobando `owner_slot == slot` y pacifistas. Validacion de dueno intacta; lo cubre `ai_apply_for_owner`.

Percepcion: `unseen_leaks 0` y `lone_foe ever_tracked false` (el Trogg a 600 m no entra). Las posiciones de enemigos no vistos quedan congeladas al escaneo (`ai_perception.gd:_update_base`, solo OWN|SEEN siguen; fiel a shiny.d:1025). Observaciones que `unseen_leaks` no mide:

- **N1 (no bloquea; documentar o decidir).** Hay lecturas en vivo de estado real de cuerpos no vistos: `groups/ai_groups.gd:44` forma grupos con `candidate.node.global_position` real (el original tambien usa `entPos` vivo, shiny.d:1710-1711 «cached live entPos»); `groups/ai_groups.gd:127` y `brains/ai_spell_eval.gd:98` leen vida real (`health_pair`); `_mana_pair` lee mana real. El efecto sobre las decisiones es chico (centros y amenaza usan `cur_pos` congelado; vida solo pesa en `_single`), pero choca con una lectura estricta de «sin trampa». Pedido: una linea en `ai_groups.gd` y en RULES/RFC diciendo que es fiel a shiny.d y que se acepta, o cambiar a posicion/vida de la ultima vez vista.
- **N2 (no bloquea).** `ai_command_port.gd:66` lanza el hechizo a `node.global_position` real del blanco, y en `_issue` (l.178) y `Orders._apply` (retarget a la criatura enemiga mas cercana, `orders.gd:94-102`) el blanco se persigue por nodo. La IA elige por posicion congelada y dispara a la real si el blanco se movio sin ser visto. El original pasa la entidad igual (shiny.d startCasting), y el Caster humano tampoco exige visibilidad. Documentarlo junto a N1.

## (2) Fidelidad a shiny.d (5 numeros de `profile_original.tres` contra la fuente)

| Numero del .tres | Fuente | Resultado |
|---|---|---|
| `slot_periods` 12,60,6,6,60,12 | shiny.d:468 `periods=[12,60,6,6,60,12]`; mascaras 0xe,0xf,1,1,0x3f,1 = `FORCE_MASKS` de `ai_side.gd:25` | coincide |
| `rerate_ticks` 16 (edad) | shiny.d:1043-1044 `rerateTick=age+0x10` | coincide |
| `threat_ticks` 8, `threat_near` 10, `threat_far` 280 | shiny.d:1063-1072 (`threatTick=age+8`, `influenceGroups(...,10,280)`) | coincide |
| `attack_coefficient` 280 y pesos 0.5 / 0.3333333 / 10 | shiny.d:3057-3072 (retail 280; beta 180) | coincide |
| `emergency_threat_factor` 1.3, `summon_threat_cap` 0.6, `emergency_mana_ratio` 1400, `ready_divisor` 2 | shiny.d:3123-3139 | coincide (retail: /2, Manaliths propios+aliados) |

Tambien verificado en codigo: `rand()` MSVC (`math/ai_rand.gd`, test `ai_rand_msvc`); el bloque BLOCK1/BLOCK2 de `SummonPhase` replica el orden, el `return` solo del encolado y el puntaje `(1-cost/pool)*s` / `cost/pool*s` (`AiField.summon_score`); `AiStance` conserva el quirk de `u[6]` (bits de float); `enemy_ratio = recs[3].ratio_a` = `sf(stanceRecs[3],6)`. Todos los numeros llevan cita `shiny.d:linea` y marca «segun [S]»; ninguno afirma «verificado [O]» y es honesto: no se uso REA. La verificacion con REA queda pendiente para 024d/e (regla de memoria del proyecto), no bloquea 024c.

Diferencia menor documentada: `SummonPhase` no implementa la rama `recPath` de shiny.d:3140-3150 (blanco de registro de captura): solo aplica con `cmd == 2` (024d), correcto diferirla.

## (3) Desvios y NaN

Desvios declarados: seguidores a 8 m del lider (`follow_radius_m`, knob en el .tres, con la medicion de 70 m de arrastre); `SAME_POS_SQ = 1` en `ai_command_port.gd:21` por el jitter de `BodySeparation`; replanificacion cada 96 ticks (el original, a edades de k2: 16 x 6); `lightCanCast` con la prueba del Caster; ordenes con tolerancia. Todos son razonables, tienen comentario con la razon, y los tuneables estan en `@export` del Resource. Pacifistas (Manahoar) no reciben `attack/advance` (`ai_command_port.gd:171-173`): el original pide y recibe rechazo; el puerto no llama. Correcto y comentado.

- **N3 (NEEDS WORK, reproducido).** `ai_task_board.gd:111` `density()` divide por `perception.max_souls_seen`; con 0 da `0/0 = NaN` (`AiField.safediv` lo preserva). En `ai_no_souls` los dos registros de `GuardTask` salen con `score "nan"` y `members 0`: la guardia no reclama a nadie (`guard_task.gd:claim`, `claimed + 0.5 <= NaN` es falso), e `insert_sorted`/`normalize` propagan el NaN a todos. No se cae nada ni hay error de script (GDScript tolera NaN y el informe lo imprime como «nan»), y el original se comporta igual. Pero en el port significa que un mago IA que parte con 0 almas no tiene escolta hasta que junte almas (024d las junta; ahi `max_souls_seen` sube y se cura solo). Hoy solo afecta a `ai_no_souls`, donde no hay criaturas. Pedido: dejar escrito en `guard_task.gd`/RULES que es un quirk del original y agregar un caso de suite (`max_souls_seen == 0` no produce excepciones y las tareas no abortan), o decidir en 024d si se protege. `AiRater.ftol(NaN)` (`ai_rater.gd:37`) daria basura si algun dia recibe NaN; hoy nadie se lo pasa.

## (4) Regresiones

- `components/mana_pool.gd`: `add(amount, source: StringName = &"")` + senal `fed`; llamadores previos intactos (parametro opcional); la unica fuente que pasa `source` es `mana_source.gd:68` (`source_name()`), mas `unit_mana_support.gd`. `given` sigue emitiendo igual. Limpio. Nit: `ManaSource` gano `class_name` sin necesidad aparente fuera de la auditoria.
- `nav/nav_service.gd`: reconstruye la grilla `rebuild_delay_frames` (2) despues de `child_entered/exiting_tree` de `%Structures` (l.46-48, 55-64). Solo se cablea si `structures` esta asignado (solo `high_noon.tscn:213`). **Efecto sobre escenas existentes:** `_blockers()` (l.136-142) ahora suma todo nodo del grupo `structure` que no sea `MapBuilding`, incluidos Manaliths puestos a mano en `structure_siege` y `guardian_manalith`; esos dos cargan sin errores (corridos) y la grilla da 8806 nodos / 1 region, 54 ms. No corri los flows de AgentKit que los usan; la suite (`nav_*`, `nav_rebuild_structure`) pasa. **N4 (costo):** 50-54 ms por reconstruccion (dos en una corrida de 3 min, sin impacto, `tick_ms` max 52 ms en ese frame). En 024d (varios Manaliths puestos, profanacion) cada estructura cuesta ~3 frames; mide `nav.rebuilds` y considera una reconstruccion local o un tope por segundo antes de 024d.
- `orders.gd`: `apply_for` y `submit_order` (con `MpAuthority.command_slot`) sin cambio de semantica para humanos; `_apply` comun. OK.
- `vision/side_vision.gd`: solo agrega la senal `marked` (l.20, 107). Sin dependencia hacia la IA (solo un comentario).
- Mezcla en el arbol: `git diff` incluye cambios de `addons/mp_kit` (`command_slot`, `MpBoot.role`, `mp_flow.gd` arranque por rol) que no son de la IA; no pude atribuirlos a este corte (el repo no tiene commits). Si no son de 024c, que el orquestador los separe. `scenes/world/ai` no los usa.

## (5) Red

`AiSide` (`ai_side.gd:53`) y `AiPerception` (l.47) se apagan en clientes (`set_physics_process(false)`/`set_process(false)`). `AiCommandPort` no define RPC; `apply_for` rechaza en clientes. `rg "rpc|multiplayer"` en `scenes/world/ai` da vacio. `AiRoster` no existe todavia (024f): la instancia en `ai_match.gd:393` es de banco. Nada dentro de `addons/mp_kit` que pertenezca a la IA. PASS. Pendiente de 024f (dedicado, humo): fuera de este corte.

## (6) Composicion

`ai_side.tscn` es una escena con hijos (`Perception`, `Groups`, `Stance`, `Port`, `CreatureBrain`, `Brain` con `AttackPhase`/`SummonPhase`, `Tasks` con `GuardTask`/`IdleTask`); sockets `@export` tipados y `node_paths`, sin `../..` en el codigo. `AiSide` solo es reloj y reparto (156 lineas utiles), con `_get_configuration_warnings`; las fases cuelgan del cerebro, quitar `AttackPhase` deja un mago pacifista. Los tipos son Resources (`AiProfile`, `AiSeat`, `profile_original.tres`; el .tres no se muta, `ai_profile_original` lo prueba). El unico aviso: `setup()` hace `profile` sobre 6 nodos con `set("profile")` por nombre (l.62): funciona pero no tiene tipo; nit. Quitar el nodo `AiSide` deja la partida igual: los digests de `ai_match` seed 7 con/sin NPC son iguales a F72/F73. `AiAudit` vive en `scenes/world/ai/` pero solo lo usan bancos; mejor moverlo a `debug/` cuando se pueda (nit, no bloquea).

Playtest: este corte es logica sin HUD; el look queda para `studio-visual`. Falta el playtest con ventana del RFC (Enter -> Wizard2 lanza y aparecen criaturas; captura del hechizo hacia un Druid): la GUT/headless no lo reemplaza (regla de memoria «no saltear playtests»).

## Criterios del RFC (§6 024c y addendum)

| Criterio | Evidencia | Estado |
|---|---|---|
| >= 3 convocatorias, primera <= 20 s | 12 en 3 min, primera tick 2 | OK |
| costo mana/almas por convocatoria | `summons[]` del informe, 12/12 | OK |
| `rejections` Sin mana / Sin almas = 0 | `{}` en las 4 corridas | OK |
| `mana_in` solo de fuentes | altar 53,9 / manahoar 2477 / manalith 5080 / other 0 | OK |
| `unseen_leaks = 0`, altar enemigo desde t=0 | 0; `enemy_altar_tracked true` | OK (ver N1/N2) |
| `ai_defend` <= 10 s hechizo + >= 2 criaturas | 2,2 s y 3 unidades a 2,47 s | OK |
| `ai_ms` mean <= 0,5 / p99 <= 2 | 0,046 / 0,70 | OK |
| sin almas no convoca (3 min) | 0 convocatorias, rechazos 0, libro exacto | OK |
| NPC en percepcion desde t=0; muerto sale <= 1 s | 32/32; 1 tick | OK |
| ataque a NPC en vista <= 2 s | 4 ticks | OK |
| reproducible con `match_seed` | digest identico x2 | OK |
| `ai_defend_far` (330 m) | 18,5 s segun el developer; no corrido (no pedido) | fuera de criterio, fiel a shiny.d:1025 |

## No-hallazgos y notas

- Producto juego: SQL/XSS/auth N/A.
- Alcance: no hay codigo de 024d (captura, Convert) adelantado; `wizard_brain.gd` lo dice en su cabecera.
- Limitaciones aceptadas: sin Manalith no convoca (shiny.d:3140; las escenas parten con uno); la IA tira Rock contra NPC (addendum Q6 = A); las almas se agotan a los 38 s (sin recoleccion hasta 024d); REA sin usar.
- Helpers `agent_` en producto: `rg "func agent_" scenes debug` da vacio (`src/` y `glue/` no existen en este proyecto). El diff de playtest no aplica en este corte.

## Se puede cerrar el RFC?

Si: 024c se puede dar por cerrado en logica y datos, sin bloqueantes. Antes del siguiente corte: decidir N1/N2/N3 por escrito (documentar y un caso de suite), medir N4 en 024d, y hacer el playtest con ventana y capturas pendiente.
