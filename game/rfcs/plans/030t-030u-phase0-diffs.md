# 030t/030u: diffs de la fase 2 (que dejó la fase 0, 2026-10-17)

La fase 0 ya creó estos archivos nuevos e inertes:
- `quake_wave.gd/.tscn`;
- `scenes/fx/quake_ring.gd/.tscn`;
- `scenes/world/sac_float.gd` (`SacFloat.f32`);
- `scenes/data/on_hit_passive_type.gd`;
- `impacts/rend_blast_impact.tscn`;
- las réplicas `agent/tools/f131`, `f157`, `f132`, `f158` y `f159_expect.py`. Todas aceptan `--lanes`, `--numbers` o un log, y `lane_report` está en `f131_expect.py`.

No se crearon todavía (se hacen en la fase 2):
- `debug/f131_devour_rend.*` y `debug/f132_quake_onhit.*`, porque usan `target_soul`.
- `data/passives/yeti_freeze.tres` (`zerf`, `Afflictions/Frozen`, `skip_if_was_frozen`) y `dragon_vines.tres` (`eniv`, `Afflictions/Vined`, `refuse_flying`). Nadie carga `data/passives/` entero.

## Soul (`scenes/world/souls/soul.gd`)
- `enum State { …, DEVOURING }` va **al final**, porque se replica como int.
- `devour_shrink_per_s := 3.0` y `_remains` (el cadáver que `sever()` disuelve).
- `is_free_or_own(slot)` = `color_for(slot) == BLUE`.
- El estático `on_corpse(c)` sale de `BreathOfLifeAbility.soul_of`; esa función pasa a llamarlo.
- `begin_devour(by)`: fija `collector` y `collector_slot`, guarda `_remains = corpse`, pone `attached = false`, `corpse = null`, `state = DEVOURING` y llama a `sever()`.
- `sever()`: si hay `_remains`, `Corpse.dissolve` y log `cadáver X disuelto`.
- `burst()` (Rend): `sever`, `number = 0`, log `alma X reventada` y `queue_free`.
- `begin_collect` también guarda `_remains`. `SoulSystem._try_collect` usa `soul.sever()` en lugar de disolver el cadáver por su cuenta, después de `soul_collected` y `SoulPurse.add`.
- `_devour_step`: se encoge a `devour_shrink_per_s` hacia `shot_origin` del `collector`. Log `alma X devorando` y `devorada`, y al final `queue_free`.

## Health
- `@export var growth: DevourGrowth`.
- `resistance = max(0, base·growth_factor + poison_bonus)`.
- `raise_maximum(a)` suma `a` a `maximum` y a `current`. Solo con autoridad.

## AbilityEffect / ActiveAbility
- `@export_range(0,1) var windup_clip := 1`: `windup()` usa `shoot_animations[windup_clip]`.
- `@export var pays_upfront := false`.
- `ActiveAbility._cost() = float(mana_cost)`, en lugar de `max(1)`. Un costo 0 no gasta nada. **R1:** correr los digests antes y después; si cambian, parar.
- `_spend` se divide en `_pay` y `_start_cooldown`.
  - Con `pays_upfront`, `_begin_windup` cobra el maná.
  - `_finish_windup` hace solo `fire()` y `_start_cooldown(false)`.
  - Log: `habilidad X enfriamiento N ticks`.

## MeleeAttack
- `signal connected(target, was_frozen)`. `was_frozen` se lee antes del daño. La señal se emite al final, aunque el monto sea ≤ 0: el daño y `struck` quedan envueltos en `if amount > 0`.
- `roll_damage`: `resistance = max(0, res·DevourGrowth.resistance_factor_of(target) + poison_bonus)`.

## Afflictions
- `Affliction.inflict(spell, from_slot) -> bool` virtual; devuelve `false` por defecto.
- `Frozen.inflict` → `try_freeze_with_cooldown`. Log `congelar X enfriamiento C tirada R congela|rechaza`, con una sola tirada. `_f32` → `SacFloat.f32`.
- `AfflictionType`: `pins` y `blocks_regeneration`.
- `Afflictions`:
  - `fixed()` = `immobilized()` o `pins()`;
  - `pins()`;
  - `blocks_regeneration()`;
  - socket opcional `life_shield`: `cc_protected()` da true con el escudo encendido, chequeado antes del `shown == 0`.
- `BodyNudge.fixed`, más `unit_body` y `wizard_body`, pasan a usar `fixed()`. Neto 0 líneas.
- `Health.regenerate` corta si `blocks_regeneration()`.
- `vined.tres`: bit 8, `coexists`, `holds = false`, `cc_protects`, `pins`, `blocks_regeneration`.
- **R2:** puede cambiar `f149` y `f128`; si cambian, parar.

## Banco
- `BenchEvent.target_soul`: si es true, `foe = Soul.on_corpse(foe)`.

## Logs que esperan las réplicas
Todos detrás de switches apagados.
- `devora Netherfiend1 alma Trogg1 n 1 vida 900->1400 máx 1800->2300 incremento 575.000 regeneración +9.583/s resistencia 0.9000 (tick N)`
- `alma X devorando|devorada|reventada`, `cadáver X disuelto`
- `cura X +4.000 vida V` (`HealEffect`)
- `congelar …`
- `enredado J durante 429 (n 1)` y `enredado fin J (n 0)`
- `sacudida X (tick N)` (`QuakeAbility`)
- `habilidad Quake enfriamiento 600 ticks`
- `vigila …`: lo imprime el watcher de `pt159`.

## Notas
- **J4 en Rend:** el plan dice 271, pero la cuenta da ≈ 408, porque el centro está a 35 m menos la media caja. La réplica usa la `d` del log.
- **Quake:** en float32 el cuadro 6 da exactamente 10,0, que no es < 10; por eso solo aturden los cuadros 1–5 y hace falta `SacFloat`. El tick de Q1 (T+195) lo fija la regla de caja `onda + 0,1`.
