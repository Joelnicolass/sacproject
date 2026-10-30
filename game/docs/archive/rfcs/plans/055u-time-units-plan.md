# 055u — Unidades de tiempo y de medida para humanos (plan)

> Origen: auditoría `docs/archive/rfcs/research/055R-legacy-audit.md` §3.3 (C-3) y `RFC-055-human-first-refactor.md` §13.2b (fila C-3, corte 055u). Explicación aprobada por el usuario.

## Regla

- La simulación sigue contando **ticks enteros a 60 Hz** (determinismo, red, snapshot, banco). No cambia.
- Lo que edita un humano (`@export` de escenas, campos de Resources de tipo, `AiProfile`) va en **segundos** (`_s`), **metros** (`_m`), **m/s** (`_m_s`), **m/s²** (`_m_s2`) o «por segundo» (`_per_s`), con la unidad en el nombre (C8).
- **Una sola frontera**: `MatchClock.ticks_for(seconds)` (`ceil(seconds·TPS − 1e-4)`). El consumidor convierte al leer (getter derivado `var x_ticks: int: get: return MatchClock.ticks_for(x_s)` cuando lo leen varios, o la llamada en el único lugar que lo usa). Nunca se suma `delta` en la simulación.
- **Valor exacto**: el número en segundos se escribe truncado a 4 decimales (`55 ticks → 0.9166 s`). `ticks_for` redondea hacia arriba al tick entero, así que cualquier valor en `(n−1, n]/60` da exactamente `n` ticks: `0.9166 · 60 = 54.996 → 55`. A 30 Hz el mismo valor da `28` ticks (0,933 s): la duración real se conserva a menos de un tick.
- Lo que el código usa como `float` directo en la simulación (no pasa por `ticks_for`) se escribe con el `double` exacto o se convierte primero a ticks enteros, para que el digest no cambie.
- Quedan en ticks: cadencias de red (resync de una copia del cliente), banco/replays y los cuadros de imagen de atlas (`h_frames`, `frames_h`…). También quedan, contados en el ratchet de C22, los desfases de **un tick** que ordenan cosas dentro de la simulación (no son duraciones) y los cuadros de clip que 055c1 pasa a marcadores de la `AnimationLibrary`.

## Tabla

### IA (`scenes/ai/data/ai_profile.gd`, `data/ai/profile_original.tres`)

Las «edades» de la IA cuentan corridas de la ranura k2 (6 ticks en Normal). El campo pasa a segundos medidos a ritmo Normal y `AiProfile.ages_for(s) = ticks_for(s) / período de k2 del perfil base`; la copia que arma una dificultad guarda el período base (`age_period_ticks`), así una dificultad lenta sigue estirando esas edades como hoy.

| Campo antes | Antes | Después | Valor |
|---|---|---|---|
| `rerate_ticks` | 16 edades (96 ticks) | `rerate_s` | 1.6 |
| `status_ticks` | 8 (48) | `status_s` | 0.8 |
| `souls_snapshot_ticks` | 32 (192) | `souls_snapshot_s` | 3.2 |
| `threat_ticks` | 8 (48) | `threat_s` | 0.8 |
| `wizard_replan_ticks` | 16 (96) | `wizard_replan_s` | 1.6 |
| `wizard_reissue_ticks` | 8 (48) | `wizard_reissue_s` | 0.8 |
| `slot_periods` (ticks, sin `_ticks` en el nombre) | 12/60/6/6/60/12 | queda | cadencia de la máquina de la IA; ver «Fuera» |

### Unidades (`scenes/units/`)

| Archivo | Antes | Después | Overrides |
|---|---|---|---|
| `corpse.gd` | `fall_ticks 55` | `fall_s 0.9166` | — |
| `passives/fire_shield.gd` | `fire_every_ticks 5` | `fire_every_s 0.0833` | — |
| `strikes/ray_strike.gd` | `period_ticks 4` | `period_s 0.0666` | `warmonger_gun.tscn 4 → 0.0666` |
| `targeting/side_vision.gd` | `purge_ticks 600` | `purge_s 10.0` | — |
| `impacts/burn_impact.gd` | `fixed_ticks 60`, `fire_every_ticks 10` | `fixed_s 1.0`, `fire_every_s 0.1666` | — |
| `impacts/spike_wave.gd` | `life_ticks 90`, `damage_frames [14,29,44,59,89]` | `life_s 1.5`, `damage_at_s [0.2333,0.4833,0.7333,0.9833,1.4833]` | — |
| `impacts/stun_impact.gd` | `cooldown_ticks 480` | `cooldown_s 8.0` | — |
| `impacts/pushback.gd` | `duration_ticks 40` | `duration_s 0.6666` | — |
| `afflictions/frozen.gd` | `max_cooldown_ticks 600` | `max_cooldown_s 10.0` | — |
| `afflictions/oiled.gd` | `fire_ticks 60` | `fire_s 1.0` | — |
| `afflictions/firewalking.gd` | `trail_every_ticks 2`, `frames 60` | `trail_every_s 0.0333`, `walk_s 1.0` | — |
| `afflictions/petrified.gd` | `knock_cooldown_ticks 240` | `knock_cooldown_s 4.0` | — |
| `afflictions/looks/vine_look.gd` | `grow_ticks 60` | `grow_s 1.0` | — |
| `afflictions/looks/body_box_look.gd` | `grow_ticks 30` | `grow_s 0.5` | — |
| `afflictions/looks/rings_look.gd` | `every_ticks 25` | `every_s 0.4166` | — |
| `abilities/lightning_strike.gd` | `travel_ticks 12` (y `launch(..., travel := -1)`) | `travel_s 0.2` (`launch(..., travel_s := -1.0)`) | — |
| `status/devour_growth.gd` | `regeneration_ticks 60.0` (un divisor: «increment/60 por segundo», no una duración en ticks) | `regeneration_over_s 60.0` (mismo número, ya era segundos) | — |
| `abilities/pull_thread.gd` | `grow 20`, `reshape 6`, `ramp 30`, `wait 30`, `max_life 2400` | `grow_s 0.3333`, `reshape_s 0.1`, `ramp_s 0.5`, `wait_s 0.5`, `max_life_s 40.0` | `cage_thread.tscn reshape 6 → 0.1, ramp 30 → 0.5`. La clave de red `grow_ticks` del evento queda en ticks (red) |
| `abilities/divine_sight_eye.gd` | `rising 45`, `refresh 30`, `ticks_per_frame 8` | `rising_s 0.75`, `refresh_s 0.5`, `frame_s 0.1333` | — |
| `status/poisoning.gd` | `mana_block 120`, `infection_cooldown_extra 180`, `fx_every 30` | `mana_block_s 2.0`, `infection_cooldown_extra_s 3.0`, `fx_every_s 0.5` | — |
| `abilities/quake_wave.gd` | `cooldown_ticks 480`, `total_frames 30` | `cooldown_s 8.0`, `life_s 0.5` | — |
| `abilities/pull.gd` | `pull_ticks 25`, `stun_ticks 480` | `pull_s 0.4166`, `stun_s 8.0` | `cage_pull.tscn`, `web_pull.tscn` |
| `abilities/fast_revive.gd` | `revive_ticks 150`, `rise_ticks 75` | `revive_s 2.5`, `rise_s 1.25` | `revive_slow.tscn 300 → 5.0, 150 → 2.5` |
| `abilities/ability_effect.gd` | `windup_ticks 0` | `windup_s 0.0` | `bilemites/sticky_bomb/viscous_oil 94 → 1.5666`, `firewalk 150 → 2.5`, `breath_of_life_ability 52 → 0.8666` |
| `abilities/halo_of_earth.gd` | `ground_grace 35`, `life 2100` | `ground_grace_s 0.5833`, `life_s 35.0` | — |
| `attacks/droplet_rain.gd` | `max_fall_ticks 600` | `max_fall_s 10.0` | — |
| `attacks/mite_hop.gd` | `rest_ticks 30` | `rest_s 0.5` | — |
| `attacks/ignite_touch.gd` | `fire_ticks 30` | `fire_s 0.5` | — |
| `attacks/ground_hug_flight.gd` | `spike_every_ticks 6` | `spike_every_s 0.1` | — |
| `attacks/ranged_attack.gd` | `facing_frames 4.0` | `facing_s 0.0666` (se usa como ticks enteros, misma cuenta float) | — |
| `impacts/stick_impact.gd` | `extra_ticks 1` | **queda** (un tick de orden, no duración; cuenta en C22) | — |
| `abilities/protector.gd` | `allies_delay_ticks 1` | **queda** (un tick de orden; cuenta en C22) | — |

### Hechizos (`scenes/spells/`)

| Archivo | Antes | Después | Overrides |
|---|---|---|---|
| `walls/fence_posts.gd` | `period_ticks 32`, `birth_tick 16` | `period_s 0.5333`, `birth_s 0.2666` | — |
| `walls/wall_scars.gd` | `every_ticks 4` | `every_s 0.0666` | — |
| `walls/spell_wall.gd` | `grow_ticks 240` | `grow_s 4.0` (getter `grow_ticks` para las partes del muro) | `vinewall/wall_of_spikes/firewall 240 → 4.0`, `wailing_wall 180 → 3.0`, `fence 176 → 2.9333` |
| `walls/wall_touch.gd` | `stun_cooldown_ticks 0` | `stun_cooldown_s 0.0` | `wall_of_spikes.tscn 480 → 8.0` |
| `walls/wall_spirit.gd` | `trail_ticks 90` (largo del rastro, una muestra por tick) | `trail_s 1.5` | `charm.tscn 60 → 1.0` (×3) |
| `zones/zone_blast.gd` | `burn_ticks 60` | `burn_s 1.0` | — |
| `zones/zone_heat.gd` (Volcano, entró con el merge) | `burn_ticks 0` | `burn_s 0.0` | `volcano_zone.tscn 30 → 0.5` |
| `zones/volcano_look.gd` (Volcano) | `lava_frame_ticks 4`, `pulse_ticks 90` (main quitó `cloud_cycle_ticks`) | `lava_frame_s 0.0666`, `pulse_s 1.5` | — |
| `zones/zone_stun_ring.gd` | `cooldown_ticks 480` | `cooldown_s 8.0` | — |
| `zones/rift_ribbon.gd` | `trail_ticks 120` | `trail_s 2.0` | — |
| `wards/ward.gd` | `grow_ticks 15` | `grow_s 0.25` | `healing_aura.tscn 30 → 0.5` |
| `drops/drop_blast.gd` | `burn_ticks 60`, `stun_ticks 0` | `burn_s 1.0`, `stun_s 0.0` | `meteor.tscn stun 480 → 8.0` |
| `animate_dead/animate_dead_fx.gd` | `every_ticks 2` | `every_s 0.0333` | — |
| `carrier/carrier_pulse.gd` | `stun_ticks 480` | `stun_s 8.0` | — |
| `carrier/spell_carrier.gd` | `roundtrip_ticks 540` | `roundtrip_s 9.0` (`SoulTrip` lo pasa a ticks; cada tramo es la mitad) | — |
| `zones/bore_drill.gd` | `resync_ticks 8` | **queda** (red: cuánto se aleja la copia del cliente antes de resincronizar) | — |

### Mapa (`scenes/map/`)

| Archivo | Antes | Después |
|---|---|---|
| `terrain/terrain_collision.gd` | `refresh_ticks 3` | `refresh_s 0.05` |
| `nav/nav_service.gd` | `holes_rebake_ticks 120`, `rebake_swap_frames 180` | `holes_rebake_s 2.0`, `rebake_swap_s 3.0` |
| `nav/nav_service.gd` | `rebuild_delay_frames 2` | **queda** (espera de dos cuadros a que la estructura haga su `_ready`: orden, no duración; cuenta en C22) |
| `terrain/terrain_stamp.gd` | `resync_ticks 8` | **queda** (red) |
| `ai/ai_roster.gd` | `settle_frames 20` | `settle_s 0.3333` |

### Fracciones del original reescritas (ya eran `_s`)

| Archivo | Antes | Después | Consumidor |
|---|---|---|---|
| `match/match_rules.gd` | `guardian_heal_per_s 1000.0 / 60.0` | `16.666666666666668` (el `double` exacto: se multiplica por `delta`) | sim |
| `match/match_rules.gd` | `teleport_effect_s 32.0 / 60.0`, `teleport_ring_s 48.0 / 60.0` | `0.5333`, `0.8` | look (redondea a ticks) |
| `fx/beam_type.gd` | `frame_s 2/60`, `change_s 6/60`, `life_s 64/60`, `travel_s 12/60` | `0.0333`, `0.1`, `1.0666`, `0.2` | look |
| `fx/particle_type.gd`, `fx/tether.gd`, `fx/portal_look.gd`, `fx/fx_trail.gd`, `spells/guardian/guardian_tether.gd` | `frame_s/interval_s 2/60 o 1/30` | `0.0333` | look |
| `sacrifice/carry_rope.gd`, `sacrifice/red_vortex.gd` | `1.0 / 30.0` | `0.0333` | look |
| `fx/spike_field.gd` | `lifetime_s 2.0 / 3.0` | `0.6666` | look |
| `spells/zones/rift_spawner.gd`, `rift_spirit.gd`, `wards/aura_impact.gd`, `drops/frog_hop.gd` | `1.0 / 3.0` | `0.3333` | `ticks_for` / `roundi(s·60)` = 20 |
| `spells/chain/chain_strike.gd`, `spells/chain/chain_hop.gd` | `12/60`, `20/60` | `0.2`, `0.3333` | `ticks_for` |
| `spells/animate_dead/streamer_fx.gd` | `128/60` | `2.1333` | look |

### Campos sin unidad (`SpellType`, `AbilityType`)

| Antes | Después |
|---|---|
| `cast_range` | `cast_range_m` |
| `speed` | `speed_m_s` |
| `acceleration` | `acceleration_m_s2` |
| `damage_range` | `damage_range_m` |
| `effect_range` | `effect_range_m` |
| `duration` | `duration_s` |

Se renombran en las dos clases, en los `.tres` de `data/catalog/{spells,abilities}/`, en el horneador (`tools/bake/catalog_builder.gd`) y en cada lector. `CreatureType`/`WizardType` (`running_speed`, `sight_range`…) quedan para 055c1, que reescribe esas clases.

## Fuera (otros cortes)

- `WizardType.death_frames`, `corpse_rise_frames`, `float_to_stance_frames`, `AbilityEffect.FRAME_TICKS`, `pull.load_frame`: cuadros de clip → marcadores `hit` en 055c1. Cuentan en C22.
- `AiProfile.slot_periods`: cadencia de las 6 ranuras de la IA (ticks). Pasarla a segundos cambia cómo escala la dificultad; va con 055f.
- `CreatureType`/`WizardType` sin unidad (`running_speed`, `sight_range`, `drain`): 055c1.
- `debug/` y `agent/` (`settle_frames` de las escenas de prueba): herramientas, no datos de juego.

## Resultado

- C22 en `scenes/`: 77 en main → 6 (los 3 cuadros de clip de `WizardType`, `NavService.rebuild_delay_frames`, `StickImpact.extra_ticks`, `Protector.allies_delay_ticks`).
- `AiProfile.age_period_ticks` es `@export_storage` (no lo edita un humano; C22 no lo cuenta).

## Verificación

- Suite: `time_unit_cases` — por cada campo convertido (default del script, override de la escena o del `.tres`), `ticks_for(valor_s) == ticks de antes` a 60 Hz; y a 30 Hz `|ticks_for(valor_s)/30 − ticks_antes/60| ≤ 1/30` (la duración real se conserva).
- Lint C22: `@export` con `_ticks` o `frames` en `scenes/` fuera de la allowlist (red: `resync_ticks`; atlas: `h_frames`/`v_frames`/`frames_h`/`frames_v`; UI: `scenes/ui/`) cuenta en el ratchet.
- Banco `quick --no-window` al final: el mismo digest que main.
