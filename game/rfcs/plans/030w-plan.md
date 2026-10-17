# Plan 030w: temblor de la melé (F177) y cortes extra del bestiario (tech lead, 2026-10-17)

Aprobado por el usuario el 2026-10-17. Se pega en RFC-030 (F161–F166) y en el RFC de movimiento (F177) al cerrar cada corte.
Fuentes: sacengine (`/Users/joelsartori/Development/sacproject/sacengine/source`, solo lectura, GPL: no se copia código), datos en `assets/original/data`, REA solo si sacengine no alcanza.

| Corte | F | Contenido | Escena / caso | Cambia digests de la base |
|---|---|---|---|---|
| 030w-a | F177 | Temblor de la melé: el acercamiento a media marcha (fiel) y, si no alcanza, el empuje repartido del par (desvío) | `f177_melee_group` (nuevo) + `s7` | **Sí, casi todos** |
| 030w-b | F161 | Brainiac `bsba` y Shrike `absh` aturden al blanco | `f161_stun_shots` (nuevo) | No (caso sin contacto) |
| 030w-c | F162 | Spitfire `fhba` y Gargoyle `ehba`: onda que crece; `FrostWave` pasa a `GrowingWave` | `f162_waves` (nuevo); `f149` igual | No (`f149` tiene que dar igual) |
| 030w-d | F166 | Rayo instantáneo de la Locust `zbba` | `f166_locust_ray` (nuevo) | No |
| 030w-e | F164 | Drenaje de vida (Charnel 0,5, Locust 0,875) en melé y en el disparo directo | `f164_drain` (nuevo) + `f166` | Sí, pocos (`f156`, quizá `f133`, `f166`) |
| 030w-f | F163 | Escudo de fuego del Phoenix `rifl` | `f163_phoenix_shield` (nuevo) | Quizá `f125` |

**Correcciones a la tabla de 030t-030v (línea 279):**
- **F161:** 480 es el **enfriamiento** del aturdimiento (`stunCooldownFrames = 8·updateFPS`, state.d:8561-8568), no la duración; la duración es la del `Stunned` del cuerpo. Además, el daño llega después del aturdimiento (`goto case` hacia `dealRangedDamage`).
- **F164:** el drenaje no es solo cuerpo a cuerpo. `healFromDrain` (8834-8840) corre dentro de `dealDamage(objeto, daño, ref atacante)` (8933-8946, línea 8940), y a esa función llega **todo** daño de una criatura viva a otra criatura o mago, también el de distancia (`dealDamage` con atacante entero, 8901-8913). F164 cubre la melé y el disparo directo. La salpicadura y las curas especiales del veneno (`healFromDrain(atacante, rangedAttack.amount)`, 23523, 24360, 24879) quedan para **F164b**, como deuda.
- **F162:** el Spitfire no «incendia 30» de daño: `setAblaze(id, updateFPS/2, true, 0.0f, …)` (23045, 23050) es un fuego de **0 de daño** durante 30 cuadros. El efecto real del fuego es el `DamageMod.ignite` del golpe (el aceite ×2, F155).

## Datos

| Tag | Criatura (vida, vuelo) | Monto | Alcance | Velocidad | Notas |
|---|---|---|---|---|---|
| `bsba` | Brainiac `bobs` (400, 18,75) | 200 | 90 | 36 | Proyectil de 0,45 m; en el suelo se desliza 1,5 m |
| `absh` | Shrike `tbsh` (450, 15) | 150 | 35 | 36 | Proyectil de 0,6 m; en el suelo termina |
| `fhba` | Spitfire `sohf` (400, 15) | 150 | 34 | 36 | Onda de 7,5 m; `ignite`; fuego de 0 durante 30 |
| `ehba` | Gargoyle `sohe` (625, 11,25) | 125 | 40 | 36 | Onda de 6 m |
| `zbba` | Locust `pazb` (450, 15) | 200 | 50 | — | Rayo instantáneo; drenaje 0,875 |
| `rifl` | Phoenix `grdr` (4800, 20) | `mrff` 250/s | caja ×1,5 | — | Costo 0; `peirceShield` |
| drenaje | Netherfiend, Blight, Necryl, Hellmouth, Styx, Deadeye, Fallen, Scythe, Abomination, Gangrel, Astaroth: 0,5; Locust: 0,875 | — | — | — | `CreatureType.drain` ya se carga (`game_data.gd:129`) |

## 030w-a — F177 Temblor en la melé de grupo

**Sacengine (cómo separa los cuerpos):**
- **Una sola regla, la misma para un par y para un grupo:** `positionAfterCollision` (state.d:14446-14564).
  - Primera pasada (caja achicada en `blockSlack`/2 = 0,1): corta el paso que entra más (14538-14543).
  - Segunda pasada (caja agrandada 0,1): suma, para **cada** obstáculo, la superposición de la cara mínima y empuja hasta `collisionFixupSpeed` = 5 m/s (stats.d:161-163), o sea 0,083 m por cuadro (14545-14552).
  - No hay reparto entre los dos cuerpos del par, ni amortiguación, ni nada propio de los grupos.
- **Foto al empezar el cuadro:** la proximidad se arma antes de mover a nadie (`addToProximity` en 29328, `updateCreature` en 29344-29347). Cada cuerpo se empuja contra las cajas del principio del cuadro. Es un paso de Jacobi: los dos cuerpos de un par se llevan cada uno la superposición entera. El port hace lo mismo (`BodyGrid` archivado en la primera resolución del tick, `body_separation.gd:107-115`).
- **El acercamiento durante el golpe va a media marcha:** `startMeleeAttacking` pone `meleeMoving` (8725-8731), y en `meleeMoving` la velocidad y la aceleración en el suelo se multiplican por 0,5 (14668-14671).
  - Desde el primer cuadro de ataque el modo pasa a `meleeAttacking` (14411-14412), que no es `isMoving`, así que el cuerpo **frena** y deja de acercarse.
  - En el port, `close_in` camina a la marcha entera durante todo el golpe (`melee_attack.gd:81-97`, `unit_body.gd:729`).
- **Las cajas de sacengine son las del cuadro de animación**, giradas (`relativeHitbox`, state.d:1177-1179; `sacobject.d:274-317`). Las del port son cuadradas, de `max(radius, reach)`. Es una divergencia conocida que se mantiene (RFC-023 trae la caja por cuadro).

**Medición (log existente `agent/out/det/s7_fixed.log`, `melee_gap_expect.py --table`):**
- Superposición mínima: Druid −0,067 y Trogg −0,072. Cambios de signo por ventana: hasta 759.
- El temblor aparece **también en pares 1 contra 1 sin nadie al lado**. Trogg5→Druid2 en t286: el Trogg ve d = 1,348 y, en el mismo tick, el Druid ve d = 1,211.
- La secuencia de t286-306 para Trogg4→Druid1 es d = 1,163 / 1,328 / 1,219 / 1,314 / 1,142 / 1,308…: un ciclo de 4 ticks con saltos de 0,08 m, el tope del empuje.
- **Mecanismo:**
  1. Un paso termina dentro de la banda de holgura.
  2. En el tick siguiente, los dos cuerpos ven la superposición en la foto y cada uno se lleva 0,08: la corrección es doble y se pasa de largo.
  3. El caminante vuelve a entrar.
- Con el acercamiento apagado (`close_in_factor` 1000) sigue habiendo 409/682 cambios de signo: lo que empuja de vuelta es el re-acercamiento de CHASE tras cada golpe y los terceros cuerpos.

**Diseño (un dueño por decisión; primero lo fiel, el desvío solo si hace falta):**
- **B — fidelidad, dueño `MeleeAttack`** (`melee_attack.gd`, sin tocar `unit_body.gd`, que está en el tope de 1040 líneas):
  - `close_in` multiplica la marcha que recibe por `moving_pace_factor` (`@export`, 0,5) mientras el golpe no llegó a su primer cuadro de ataque (`_next_tick == 0`). Después devuelve cero (`meleeAttacking` frena).
  - Interruptor de banco `static var melee_moving := true`; con `false` vuelve a la regla vieja, para medir.
- **A — desvío, dueño `BodySeparation`.** Entra solo si B no cumple el criterio.
  - `share_of(body, other)`: 0,5 cuando el otro también se resuelve contra este cuerpo en el mismo tick (es obstáculo, no está `Afflictions.fixed()`, no lo exime `_passes`, y es `unit`, `wizard` o `doctor`). Si no, 1,0.
  - `_second_pass` multiplica cada `amounts[i]` por su `share` antes de sumar. Con eso, un par se separa exacto en un tick, sin pasarse, y las cadenas se amortiguan.
  - `rest_distance` no cambia (el reposo sigue siendo la caja agrandada que apenas toca).
  - `_without_carry` recibe los montos ya repartidos.
  - Interruptor `static var share_push := true` (con `false`, la regla de sacengine). Se documenta como el tercer desvío, junto a `make_way` y `wizard_passes_own`.
- **Atribución (solo si ninguna combinación cumple):** log de banco `BodySeparation.log_push` (estático, apagado; lo enciende `ai_match`) con la línea `sep_push A tick push=(x,z) de [B cara monto share]…` para los cuerpos en ATTACK. Se para y se reporta la tabla; no se itera a ojo.

**Escena de prueba / caso:** `debug/f177_melee_group.tscn` + `debug/rules/f177_melee_group.tres` (0,3 min, ancla 1270,1270, fila z−80, validada en f133).
- **Cuerpos:**
  - D1–D3: Druid `nmuh` del slot 1 en −6/−83, −6/−80 y −6/−77.
  - T1–T3: Trogg `ycro` del slot 2 en +6/−83, +6/−80 y +6/−77.
  - T4: Trogg del slot 2 en +14/−80 (el tercero que aprieta).
- **Eventos:** a los 0,3 s, ataque entre pares (D*→T*, T*→D*); a 1,0 s, T4 ataca a D2.
- **Estado inicial:** separados 12 m. Lo que todavía no está es el resultado: una melé quieta.
- Antes de correr Godot se validan los carriles con `lane_report` (`--lanes` en la réplica).

**Réplica:** `agent/tools/melee_gap_expect.py`, sin script nuevo. Se agrega `TREMOR_MAX = 2` (cambios de signo por ventana) en lugar de «a lo sumo 1» y se lo documenta.

**Medición del corte:** 4 corridas `fixed` de `f177` (A×B: off/off, off/on, on/off, on/on), después `s7 fixed` con la combinación elegida.
- Si B sola cumple, A **no se agrega** (se borra el interruptor y `share_of`).
- Si hace falta A, quedan A y B.

**Criterios:**
1. En `f177` y `s7`, ninguna ventana con caja < −0,05 m (hoy −0,067/−0,072) y ≤ 2 cambios de signo por ventana (hoy hasta 759).
2. `final_spit_melee` sigue en PASS con 0 cambios y asentado en el piso de `BodySeparation`.
3. `debug/crowd_cases.gd` (crowd_150, crowd_return, crowd_return_held, crowd_return_trogg, crowd_return_grid) da PASS. Si cambia `MakeWay`, se para.
4. **Digests.** Cada caso que cambie tiene que dar el mismo digest en fixed, stress y window. Su primera línea distinta tiene que ser un `pos`, `hp` o `struck` posterior al primer contacto, y se anota en la tabla de FEATURES como la de «Acercamiento cuerpo a cuerpo».
5. `rules_suite` da PASS. `all` (s7, s7_npcs, s1_trivial, f139) en los 3 modos, sin CONTAMINATED.

**Impacto esperado en los digests:**
- Con B: cambian los casos con acercamiento cuerpo a cuerpo (los de la tabla de FEATURES: s7, f139, f121, f130, f131, f132, más s7_npcs, s1_trivial y s1_quick).
- Con A, además, todo caso con dos cuerpos en contacto (posibles: f123, f124, f126, f127, f129, f149, f153, f155, f156).
- No deberían cambiar `f133` ni los casos nuevos sin contacto de este lote. Si cambian, se para.

**Visible:** sí. Playtest corto: una ventana de `f177` con cámara fija, para ver que la melé está quieta, más el flow `final_spit_melee`.

**Árbol:**
```
[~] scenes/world/units/melee_attack.gd        B: moving_pace_factor, melee_moving (static), close_in con 0,5 / 0
[~] scenes/world/body_separation.gd           A (solo si hace falta): share_of, share_push, log_push
[+] debug/f177_melee_group.tscn               caso (BenchRules)
[+] debug/rules/f177_melee_group.tres
[~] agent/tools/melee_gap_expect.py           TREMOR_MAX = 2, --lanes del caso
[~] agent/run_determinism.sh                  case_args f177 + lista quick
[~] agent/det_baseline.txt                    se regraban los casos que cambian + f177
[~] debug/ai_match.gd                         enciende log_push (si A)
```

## 030w-b — F161 El Brainiac y el Shrike aturden al blanco

**Sacengine:**
- **`brainiacShoot` / `shrikeShoot`** (11513-11525): proyectil recto (`getShotDirection` con precisión), `remainingDistance = range`.
- **`updateBrainiacProjectile`** (22886-22936) y **`updateShrikeProjectile`** (22952-22989):
  - choca con el blanco o con un cuerpo que no es del bando del tirador (filtro 22882-22884, 22946-22948);
  - si es una **criatura** (los magos también, son `MovingObject`): `stunWithCooldown(stunCooldownFrames)` y **después** `dealRangedDamage` (`DamageMod.none`), por el `goto case` (22924-22929, 22978-22983);
  - si es un **edificio**: solo el daño;
  - si es el **terreno**: el Brainiac se desliza ≤ 1,5 m pegado al suelo (`brainiacProjectileSlidingDistance`) y el Shrike termina (0).
- **Look:** `BrainiacEffect` 32 cuadros y `ShrikeEffect` 128 cuadros por tick de vuelo (estela). La textura de SPEL es `mind` (bsba) y `sonc` (absh), con `ttyp tube`.

**Diseño (reusa `StunImpact`, `DirectImpact`, `ShotLook`):**
- **`StunImpact`:** `@export var target_only := false`. Encendido, aturde solo a `target` si es una criatura o un mago con `Stunned` (no a un edificio ni al suelo). Apagado, se queda la caminata de radio de hoy (Flummox F120, sin cambios).
- **`impacts/stun_hit_impact.tscn`:** `StunImpact` (`target_only = true`) con un hijo `DirectImpact`. `ShotImpact.apply` corre primero `_affect` y después los hijos: aturde y después daña, en el orden de sacengine. Una sola escena para los dos, sin script nuevo.
- **`data/shots/bsba.tres` y `absh.tres`:** `ShotLook` con `hit_size` 0,45 y 0,6, `impact = stun_hit_impact.tscn`, `trail_fx` provisorio y `sweep = true` (vuela a 36 m/s, 0,6 m por tick).
- **Deuda declarada:** el deslizamiento de 1,5 m del Brainiac (en el suelo revienta sin daño) y la estela original.

**Escena de prueba / caso:** `debug/f161_stun_shots.tscn` + `rules/f161_stun_shots.tres` (0,4 min, fila z−80).
- **Cuerpos:**
  - B1: Brainiac del slot 1 en −45/−80.
  - S1: Shrike del slot 1 en −45/−72.
  - T1: Troll `ycrp` del slot 2, pacifista, en −20/−80.
  - T2: Troll del slot 2, pacifista, en −20/−72.
  - Separados ≥ 8 m entre filas, sin contacto.
- **Eventos:** B1 ataca a T1 y S1 ataca a T2 a los 0,5 s.

**Criterios:**
1. El primer impacto sobre cada Troll da `aturdido Troll… durante N` en el tick del impacto, con el `directo` en la misma línea de tick, después del aturdido.
2. El daño de cada impacto es `monto · resistencia a distancia directa` del Troll, según el log (±0,01).
3. Los impactos dentro de los 480 ticks del primero dan `aturdir: … en enfriamiento (c)`, con c = 480 − Δt (±1). El primero después de 480 vuelve a aturdir.
4. `f161` da lo mismo en los 3 modos y `quick` no cambia.

**Réplica:** `agent/tools/f161_expect.py` (lee `aturdido`, `aturdir:` y `directo`; `--lanes`).

**Visible:** sí (estela y aturdimiento). Playtest corto, con captura cercana.

**Árbol:**
```
[~] scenes/world/units/impacts/stun_impact.gd       target_only
[+] scenes/world/units/impacts/stun_hit_impact.tscn StunImpact(target_only) + DirectImpact
[+] data/shots/bsba.tres, data/shots/absh.tres      ShotLook
[+] debug/f161_stun_shots.tscn, debug/rules/f161_stun_shots.tres
[+] agent/tools/f161_expect.py
[~] agent/run_determinism.sh, agent/det_baseline.txt (una línea)
```

## 030w-c — F162 Ondas del Spitfire y del Gargoyle (generalizar `FrostWave`)

**Sacengine:**
- **`updateSpitfireProjectile`** (23025-23069) y **`updateGargoyleProjectile`** (23079-23113): vuelan su alcance entero sin chocar.
  - El radio vale `final·frame/(60·range/speed)`: 7,5 m el Spitfire y 6 m el Gargoyle.
  - Cada tick recorren `dealDamageAt` (9075-9089), y cada cuerpo se toma **una vez** (`damagedTargets`).
- **Callback del Spitfire:**
  - el blanco recibe `dealRangedDamage` entero con `DamageMod.ignite` y después `setAblaze(30, 0)`;
  - un cuerpo del bando del tirador, nada;
  - cualquier otro recibe `setAblaze(30, 0)` y después la salpicadura `monto·(1 − d/r)` como `ranged|splash|ignite` (`dealDamage` con radio, 9053-9057).
- **Gargoyle:** el mismo esquema, sin fuego y con `DamageMod.none`.
- **Efectos:** solo en los cuadros < 12.
- Es lo mismo que `FrostWave` (Silverback, 24758-24831) cambiando lo que pasa al tocar. `FrostWave` congela al final del cuadro (`toFreeze`) y lee `can_freeze` antes del golpe.

**Diseño (composición, como `ShotImpact`):**
- **`GrowingWave extends ShotInFlight`** (sale de `frost_wave.gd`) es el dueño único de:
  - el radio `radius_at`;
  - la caminata con `SplashDamage.bodies_within`;
  - el «una vez por vuelo»;
  - el filtro de bando;
  - directo contra salpicadura y los `mods` (lee `shot.mods`: `ShotLook.ignites`);
  - el log `onda …`, con el mismo formato que hoy, que lee `f149_expect.py`.
  - Knobs: `final_radius` y `building_groups`. `static var log_touches`.
- **`WaveTouch extends Node`**: hijos de la onda con `before_hit(body) -> Variant`, `after_hit(body, direct, before)` y `settled()` al final del cuadro.
  - `FreezeTouch`: lógica de hoy, `zerf` y la lista `to_freeze`.
  - `IgniteTouch`: `Burning.ignite(body, 0.0, 30, DIRECT_RANGED, slot)`; el orden de sacengine (blanco: daño y después fuego; otros: fuego y después daño) se respeta con `before_hit`/`after_hit`.
- **Escenas:**
  - `frost_wave.tscn` = `GrowingWave(7,5)` + `FreezeTouch`;
  - `spitfire_wave.tscn` = `GrowingWave(7,5)` + `IgniteTouch`;
  - `gargoyle_wave.tscn` = `GrowingWave(6,0)`.
- **`data/shots/fhba.tres`** (`in_flight = spitfire_wave`, `collides = false`, `ignites = true`) y **`ehba.tres`** (`gargoyle_wave`, `collides = false`).
- **`ai_match.gd`:** `FrostWave.log_touches` pasa a `GrowingWave.log_touches`.
- Se mantiene el desvío declarado del radio 0 en el primer tick.

**Escena de prueba / caso:** `debug/f162_waves.tscn` + `rules/f162_waves.tres` (0,3 min, fila z−80 y fila z−66; esta última se valida con `--lanes`).
- **Cuerpos:**
  - P1: Spitfire del slot 1 en −45/−80.
  - W1: Trogg del slot 2, pacifista, en −20/−80 (blanco).
  - W2: Trogg del slot 2, pacifista, en −24/−77 (salpicadura).
  - A1: Druid del slot 1, pacifista, en −30/−78 (mismo bando).
  - G1: Gargoyle del slot 1 en −45/−66.
  - W3: Trogg del slot 2, pacifista, en −20/−66.
  - W4: Trogg del slot 2, pacifista, en −24/−63.
  - Nadie se toca.
- **Eventos:** P1 ataca a W1 y G1 ataca a W3 a los 0,5 s.

**Criterios:**
1. **Paso 0:** `f149` da **el mismo digest** con `GrowingWave` que antes, y `f149_expect.py` PASS. Si cambia, se para.
2. El radio de cada `toca` es `final·(n−1)/(60·range/speed)` (±0,001).
3. El blanco recibe el monto · resistencia directa; la salpicadura, `monto·(1 − d/r)` · resistencia de salpicadura con la d del log (±0,5); el aliado, 0; cada cuerpo, una vez.
4. **Spitfire:** `fuego` en W1 y W2 durante 31 actualizaciones, con 0 de daño. **Gargoyle:** sin fuego.
5. `f162` da lo mismo en los 3 modos y `quick` no cambia.

**Réplica:** `agent/tools/f162_expect.py`, que importa el parser de `f149_expect.py`.

**Visible:** sí (las ondas). Playtest corto.

**Árbol:**
```
[-] scenes/world/units/frost_wave.gd                → growing_wave.gd (git mv)
[+] scenes/world/units/growing_wave.gd              GrowingWave
[+] scenes/world/units/wave_touch.gd                WaveTouch (base)
[+] scenes/world/units/freeze_touch.gd              FreezeTouch (lo de hoy)
[+] scenes/world/units/ignite_touch.gd              IgniteTouch
[~] scenes/world/units/frost_wave.tscn              GrowingWave + FreezeTouch
[+] scenes/world/units/spitfire_wave.tscn, gargoyle_wave.tscn
[+] data/shots/fhba.tres, data/shots/ehba.tres
[~] debug/ai_match.gd                               GrowingWave.log_touches
[+] debug/f162_waves.tscn, debug/rules/f162_waves.tres, agent/tools/f162_expect.py
[~] agent/run_determinism.sh, agent/det_baseline.txt (una línea)
```

## 030w-d — F166 Rayo instantáneo de la Locust

**Sacengine:**
- **`locustShoot`** (11527-11531) crea un `LocustShoot`. **`updateLocustShoot`** (22992-23005) en el mismo cuadro hace:
  - `collideRay` desde el origen del disparo hasta `range`, con filtro `id != atacante && isValidTarget`: cualquier bando, edificios incluidos;
  - con una criatura o un edificio, `dealRangedDamage(DamageMod.none)`;
  - sin blanco, el extremo visual es `0,5·range`.
- **`LocustProjectile`** (23007-23022) es solo visual: partículas de sangre o de escombro que viajan del extremo **hacia** la Locust a 36 m/s.
- El daño drena 0,875 (F164).

**Diseño (reusa `RayStrike`, como el Gnome):**
- **`strikes/locust_ray.tscn`:** `RayStrike`, `bursts 1`, `foes_only = false` (Health decide el fuego amigo), `beam` provisorio.
- **`RayStrike`:** `@export_range(0,1) var miss_fraction := 1.0`, solo visual (Locust 0,5).
- **`data/shots/zbba.tres`:** `strike = locust_ray.tscn`, sin `impact`. Así el daño va por `ShotImpact.land` (directo), que es donde F164 pone el drenaje.
- **Deuda declarada:** el flujo de partículas hacia la Locust (placeholder: beam).

**Escena de prueba / caso:** `debug/f166_locust_ray.tscn` + `rules/f166_locust_ray.tres` (0,3 min, fila z−80).
- **Cuerpos:**
  - L1: Locust del slot 1 en −45/−80, `health_fraction 0.5` (para F164).
  - T1: Troll del slot 2, pacifista, en −20/−80.
  - Y1: Druid del slot 1, pacifista, en −30/−80, en la línea (para el criterio 2).
  - L2: Locust del slot 1 en −45/−70.
  - T2: Troll del slot 2, pacifista, en −20/−70 (línea libre).
- **Eventos:** L1 y L2 atacan a los 0,5 s.

**Criterios:**
1. El daño cae en el **mismo tick** del disparo, sin vuelo: 200 · resistencia directa a T2.
2. El rayo de L1 frena en Y1. Y1 recibe 0 si el fuego amigo está apagado, y T1 no recibe nada de ese rayo.
3. `f166` da lo mismo en los 3 modos y `quick` no cambia.
4. (Lo agrega F164: L1 y L2 curan 0,875 · daño.)

**Réplica:** `agent/tools/f166_expect.py`. **Visible:** sí. Playtest corto.

**Árbol:**
```
[~] scenes/world/units/strikes/ray_strike.gd        miss_fraction (visual)
[+] scenes/world/units/strikes/locust_ray.tscn
[+] data/shots/zbba.tres
[+] data/fx/beams/<locust>.tres (provisorio, si no se reusa uno)
[+] debug/f166_locust_ray.tscn, debug/rules/f166_locust_ray.tres, agent/tools/f166_expect.py
[~] agent/run_determinism.sh, agent/det_baseline.txt (una línea)
```

## 030w-e — F164 Drenaje de vida (melé y disparo directo)

**Sacengine:** `dealDamage(objeto, daño, ref atacante)` (8933-8946) calcula `actualDamage` (con el tope de la vida que queda, 9033) y llama a `healFromDrain`, que cura al atacante `actualDamage·drain` al instante, con el tope del máximo (8834-8840, `heal` 8815-8817).
- Se aplica solo contra cuerpos móviles, nunca contra edificios (9193-9207 no drena), y solo si el atacante es una criatura viva (8910-8911).

**Diseño (un dueño):**
- **`LifeDrain`** (`scenes/world/units/life_drain.gd`, `class_name`, `static func feed(attacker, target, taken)`): es la regla única.
  - Solo actúa si `taken > 0`, el atacante es un `UnitBody` vivo con `type.drain > 0`, `attacker != target`, y el blanco es `unit` o `wizard` (no `structure`).
  - Llama a `attacker.Health.heal(taken·drain)`.
  - Log de banco `static var log_drain`: `drena A de B taken -> hp`.
- **`Health.damage()`** devuelve `float` taken = `min(current_antes, monto_escalado)`. No cambia lo que emite `hit` (sin efecto en los digests).
- **Llamadores, uno por camino, sin lógica propia:**
  - `MeleeAttack._land`;
  - `ShotImpact.land` (rama directa por defecto: Fallen `dkba`, Locust `zbba` por `RayStrike`);
  - `DirectImpact._affect`.
  - El tirador sale de `shooter_path` del holder.
- **F164b (deuda):** `SplashImpact` por cuerpo, `PoisonImpact` y `DiseaseImpact` con la cura por `rangedAttack.amount` (23523, 24360, 24879), `Burning`.

**Escena de prueba / caso:** `debug/f164_drain.tscn` + `rules/f164_drain.tres` (0,3 min, fila z−80).
- **Cuerpos:**
  - K1: Scythe `dzid` del slot 1 en −30/−80, `health_fraction 0.5`.
  - T1: Troll del slot 2, pacifista, en −27/−80.
  - K2: Scythe del slot 1 en −30/−70, con la vida llena.
  - T2: Troll del slot 2, pacifista, en −27/−70.
  - F1: Fallen `dplk` del slot 1 en −45/−90, `health_fraction 0.5`.
  - T3: Troll del slot 2, pacifista, en −25/−90.
- **Eventos:** todos atacan a los 0,5 s.

**Criterios:**
1. En cada golpe de K1 con cantidad > 0, la vida de K1 sube `0,5·cantidad` en el mismo tick (±0,01), con el tope de 540.
2. K2 queda en 540 sin líneas de cura.
3. Cada disparo de F1 cura `0,5·directo`.
4. En `f166`, L1 cura `0,875·directo` (se regraba `f166`).
5. `f164` da lo mismo en los 3 modos. En `quick` solo pueden cambiar `f166`, `f156` (Blight), `f133` (Fallen) y `s1_*`/`s7*` si aparece un Charnel. Cualquier otro, se para.

**Réplica:** `agent/tools/f164_expect.py`. **Visible:** no (lógica pura): cierra con banco y review.

**Árbol:**
```
[+] scenes/world/units/life_drain.gd                LifeDrain (regla única)
[~] scenes/world/components/health.gd               damage() -> float taken
[~] scenes/world/units/melee_attack.gd              _land: LifeDrain.feed
[~] scenes/world/units/shot_impact.gd               land (rama directa): LifeDrain.feed
[~] scenes/world/units/impacts/direct_impact.gd     LifeDrain.feed
[~] debug/ai_match.gd                               LifeDrain.log_drain
[+] debug/f164_drain.tscn, debug/rules/f164_drain.tres, agent/tools/f164_expect.py
[~] agent/tools/f166_expect.py                      criterio 4
[~] agent/run_determinism.sh, agent/det_baseline.txt
```

## 030w-f — F163 Escudo de fuego del Phoenix

**Sacengine:**
- **`runPhoenixPassive`** (13898-13919) corre cada cuadro desde `updateCreatureStats` (`runPassive`, 13921-13931, llamado en 13942). Hace esto:
  - si el modo `canShield` (218-225) y el maná ≥ `manaCost` (0), toma cada cuerpo móvil cuya caja toca la caja del Phoenix escalada ×1,5 desde el centro, menos el propio Phoenix;
  - si su bando **no** es aliado, recibe `ignite(fireform.amount/60)`, es decir `dealFireDamage(0, 250/60, …, peirceShield)` como daño de hechizo directo (17254-17261, 9421-9427), más 3 partículas de fuego;
  - si tocó a alguien, drena `manaCost` (0) y suelta las partículas del escudo (tasa 3, 13880).
- No toca edificios.

**Diseño:**
- **`FireShield`** (componente en `unit.tscn`, como `MeleeOnHit`; ya lo anticipa el comentario de `damage_passive_type.gd:9`).
  - Knobs: `@export var passive_tag := "rifl"`, `box_scale := 1.5`, `spell := "mrff"`, `groups [unit, wizard]` y FX.
  - Solo actúa si `type.passive_on_damage == passive_tag` y en el servidor.
  - Cada tick: caja propia con `BodySeparation.box_of` (medio ancho y alto) escalada ×1,5 desde el centro, contra las cajas de los otros. Para los no aliados, `Health.damage_typed(250/60, DIRECT_SPELL, slot, pierce_shield = true)` y FX de fuego. El maná no se toca (costo 0; si fuera > 0, `ManaPool.drain`).
  - `static var log_shield` (banco).
- No se agregan líneas a `unit_body.gd`. El modo `canShield` sale de `is_targetable()` y de un `mode` que no sea DEAD.

**Escena de prueba / caso:** `debug/f163_phoenix_shield.tscn` + `rules/f163_phoenix_shield.tres` (0,2 min, fila z−80, `holds_still`).
- **Cuerpos:**
  - P1: Phoenix del slot 1, pacifista, en −30/−80.
  - P2: Phoenix del slot 2, pacifista, en −30/−77, superpuesto ×1,5 a la misma altura.
  - P3: Phoenix del slot 1, pacifista, en −33/−80 (aliado).
  - P4: Phoenix del slot 2, pacifista, en −30/−60 (lejos).
  - El desarrollador confirma las distancias con `BodySeparation.box_of` y `lane_report`.

**Criterios:**
1. P2 pierde `250/60 · resistencia de hechizo directo` por tick (±0,001) mientras las cajas ×1,5 se tocan, y P1 lo mismo por P2.
2. P3 y P4 no pierden nada por el escudo.
3. El maná no cambia.
4. `f163` da lo mismo en los 3 modos. En `quick` solo puede cambiar `f125` (Phoenix contra Druids): si cambia, la primera línea distinta tiene que ser un `hp` del escudo.

**Réplica:** `agent/tools/f163_expect.py`. **Visible:** sí (fuego). Playtest corto.

**Árbol:**
```
[+] scenes/world/units/fire_shield.gd + fire_shield.tscn   FireShield
[~] scenes/world/units/unit.tscn                           instancia FireShield
[~] debug/ai_match.gd                                      FireShield.log_shield
[+] debug/f163_phoenix_shield.tscn, debug/rules/f163_phoenix_shield.tres, agent/tools/f163_expect.py
[~] agent/run_determinism.sh, agent/det_baseline.txt
```

## Resource, nodo y `@export`

- **Resource (tipo):**
  - `ShotLook` por tag (`bsba`, `absh`, `fhba`, `ehba`, `zbba`).
  - `AbilityType`/`SpellType` (montos, alcance, `mrff`).
  - `CreatureType.drain` y `passive_on_damage`.
  - No se muta ninguno.
- **Nodo (comportamiento):** `GrowingWave` y sus `WaveTouch`, `StunImpact`/`DirectImpact` en escenas de impacto, `RayStrike` en `locust_ray.tscn` y `FireShield` en `unit.tscn`.
- **Estático (regla sin estado):** `LifeDrain.feed` y `BodySeparation.share_of`.
- **`@export` de instancia:** `target_only`, `final_radius`, `miss_fraction`, `box_scale`, `moving_pace_factor`, `passive_tag`.
- **Interruptores de banco (`static var`, apagados en el producto):** `log_push`, `log_drain` y `log_shield`, más los de medición `melee_moving` y `share_push`.

## Orden y paralelismo

Reglas:
1. Godot va solo por `godot_run.sh`: 2 headless y la ventana exclusiva. Los playtests van de a uno.
2. Dos cortes que regraban **la misma línea** de `det_baseline.txt` nunca van en paralelo.
3. Los casos nuevos de este lote son **sin contacto** (carriles separados, pacifistas), así que su digest no depende de F177.

| Etapa | Cortes (worktree propio cada uno) | Por qué no se pisan |
|---|---|---|
| 1 | **F177** ∥ F161 ∥ F162 ∥ F166 | F177 toca `body_separation`/`melee_attack` y regraba la base. Los otros tocan `stun_impact`, `frost_wave`→`growing_wave` y `ray_strike`, y solo **agregan** su línea |
| 2 | F164 ∥ F163 (después de mergear F177 y F166) | F164 toca `health`, `melee_attack`, `shot_impact` y `direct_impact`, y regraba f156/f133/f166. F163 toca `unit.tscn` y `fire_shield`, y regraba f125. Si los dos cambian el mismo caso, F163 espera |

- **F177 va primero** (de los que cambian digests): cambia la simulación de todas las peleas. Todo corte que regrabe digests después lo hace sobre la física nueva, y así no se regraba dos veces.
- **Merge en serie:** F177 → F162 → F161 → F166 → F164 → F163. Cada uno se rebasea sobre main y corre `quick` (fixed) contra la base de ese momento antes de mergear.
- **Conflictos de texto esperados**, que se resuelven uniendo:
  - las líneas agregadas al final de `det_baseline.txt`;
  - `case_args` y la línea de `quick` en `run_determinism.sh`;
  - las líneas de logs en `debug/ai_match.gd`.
- **Si un caso nuevo cambia después del rebase sobre F177** (hubo contacto), se regraba dentro de su propio merge y se revisa por qué hubo contacto.
- **F162:** el criterio «`f149` igual» se mide en su worktree antes del rebase (base vieja) y otra vez después (base con F177).

## Riesgos

- **R1:** F177-B puede no alcanzar. A es un desvío del port y se declara como tal. A puede romper criterios de `MakeWay` (crowd_*), que se ajustaron con el empuje entero: si se rompe uno, se para y se reporta.
- **R2:** con A, cambia `rest_distance` en la práctica (el par llega exacto, sin pasarse). `final_spit_melee` tiene que seguir asentándose a 0,100.
- **R3:** `unit_body.gd` está en el tope (1040). Ningún corte del lote le agrega líneas.
- **R4:** la refactorización de `FrostWave` mueve el orden de la tirada de congelar. El gate es `f149` idéntico.
- **R5:** F164 cambia el valor de retorno de `Health.damage()`. Los llamadores que lo ignoran no cambian. `hit.emit` queda igual.
- **R6:** el Phoenix vuela. Si su caja ×1,5 no llega a cuerpos en el suelo, en el juego solo quema a otros voladores o en picada; se documenta lo que mida el caso.
- **R7:** las tags de SPEL dicen nombres de UI engañosos («Wind Gust», «Hose», «Firehose», «Hail of Earth», «Drain Essence»). Manda el `SpellTag` de sacengine (nttData.d:1177-1183).
- **R8:** el pasto está apagado; las capturas de los playtests son cercanas igual.
- **Fuera de alcance:**
  - F164b (salpicadura y veneno);
  - el deslizamiento del Brainiac;
  - la caja por cuadro (RFC-023);
  - `meleeAttackTarget`, que en sacengine puede golpear a otro enemigo de la caja al llegar el tick (14413);
  - sonidos.

## Verificación humana (editor)

- **F177:** abrir `debug/f177_melee_group.tscn`, F6. Con la cámara fija en la melé, los cuerpos no vibran. En el inspector de `MeleeAttack` se ve `moving_pace_factor` en 0,5.
- **F161/F162/F166/F163:** F6 en cada `debug/f16x_*.tscn`.
  - F161: el Troll se tumba (aturdido) con el primer impacto.
  - F162: la onda crece y quema al Trogg de al lado, no al Druid aliado.
  - F166: el rayo es instantáneo y frena en el primer cuerpo.
  - F163: el Phoenix enemigo pegado echa fuego, el aliado no.
  - En el inspector: `ShotLook` de cada tag (`data/shots/*.tres`), `StunImpact.target_only` y `GrowingWave.final_radius`.
- **F164:** sin ventana. `f164_expect.py` sobre el log del banco.
