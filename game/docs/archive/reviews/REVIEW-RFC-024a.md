# REVIEW RFC-024a (F71: semilla de partida y banco reproducible, sin IA)

Revisor: studio-reviewer. Un pase. Plan: RFC-024 §5.1-§5.4, §6 «024a» y adenda de poblados (manda §5.2).

## Veredicto: PASS (con nits). El corte se puede dar por cerrado en lo que toca a código; falta el playtest con ventana.

| Dimensión | Veredicto |
|---|---|
| Criterios de aceptación del RFC | PASS |
| Reproducibilidad (digest) | PASS |
| Azar sin semilla | PASS (nits) |
| Cobertura del digest | PASS con límites (nit, ver N2) |
| Composición | PASS |
| MP / escenas existentes | PASS (nit N3) |
| Riesgo 024b+ | Marcado, no bloquea |
| Seguridad SaaS (SQL/XSS/auth) | N/A: es un juego |
| Visual | N/A: no hay HUD nuevo salvo el rótulo del banco; look para `studio-visual` / playtest con ventana |

## Bloqueantes
Ninguno.

## Corridas (mismos comandos del developer, un solo Godot, editor 9527 intacto)
`Godot --headless --path game --fixed-fps 60 res://debug/ai_match.tscn -- --rules=res://debug/rules/ai_duel_seeded.tres --seed=S --minutes=2 --out=agent/out/ai/rev_sS.json`

| Corrida | digest | end_tick | eventos | real | RSS |
|---|---|---|---|---|---|
| seed 7 (1) | 6acf6b9498c519cc8248cc4790be16932551c7af73cdaa7694daa607ea330027 | 3249 | 346 | 3,23 s | 216 MB |
| seed 7 (2) | 6acf6b9498c519cc8248cc4790be16932551c7af73cdaa7694daa607ea330027 | 3249 | 346 | 3,27 s | 216 MB |
| seed 8 | 4596e2790ffc842c36614f150287d35601a7f2bc5fa50a96ade365adc083406a | 3263 | 344 | 3,33 s | 216 MB |
| seed 0 (sorteó 943254164) | 90539dab1ccbe357b539b6a32877e07c6a01be8f9bf6497b2689b3d940ac4698 | 3271 | 372 | - | - |
| re-correr `--seed=943254164` | 90539dab1ccbe357b539b6a32877e07c6a01be8f9bf6497b2689b3d940ac4698 | 3271 | 372 | - | - |

- El digest de seed 7 coincide con el declarado (6acf6b94...). Seed 8 distinto. Semilla 0 se imprime (`semilla 943254164`) y reproduce exacto.
- `rules_suite`: terminó con `RULES SUITE PASS` (37 líneas PASS, 0 FAIL). Nota: la escena no hace `quit()` (no hay `get_tree().quit` en `debug/rules_suite.gd`), el proceso queda vivo tras imprimir PASS; lo maté a mano (mi pid). Preexistente, no de 024a.
- `f26_duel` / `f27_orders` no los re-corrí (no me los pidieron); queda lo declarado por el developer (AGENT_OK).
- Chequeos `rg -n "func agent_" ...`: `src` y `glue` no existen en este proyecto (el rg devolvió error de ruta); `rg "func agent_" scenes` no encontró nada. `git diff --stat -- scenes` está sucio con muchos cortes anteriores sin commitear (52 archivos), no sirve para aislar 024a.

## Criterios del RFC §6 «024a»
- Dos corridas seed 7 = mismo digest; seed 8 otro: cumplido (arriba).
- Duración ≤ 60 s y RSS ≤ 1,5 GB: 3,3 s y 216 MB. Cumplido.
- `rules_suite` PASS: cumplido.
- `f26_duel` / `f27_orders`: declarado por el developer, no verificado en este pase.
- Playtest con ventana (Enter -> pelean -> «Terminado · semilla 7»): pendiente, es del playtester. `pt024a_smoke.json` es solo humo.
- Adenda §5.2: el libro de almas tiene `start, collected, converted, spent, now, by_origin{npc,creature,wizard}` y el criterio `now == start + collected + converted - spent` (`ai_audit.gd` sides_report). Los campos `npc_kills`, `npc_alive_end`, `npc_spawned`, `buildings_placed`, `shelters` corresponden a 024b2 y no están: correcto para este corte. Declarado como esqueleto; en el duelo el libro cuadra trivialmente (0 recolectadas, 12 = 12): no ejercita colectar/gastar.

## (1) Azar sin semilla
grep de `randomize|randi|randf|RandomNumberGenerator|shuffle|pick_random` en scenes/ y addons/:
- Sembrados bajo `MatchSeed`: `unit_body.gd:207-211` (`derive(["body", name])`; los nombres del `UnitSpawner` son deterministas, `Trogg1…`, `unit_spawner.gd:23`), `ghost_form.gd:69-72`, `guardian_tether.gd:70-73`, `match_biome.gd:49`, `body_separation.gd:172-178` (flujo propio `MatchSeed.separation`, así que `randf()` de efectos no mueve la simulación). Cubren los 4 puntos de la adenda más el tether.
- Sin semilla pero sin efecto en la simulación: `portal_disc.gd:114` (fase de shader), `ranged_shot.gd:40`, `rock_projectile.gd:63` (giro visual), `grass_blade_mesh.gd:50` (pasto), `map_props.gd:43` (usa `plant_seed` fijo), `theme_applier.gd:29` (cuando no hay semilla), `mp_room_directory.gd` (códigos de sala).
- N1 (nit): `melee_attack.gd:125` y `:186` caen a `randf()/randi()` global si `_rng` es null. `unit_body.gd:435` siempre le pasa el `_rng`, así que hoy no se ejecuta; si 024b+ instancia un `MeleeAttack` sin ese `setup`, el azar queda fuera del banco en silencio. Conviene un `assert` o quitar el fallback.
- Solo abre en quien simula: `high_noon.gd:12-15` `_enter_tree` llama `MatchSeed.begin(rules)` si `not MpKit.is_networked() or MpKit.is_server()`; en el cliente no se abre. `unit_body` y `ghost_form` además cortan antes de simular en clientes. Cumplido.

## (2) Digest
- Es sha256 encadenado de líneas de texto `tick tipo texto` (`ai_audit.gd` record/digest). El reloj es el `tick` físico propio; `wall_s`, `tick_ms` y `godot` salen solo en el informe, nunca entran al hash. Sin dependencia de tiempos de pared.
- Cubre: golpes (`struck` con probabilidad y dado), daño tipado (`hurt`), bajadas de vida (`hp`), muertes con posición a 0,1 m, almas, bolsa de almas, y posiciones muestreadas. Una divergencia de dado, daño o momento de muerte cambia el hash (seed 7 vs 8 lo muestra).
- N2 (nit, importante para 024b+): las posiciones solo se muestrean cada 60 s (`ai_match.gd` `sample_every_s`) y al final. Con la pelea de ~54 s solo cuenta la muestra final; una divergencia de movimiento sin efecto en combate no se vería hasta el final. Para el banco con IA conviene bajar el intervalo (p. ej. 5-10 s, ya existe `--sample-s`) por defecto, o fijarlo en el `.tres`. Además `%.1f` redondea posiciones: en un borde de 0,05 m puede girar con ruido de coma flotante; aceptable para misma máquina y binario.
- No registra todavía casts, invocaciones, rechazos ni maná: es el alcance del corte (la IA llega en 024c).
- `rules` en el informe es la cadena de la ruta; no afecta al hash.

## (3) Composición
- `MatchSeed` es un `RefCounted` estático chico (semilla, `derive`, `rng_for`, flujo de desempate); sin god-node. `AiAudit` es un nodo que solo observa (señales hacia arriba: `struck`, `died`, `hurt`, `changed`, `soul_spawned`); no decide ni cambia el juego, cumple «se quita sin afectar». `ai_match.gd` orquesta el banco en `debug/` y usa sockets `@export` (`audit`, `world_scene`, `status_label`, `camera`). `BenchRules extends MatchRules` y `BenchGroup` viven en `debug/` y el mundo los ve como `MatchRules`: el desvío es aceptable y está justificado (el `.tres` de debug lleva los grupos). Sin `agent_*` en producto. Sin MpKit ni RPCs nuevos.
- `AiAudit` se ubica en `scenes/world/ai/`, que es donde el RFC lo prevé.
- Fuera de alcance (ya en el working tree, no son de 024a): `body_separation.gd` trae además la refactorización de rendimiento (arrays planos, caché de cajas, grupo `&"doctor"`) y `match_rules.gd` trae los campos de manahoar y de sacrificios/guardián/teleport. Son de otros cortes; solo señalo que el diff de 024a no se puede aislar con `git diff` y que `_scan` recorre el mismo orden y consume el RNG de desempate en el mismo orden que antes (condición necesaria para que el digest sea estable).

## (4) MP y escenas existentes
- MP: el cliente no abre la semilla; el dedicado y el listen-server sí, en `_enter_tree`, antes de que nazcan los hijos. No agrega RPC. Cada `HighNoon` nuevo vuelve a sembrar.
- N3 (nit): `MatchSeed.current` es estático y nunca se pone en 0. Un proceso que jugó una partida simulada y luego entra como cliente a una remota queda con `is_active() == true`: `ghost_form.gd:69` y `match_biome.gd:49` sembrarían con una semilla vieja. Hoy solo afecta presentación del cliente (no simula), pero es un resto de estado. Un `MatchSeed.end()`/reset al salir de `HighNoon` (o `begin` con 0 en el cliente) lo cierra.
- Escenas existentes: `rules_suite` PASS; humo con mundo completo corre en 3 s sin errores. Sin ventana y con vsync/tiempo real no verificado aquí: no probé que la ventana (con efectos que llaman al `randf()` global) dé el mismo digest que headless; el flujo propio de separación y los `_rng` por cuerpo lo protegen, pero el playtest con ventana debería comparar el digest impreso.

## (5) Riesgo 024b+
- Física: el motor es `DEFAULT` (el informe lo imprime); con un hilo y `--fixed-fps 60` dio bit a bit igual en esta máquina. Al agregar `PathFollower` y `NavService` (024b), cualquier uso de `NavigationServer`, hilos o `Time` en la simulación rompe el digest: conviene un chequeo del digest en el cierre de cada corte.
- Hooks de Convert/almas: `AiAudit` asume que todo alma que entra a la bolsa es de criatura (`by_origin.creature`) y deja `npc` y `wizard` en 0 (`_on_purse_changed`). En 024b2/024d el origen no se podrá inferir de `Purse.changed`; hay que pasar el origen explícito desde `SoulSystem`/`ConvertAction`.
- La condición de fin del banco por aniquilación (~54 s) hace que `--minutes=2` no se ejerza; para 024c+ se necesitarán escenarios más largos para ver la muestra de 60 s.
- `rules_suite` no termina sola (ver arriba): conviene `quit` al final para correr en CI.

## Cierre
RFC-024a puede cerrarse con el playtest con ventana pendiente (Enter -> «Terminado · semilla 7»). Los nits N1-N3 no bloquean; N2 conviene atenderlo antes de 024c.
