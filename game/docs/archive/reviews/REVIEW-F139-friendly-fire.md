# REVIEW F139 (031a): fuego amigo como regla de simulación

**Código: PASS.** No hay bloqueantes. Para cerrar faltan pruebas: los criterios 4 (rencor), 5 (disparo en línea) y 6 (regresiones) los tiene que confirmar el playtest. El revisor es de solo lectura, así que este informe lo guardó el orquestador (2026-10-16).

- **Fidelidad.** El orden es el mismo que en sacengine: `canDamage`, después deflect/guardianes, después bando, y por último resistencia, factor y pasiva, con tope en `current` (`state.d:8948-8972`, `9001-9050`, `9180-9184`). El mago dentro de su propio Fireball recibe ×0,5 (`30058`, `9077`). El veneno con `ignoreFriendly` hace ×1 con FF on y 0 con FF off. Los edificios aplican la misma regla, y las casas neutrales ×1.
- **Un dueño.** Ningún camino de daño filtra por bando fuera de `Health`: los filtros que quedan son de blanco, cura, rencor o rituales. La caché de `MatchState` revalida con `is_instance_valid` y no corre nunca en clientes.
- **Red.** `take_rules` corre solo en la autoridad y lee `world.rules`. El snapshot lleva la regla, también a quien entra tarde. No hay RPC nuevas.
- **Determinismo.** Los bancos heredan `false`. Se esquiva la trampa de `world.rules`: `ai_match` asigna las reglas antes del `add_child`.
- **Referencia de digest que discrimina.** `f139_ff_clouds`, seed 7, 0,5 min, corrida dos veces, tiene que dar el mismo digest. Además `f139_ff_off_clouds` tiene que dar un digest distinto de ese e igual al de `f116_death_clouds`.
- **Escenas que heredan FF on.** Leyendo el código, ninguna daña al propio bando: `rock_hit` solo apunta a enemigos y `village_net` daña la casa neutral.
- **Composición.** Las perillas están en `.tres`, no hay API pensada para harness, `unit_body.gd` no se tocó y la escena no se cumple sola.

## No bloqueantes
1. `unruled`: dos defaults sin `MatchState`. Hay que borrarlo cuando los harness monten un `MatchState`.
2. El `friendly_fire = false` explícito de `f139_ff_off_clouds.tres` lo borra el editor al guardar.
3. `take_rules` crea un `MatchRules.new()` siempre.
4. **Rencor:** sacengine marca también a un atacante aliado (`8933-8935`) y el port lo filtra. Es una divergencia heredada, anotada para AUDIT.
5. **Para 030i:** `damage()` (melee) no aplica `damage_factor` ni `kind_factors`, así que la petrificación ×0,2 tiene que llegar también por ese camino.
6. `get_first_node_in_group` puede devolver un `MatchState` viejo durante una transición.
