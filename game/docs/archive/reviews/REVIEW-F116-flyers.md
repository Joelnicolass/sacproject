# REVIEW F116 — RFC-030 030e: voladoras híbridas (despegue, vuelo, aterrizaje)

Revisor: studio-reviewer, en una pasada, leyendo código. No corrí Godot: usé los logs del developer en el scratchpad de la sesión (`f116/pt116d.log`, `duel_A.log`, `duel_game.log`, `suite.log`).

## Veredicto: **FAIL** (hay un bloqueante y se arregla barato)

El núcleo está bien y es fiel a sacengine. No se cierra por dos motivos:
- **B1:** la sonda usa tokens que AgentKit prohíbe.
- El criterio 3 queda sin hacer. Para cerrar 030e, el orquestador tiene que aceptar que pasa a otro corte y registrarlo en el RFC.

| Dimensión | Veredicto |
|---|---|
| Criterio 1 (despegan, vuelan, aterrizan a 150 m) | PASS en el log de la sonda. Los no bloqueantes N1 y N2 quedan para el playtester |
| Criterio 2 (a 5 m caminan) | PASS para 9 de 10. Phoenix vuela a 5 m, igual que en sacengine (ver D1) |
| Criterio 3 (cápsula y pose) | NO HECHO. Se difiere y lo tiene que aceptar el orquestador |
| Criterio 4 (red) | Sin evidencia. El código está bien y la prueba queda para el playtester |
| Fidelidad a sacengine | PASS. Hay nits |
| Red (cliente deriva de `Flight:state`) | PASS en el código |
| Determinismo (digest seed 7) | PASS |
| AgentKit | **FAIL** (B1) |
| Composición | PASS |
| Alcance | PASS. Hay nits |
| Seguridad SaaS | N/A: es un juego |

## Criterios del RFC y su evidencia

1. **A 150 m despegan con el clip `takeoff`, vuelan a `flying_speed` y aterrizan al llegar.** Lo muestra `pt116d.log` en la fase far. En las 8 que tienen clip pasa `TAKEOFF@0.02s → FLYING@takeoff_time → LANDING@d≈0.1–2.7 → GROUND`. Los clips que se ven son `takeoff,fly,land,idle`, y la velocidad máxima en el aire es igual a `flying_speed` en Blight, Gremlin, Ikarus, Pyrodactyl, Seraph y Silverback. Phoenix pasa de FLYING a GROUND sin clip de aterrizaje. Rhinok camina. Ver N1 y N2.
2. **A 5 m caminan.** En la fase near, 9 de 10 hacen `run,idle` y no cambian de estado. **Phoenix vuela.** Es lo correcto según sacengine: con `takeoffTime = 0`, la cuenta `0 + d/20 < d/10` da verdadero para cualquier distancia, y sin clip de despegue pasa directo a volar (`state.d:8098-8108`). Va como desvío D1.
3. **Captura lateral de la cápsula en tierra y en vuelo (más Rhinok `Eds1` y Phoenix +3,26 m, §13).** **No hay evidencia: se difiere.** El RFC §13 mete esto en 030e de forma explícita. Si se separa, hay que agregar el corte nuevo (030e2 o el nombre que elija el orquestador) en el §10 del RFC.
4. **La red se ve igual en A y B.** No hay evidencia en ejecución. El análisis del código está más abajo y queda para el playtester.

## Desvíos declarados, comparados con sacengine

- **D1. Rhinok no vuela y Phoenix vuela sin despegue ni aterrizaje.** Es correcto. En `sacobject.d:679-683` se descarta `animID[0..2]=="00"`. Como el tag humano está invertido (`human_tag` hace `[::-1]`), en el export queda como "termina en 00": por ejemplo, el `DF00` de Phoenix. También se descarta un `animID == stance1` que no sea el propio slot de stance1. `canFly = hasAnimationState(fly)` (`sacobject.d:113-115`). Los slots que se exportan son takeoff=32, fly=33 y land=34, y coinciden con el struct de `animations.d:33-35`. El export lo deja así: `gard` sin claves y `grdr` solo con `fly`.
- **D2. Aterriza al quedarse quieta.** Lo pide el RFC (el árbol de 030e cita 8706-8716) y está documentado en el encabezado de `flight.gd`. La bajada usa `landingSpeed = 0,5·fly` (`stats.d:145-147`, que se usa en `state.d:14714` en modo landing). Es coherente porque el modo «quieta» del port equivale al `landing` de sacengine.
- **D3. El criterio 3 se difiere.** Ver arriba. El RFC no se puede dar por cerrado hasta que el orquestador lo acepte.
- **D4. El criterio 4 queda para el playtester.** Es aceptable.

## Fórmulas

- **Decisión de despegar.** `Flight.goes_by_air`: si `takeoff_time_s() + d/flying_speed >= d/running_speed`, no despega. Es la misma desigualdad que `state.d:12335-12339`. `d` es la distancia plana a la meta final: en `_move` se mira `PathFollower.goal`, no el waypoint, y sacengine usa `ultimateTargetPosition`. Se evalúa cada tick en tierra, como `moveTowards`. `takeoffTime` = frames / 30 (`sacobject.d:125-128`, con `animFPS = 30`). PASS.
- **Subida.** Mientras camina por debajo de 4,5 m: `min(Δ/dt, flying_speed)`, que equivale a `takeoffSpeed = movementSpeed(true)` (`stats.d:158`, `state.d:14759-14762`). Por encima de 4,5 m: `-min(Δ/dt, 3)` (`downwardHoverSpeed`). PASS. El nit sobre el paso horizontal está en N3.
- **Bajada.** Detenida: `-min(above/dt, 0,5·fly)`. Toca suelo con `above <= 0.05` o `is_on_floor`, y entonces pasa a LANDING (`land` frames / 30, `state.d:14155-14160`) o a GROUND si no tiene clip (`state.d:8117-8121`). PASS.

## Red

- `unit.tscn`: `Flight:state` con `spawn=true` y `replication_mode=2` (on change).
- En el cliente, `_physics_process` sale temprano y llama a `_update_clip_state()`. Ese método saca el clip de `_flight_role()`, que solo lee `_flight.state`, y `is_flying()` también lee solo `state`. El setter de `state` emite `state_changed` en todos los peers, y `_on_flight_changed` recalcula `move_speed` y el clip.
- `Flight.advance`, `goes_by_air` y `_flies_to` corren solo en el servidor (`_should_simulate`). `_left` no se replica y el cliente no lo necesita.
- No encontré divergencias. Nit N6: el valor de spawn se aplica antes del `connect` de `_ready`.

## Determinismo

`duel_A.log` es la base y `duel_game.log` es con el cambio. Los dos dan el digest `4915c884…5597d`, `end_tick` 1756 y 472 eventos. Es lo esperable: en `ai_duel_seeded` (nivel 1) no hay ninguna híbrida, porque son de nivel 3 a 9 (`spell_order` 352–989). Cuando la criatura no es híbrida, el código cae en las mismas ramas de antes. `suite.log` dice `RULES SUITE PASS`. Falta registrar los flows de regresión de §7 (`f25_summon`, `f29_spit`, `ai_summon`, `f25_flying_summon`): los corre el playtester.

## AgentKit

```
$ rg -n "func agent_" scenes debug        # src/ y glue/ no existen
(vacío, rc=1)
```

No hay API de producto que solo use un harness. `UnitOrders.give` es la API que usa el clic derecho (`scenes/world/orders.gd:110`). Que un harness la llame **por API tipada** es aceptable para una sonda de developer. No reemplaza el playtest, que tiene que hacer rectángulo más clic derecho, como dice el RFC.

**B1 (bloqueante).** `agent/harness/pt116_flight.gd` contiene tokens de `_FORCE_TOKENS` (`addons/agent_kit/agent_workspace.gd:11-20`):
- `global_position` en las líneas 52, 62, 66 y 71, y en `_summary`;
- `velocity` en la línea 65 (`unit.velocity`);
- `.call(` en la línea 57 (`Orders`.call("give")), en la 67 (`ClipPose`.call("active_role")) y en `_ground` (`terrain.call("ground_height")`).

Funciona porque se monta con el fixture `pt116_flight.tscn` y no pasa por el chequeo del kit, pero el kit rechazaría ese harness («forces play»).

**Arreglo:** reescribirlo con llamadas tipadas: `(unit.get_node("Orders") as UnitOrders).give(UnitOrders.Command.MOVE, …)`, `ClipPose` tipado y `Terrain` tipado. Hay que leer `position` (el padre `Units` está en el origen) y sacar la velocidad de la diferencia de posición entre ticks. Otra opción es sacar la sonda de `res://agent/harness/`. De paso, cambiar el `1` mágico por `UnitOrders.Command.MOVE`.

## Composición

- `Flight` es un hijo de `unit.tscn` con socket `@export var body`. Tiene perillas `@export`: `flying_height`, `downward_hover_speed`, `landing_speed_factor` y `touch_m`. Si se saca el nodo, las híbridas caminan. Es un solo comportamiento por nodo, sin god-node. PASS.
- `CreatureType` suma `flight_animations`, `is_hybrid_flier()`, `takeoff_time_s()` y `land_time_s()`. Son datos de tipo y no muta el `.tres`. PASS.
- Señal hacia arriba (`state_changed`), API hacia abajo (`goes_by_air`, `advance`). No hay `../..`. PASS.
- La escena de debug `f114_flyers.tscn` instancia `ai_match.tscn` con `f114_flyers.tres` (datos de `BenchRules`, no un script paralelo). Arranca con las 10 en tierra, `start_paused` y sin órdenes, así que el criterio no viene resuelto en el `.tscn`. PASS. `bench_group.offset_z_m` y su uso en `ai_match.gd` son perillas de banco y están justificadas.

## No bloqueantes

- **N1. Velocidad en el aire por encima de `flying_speed`.** Dragon llega a 24,99, Hellmouth a 20,61 y Phoenix a 25,00, contra 20. Es un máximo horizontal: probablemente lo causan `BodySeparation` o el deslizamiento contra el terreno al subir. Que el playtester mida el promedio.
- **N2. Después de aterrizar, Hellmouth y Silverback quedan a 11,7 y 13,9 m de su meta, con velocidad en tierra de 9 a 12.** Coincide con la llegada de Rhinok a pie (27,8 s), que está entre los dos: es el empuje de cuerpos grandes (riesgo §8.3, no es del vuelo). En la fase near, **Silverback no llega nunca** (`done_tick` −1, clip `run`, le faltan 1,46 m): está trabado en tierra. Hay que revisarlo en el playtest o con F88/RFC-026.
- **N3. Al subir, el paso horizontal no baja.** En sacengine sí baja, porque normaliza la dirección con la componente z (`state.d:14769-14774`). En el port, la velocidad 3D puede llegar a √2·fly mientras sube.
- **N4. Al bajar suena el clip `fly`.** sacengine usa `hover` (`state.d:8122`). Es cosmético.
- **N5. Persecución y ataque no despegan.** `_chase` no pasa por `_flies_to`. Si una voladora entra en CHASE o ATTACK, `walking=false` y baja. sacengine pelea en el aire (`flyAttack`). Queda fuera de los criterios: hay que anotarlo para un corte futuro.
- **N6. Al aparecer, el valor replicado de `state` puede llegar antes del `connect` de `_ready`.** El clip igual se recalcula en cada frame. `move_speed` en el cliente queda mal, pero no se usa.
- **N7. El export no aplica `nttData.d:140-148` `nonFlyingTags` (`rdbO`, `tshg`) ni `fixFamiliar` (`imaf`, `tnem` deben volar siempre).** Dragon Hatchling sale como híbrida y Ghost con clips de vuelo. Ninguna se usa hoy (§9), pero el docstring dice «como sacengine».
- **N8. `Flight.state` es `@export`.** Se puede editar en el inspector y una instancia podría arrancar en FLYING. `_get_configuration_warnings` no hace nada sin `@tool`.
- **N9. Hay dos perillas `flying_height`: en `UnitBody` (las que vuelan siempre) y en `Flight` (las híbridas).** Los dos valen 4,5.
- **N10. El texto no coincide.** `editor_description` dice «las 9 del RFC (… Rhinok …) más Phoenix», `pending_text` dice «10 híbridas» y el encabezado de `flight.gd` lista 9 sin Rhinok. Hay que unificarlo.
- **N11. Hay `.uid` sueltos de otros cortes en el árbol:** `agent/harness/pt88b_watch.gd.uid`, `debug/wizard_slope.gd.uid` y `tools/bake_clips.gd.uid`. No los commitees con F116 sin revisarlos.
- **N12. `creatures.json` y los cuadros horneados están en `cache/` (gitignored).** El diff de git no los muestra. Se verificaron leyendo `cache/data/creatures.json`.

## Para cerrar

1. Una corrección: B1, la sonda sin tokens prohibidos.
2. Que el orquestador acepte D1 (Phoenix vuela a 5 m, fiel a sacengine) y registre el criterio 3 como un corte aparte en el RFC.
3. Que el playtester haga el criterio 1 y el 2 con rectángulo y clic derecho, con capturas. También el criterio 4 en A/B, y los flows de §7, incluido `f25_flying_summon`. Además, que mire N1 y N2.
