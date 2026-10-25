# 055c1 + 055i-b — `CreatureType` limpio, clips en la `AnimationLibrary` del modelo e identidad por recursos en unidades, IA y audio (plan del tech lead, pendiente de aprobación)

> **Aprobado por el usuario (2026-10-25)** con todas las recomendaciones: la biblioteca de clips es del modelo; extracción única con el migrador (`new_creature --sync` para los propios); el dedicado carga las bibliotecas con tope de +1 s y +100 MB; los `.res` van a git normal si pesan ≤40 MB, si no a LFS; la escena por criatura va en 055s; se borra `CreatureType.god`; las milésimas pasan a escala 1,0 (si un digest cambia, `_permille`); regla C18c; las 7 pasivas y nubes se renombran ahora; el mago toma su tipo del pick; `testmonster.tres` conserva el nombre; las pistas de `Events` van dentro de cada animación si c1-0 lo confirma. Los cortes se implementan sin Godot y se prueban al final; c1-0 (mediciones) lo corre el orquestador.

> **Resultados de c1-0 (2026-10-25, medidos por el orquestador con `debug/creatures/c1_0/`):**
> - Peso de los `.res` de los 74 modelos: 34,7 MB crudos (17 MB comprimidos) → **git normal** (límite 40 MB).
> - Carga de todas las bibliotecas estimada en **~770 ms y ~46 MB** (tope +1 s / +100 MB) → OK.
> - El `AnimationTree` dispara **13/13 marcadores** y **14/14 pistas de método** en el cuadro exacto, también con el crossfade de 0,15 s; el roundtrip del `.res` conserva marcadores y largo en cuadros enteros → **`Events` va dentro de cada animación** (pregunta 12: sí).
> - La variante sin custom timeline (`oneshot_none`) vuelve sola a idle en los roles de un golpe (19/19); `plain`/`timeline` no (0/19).
> - Import nativo del `.glb`: guarda un `.res` por rol con nombre (sí), pero **pierde claves** (403 de 480) y no trae marcadores → se usa la **extracción única con el migrador** (pregunta 2), no el import nativo.

Fuente: RFC-055 §13.2 (fila `CreatureType`, «Herramientas de bake»), §13.2b filas **C-1**, **C-2** y **C-8e**, §15 («055c1: `ClipTiming` pasa a marcadores `hit`…»); auditoría `rfcs/research/055R-legacy-audit.md` §3.1, §3.2 y fila «Animación» de §3.8; planes ya hechos `055i-a-identity-plan.md` (identidad en UI, lobby y flujo) y `055o-audio-plan.md` (055o-b: `CreatureType.sounds`/`WizardType.sounds` tipados). Medido en `main` = `ec85bccd` y revisado en `11d8da46` (2026-10-25), rutas relativas a `game/`. En `11d8da46` ya están mergeados 055h-4 (`1930942c`) y 055o-d: los conteos del alcance son los mismos (solo C9 bajó a 319). No hay código escrito; no se corrió Godot.

**Contradicciones entre artefactos (gana lo que se cita):**
- **¿La escena por criatura entra acá?** RFC-055 §15 dice «055c1 + escena por criatura → 055s» y que 055c pide «una escena heredada por criatura, obligatoria» (`trogg.tscn` hereda `unit.tscn`). El pedido de este corte no la nombra, y la auditoría la pone en `CreatureType.body: PackedScene (055c)`. El cuerpo como escena es justo lo que hace 055s (sockets, colisión, modelo instanciado). Gana el RFC si el usuario no dice otra cosa, pero recomiendo moverla a 055s para no hacer dos veces el cuerpo (pregunta 5). Este plan **no** la incluye y deja `model: String` hasta 055s, igual que 055i-a dejó `model` en el pick.
- **El audio de 055i-b ya está hecho.** C-8d pone `CreatureType.sounds` en 055i-b; 055o-b (`95fe07f8`, `f6561de6`) ya lo cerró. En `scenes/audio/` C18 = 0 y C18b = 0. Acá solo se cambia `WizardSounds` para que lea el tipo tipado del mago (una línea) y se confirma con la sonda `SOUND REFS`.
- **055u dejó las unidades de `CreatureType`/`WizardType` a 055c1** (`055u-time-units-plan.md` líneas 123, 127 y 129). Entran como sub-corte c1-d.
- **055h-4 ya no es un corte en paralelo:** mergeó mientras se escribía este plan. Por eso las 4 búsquedas de órdenes y UI que dependían de él (`ability_command.gd`, `selection_roster.gd`) entran en c1-b.

---

## 1. Objetivo (criterios del RFC, sin extras)
- `CreatureType` y `WizardType` sin `Dictionary` ni `Array[Dictionary]` (C8 −17: 24 → **7**, quedan los de `SpellType`/`AbilityType`, que son 055e). Los clips viven en **una** `AnimationLibrary` por modelo, con nombres de rol (`idle`, `run`, `attack`…), la duración exacta del clip y marcadores `hit`/`shoot` en la línea de tiempo. Se borran los duplicados `BodyModel.clips.frames/framerate` y `CreatureType.*_animations`.
- Habilidades y pasivas como **referencias tipadas**: `ranged_attack`, `active_ability`, `on_damage: AbilityType` y `passives: Array[CreaturePassive]`. Ningún `*_tag: String` de contenido en `scenes/units`, `scenes/ai` ni `scenes/wizards`.
- Unidades, IA y audio **no buscan por tag** (C18 en esas carpetas, en sus vecinos directos y en órdenes y UI −39: 74 → **≤ 35**; C18b 7 → **6**). El tag queda solo como id de red/snapshot, derivado y de solo lectura, y lo convierten los spawners, `scenes/net/` y `scenes/core/catalog/`.
- Los 72 `.tres` de `data/catalog/creatures/` con nombre humano, los mismos que ya tienen los sets de audio (`trogg.tres`, `phoenix.tres`…). `bake_catalog` y `bake_body_scenes` quedan congelados.
- **La simulación no cambia**: los 28 digests de `agent/run_determinism.sh quick` son idénticos a `agent/det_baseline.txt`. **El cable no cambia**: diff vacío de las líneas de pick y resultado de `run_034m.sh`/`run_049e.sh`, y `replication_config` sin cambios.

## 2. Escena de prueba
**No hay escena debug nueva** (como 061a y 055i-a: el usuario va a borrar `debug/`). El criterio empieza en escenas que ya existen:
- **Editor (F6):** `scenes/bodies/models/eorc.tscn` (trogg). Hoy el nodo `Tree` tiene un estado por rol que reproduce el clip `HUa1`, el golpe vive en `Events` y en `CreatureType.melee_animations[0].attack_ticks`. Con el corte: estado `attack` → animación `attack` de `eorc_clips.tres` con un marcador `hit` en 0,5 s; `preview_role = attack` lo muestra. Lo que **no** está todavía (resultado del criterio): el marcador `hit` y la biblioteca de rol.
- **Editor (inspector):** `data/catalog/creatures/trogg.tres` (hoy `ycro.tres`): grupos `Abilities` y `Clips` con recursos arrastrables; `tag = ycro` de solo lectura.
- **Headless, ya existentes:** `rules_suite` (+ caso nuevo `clip_facts_cases`, §12), `debug/suite/catalog_cases.gd`, `debug/units/custom_creature.tscn`, `debug/net/late_join.tscn`, `agent/run_determinism.sh quick`, `agent/runs/run_034m.sh`, `agent/runs/run_049e.sh`, `agent/runs/run_audio_cases.sh`.
- **Captura (sin playtest humano: el cambio no es visible):** `agent/harness/` con cámara fija sobre los 74 modelos posados en un rol y un tiempo dados (ver §12).
- Acciones del InputMap: ninguna. Es datos y editor; la partida se prueba con el banco y con las corridas de red.

---

## 3. Inventario

### 3.1 Conteos del lint en `ec85bccd` (iguales en `11d8da46` salvo C9)
| Regla | Hoy | Dónde, en el alcance |
|---|---|---|
| C8 crudos en `*_type.gd` | **24** | `creature_type.gd` 11 (44–84), `wizard_type.gd` 6 (19–38); los 7 restantes son `SpellType`/`AbilityType` (055e) |
| C18 contenido por tag | **74** | units 24 (de ellas 6 son `BodyCatalog.info`, 055s), ai 9, wizards 4, components 1, souls 1, sacrifice 2 (1 es `BodyCatalog`), map 1 (+11 de mapa, no son de este corte), orders 3, ui 1, spells 7 |
| C18b búsqueda por id | **7** | `scenes/ai/data/ai_profile.gd:125` (el resto es bioma y `caster`, fuera de alcance) |
| C9 doc que abre citando al original | **320** (319 en `11d8da46`) | units 115, ai 33, bodies 9, wizards 2 |
| C13 lecturas del original | **9** | ninguna en el alcance (no puede subir) |
| C22 tiempo en ticks/cuadros | **6** | `wizard_type.gd:26-28` (3) |
| C1a / C1b | 102 / 22 | `unit_body.gd` 783, `wizard_body.gd` 549, `ai_perception.gd` 700, `ranged_attack.gd` 338, `doctor_body.gd` 418, `ai_audit.gd` 476 (se tocan, no se parten acá: 055c) |
| C11 herencia ≥ 2 | 5 | — (no puede subir: `CreaturePassive` es profundidad 1) |

### 3.2 `CreatureType` (47 `@export`, `scenes/units/creature_type.gd`, 116 líneas)
| Campo | Lo leen en `scenes/` | Qué pasa |
|---|---|---|
| `tag` | spawners, `GameData`, cable | **queda** como id de red, de solo lectura en el inspector; + `id()` (vacío = nombre del archivo, como `WizardType.id()`) |
| `display_name`, `icon`, `sounds`, `carried_fx` | UI, `UnitSpawner` (`label` del paquete), `UnitSounds`, `CreatureFx:58` | quedan |
| `god: String` | `spells/caster.gd:411` (partícula de lanzamiento) | **se borra**. Tiparlo como `GodType` arma un ciclo `GodType → GodBook → CreatureType → GodType` que Godot no carga bien. Una criatura solo se invoca desde el libro del dios del mago, así que `caster` usa el dios del mago (riesgo 9) |
| `model: String` | `unit_body.gd:499`, `npc_spawn.gd:75`, `BodyCatalog` | **queda hasta 055s** (cuerpo como escena) |
| `health`, `regeneration_per_s`, `regenerates_always`, `mana`, `melee_strength`, 5 resistencias, `mana_cost`, `souls`, `cooldown_s`, `casting_time_s` | `unit_body._init_stats`, `health.gd:192` (`"%s_resistance" % kind`), invocación | quedan (las resistencias conservan el nombre, porque `Health` arma la propiedad por texto) |
| `drain` | `ai_rater.gd:54` | queda; el doc dice qué es, sin citar CRE8 |
| `running_speed`, `flying_speed`, `sight_range` | `unit_body.gd:494`, `flight.gd:82`, `ai_rater.gd:53`, visión | c1-d: `run_speed_m_s`, `fly_speed_m_s`, `sight_m` (mismo patrón que `speed_m_s` de 055u) |
| `melee_accuracy`, `melee_evasion`, `ranged_accuracy`, `aggressiveness` (milésimas: 1000 = normal) | `melee_attack.gd:168`, `unit_body.gd:282,681`, `doctor_body.gd:277`, `ranged_attack.gd:254`, `lob_ability.gd:116`, `target_rules.gd:43`, `focus_task.gd:145`, `ai_rater.gd:52-55` | c1-d: escala 1,0 = normal (`@export_range(0, 5)`), pregunta 7 |
| `spell_order` | `cast_time.gd:39` y `spellbook.gd:210` (comparten forma con `SpellType`) | **queda hasta 055e** (se cambia junto con `SpellType`) |
| `ability_tags: PackedStringArray` | `ai_perception.gd:225,245,301,315`, `unit_mana_support.gd:21` | **se borra**. Verificado en los 72 `.tres`: es exactamente `[ranged, active, on_damage]` sin vacíos, en ese orden (0 discrepancias). Pasa a `abilities()` derivado |
| `is_ranged` | `ranged_attack.gd:69`, `kill_estimate.gd:39,77` | **se borra** → `is_ranged()` = `ranged_attack != null` (verificado: 35 a distancia, 0 inconsistencias con el tag) |
| `ranged_attack_tag` | `target_picker.gd:183,201,204`, `wounded_ally_policy.gd:23`, `ranged_attack.gd:69`, `kill_estimate.gd:39-41,54,77,133` | → `ranged_attack: AbilityType` |
| `active_ability_tag` | `active_ability.gd:51`, `orders/selection.gd:76-77`, `orders/command/ability_command.gd:90` | → `active_ability: AbilityType` (en `orders/`, una línea cada uno) |
| `passive_on_damage` | `fire_shield.gd:156`, `lightning_charge.gd:212`, `damage_passive.gd:58,65` | → `on_damage: AbilityType` |
| `passive_abilities` (abilities `goc@`, `cen@`, `tum@` y spells `eniv`, `zerf`) | `death_cloud_spawner.gd:48`, `melee_on_hit.gd:34` | → `passives: Array[CreaturePassive]` (las nubes y los golpes con efecto son recursos que la criatura lista) |
| 11 diccionarios de clips (`stance/idle/run/walk_animation`, `melee/shoot_animations`, `extra/flight/stun/death/captive_animations`) | ver §3.4 | → `clips: AnimationLibrary` (la del modelo) |

Funciones: `is_flying()` queda; `is_hybrid_flier()` pasa a leer `clips.has_animation(&"fly")`; `takeoff_time_s()`/`land_time_s()` pasan a `ClipFacts`; `level()` queda (lee `spell_order`); `icon_of()` queda.

### 3.3 `WizardType` (25 `@export`, `scenes/wizards/wizard_type.gd`)
| Campo | Lectores | Qué pasa |
|---|---|---|
| `tag`, `display_name`, `offered`, `sounds`, `model` | flujo, cable, pick | quedan (`model` hasta 055s) |
| `spell_tag` (el tag del WAD al revés) | **ninguno** en `scenes/` | se borra |
| `stance/idle/run/walk_animation`, `stun_animations`, `cast_animations` (6 `Dictionary`) | `stunned.gd:130-151` (stun), `tools/bake/bake_body_scenes.gd` (el `Tree`) | → `clips: AnimationLibrary` del modelo del mago |
| `death_frames` (3), `corpse_rise_frames`, `float_to_stance_frames` (C22) | `ghost_form.gd:184,204,222-224,267,276` | → roles `death`, `death2`, `death3`, `ghost_rise`, `unghost` de la misma biblioteca. `ghost_form` sortea entre las muertes con su RNG: el número de roles de muerte tiene que ser igual al tamaño de `death_frames`, para que la cantidad de tiradas no cambie |
| `running_speed`, `melee_evasion`, resistencias… | `wizard_body`, `melee_attack.gd:209` | c1-d, como en `CreatureType` |

### 3.4 Los clips: tres copias del mismo dato
- **Hoy hay tres fuentes para «qué clip hace el ataque y cuándo pega»:**
  1. el estado `attack` del `Tree` de `scenes/bodies/models/<modelo>.tscn` (`animation = &"HUa1"`, `timeline_length = 0.8`);
  2. `BodyModel.clips["HUa1"] = {frames, framerate, hands}`;
  3. `CreatureType.melee_animations[0] = {tag, frames, framerate, attack_ticks}`.

  Además, el «golpe visual» vive en `Events` (pista de método `fire("attack")` a 0,5 s), que es el mismo cuadro 15 que `attack_ticks`. `new_creature.gd --sync` existe solo para volver a copiar 1 en 3.
- **Medido** (script en el scratchpad que compara los 72 `.tres` con los 74 modelos):
  - 852 roles en los diccionarios. 0 con otro clip que el modelo y 1 con otra duración (`sacd` `idle`: 0,367 s en el tipo, 0,033 s en el modelo, porque el doctor «posa» un cuadro).
  - 38 roles que el modelo no tiene: 31 `gesture` (el `idle0`), 6 `pull`, 2 `attack2/3` del doctor y `Spa3`.
  - **11 criaturas sin escena de modelo**, porque su `.glb` trae un solo clip de relleno y se dibujan quietas: `the2`, `ban2`, `faez`, `thes`, `gamm`, `hoom`, `sara`, `bane`, `baby`, `sirc`, `surt`. Su sim lee los tiempos del diccionario.
  - Dos modelos compartidos: `peas` (campesino y fantasma, con mapeos distintos) y `FAmr` (familiar y zyzyx, iguales).
- **Lectores de la simulación** (cambian el resultado del banco):

| Archivo:línea | Qué lee | Rol nuevo |
|---|---|---|
| `units/attacks/melee_attack.gd:39,254-256` | `melee_animations[i]` (frames, `attack_ticks`), respaldo `HUa1` 24/15 | `attack`, `attack2`, `attack3` + marcadores `hit` |
| `units/attacks/ranged_attack.gd:171-176` | `shoot_animations[0]` (`shoot_ticks`) | `shoot` + marcadores `shoot` |
| `units/abilities/ability_effect.gd:49-58` | `shoot_animations[windup_clip]` | `shoot`, `shoot2` |
| `units/abilities/pull.gd:106-108` | `shoot_animations[clip_index].frames` | ídem |
| `units/afflictions/stunned.gd:130-142` | `stun_animations` (knock, get_up, fly_damage, hit_floor), `flight.fly`, `idle_animation` | `knock`, `get_up`, `fly_damage`, `hit_floor`, `fly`, `gesture` |
| `sacrifice/doctor_body.gd:72-77,244` | slots de `melee_animations`, `stun.hit_floor` | `attack/attack2/attack3`, `hit_floor` |
| `units/movement/flight.gd:61,82,136,160`, `afflictions/tumbling.gd:192` | `takeoff_time_s`, `land_time_s`, `is_hybrid_flier` | `takeoff`, `land`, `fly` |
| `ai/tasks/kill_estimate.gd:45,65-70` | `melee_animations` (promedio), `shoot_animations[0]` | ídem |
| `wizards/ghost_form.gd:184-276` | `death_frames`, `corpse_rise_frames`, `float_to_stance_frames` | `death*`, `ghost_rise`, `unghost` |

- **Lectores de presentación:** `BodyRig.role_frames/role_framerate/impact_frame` (`body_rig.gd:69-89`) y `BodyModel.frames_of/framerate_of/impact_frame` (`body_model.gd:150-171`) sobre `BodyModel.clips` y `Events`; `UnitClips.info()`.
- **Herramientas:** `bake_body_scenes.gd` (424 líneas, arma los `Tree` desde los diccionarios), `catalog_builder.gd` (los escribe), `new_creature.gd` (718 líneas, `SETS`, `--sync`), `creature_icon.gd:37`, `audit_skeletal_center.gd`. Debug: `anim_expect.gd`, `custom_creature.gd`, `catalog_cases.gd:262-300`.

**Tabla de traducción diccionario → rol** (la usa el migrador; los nombres de la derecha ya son los de `BodyModel.ROLES`, más 7 nuevos marcados con +):

| Hoy | Rol |
|---|---|
| `stance_animation` (stance1) | `idle` |
| `idle_animation` (idle0) | `gesture` |
| `run_animation` / `walk_animation` | `run` / `walk` (+; solo si difiere de `run`) |
| `melee_animations[0..2]` + `attack_ticks` | `attack`, `attack2`, `attack3` + marcadores `hit`, `hit2`… |
| `shoot_animations[0..1]` + `shoot_ticks` | `shoot`, `shoot2` (+) + marcadores `shoot`, `shoot2`… |
| `extra_animations` | `cower`, `talk_cower`, `work`, `pull` (+) |
| `flight_animations` | `takeoff`, `fly`, `land`, `hover` |
| `stun_animations` | `knock`, `get_up`, `fly_damage`, `hit_floor` |
| `death_animations` | `death`, `fly_death` |
| `captive_animations` | `rise`, `held`, `thrash` |
| mago `cast_animations` | `cast`, `cast_run` |
| mago `death_frames[0..2]`, `corpse_rise_frames`, `float_to_stance_frames` | `death`, `death2` (+), `death3` (+), `ghost_rise` (+), `unghost` (+) |

### 3.5 Búsquedas por tag que se van (archivo:línea)
- **Unidades (18):** `abilities/active_ability.gd:51` · `breath_of_life.gd:43` · `call_lightning.gd:27` · `devour.gd:63` · `divine_sight_eye.gd:80` · `halo_of_earth.gd:116` · `protector.gd:45` · `attacks/freeze_touch.gd:44` · `melee_attack.gd:207` · `melee_on_hit.gd:43` · `ranged_attack.gd:69` · `ranged_shot.gd:56` · `passives/fire_shield.gd:74,150` · `lightning_charge.gd:138` · `strikes/shot_strike.gd:63` · `targeting/wounded_ally_policy.gd:23` · `unit_body.gd:492`.
- **IA (9):** `ai_audit.gd:285` · `perception/ai_perception.gd:228,303,312,317` · `tasks/kill_estimate.gd:40,54,100,133`.
- **Magos (4):** `ghost_form.gd:232` · `wizard_body.gd:160` (dios), `:199`, `:443`. La línea 443 hace la búsqueda **en cada cuadro** de física, para la regeneración.
- **Vecinos que leen lo mismo (4):** `components/health.gd:189` · `sacrifice/doctor_body.gd:129` · `souls/soul_system.gd:221` · `map/map_population.gd:74`.
- **Órdenes y UI (4, con 055h-4 ya cerrado):** `orders/command/ability_command.gd:31,62,83` · `ui/selection_roster/selection_roster.gd:169`. La orden y el plantel reciben la habilidad de `type.active_ability`. La RPC sigue mandando el mismo tag (`.tag` del recurso).
- **C18b (1):** `ai/data/ai_profile.gd:125` (`for_god` por id; desde 055i-a `ai_side` usa `for_type`, así que queda sin llamadores: se borra).
- **Se quedan, con dueño:**
  - `BodyCatalog.info/pose` ×8 (`unit_body.gd:280,526`, `captive.gd:273`, `body_collider.gd:48`, `melee_attack.gd:200`, `unit_orders.gd:254`, `doctor_body.gd:275`, `orders.gd:309`): **055s**.
  - `spellbook.gd:202`: 055e.
  - Los 11 de mapa (`MapCatalog.active`, `SideRelations`): 063.
- **`@export` de texto en lugar del recurso (19):** `creature_type` `ranged_attack_tag`, `active_ability_tag`, `passive_on_damage`, `ability_tags`, `passive_abilities` · `wizard_type.spell_tag` · `damage_passive_type.tag` · `on_hit_passive_type.tag` · `death_cloud_type.tag` · `target_policy.tag` · `fire_shield.passive_tag` y `.spell` · `lightning_charge.tag` · `unit_mana_support.source_ability_tag` · `protector.shield_tag` · `call_lightning.spell_tag` · `breath_of_life.spell_tag` · `devour.heal_spell` · `halo_of_earth.spell_tag` · `freeze_touch.freeze_spell`. Quedan, porque son FX por texto (055x): `look_tag`, `rock_tag`, `texture_tag`, `shot_tag`.
- **Tablas por tag en código:**
  - Se van: `melee_attack.gd:37 WIDTH_SCALE {"nmuh": 1.3}` → `CreatureType.melee_width_scale`; `peasant_behavior.gd:15 TAGS` (5 campesinos) → `CreatureType.peasant`.
  - Quedan: `ranged_attack.gd:28 FALLING_ACCELERATION {"dkba"}` (es de la habilidad: 055c3/055e) y `melee_attack.gd:39 FALLBACK_ANIMATION` (pasa a un `ClipFacts` de respaldo con nombre, sin tag).
- **Comparaciones por tag entre cuerpos:** `orders/selection.gd:330,344` y `ai/command/ai_command_port.gd:216` comparan `creature_tag` (mismo tipo de criatura). Quedan, porque comparar ids es la frontera de órdenes y es correcto.
- **Lo que resuelve por nombre de archivo (se rompe al renombrar):**
  - `core/catalog/type_ref.gd:23-38` (`creatures/<tag>.tres` primero);
  - `tools/bake/creature_icon.gd:36`, `creature_icon_render.gd:51`, `new_creature.gd:191,562-617,684`;
  - `tools/import/scaffold_map.py:410`;
  - `tools/migrate/migrate_055o_bodies.*` (de una sola vez: se borra);
  - `debug/suite/catalog_cases.gd` (regla «archivo = tag»).

### 3.6 Lo calcado 1 a 1 del original que este corte borra
- Los 11 + 6 diccionarios de clips con la estructura de los slots SXSK/CRE8 (`{tag, frames, framerate, attack_ticks}` a 30 fps) y su tercera copia en `BodyModel.clips`.
- Los slots de habilidad del CRE8 repetidos dos veces (`ability_tags` y los tres `*_tag`) y `passive_abilities` (bytes 440/452 del CRE8) como texto.
- `is_ranged` («nttData `ranged`»), duplicado del slot de ataque a distancia.
- `CreatureType.god = "none"` y `WizardType.spell_tag` (el tag del WAD al revés).
- `death_frames`/`corpse_rise_frames`/`float_to_stance_frames` como cuadros de 30 fps sueltos.
- Los `.tres` con nombre de WAD (`EHTH_2.tres`, `ycro.tres`) y `TypeRef` resolviendo por nombre de archivo.
- Tablas por tag en código (`WIDTH_SCALE`, `PeasantBehavior.TAGS`).
- La conversión tag → recurso repetida en 40 lugares de unidades, IA, magos, órdenes y UI (y una por cuadro en `wizard_body.gd:443`).
- **Razonable, se mantiene:**
  - el tag como id compacto en la red;
  - `spell_order` hasta 055e;
  - los slots «a distancia / activa / al recibir daño» como tres campos con nombre, porque es el diseño del juego;
  - el `AnimationTree` con un estado por rol, que ya es nativo.

---

## 4. Diseño

### 4.1 Una biblioteca de clips por modelo (dueño: la `AnimationLibrary`)
- **`scenes/bodies/models/<modelo>_clips.tres`** (`AnimationLibrary`): `rol → Animation`. Cada `Animation` es un `.res` en `scenes/bodies/models/<modelo>_clips/<clip>.res`, con:
  - las pistas de huesos del `.glb`;
  - `length = frames / framerate` **exacto**, el mismo que hoy usa el `Tree` en `timeline_length`;
  - `step = 1 / framerate`;
  - marcadores `hit`, `hit2`… y `shoot`… en el tiempo `tick / framerate`;
  - la pista de método a `ClipEvents.fire(kind)` que hoy vive en `Events` (sonido, pie, lanzamiento…).
- **La escena del modelo la reproduce** con un `AnimationPlayer` propio (`Clips`). El `Tree` pasa a apuntar a `Clips` y cada estado reproduce `&"attack"`, no `&"HUa1"`. Se borran `Events` y `BodyModel.clips.frames/framerate`; `hands` queda hasta 055s.
- **`CreatureType.clips` y `WizardType.clips` apuntan al mismo archivo.** El servidor dedicado no carga mallas (`BodyCatalog.loads_meshes()`), pero sí carga la biblioteca: así la sim y el dibujo leen **una sola fuente**. `catalog_cases` falla si `type.clips` no es la biblioteca de `models/<type.model>.tscn` (dos referencias a un archivo, validadas; ningún dato copiado).
- **Casos especiales:**
  - Las 11 criaturas sin escena de modelo tienen igual su `<modelo>_clips.tres`. Sus `Animation` no traen pistas, solo la duración y los marcadores: es su tiempo.
  - Si el fantasma necesita roles distintos del campesino en algo que la sim lee, tiene su propia `peas_ghost_clips.tres` sobre los mismos `.res`. Lo decide la sonda de paridad (§12). Hoy el dibujo del fantasma ya usa el mapeo del campesino; eso no cambia.
- **`ClipFacts`** (`RefCounted`, `scenes/bodies/clip_facts.gd`): lo que leen las reglas, calculado **una vez por biblioteca**, con un caché estático `Dictionary[AnimationLibrary, ClipFacts]`.
  - API: `frames(role) -> int` = `roundi(length * fps)`, `fps(role)`, `seconds(role)`, `hits(role) -> PackedInt32Array`, `shots(role)`, `has(role)`.
  - Cada cuerpo lo guarda en `_ready` (`UnitBody.clip_facts`, `WizardBody.clip_facts`, `DoctorBody`).
  - Nada lo pide por cuadro con `load()` ni `find()`. `roundi` devuelve los mismos enteros de hoy porque todos los tiempos son múltiplos de 1/30.

### 4.2 Habilidades y pasivas por referencia
- `CreatureType`:
  - `ranged_attack: AbilityType`, `active_ability: AbilityType`, `on_damage: AbilityType`;
  - `passives: Array[CreaturePassive]`;
  - `abilities() -> Array[AbilityType]` (los tres no nulos, en el orden de hoy, para la IA);
  - `is_ranged()`;
  - `melee_width_scale := 1.0`;
  - `peasant := false`.
- **`CreaturePassive`** (`Resource`, ≤ 15 líneas, base común para tipar la lista): `DeathCloudType` y `OnHitPassiveType` pasan a extenderla, con profundidad 1 (C11).
  - `DeathCloudType.ability: AbilityType` reemplaza `tag` (los números de la nube).
  - `OnHitPassiveType.spell: SpellType` reemplaza `tag`.
  - `DeathCloudSpawner` y `MeleeOnHit` recorren `body.type.passives` filtrando por su clase, y se borran sus listas `types` en `unit.tscn`. «Una nube nueva» es un `.tres` arrastrado a la criatura.
- **Componentes con su propia regla, comparando referencias** (no tags):
  - `DamagePassiveType.ability`, `TargetPolicy.attack`, `FireShield.passive`/`fire`, `LightningCharge.passive`;
  - `UnitManaSupport.source`, `Protector.shield`, `CallLightning.spell`, `BreathOfLife.spell`, `HaloOfEarth.spell`, `Devour.heal`, `FreezeTouch.freeze`.

  Todos son `@export` tipados con warning si faltan. Comparan `==` contra `body.type.on_damage` / `ranged_attack`.

### 4.3 El cuerpo recibe su tipo; no lo busca
- **`UnitSpawner._make`** (spawner, permitido por C18) hace `unit.type = <tipo del tag del paquete>` **antes** de `add_child`, en cada par. `spawn_function` corre igual en el servidor, en los clientes y en el late join. `UnitBody`:
  - tiene `@export var type: CreatureType`;
  - deriva `creature_tag` de `type.id()` (sigue en el `MultiplayerSynchronizer`, mismos bytes);
  - deja de llamar a `GameData`.

  Lo mismo hacen `ShotSpawner._make` (`setup(data, ability)`), el doctor (`@export var type` en su escena) y `map_population` (usa `spawn.creature`, que `NpcSpawn` ya tiene tipado).
- **`WizardBody.wizard_type: WizardType`** (no `type`: varios lectores toman `"type" in body` por «es una criatura», `stunned.gd:146-151`).
  - Sale del `WizardPick` del slot, que en cada par ya está tipado por `MatchWire.decode_pick`. Hay un valor por defecto en `wizard_body.tscn` para bancos sin flujo.
  - `wizard_tag/model/god` siguen siendo el cable (055i-a), escritos desde el pick.
  - `god_type()` devuelve `pick.god`.
  - `Health`, `KillEstimate`, `MeleeAttack`, `GhostForm` y `WizardSounds` leen `wizard_type` (o `clip_facts`), nunca `GameData.wizard(wizard_tag)`.
- **`SoulSystem`**: usa el `unit` que ya liga en `_on_unit_died` (`unit.type.souls`). No se cambia la firma de `UnitBody.died`.

### 4.4 Qué es Resource de tipo, qué es nodo, qué es `@export` de instancia
| Cosa | Forma | Dónde |
|---|---|---|
| Una criatura, un mago | Resource de tipo (ya existen) | `data/catalog/creatures/<nombre>.tres`, `data/catalog/wizards/<nombre>.tres` |
| Los clips de un modelo | `AnimationLibrary` + un `Animation` `.res` por clip (con marcadores y pistas de método) | `scenes/bodies/models/<modelo>_clips.tres` y `<modelo>_clips/` |
| Una pasiva (nube, golpe con efecto) | `CreaturePassive` `.tres` | `data/death_clouds/`, `data/passives/` (ya existen) |
| Una habilidad | `AbilityType` (sin cambios: 055e) | `data/catalog/abilities/` |
| Lo que leen las reglas de los clips | `ClipFacts` (derivado, en memoria; no es un archivo) | `scenes/bodies/clip_facts.gd` |
| Qué tipo es este cuerpo | `@export var type` (criatura, doctor), `wizard_type` (mago) | nodo raíz del cuerpo; lo escribe el spawner o el pick |
| Qué hechizo usa un componente | `@export` tipado en el nodo del `.tscn` | `unit.tscn`, escenas de habilidades |

---

## 5. Árbol de archivos
```
scenes/units/
  [~] README.md                          5 líneas; Edit: data/catalog/creatures/<nombre>.tres; los clips en models/<modelo>_clips.tres
  [~] creature_type.gd                   ≤ 120: grupos Body/Combat/Abilities/Summon/Identity; clips: AnimationLibrary; ranged_attack,
                                         active_ability, on_damage: AbilityType; passives: Array[CreaturePassive]; melee_width_scale; peasant;
                                         id(), is_ranged(), abilities(); [-] god, ability_tags, is_ranged (campo), *_tag, 11 Dictionary
  [~] unit_body.gd                       @export var type; creature_tag derivado; clip_facts en _ready; [-] _apply_type por GameData (líneas 491-499)
  [~] unit_spawner.gd                    _make: unit.type = el tipo del paquete (antes de add_child); peasant por type.peasant
  [~] unit.tscn                          [-] types de DeathCloudSpawner y MeleeOnHit; DamagePassive.types con `ability`; ManaSupport.source;
                                         FireShield/LightningCharge tipados; TargetPicker.policies con `attack`  (replication_config sin tocar)
  [~] peasant_behavior.gd                [-] TAGS, is_peasant_tag
  passives/[+] creature_passive.gd       CreaturePassive (Resource, base común de una pasiva que la criatura lista)
  passives/[~] damage_passive_type.gd, damage_passive.gd, fire_shield.gd, lightning_charge.gd, on_hit_passive_type.gd
  death_clouds/[~] death_cloud_type.gd (extends CreaturePassive; ability), death_cloud_spawner.gd (recorre type.passives)
  attacks/[~] melee_attack.gd (ClipFacts; melee_width_scale; wizard_type), melee_on_hit.gd, ranged_attack.gd, ranged_shot.gd,
              freeze_touch.gd, shot_spawner.gd (resuelve la habilidad del paquete)
  abilities/[~] active_ability.gd, ability_effect.gd, pull.gd, breath_of_life.gd, call_lightning.gd, devour.gd, divine_sight_eye.gd,
               halo_of_earth.gd, protector.gd
  afflictions/[~] stunned.gd (ClipFacts), tumbling.gd · movement/[~] flight.gd · strikes/[~] shot_strike.gd
  targeting/[~] target_policy.gd, target_picker.gd, wounded_ally_policy.gd · [~] unit_mana_support.gd
scenes/bodies/
  [~] README.md                          5 líneas What/Not/Talks to/Edit/Check (hoy no las tiene)
  [+] clip_facts.gd                      ClipFacts (RefCounted ≤ 100): frames/fps/seconds/hits/shots/has por rol; caché por biblioteca
  [~] body_model.gd                      [-] clips.frames/framerate (queda `hands`, 055s), frames_of/framerate_of/impact_frame leen la Animation;
                                         ROLES + walk, shoot2, pull, death2, death3, ghost_rise, unghost; warning si falta Clips o un rol sin hit
  [~] body_rig.gd                        role_frames/impact_frame desde ClipFacts de la biblioteca del modelo
  [~] clip_events.gd                     doc: la pista de método vive en cada Animation de rol
  models/
    [~] <modelo>.tscn ×74                + Clips (AnimationPlayer, root_node = ../Model, biblioteca = <modelo>_clips.tres); Tree.anim_player = ../Clips;
                                         estados por rol con animation = &"<rol>" (sin custom timeline); [-] Events
    [+] <modelo>_clips.tres ×85          AnimationLibrary rol → Animation (74 modelos + 11 sin escena)
    [+] <modelo>_clips/<clip>.res ~900   Animation extraída: pistas, length exacto, marcadores hit/shoot, pista de método a ClipEvents
scenes/wizards/
  [~] README.md                          5 líneas
  [~] wizard_type.gd                     clips: AnimationLibrary; [-] spell_tag, 6 Dictionary, death_frames, corpse_rise_frames, float_to_stance_frames
  [~] wizard_body.gd                     wizard_type desde el pick (y default del .tscn); clip_facts; god_type() = pick.god; [-] GameData (160, 199, 443)
  [~] wizard_body.tscn                   wizard_type = jadugarr.tres (default); wizard_tag queda como propiedad replicada
  [~] ghost_form.gd                      roles death*/ghost_rise/unghost de ClipFacts; [-] GameData.wizard
scenes/ai/
  [~] README.md                          5 líneas
  [~] ai_audit.gd · perception/[~] ai_perception.gd (type.abilities()) · tasks/[~] kill_estimate.gd (ClipFacts, ranged_attack, wizard_type)
  data/[~] ai_profile.gd                 [-] for_god (sin llamadores desde 055i-a)
scenes/audio/[~] wizard_sounds.gd        body.wizard_type (en vez de clip_type()) — 1 línea
scenes/components/[~] health.gd          _base_resistance: type o wizard_type del cuerpo, sin GameData
scenes/sacrifice/[~] doctor_body.gd (@export var type; ClipFacts) · [~] doctor_body.tscn (type = sac_doctor.tres)
scenes/souls/[~] soul_system.gd          unit.type.souls
scenes/map/[~] map_population.gd         spawn.creature (ya tipado en NpcSpawn)
scenes/spells/[~] caster.gd              _cast_god(): el dios del mago (sin CreatureType.god) — 3 líneas
scenes/orders/[~] selection.gd:76-77 · command/[~] ability_command.gd:31,62,83,90   la habilidad sale de type.active_ability; la RPC manda su .tag
scenes/ui/selection_roster/[~] selection_roster.gd:169   la habilidad de la celda sale del tipo de la criatura
scenes/core/catalog/
  [~] game_data.gd                       creatures por id(); doc de book() sin abrir citando
  [~] game_catalog.gd                    + creature(id) indexado (lo usan spawners y TypeRef)
  [~] type_ref.gd                        [-] _from_file (por nombre de archivo); creature(id) = GameCatalog.creature
data/
  catalog/creatures/[~] 72 .tres         renombrados (ycro.tres → trogg.tres; tabla §10); clips = ExtResource; habilidades y pasivas ExtResource;
                                         [-] diccionarios, god, ability_tags, is_ranged, *_tag
  catalog/wizards/[~] 15 .tres           clips = ExtResource; [-] spell_tag, diccionarios, *_frames
  death_clouds/[~] goc, cen, tum .tres   ability = ExtResource; nombres humanos (pregunta 9)
  passives/[~] korq, ahtf, yeti_freeze, dragon_vines .tres   ability/spell = ExtResource
  targeting/[~] slba.tres, rage.tres     attack = ExtResource (si aplica)
  gods/[~] 5 .tres                       solo las rutas de los libros (las reescribe la herramienta)
tools/
  migrate/[+] creature_names_055c1.csv   72 filas viejo,nuevo (salen de CreatureType.sounds; 5 a mano)
  migrate/[+] typed_refs_055c1.gd        una vez: tags → ExtResource en 72 criaturas, pasivas y unit.tscn; creature_tag → type en 25 .tscn de debug
  migrate/[+] extract_clips_055c1.gd     una vez: diccionarios + .glb + Events → <modelo>_clips.tres/.res; reescribe los 74 modelos; informe de paridad
  migrate/[-] migrate_055o_bodies.gd/.py (ya corrió en 055o-b)
  bake/[~] new_creature.gd               escribe <nombre>.tres (tag vacío), <modelo>_clips.tres con roles y marcadores (hit desde _atNN/_fNN),
                                         Clips + Tree por rol; --sync re-extrae los clips del .glb conservando los marcadores; [-] SETS de diccionarios
  bake/[~] bake_body_scenes.gd           congelado: sale con aviso si la escena ya existe (se borra en 055z)
  bake/[~] creature_icon.gd, creature_icon_render.gd   por ruta del tipo (no por tag); clip = rol `gesture`/`idle`
  bake/[~] catalog_builder.gd            ya congelado por bake_catalog: no escribe diccionarios (o se borra con él en 055z)
  import/[~] scaffold_map.py             la criatura del NpcSpawn por tabla tag → archivo del catálogo
  audit/[~] audit_skeletal_center.gd     lee la biblioteca
  lint/[~] conventions.sh                + C18c (texto en lugar de recurso en @export de units/ai/wizards/sacrifice), base propia (pregunta 8)
  lint/[~] baseline.txt                  --update-baseline al cerrar cada sub-corte
debug/
  suite/[+] clip_facts_cases.gd          paridad diccionario ↔ ClipFacts (c1-c1) y forma de las bibliotecas (después); en rules_suite
  suite/[~] catalog_cases.gd             archivo snake_case + id único; type.clips = biblioteca del modelo; cada attack con ≥ 1 hit; referencias tipadas
  net/[+] wire_config_cases.gd           lista ordenada de propiedades replicadas (replication_config) de unit/wizard/shot/doctor: hash igual antes y después
  bodies/[~] anim_expect.gd · units/[~] custom_creature.gd · audio/[~] (fixtures que nombran ycro.tres por ruta: los reescribe la herramienta)
  [~] 25 .tscn con creature_tag = "…"    type = ExtResource (typed_refs_055c1.gd); 5 con wizard_tag → wizard_type
agent/
  harness/[+] clip_shots/                cámara fija: cada modelo posado en (rol, t) → PNG; diff antes/después (§12)
```

### Árbol de nodos

`scenes/bodies/models/eorc.tscn` (igual en los 74):
```
eorc (Node3D, BodyModel)          model = "eorc", aabb_margin, carried_fx_socket, preview_role
├── Model (eorc.glb)              sin cambios (esqueleto, malla, Ragdoll)
│   └── Skeleton3D
│       └── Ragdoll (PhysicalBoneSimulator3D) …
├── Clips (AnimationPlayer)       root_node = ../Model · libraries = { "": eorc_clips.tres }        [+]
│                                 eorc_clips.tres: idle → HUst.res · gesture → HUi1.res · run → HUrn.res
│                                 attack → HUa1.res (0,8 s · ◆hit 0,5 s · fire(sound) 0 s, fire(attack) 0,5 s)
│                                 attack2 → HUa2.res (◆hit 0,467) · attack3 → HUa3.res (◆hit 0,6) · knock, get_up, hit_floor,
│                                 death, rise, held, thrash, shoot/shoot2 (HU00, 1 cuadro)
├── Tree (AnimationTree)          anim_player = ../Clips · un estado por rol: animation = &"attack" …
└── ClipEvents (ClipEvents)       lo llaman las pistas de método de cada Animation de rol
    [-] Events (AnimationPlayer)  sus pistas pasan a las Animation de rol
```

`scenes/units/unit.tscn` (fragmento que cambia) y sus datos:
```
Unit (UnitBody)  type: CreatureType ─► data/catalog/creatures/trogg.tres
│                creature_tag (derivado, replicado)     ├─ clips ─► scenes/bodies/models/eorc_clips.tres
│                                                       ├─ ranged_attack · active_ability · on_damage ─► data/catalog/abilities/…
│                                                       └─ passives [ data/death_clouds/cog_cloud.tres, … ]
├── MeleeAttack            lee body.clip_facts (attack*, hits) y type.melee_width_scale
├── MeleeOnHit             recorre type.passives (OnHitPassiveType)            [-] types
├── DamagePassive          types: [DamagePassiveType{ability = korq}, …] == type.on_damage
├── DeathCloudSpawner      recorre type.passives (DeathCloudType)              [-] types
├── FireShield             passive = rifl.tres · fire = mrff.tres (tipados)
├── LightningCharge        passive = gcil.tres
├── ManaSupport            source = hmba.tres
├── RangedAttack           type.ranged_attack · clip_facts (shoot)
├── ActiveAbility          type.active_ability
├── Afflictions/Stunned    clip_facts (knock, get_up, fly_damage, hit_floor)
└── MultiplayerSynchronizer   sin cambios (creature_tag sigue en properties/3)
```

`data/catalog/creatures/phoenix.tres` en el inspector:
```
Display Name  Phoenix          Icon  grdr.png      Sounds  phoenix.tres      Clips  fdrg_clips.tres
▸ Body        Health 4800 · Regeneration Per S 16.67 · Mana 750
▸ Combat      Melee Strength 1000 · Melee Accuracy 3000 (c1-d: 3.0) · … · Melee Width Scale 1
▸ Abilities   Ranged Attack  rdra.tres · Active Ability  <vacío> · On Damage  rifl.tres · Passives  []
▸ Summon      Mana Cost 1900 · Souls 5 · Cooldown S 10 · Casting Time S 3.33 · Spell Order 986
▸ Identity    Tag  grdr (solo lectura) · Model  fdrg (hasta 055s) · Peasant  off
```

## 6. Mapa de responsabilidades (un dueño por estado)
| Estado | Dueño | Lo leen |
|---|---|---|
| Qué clip hace un rol, cuánto dura y cuándo pega | `<modelo>_clips.tres` (sus `Animation` y marcadores) | `Tree`/`Clips` (dibujo), `ClipFacts` (reglas, servidor incluido) |
| Los números que leen las reglas de esos clips | `ClipFacts` (derivado, idempotente, sin escritura) | ataques, aturdido, vuelo, doctor, fantasma, IA |
| Habilidades y pasivas de una criatura | `CreatureType` (campos tipados) | componentes de `unit.tscn`, IA, órdenes, plantel |
| Qué tipo es un cuerpo | el spawner (`_make`) / el pick (mago) | el cuerpo y sus hijos |
| Id de red de un cuerpo | `type.id()` copiado a `creature_tag` / `wizard_tag` | `MultiplayerSynchronizer`, logs, órdenes |
| Texto ↔ recurso | spawners, `scenes/net/` (`MatchWire`), `scenes/core/catalog/` | — |
| A qué dios pertenece una criatura | `GodType.book` (único) | lobby, IA, `caster` (por el mago) |

## 7. Cómo lo hace un humano
| Verbo | Ejemplo | Qué abre y toca | Lugares |
|---|---|---|---|
| **Entender** | «¿qué habilidades tiene el fénix y cuándo pega el trogg?» | `data/catalog/creatures/phoenix.tres` → grupo `Abilities` (recursos con nombre; clic los abre). Para el trogg: `scenes/bodies/models/eorc.tscn` → `Clips` → animación `attack`, con el marcador `hit` en la línea de tiempo | 1 |
| **Modificar** | «cambiar la animación de ataque de una criatura» | su modelo (`models/<modelo>.tscn`) → `Clips` → Animación ▸ Gestionar animaciones → en `attack`, cargar otro `.res` del `<modelo>_clips/`. La sim y el dibujo cambian juntos | 1 |
| | «que pegue antes» | misma animación → arrastrar el marcador `hit` | 1 |
| | «más vida, más rápida» | `<criatura>.tres` → `Health`, `Run Speed M S` (c1-d) | 1 |
| **Agregar** | «darle una habilidad nueva a una criatura» | `<criatura>.tres` → `Active Ability` (o `Ranged Attack`) → arrastrar `data/catalog/abilities/<x>.tres` | 1 |
| | «darle la nube de muerte del Cog a un trogg» | `trogg.tres` → `Passives` → + → arrastrar `data/death_clouds/cog_cloud.tres` | 1 |
| | «una criatura propia desde Blender» | exportar el `.glb` con acciones con nombre de rol (`idle`, `run`, `attack_f18`…) a `assets/custom/models/`; Project › Tools › Sacrifice › «Nueva criatura desde modelo…» escribe el modelo, `<modelo>_clips.tres` con roles y marcadores, `<nombre>.tres` (tag vacío: el id es el nombre) y su set de sonidos; después se arrastra al libro del dios | 2 (el `.glb` y el libro) |
| **Quitar** | «sacar una criatura del libro de un dios» | `data/gods/<dios>.tres` → `Book` → `Creatures` (y su fila de `unlocks`): quitar. `catalog_cases` avisa la huérfana | 1 |
| | «que el Necryl no deje nube» | `necryl.tres` → `Passives` → quitar la fila | 1 |
| **Crear** | «un trogg de élite» | duplicar `trogg.tres` → `trogg_elite.tres` (vaciar `Tag`: el id es `trogg_elite`), subir stats; comparte `Clips` y sonidos; arrastrarlo al libro | 2 |
| **Escalar** | «100 criaturas, 20 nubes nuevas» | sin registros ni tablas: el catálogo escanea la carpeta, el id sale del archivo, cada pasiva es un `.tres` que se arrastra, las variantes comparten la biblioteca de su modelo, y el servidor lee lo mismo que el dibujo | 1 por pieza, 0 código |

**Se rediseñó porque hoy pedía código o más de dos lugares:**
- Cambiar el clip de ataque hoy son 3 lugares: el estado del `Tree`, `BodyModel.clips` y `CreatureType.melee_animations`, más `new_creature --sync`. El golpe va en 2 más (`attack_ticks` y la clave de `Events`). Con el corte es 1.
- Darle una pasiva hoy es escribir el tag en `passive_abilities` y que su `.tres` esté en `DeathCloudSpawner.types` de `unit.tscn`. Son 2 lugares, y un error de tipeo no da aviso. Con el corte es 1.
- Una criatura propia hoy necesita un tag de 4 letras que se repite en el nombre de 4 archivos. Con el corte, el id es el nombre del archivo.

## 8. Red y snapshot
- **Lo que viaja (sin cambios, byte a byte):**
  - paquete de `UnitSpawner` (`tag, label, slot, x, y, z, yaw, summoning, npc, peasant, name`), con `tag = type.id()` = el mismo `ycro`;
  - `creature_tag` en el `MultiplayerSynchronizer` de `unit.tscn`; `wizard_tag/model/god` en el de `wizard_body.tscn`;
  - paquete de `ShotSpawner` (`tag` de la habilidad);
  - el tag de la habilidad en la orden (`ability_command`);
  - canales `pick`/`slot_picks` (055i-a).

  Nunca viajan rutas, nombres de archivo ni recursos.
- **Late join:**
  - el que entra tarde recibe el replay del `MultiplayerSpawner`; `spawn_function` (`_make`) le pone `type` a cada criatura antes de entrar al árbol, igual que en el servidor;
  - los magos toman `wizard_type` del `slot_picks` decodificado. Si el id replicado llega antes que el pick, el cuerpo usa el default de la escena hasta que `SacrificeFlow.slot_picks_changed` (ya existe) avise el pick, y vuelve a aplicar (riesgo 5);
  - `debug/net/late_join.tscn` tiene que pasar.
- **Cómo se prueba que el cable no cambió** (el método de 055i-a, más una prueba estática):
  1. Antes de tocar código (paso 1 de c1-0, sobre `main` sin el corte), correr `bash agent/runs/run_034m.sh` y `bash agent/runs/run_049e.sh` y guardar en `agent/out/055c1/` las líneas que matchean `slot [0-9]+ pick`, `"picks"`, `ia slot [0-9]+ lista`, `partida terminada` y `dedicado listo puerto`. Al cerrar c1-b y c1-c2, repetir: el **diff tiene que estar vacío**.
  2. `debug/net/wire_config_cases.gd` (headless) imprime `WIRE CONFIG sha256=<…> props=<n>` sobre la lista ordenada `(escena, nodo, propiedad, spawn/sync, watch)` de `replication_config` de `unit.tscn`, `wizard_body.tscn`, `doctor_body.tscn` y las escenas de disparo. Mismo hash antes y después.
  3. Estático: `git diff <base> -- '*.tscn' | grep -E '^[+-](properties/|\[sub_resource type="SceneReplicationConfig")'` vacío, y sin cambios en las funciones que arman paquetes (`spawn_unit`, `spawn_map_creature`, el `fire` de los disparos, el `submit_*` de `ability_command`).
  4. `late_join.tscn` y `local_server_e2e` en PASS.

## 9. Determinismo
- **Criterio:** `bash agent/run_determinism.sh quick` da los **28 digests idénticos** a `agent/det_baseline.txt`. Se corre al cerrar c1-b, c1-c2 y c1-d. **No se regraba la base.** Si un caso cambia, el sub-corte no cierra: se biseca por paso hasta encontrar el campo.
- **Por qué no debería cambiar:**
  - **Clips.** `ClipFacts.frames = roundi(length * fps)` y `hits = roundi(t * fps)`. El migrador escribe `length = frames / framerate` y `t = tick / framerate` de los diccionarios de hoy, y los lectores siguen multiplicando por `FRAME_TICKS = 2`. Antes de borrar los diccionarios, `clip_facts_cases` compara los dos para las 72 criaturas y los 15 magos: **852 + N roles al 100 %**. La única diferencia conocida (`sacd idle`: 0,367 contra 0,033 s) se resuelve a favor del diccionario, que es lo que lee la sim hoy; el modelo del doctor conserva su pose de un cuadro con `start_offset` en el estado del `Tree`.
  - **Habilidades.** `abilities()` devuelve el mismo orden que `ability_tags`, verificado. El único caso distinto es `tsg@`, que no existe en el catálogo: hoy entra `null` a la lista de la IA y `AiRater.fill_from_object` lo saltea (`ai_rater.gd:110`); mañana no entra. Mismo resultado.
  - **Tiradas.** `ghost_form` sortea con `randi_range(0, death_frames.size() - 1)`: hay tantos roles `death*` como entradas, y en el mismo orden. Ningún RNG nuevo.
  - **c1-d (escalas).** Donde hoy se hace aritmética entera con milésimas, el lector convierte con `roundi(x * 1000.0)` y la cuenta queda idéntica. Donde hoy se divide (`float(x) / 1000.0`), el double de `1.1` escrito en el `.tres` es el mismo que `1100 / 1000.0`. Ver la pregunta 7.

## 10. Renombrar los 72 `.tres`
- **Herramienta:** `tools/migrate/rename_resources.py --csv tools/migrate/creature_names_055c1.csv --apply` (055i-a). `git mv` más la reescritura de `res://data/catalog/creatures/<viejo>.tres` en `.tres/.tscn/.gd/.json/.cfg/.txt/.sh`. Sale con 1 si queda una ruta vieja. El `tag` **no cambia**.
- **El CSV sale de `CreatureType.sounds`** (el nombre del set de audio, que ya es humano y único, también en macOS sin distinguir mayúsculas). Hay 5 filas a mano para los que no tienen set.

| Viejo → nuevo |
|---|
| `EHTH_2` → `faestus_pyro` · `RAMH_2` → `astaroth` · `ahcr` → `sylph` · `alab` → `squall` · `amuh` → `ranger` · `bobs` → `brainiac` · `cara` → `scarab` · `cbab` → `mutant` · `craa` → `vortick` · `craf` → `tickferno` · `crpd` → `netherfiend` · `ctug` → `abomination` |
| `dcas` → `sac_doctor` (a mano) · `dplk` → `fallen` · `dzid` → `scythe` · `eafH` → `thestor` · `ehtH` → `faestus_persephone` · `fplk` → `flame_minion` · `gard` → `rhinok` · `glsd` → `necryl` · `grdb` → `silverback` · `grdg` → `dragon` · `grdr` → `phoenix` · `grps` → `seraph` |
| `guls` → `basilisk` · `imaf` → `familiar` (a mano) · `kacd` → `blight` · `kace` → `ikarus` · `kacf` → `pyrodactyl` · `lbog` → `frostwolf` · `llab` → `boulderdash` · `lort` → `troll` · `lrps` → `gremlin` · `lrtf` → `firefist` · `magH` → `gammel` · `mtse` → `jabberocky` |
| `mtsl` → `ent` · `nmuh` → `druid` · `nomd` → `hellmouth` · `nugd` → `styx` · `nugf` → `warmonger` · `oham` → `manahoar` (a mano) · `oohH` → `toldor` · `palk` → `earthfling` · `pazb` → `locust` · `pezH` → `sara_bella` · `plfd` → `deadeye` · `plff` → `pyromaniac` |
| `plfl` → `gnome` · `raeb` → `taurock` · `ramH` → `gangrel` · `rdbO` → `dragon_hatchling` · `rgos` → `storm_giant` · `risH` → `sirocco` · `saep` → `peasant` · `sohe` → `gargoyle` · `sohf` → `spitfire` · `tbsh` → `shrike` · `testmonster` → `testmonster` (se queda: fixture de `run_audio_cases`) · `tnem` → `zyzyx` (a mano) |
| `tshg` → `ghost` · `uslH` → `lord_surtur` · `wlca` → `flurry` · `wlce` → `flummox` · `wlcf` → `bombard` · `ycro` → `trogg` · `ycrp` → `yeti` · `zepa` → `snowman` · `zepd` → `zombie` · `zepe` → `farmer` · `zepf` → `slave` · `zidf` → `cog` |

- **Lo que resuelve por nombre de archivo y se arregla en el mismo commit** (§3.5): `TypeRef`, `creature_icon(_render)`, `new_creature`, `scaffold_map.py` y la regla de `catalog_cases`. Los escaneos de carpeta (`GameCatalog._load_folder`, `bake_body_scenes`, `anim_expect`, `sound_refs_cases`) no dependen del nombre.
- **Fixtures:** `debug/rules/*.tres` y `agent/` nombran criaturas **por tag** (`"ycro"`), que no cambia; las que nombran la ruta las reescribe la herramienta.
- **Después:** una sola corrida `--headless --import` en la cola FIFO, y después `catalog_cases` y `rules_suite`.
- **Iconos:** `assets/original/ui/icons/ycro.png` y los `models/<modelo>.tscn` **no** se renombran. Son assets con el nombre de su archivo fuente, no identidad. Los modelos se nombran en 055s, con el cuerpo como escena.

## 11. Riesgos (con las lecciones ya aprendidas)
1. **Nada por cuadro con `load()`/`find()`.** `ClipFacts.of()` se llama en `_ready` y el cuerpo guarda la instancia. `wizard_body.gd:443` (regeneración, por cuadro) pasa a leer `wizard_type`. El reviewer busca `GameData.`, `GameCatalog.`, `ClipFacts.of(` y `.get_animation(` dentro de `_physics_process`/`_process` de lo tocado: tiene que dar 0.
2. **Los autoloads que son escena no tienen tipo estático** (`SacrificeFlow`, `SoundBus`). Lo que devuelven se guarda en una variable tipada explícita (`var chosen: WizardPick = SacrificeFlow.pick_for(slot)`). No se agrega ningún autoload.
3. **Fixtures que resuelven por nombre de archivo** (§3.5 y §10). La herramienta falla si queda una ruta vieja; `rg "creatures/%s|CREATURES_DIR \+ tag"` tiene que quedar en 0 fuera de `tools/migrate/`.
4. **No cambiar el texto de un `print`.** Se conservan exactos `NEW_CREATURE …` (los lee `run_audio_cases.sh`), `CATALOG PASS`, `pasiva %s …`, `rayo %s …`, `slot %d pick %s %s` e `ia slot %d lista`. Las líneas nuevas son solo las de las sondas (`CLIP FACTS …`, `WIRE CONFIG …`).
5. **Carrera del mago en el cliente**: el id replicado puede llegar antes que el pick. El cuerpo usa el default de la escena y vuelve a aplicar con `SacrificeFlow.slot_picks_changed`. Solo afecta la presentación del cliente: la vida y la resistencia las decide el servidor. Se prueba con `late_join`.
6. **Costo de que el dedicado cargue las bibliotecas** (pistas de huesos de unos 900 clips; los `.glb` pesan 102 MB con mallas). NO VERIFICADO. Se mide en c1-0 con `Performance.MEMORY_STATIC` y el tiempo hasta `GameData` listo, en cliente, `--dedicated --no-flow` y banco. Presupuesto propuesto **+≤ 1 s y +≤ 100 MB** sobre lo de 055o. Si se pasa: `ClipTiming` derivado (pregunta 3).
7. **Peso en git** de los `.res` extraídos. NO VERIFICADO; se mide en c1-0 (pregunta 4).
8. **Marcadores y pistas de método en `Animation` sueltas** (Godot 4.4+, `add_marker`): NO VERIFICADO en 4.7 que el `AnimationTree` dispare las pistas de método de una biblioteca que no es la del `.glb`, ni que el diálogo «Gestionar animaciones» deje reemplazar un rol desde el editor. Se prueba en c1-0 con `eorc` y `jnwr`.
9. **Ciclo de recursos**: `CreatureType` no puede referenciar `GodType` (`GodType → GodBook → CreatureType`). Por eso se borra `CreatureType.god`. El reviewer revisa que ningún tipo nuevo cierre otro ciclo (`AbilityType` y `CreaturePassive` no apuntan hacia atrás).
10. **`"type" in body` como «es una criatura»** (`stunned.gd:146`, `kill_estimate.gd:96`, `health.gd:185`): por eso el mago usa `wizard_type`, no `type`.
11. **Archivos calientes:** `unit.tscn` (055o-b ya mergeó); `data/gods/*.tres` (055o-c le agrega `music/ambience`; la herramienta de renombrado reescribe las rutas del libro). Ver §13.
12. **El árbol de trabajo de `main` tiene más de 50 archivos modificados sin commitear** (`.import`, `data/look`, `data/fx`): el developer trabaja en un worktree y no los incluye.
13. **Importación pesada** (unos 900 `.res` nuevos): una sola `--import` en la cola FIFO después de c1-c1, sola, sin otros Godot (memoria «Godot puede colgar la Mac»).

## 12. Criterios medibles y código 1 a 1 que se borra
**Lint** (`bash tools/lint/conventions.sh`; ningún conteo sube; `--update-baseline` al cerrar cada sub-corte):

| Regla | Hoy | Al cerrar | Sub-corte |
|---|---|---|---|
| C8 | 24 | **7** (−17) | c1-c2 |
| C18 | 74 | **≤ 35** (−39: units 18, ai 9, wizards 4, vecinos 4, órdenes y UI 4) | c1-b (38), c1-c2 (1: `ghost_form`) |
| C18b | 7 | **6** | c1-b |
| C18c (nueva, pregunta 8) | 19 (el developer la fija al agregarla) | **0** | c1-b |
| C22 | 6 | **3** | c1-c2 |
| C9 | 319 | **≤ 300** (encabezados de los archivos tocados, `## Ref:` al final) | todos |
| C1a / C1b | 102 / 22 | no suben; `creature_type.gd` ≤ 120, archivos nuevos ≤ 150 | — |
| C11 / C13 / C12 / C14 | 5 / 9 / 78 / 221 | iguales o menores | — |

**Sondas y suites (headless, en la cola FIFO):**
- `clip_facts_cases` imprime `CLIP FACTS roles=<n> equal=<n> differ=0 missing=0`. En c1-c1 compara con los diccionarios; desde c1-c2 valida la forma: cada `attack*` tiene ≥ 1 `hit`, cada `shoot*` ≥ 1 `shoot`, y todo rol que lee la sim existe o tiene respaldo declarado.
- `catalog_cases` → `CATALOG PASS` con las reglas nuevas. `rules_suite` PASS. `run_audio_cases.sh` con `SOUND REFS` igual que hoy (67 + 15 sets).
- Determinismo: `quick` con los 28 digests idénticos (§9).
- Red: diff vacío (§8) y `WIRE CONFIG` igual.
- **Greps en 0** en `scenes/`: `_animations\b`, `death_frames`, `corpse_rise_frames`, `float_to_stance_frames`, `ability_tags`, `ranged_attack_tag`, `active_ability_tag`, `passive_on_damage`, `passive_abilities`, `is_peasant_tag`, `WIDTH_SCALE`, `spell_tag` (salvo en `abilities/` como FX), `GameData.(creature|ability|wizard)\(` en `scenes/units`, `scenes/ai`, `scenes/wizards`, `scenes/orders`.
- **Capturas** (la ventana la abre el orquestador, una por vez):
  - `agent/harness/clip_shots`: los 74 modelos posados con `seek` exacto en (`idle`, 0 s), (`attack`, en el `hit`), (`run`, 0,5 s), con cámara fija. PNG-diff de AgentKit **≤ 0,5 %** de píxeles distintos por modelo, antes (c1-0, sobre `main` sin el corte) y después de c1-c1.
  - `match_shots` en High Noon: igual, ≤ 0,5 %.
- **Humano** (se borra al final): duplicar `trogg.tres` → `trogg_elite.tres` con el tag vacío, subir `Health` y arrastrarlo al libro de James. Aparece en el libro y se invoca, con id `trogg_elite` en el log del spawner.

**Código 1 a 1 que se borra:**
- Los 11 diccionarios de `CreatureType` y los 6 de `WizardType`, más `death_frames`, `corpse_rise_frames` y `float_to_stance_frames`.
- `BodyModel.clips.frames/framerate`, los 74 nodos `Events` y sus 74 `AnimationLibrary` de eventos por tag. También `timeline_length`/`use_custom_timeline` de los estados.
- `CreatureType.god`, `ability_tags`, `is_ranged` (campo), `ranged_attack_tag`, `active_ability_tag`, `passive_on_damage`, `passive_abilities`, `takeoff_time_s`/`land_time_s` (pasan a `ClipFacts`). También `WizardType.spell_tag`.
- Las 40 búsquedas de §3.5 y `AiProfile.for_god`.
- Los `tag` de `DeathCloudType`, `OnHitPassiveType`, `DamagePassiveType` y `TargetPolicy`, y los 13 `@export` de texto de los componentes.
- Las listas `types` de `DeathCloudSpawner` y `MeleeOnHit` en `unit.tscn`.
- `WIDTH_SCALE`, `PeasantBehavior.TAGS`/`is_peasant_tag`, `TypeRef._from_file`.
- Los 72 nombres de WAD de `data/catalog/creatures/`.
- `SETS` y `--sync` por diccionarios de `new_creature.gd`, la escritura de diccionarios de `catalog_builder.gd` y `bake_body_scenes.gd` como generador que se puede volver a correr (congelado; se borra en 055z). También `tools/migrate/migrate_055o_bodies.*`.

## 13. Sub-cortes y paralelo
**055h-4 ya mergeó** (`1930942c`, en `main` desde `11d8da46`): no es una restricción. Si no hubiera mergeado, los únicos archivos compartidos eran `orders/selection.gd`, `orders/command/ability_command.gd` y `ui/selection_roster/selection_roster.gd`, todos en c1-b.

| Sub-corte | Qué | Tamaño | Depende | Paralelo con 055o-c / 055s |
|---|---|---|---|---|
| **c1-0** prueba | Rama descartable: extraer `eorc` y `jnwr`, la biblioteca, `Clips` + `Tree` por rol, marcador `hit`, pista de método; medir carga en dedicado y peso en git; probar «Gestionar animaciones». Guardar las capturas y logs de referencia (§8, §12) sobre `main` sin el corte. Anotar los números en este plan | S | — | sí con los dos (no mergea) |
| **c1-a** nombres | `wire_config_cases` (hash de referencia) primero; CSV y `rename_resources.py` sobre las 72; `CreatureType.id()`; `GameCatalog.creature(id)`; `TypeRef` por id; herramientas por nombre (§3.5); `catalog_cases`; congelar `bake_body_scenes` | S | — (paralelo con c1-0) | 055o-c: **después** de que mergee (`data/gods/*.tres`); si choca, se descarta el lado de c1-a en `data/gods/` y se vuelve a correr la herramienta, que es idempotente. 055s: **sí** (no toca modelos) |
| **c1-b** referencias tipadas (= **055i-b**) | `CreaturePassive`; campos tipados de habilidad y pasiva; los 13 `@export` de texto de los componentes; `typed_refs_055c1.gd`; spawners que pasan el tipo; `UnitBody`/`DoctorBody.type`; `WizardBody.wizard_type` desde el pick; `Health`, `KillEstimate`, `AiPerception`, `AiAudit`, `SoulSystem`, `MapPopulation`, `caster`, órdenes y plantel; `melee_width_scale` y `peasant`; C18c en el lint | M | c1-a | 055o-c: **sí** (no comparten archivos: 055o-c toca `god_type.gd`, `data/gods`, directores, consejero, `ritual.tscn`, `soul.tscn`, `match.tscn`, `boot.tscn`). 055s: **no** (`unit_body.gd`, `melee_attack.gd`, `doctor_body.gd`) |
| **c1-c1** clips (dibujo) | `extract_clips_055c1.gd`: 85 bibliotecas, unos 900 `.res`, 74 modelos con `Clips` y `Tree` por rol, sin `Events`; `CreatureType.clips`/`WizardType.clips` asignados; `ClipFacts`; `clip_facts_cases` en paridad (los diccionarios siguen vivos); `new_creature` reescrito; capturas | L | c1-0 resuelto, c1-a | 055o-c: **sí** (`scenes/bodies`, `tools/`, datos de catálogo). 055s: **no** (los 74 modelos) |
| **c1-c2** clips (reglas) | los 9 lectores de §3.4 pasan a `ClipFacts`; `BodyRig`/`BodyModel` sin `clips.frames`; borrar los diccionarios y los `*_frames`; banco `quick` | M | c1-b, c1-c1 | 055o-c: **sí**. 055s: **no** |
| **c1-d** unidades | `run_speed_m_s`, `fly_speed_m_s`, `sight_m`; escalas de milésimas a 1,0 (pregunta 7) en `CreatureType` y `WizardType`, más los 58 archivos que las leen; banco `quick` | S–M | c1-c2 | 055o-c: **sí**. 055s: **no** |

- **Orden:** c1-0 ∥ c1-a → c1-b ∥ c1-c1 (carpetas casi disjuntas; `creature_type.gd` se toca en los dos, así que c1-c1 mergea segundo y agrega solo `clips`) → c1-c2 → c1-d → **055s**. 055s va después de todo 055c1, porque convierte los `hands` de `BodyModel.clips` en `BoneAttachment3D` sobre los mismos 74 modelos.
- Cada sub-corte es un developer en un worktree. Review solo en c1-b y c1-c1 (cambian datos de 72 fichas y 74 escenas). Godot va por la cola FIFO: como mucho 3 headless y 1 ventana; la `--import` grande de c1-c1, sola.

## 14. Orden de implementación
1. **c1-0:**
   1. Referencias sobre `main` sin el corte: logs de `run_034m`/`run_049e`, `quick`, `clip_shots`.
   2. Prueba de `eorc`/`jnwr`.
   3. Medidas de carga y peso.
   4. Respuestas a los riesgos 6–8 escritas en este plan.
2. **c1-a:**
   1. `wire_config_cases` (hash de referencia).
   2. CSV + `rename_resources.py` (primero el ensayo, después `--apply`).
   3. `id()`, `GameCatalog.creature(id)`, `TypeRef`.
   4. Herramientas por nombre.
   5. `catalog_cases`; congelar `bake_body_scenes`.
   6. `--import`, `catalog_cases`, `rules_suite`.
3. **c1-b:**
   1. `CreaturePassive` y los tipos de pasiva con `ability`/`spell`.
   2. Campos tipados en `CreatureType` (conviviendo un paso con los viejos).
   3. `typed_refs_055c1.gd` sobre las 72, las pasivas, `unit.tscn` y los 25 + 5 `.tscn` de debug.
   4. Spawners y cuerpos con el tipo.
   5. Componentes de §4.2.
   6. IA, `Health`, `SoulSystem`, `MapPopulation`, `caster`, órdenes y plantel.
   7. Borrar los campos viejos.
   8. C18c.
   9. `quick`, `rules_suite`, `catalog_cases`, `late_join`, `run_034m`/`run_049e` con diff y `WIRE CONFIG`.
4. **c1-c1:**
   1. `ClipFacts`.
   2. `extract_clips_055c1.gd` con el informe de paridad.
   3. Modelos con `Clips`/`Tree` por rol.
   4. `clips` en los tipos.
   5. `clip_facts_cases` al 100 %.
   6. `new_creature` (rehacer `testmonster` con `--force` en un directorio de salida de prueba, no en el repo).
   7. `--import` sola.
   8. `clip_shots` y `match_shots` con diff ≤ 0,5 %.
5. **c1-c2:**
   1. Los 9 lectores.
   2. `BodyRig`/`BodyModel`.
   3. Borrar los diccionarios y los `*_frames`.
   4. `quick` idéntico, `rules_suite`, `custom_creature`.
6. **c1-d:**
   1. Renombres con unidad y escalas, con su migrador de una vez.
   2. `quick` idéntico.
7. **Al cerrar:**
   1. Los 4 READMEs (units, bodies, wizards, ai) con las 5 líneas (`Check:`, no `Debug:`).
   2. C9 de los encabezados tocados.
   3. `--update-baseline`.
   4. La tabla §7 la revisa el reviewer.

## 15. Cómo lo verifica un humano en el editor
- **FileSystem:** `data/catalog/creatures/` muestra `trogg.tres`, `phoenix.tres`… Al abrir uno, el inspector tiene los grupos de §5, `Tag` de solo lectura y `Clips` → `eorc_clips.tres`.
- **`scenes/bodies/models/eorc.tscn` (F6 o el editor):**
  - en `Tree` (panel AnimationTree), los estados se llaman como los roles;
  - en `Clips` → panel Animación → `attack`: el marcador `hit` en 0,5 s;
  - con `preview_role = attack`, el trogg golpea.
- **Mover el marcador** `hit` de `attack` a 0,3 s → F5 en High Noon (o el banco `f177`) → el trogg pega antes. Volver a ponerlo en su lugar.
- **`phoenix.tres` → `On Damage`:** se ve `rifl.tres` (escudo del fénix). Vaciarlo → el fénix ya no enciende el escudo al recibir daño (`f163`). Deshacer.
- **`necryl.tres` → `Passives`:** se ve la nube; quitarla → no deja nube al morir (`debug/units/f116_death_clouds.tscn`, F6). Deshacer.
- **Headless:** `bash tools/lint/conventions.sh`, `rules_suite`, `bash agent/run_determinism.sh quick`, `bash agent/runs/run_034m.sh`, `bash agent/runs/run_049e.sh`.

## 16. Fuera de alcance
- La escena por criatura (`trogg.tscn` heredando `unit.tscn`), `model` como escena, `BodyCatalog`, `body_sizes`, `hands` → `BoneAttachment3D`: **055s** (pregunta 5).
- `AbilityType`/`SpellType` (`flags*`, `amount2`, `args`), `spell_order`, nombres humanos de las 63 habilidades y los 53 hechizos: **055e** (y 055i-a a4).
- `FALLING_ACCELERATION {"dkba"}`, armas como escenas: **055c3**. Partir `unit_body.gd`/`wizard_body.gd`: **055c**.
- FX por texto (`look_tag`, `shot_tag`, `ShotLook.for_tag`): **055x**.
- Los 114 edificios `<dios>_<tag>`: 055i-c. Los modelos `models/<tag>.tscn`: 055s.

## 17. Preguntas abiertas (con recomendación)
1. **¿La biblioteca de clips es del modelo (y la ficha apunta a ella) o de cada criatura?** **Recomiendo del modelo**, como dice el RFC: 70 de 72 fichas usan su modelo tal cual, y «cambiar el ataque» queda en un lugar que se ve. Solo el fantasma tendría la suya si la sonda muestra roles distintos que la sim lee.
2. **¿Cómo se extraen los clips del `.glb`?** **Recomiendo una sola extracción con el migrador** para los del original (congelados, como `bake_catalog`) y `new_creature --sync` para los propios (re-extrae al reexportar desde Blender y conserva los marcadores por nombre). La alternativa nativa (`save_to_file` + `keep_custom_tracks` en el `.glb.import`) reimporta 74 modelos y no está claro que conserve `length` y marcadores (NO VERIFICADO): se prueba en c1-0 y, si funciona igual, se usa para los propios.
3. **¿Se acepta que el dedicado cargue las bibliotecas** (pistas de huesos) dentro de +≤ 1 s y +≤ 100 MB? **Recomiendo que sí**, porque es la única forma de tener una sola fuente. Si se pasa: `ClipTiming` (Resource chico, derivado de la biblioteca por la herramienta y validado por `catalog_cases`, sin edición a mano) solo para el servidor, que es el «respaldo» que nombra RFC-055 §15.
4. **¿Los `.res` extraídos van a git normal o a LFS?** **Recomiendo** git normal si el total medido en c1-0 es ≤ 40 MB. Si no, un patrón LFS `game/scenes/bodies/models/**/*.res`, igual que los `.glb`.
5. **¿La escena por criatura (RFC-055 §15) entra en este corte o en 055s?** **Recomiendo 055s**: ahí el modelo pasa a ser parte del cuerpo con sus sockets y su colisión, y hacerla acá obligaría a rehacerla. `model: String` queda hasta entonces.
6. **¿Se borra `CreatureType.god`** (por el ciclo de recursos; el dueño es el libro del dios) y `caster` usa el dios del mago? **Recomiendo que sí.** Hoy una criatura solo se invoca desde el libro del dios del mago, así que la partícula es la misma.
7. **¿Las escalas en milésimas (`melee_accuracy = 1000`) pasan a 1,0 = normal en este corte (c1-d)?** **Recomiendo que sí**, con la conversión exacta de §9. Si un digest cambia, ese campo vuelve a entero con un nombre que diga la unidad (`melee_accuracy_permille`) en vez de regrabar la base, porque el pedido es «digests idénticos».
8. **¿Regla nueva C18c** (`@export` de texto donde existe el recurso, en `scenes/units|ai|wizards|sacrifice`: `*_tag`, `*_tags`, `*_spell`, `spell :=` y `PackedStringArray` de tags), con base propia? **Recomiendo que sí**, para que la baja sea medible. Los ids de red (`tag` en `*_type.gd`, `creature_tag`, `wizard_tag`) van en la allowlist.
9. **¿Se renombran ahora las 7 pasivas y nubes** (`goc.tres` → `cog_cloud.tres`, `cen.tres` → `necryl_cloud.tres`, `tum.tres` → `mutant_cloud.tres`, `korq.tres` → `taurock_hide.tres`, `ahtf.tres` → `firefist_fury.tres`)? **Recomiendo que sí**, con la misma herramienta y un CSV revisado por el usuario, porque son los recursos que un humano arrastra. Las 63 habilidades van con 055e: sus `display_name` son genéricos («Shoot» ×3) o el tag crudo, y piden nombres a mano.
10. **¿El mago toma su tipo del pick en cada par** (sin búsqueda por `wizard_tag`), o el setter del id replicado queda como única frontera con una entrada en la allowlist? **Recomiendo el pick**: ya está tipado en cada par por `MatchWire` y deja a `WizardBody` sin `GameData`. El riesgo 5 se prueba con `late_join`.
11. **¿`testmonster.tres` conserva su nombre?** **Recomiendo que sí**: lo crea y lo busca `run_audio_cases.sh` (fixture de `new_creature`), y ya es legible.
12. **¿Las pistas de método de `Events` (sonido, pie, lanzamiento) pasan dentro de cada `Animation` de rol y se borra `Events`?** **Recomiendo que sí**: así un clip es un solo archivo con su tiempo, su golpe y sus eventos. Si c1-0 muestra que el `Tree` no dispara pistas de método de una biblioteca externa, `Events` queda con animaciones nombradas por rol (no por tag).
