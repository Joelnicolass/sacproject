# RFC-032 — Determinismo de la simulación

Estado: plan del tech lead (Opus), aprobado por el orquestador el 2026-10-16. Arquitectura estándar. MP con dedicado, sin RPC nuevas.
- **Origen:** REVIEW-F138, la deuda de `RFC-024-addendum-poblados.md:226-228` y F95, y RULES §IA («las partidas con IA son reproducibles con `match_seed`»).
- **Features:** F144–F147 (032a–032d).

## 1. Objetivo
- **Tiempo:** ninguna regla de simulación lee el reloj de render. Todo lo que vence (enfriamientos, plazos, vidas útiles) se mide en ticks de partida. Un solo dueño: `MatchClock`.
- **Azar:** un solo dueño, `MatchSeed` (`rng(parts)`, `seed_rng(rng, parts)`). El RNG global queda para la presentación.
- **Mismo digest en los tres modos:**
  - headless `--fixed-fps 60`;
  - headless en tiempo real con cadencia forzada (`--max-fps 6`, «stress»);
  - con ventana `--max-fps 60`.

  Casos: seed 7, seed 7 `--npcs`, `ai_vs_trivial` seed 1 y `f139_ff_clouds`.
- **Pausa:** no cambia la partida. `MatchClock` no avanza mientras el juego está en pausa.
- **Guarda en `rules_suite`:** casos de cadencia y de pausa, y un lint contra el RNG global y contra ordenar por `instance_id`.
- **Destraba 030h3:** las gotas de la Abomination usan `MatchSeed.rng(["drops", name])` (`state.d:24445`).

## 2. Hechos verificados
### 2.1 sacengine
- **Un solo RNG de estado:** `MinstdRand0(1)` (`state.d:29072`). Lo usan `uniform` (`29086-29092`) y `copyFrom` (`29125`), y la secuencia depende del orden de actualización.
- **Presentación:** usa `std.random` global (`dagonBackend.d:94-100`, `164-165`, `2073-2074`, `1883-1887`) o un `MinstdRand0` local (`sacobject.d:4343`).
- **Enfriamientos:** se descuentan una vez por cuadro de simulación, `max(0, cooldown − 1/updateFPS)` (`state.d:28136`), y se fijan en `applyCooldown` (`2284-2296`).
- **Gotas de la Abomination:** se tira el azar con `!!state.uniform(4)` en cada cuadro de vuelo (`24445`). Su actualización es determinista (`24488-24505`).

### 2.2 Port
- **`MatchSeed`** (`match_seed.gd`): `begin` (`18-26`) siembra el global con la semilla de la partida (`:23`). Expone `derive` y `rng_for` (`34-47`).
- **Medición del tech lead (2026-10-16):** `ai_duel_seeded` seed 7, headless en tiempo real a `--max-fps 20`, da `4915c884…` con `end_tick` 1756, igual que con `--fixed-fps`. Seed 7 no discrimina, porque no hay magos.
- **Antecedentes:**
  - 024a: el tween del cadáver se pasó a física.
  - F85: `ai_vs_trivial` con ventana daba igual que headless, porque a 60 fps hay 1–1,5 ticks por cuadro.
  - F137 B1: el `Engine.get_physics_frames` avanzaba en pausa.
- **`ai_match`:** el digest se indexa por `audit.tick`. Con ventana solo es comparable con `--autostart`, porque mientras espera Enter el mundo ya corre.
- **`unit_body.gd`:** 1045 líneas, no puede crecer.

### 2.3 Auditoría
**A. Reloj de render en lógica de simulación**
- `spellbook.gd:174-177`: `_cooldowns` en `_process(delta)`. Lo leen `wizard_brain.gd:229-245` y `caster.gd:87,104,263,593-597`. Se corrige en 032b.
- `red_vortex.gd:49-56`: `max_life_s` en `_process` en el servidor. Se corrige en 032d.
- El resto es presentación: `clip_pose_player` (warm), `guardian_tether`, `stone_look`, `altar_collapse`, `carry_rope`, `ritual_fx`, `soul`, el giro de proyectiles, `ghost_form`, `wizard_body:243`, `selection`, `sky`, `world_camera`, `look/*`, `fx/*` y `ui/*`.

**B. `Time.get_ticks_*`:** todos miden y ninguno decide. No hay hallazgos de simulación.

**C. `Engine.get_physics_frames`**
- `make_way.gd:62,70,114,133,168,175,201` (plazos `HOLD_TICKS`/`RETURN_TICKS`) y `petrified.gd:47,69` son simulación y avanzan en pausa. Se corrigen en 032d.
- `stunned.gd:55,90` es solo log.
- `body_grid.gd:46` y `body_separation.gd:375` usan una caché por paso del motor. Eso es correcto y se queda.

**D. RNG**
- **Global:**
  - `match_seed.gd:21`: el sorteo de la semilla es correcto.
  - `match_seed.gd:23`: `seed(wanted)` es un vestigio. Se corrige en 032c.
  - `match_biome.gd:49`: fallback.
  - `CPUParticles3D.new()` consume el global, pero es presentación.
  - No hay ningún consumidor global de simulación.
- **Corrientes de simulación propias:** `unit_body:232-237`, `melee_attack:51`, `ranged_attack:225`, `ghost_form:69-72,216`, `ai_side:104`, `ai_roster:84-87`, `body_separation:469-475`, `match_biome:49`.
- **El fallback `is_active() ? derive : randomize()` está copiado 4 veces:** `unit_body`, `ghost_form`, `guardian_tether` y `ai_roster`. Se unifica en 032c.

**E. Orden**
- Los grupos y `find_children` siguen el orden del árbol, que es estable.
- `selection.gd:165` ordena por `instance_id`, pero es input humano y queda fuera de alcance.
- **Regla nueva:** nunca ordenar ni hashear la simulación por `instance_id`, porque los ids difieren entre ventana y headless.

**F. Ramas ventana/headless:** todas son de presentación. El candidato `warm` de `ClipPosePlayer` queda **descartado**: `body_height()` lee el JSON de `BodyCatalog`.

## 3. Decisiones
1. **`MatchClock`** (estático, como `MatchSeed`):
   - `begin(tree)` corre en `HighNoon._enter_tree` en todos los peers. Pone `now = 0` y conecta una sola vez `SceneTree.physics_frame`, que hace `now += 1` si el árbol no está en pausa.
   - La señal sale antes de cualquier `_physics_process`, así que no depende del orden de los nodos.
   - Sin `HighNoon`, se engancha de forma perezosa.
2. **`Spellbook` guarda estado derivado, sin escritor por tick:**
   - `cooldown(i) = maxi(0, _ready_tick[i] − now) / 60.0`.
   - `_raise` fija `_ready_tick = now + ceili(s·60 − 1e-4)` y se borra `_process`.
   - El cliente convierte el RPC a su propio `now`.
   - Se descartó el escritor por tick estilo `state.d:28136`, por la regla «un dueño, no parches de orden». El costo es un desfase de hasta 1 tick, que queda declarado.
3. **`MatchSeed` es el único dueño del azar:**
   - Expone `rng(parts)` y `seed_rng(rng, parts, override)`, y el fallback vive solo ahí.
   - Los nombres siguen la forma `[sistema, id estable]`: nombre de serie o slot, nunca `instance_id`.
   - No se reproduce la secuencia única de sacengine; se mantienen corrientes por sistema.
4. **RNG global para presentación:** `begin` hace `seed(derive(["presentation"]))`. Si eso cambia un digest, hay un consumidor oculto y se bisecta con `--events`.
5. **Plazos en `MatchClock`:** `make_way` y `petrified` (032d). Las cachés por paso del motor siguen como están.
6. **`RedVortex`:** la vida útil se cuenta en ticks en `_physics_process`, solo en el servidor. El `@export` sigue en segundos.
7. **Banco `agent/run_determinism.sh <caso>`:**
   - Corre los modos `fixed`, `stress` y `window` (`--autostart --quit`) de a uno con `godot_run.sh`.
   - Escribe `agent/out/det/<caso>_<modo>.json` y `.events`, más la primera línea de `events` que difiera.
   - Termina con `DETERMINISM PASS|FAIL`, con vigía de RSS y un aviso `CONTAMINATED`.
8. **`--fixed-fps 60` con ventana:** Godot lo permite, pero no sirve, porque esconde justo el bug. La ventana corre en tiempo real y se compara por tick. El modo que separa los relojes es `stress`.

## 4. Escena de prueba
No hay escena nueva:
- `debug/ai_match.tscn` con `ai_vs_trivial.tres`, `ai_duel_seeded.tres` y `f139_ff_clouds.tres`, arrancando con `--autostart`;
- `debug/rules_suite.tscn` para los casos.

El playtester corre el modo `window` y saca una captura aparte del final.

## 5. Cortes
### 032a — F144 Banco y línea base (sin cambio de producto)
```text
agent/run_determinism.sh   N  modos fixed|stress|window; casos s7, s7_npcs, s1_trivial, f139; diff de events; tabla
debug/ai_match.gd          M  solo doc: «ventana comparable solo con --autostart»
```
Criterios:
1. `fixed` corrido dos veces da el mismo digest en los 4 casos.
2. Tabla de línea base en HEAD (4 casos × 3 modos, sha256 completo). Seed 7 tiene que dar `4915c884…` en los 3 modos. Volver a medir seed 1 y `--npcs`.
3. El banco discrimina: en HEAD, `s1_trivial` da `stress` ≠ `fixed`. Si no discrimina, se prueba con `ai_easy_vs_normal` y `ai_perf60`. Si tampoco, se anota y 032b se apoya en `rules_suite`.
4. Un solo Godot a la vez y RSS ≤ 2,5 GB.

### 032b — F145 `MatchClock` y enfriamientos por tick
```text
scenes/world/match_clock.gd       N
scenes/world/high_noon.gd         M  MatchClock.begin antes de MatchSeed.begin
scenes/world/spells/spellbook.gd  M  _ready_tick derivado; sin _process
debug/determinism_cases.gd        N  spellbook_cadence, match_clock_pause
debug/rules_suite.gd              M  merge
```
Criterios:
1. **`spellbook_cadence`:** 30 ticks dejan `c − 0,5` ± 1e-6. No hay `_process`.
2. **`match_clock_pause`:** con 30 cuadros en pausa, `now` no cambia.
3. **`s1_trivial`:** `fixed` = `stress` = `window`. `s7`, `s7_npcs` y `f139` quedan iguales a 032a.
4. Se publican los digests nuevos de los casos con IA.
5. Regresiones:
   - `rules_suite` PASS;
   - el HUD del libro se ve bien en vivo;
   - en dedicado con cliente, el enfriamiento coincide con el del servidor ±1 tick;
   - `pt143` y `f25` dan OK.

### 032c — F146 Un dueño del azar
```text
scenes/world/match_seed.gd        M  rng(), seed_rng(); begin: seed(derive(["presentation"]))
scenes/world/unit_body.gd         M  232-237 → seed_rng (−4 líneas)
scenes/world/wizard/ghost_form.gd M  → seed_rng
scenes/world/guardian/guardian_tether.gd M → seed_rng
scenes/world/ai/ai_roster.gd      M  → MatchSeed.rng(["ai_god", slot])
scenes/world/match_biome.gd       M  → MatchSeed.rng(["biome"])
debug/determinism_cases.gd        M  sim_rng_lint (lista blanca explícita)
```
Criterios:
1. El lint da PASS, y falla con un `randf()` sembrado en una copia en el scratchpad.
2. Los digests quedan iguales a 032b. Si alguno cambia, hay un consumidor oculto y se bisecta.
3. Con `--seed=0` cada corrida usa una semilla distinta.
4. `unit_body.gd` tiene ≤ 1045 líneas.
5. El ruido de F95 sigue en 0.

### 032d — F147 Plazos y vidas útiles en ticks de partida
```text
scenes/world/make_way.gd          M  → MatchClock.now()
scenes/world/units/afflictions/petrified.gd, stunned.gd M → MatchClock.now()
scenes/world/sacrifice/red_vortex.gd M max_life por ticks en _physics_process (servidor)
scenes/world/body_grid.gd, body_separation.gd M solo doc
debug/determinism_cases.gd        M  make_way_pause, vortex_life
```
Criterios:
1. **`make_way_pause`:** un plazo sobrevive a 120 ticks en pausa.
2. **`vortex_life`:** se libera en el tick 60 ±1 en `fixed` y en `stress`.
3. La petrificación dura lo mismo que en F137, aun con una pausa de 30 s.
4. Los digests quedan iguales a 032c.
5. `rules_suite`, `crowd_cases` y `pt141_solo` dan PASS.

## 6. Digests
- Seed 7, `--npcs` y `f139` se vuelven a medir en 032a y después no deberían cambiar.
- `ai_vs_trivial` seed 1 sale nuevo en 032b, igual en los 3 modos.
- Los demás casos con IA salen nuevos si cambian en 032b.
- Cada corte cierra con un bloque «Digests 032x» en FEATURES: caso, modo y sha256.

## 7. Riesgos
- **Redondeo a ticks (032b):** desfase de hasta 1 tick.
- **Señal estática:** hace falta una guarda contra conectar dos veces, y verificar que `physics_frame` se emite en pausa.
- **`now` del cliente:** es solo para la cuenta regresiva local.
- **Ventana a 120 Hz:** casi no separa los relojes. El modo que los separa es `stress`.
- **Consumidor oculto del RNG global:** si aparece en 032c, ese corte no cierra hasta nombrarlo.
- **Seguridad de la Mac:** un Godot a la vez, ventana a 60 fps y RSS ≤ 2,5 GB.
- **Falsos positivos del lint:** se resuelven con una lista blanca explícita.

## 8. Fuera de alcance
- La selección por `instance_id`.
- Determinismo entre arquitecturas, replays y lockstep.
- La secuencia única de `state.rng`.
- Timers que ya corren en física con delta fijo.
- La espera con Enter de `ai_match`.
- `portal_disc.gd:44`.
- 030h3 en sí: lo implementa RFC-030 sobre `MatchSeed.rng`.

## 9. Orden
032a → 032b → (032c ∥ 032d en código; Godot de a uno). 030h3 puede ir después de 032c.
