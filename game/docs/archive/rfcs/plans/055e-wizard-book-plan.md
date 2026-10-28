# 055e — Mago y libro (plan del tech lead)

> **Aprobado (2026-10-25)** con todas las recomendaciones de §13 (el usuario las aprobó de antemano: «sigue y da por bueno el siguiente rfc»). Lo guarda el orquestador. Corregida la errata de la fila 3 de §12 (Air Shield: SELF_GUARD · SUPPORT).

Base: `main` en c5446b15. Fuentes leídas: CONVENTIONS (C1–C22, §2c), RFC-055 (§3, §4 fila 055e, §12.2, §13, §13.2b C-2, §15), plan 061, el código de `scenes/spells`, `scenes/ai/brains`, `scenes/wizards`, `scenes/gods`, `tools/bake/catalog_builder.gd`, los 53 `data/catalog/spells/*.tres` y `sacengine/source/spells.d:167-203` (nombres de los bits).

## 0. Contradicciones y cuál gana
| # | Dice | Dice otra cosa | Gana |
|---|---|---|---|
| 1 | RFC: «`WizardType.*_animation` a su `BodyModel`» | Ya no existe: `WizardType.clips: AnimationLibrary` (055c1) | El código: 055e no lo toca |
| 2 | RFC: «`structures` → `Dictionary[StringName, PackedScene]`» | 061a lo hizo `GodType.structures: Array[GodStructure]` | El código (C8 y C18 por encima de una fila del RFC) |
| 3 | RFC §12.2: «solo 12 lanzables» | Los 53 tienen acción (40 por `SpellType.action`, 13 como hijos de `wizard_body.tscn/Caster/Actions`) | El código: la checklist de §12 pasa a ser de verificación |
| 4 | Auditoría: «15 de 53 sin `action`» | Hoy son 13 (brif, ccas, elet, htlm, kcor, laeh, mrws, ndrg, ntil, oalf, pcas, pups, ucas) | Los datos |
| 5 | README de spells: «4 actions at depth 2» | El lint C11 cuenta 5 | El lint |
| 6 | RFC: «`Aim` como hijo» | Plan 061 (posterior): blanco = `SpellTarget` embebido | 061 |
| 7 | «booleanos con nombre» | C-2: «booleanos y enums con nombre» | Las dos |

## 1. Objetivo
- `SpellType` sin `flags`, `flags1`, `flags2`, `amount2` ni `count`: campos con nombre (§8.1). La IA solo lee esos campos y `ai_use`; ningún `spell.tag ==` en `scenes/ai`. **Paridad:** los 53 dan las mismas decisiones que con los bits (`spell_field_cases`).
- `WizardBody.book: GodBook` es un override; vacío, manda el libro del dios. `Spellbook` lo resuelve sin `GameData.book` (C18 −1) y sin `get_parent()` (socket `@export var wizard`).
- Ninguna acción hereda de `AimedAction` (C11 5 → 0). El blanco es un `SpellTarget` embebido y el chequeo común (fondos → blanco → alcance) es `SpellAction.aim_at_body`.
- Una sola forma de enchufar una acción: los 53 `SpellType` con `action`; `wizard_body.tscn/Caster/Actions` queda vacío.
- La malla de Fireball, Rock y Swarm vive en su `.tscn` (C15 −6).
- La checklist de los 41 (§12) completa.

## 2. Escena de prueba
`res://debug/spells/book_override.tscn` (F6): instancia `scenes/match/high_noon.tscn` con `rules = debug/rules/cast_wards.tres` (mago nivel 3, maná lleno) y un nodo `Targets` con `debug/units/rock_hit.gd` (Trogg `ycro` enemigo a 3 m, Ranger `amuh` a 25 m, `wizard_god = "pyro"`, `wizard_book = debug/spells/mixed_book.tres`). `mixed_book.tres` (`GodBook`): `spells = [kcor, laeh, niks, zerf]`, `structures = [htlm]`, sin `unlocks`. `rock_hit.gd` gana `@export var wizard_book: GodBook` (vacío: las otras `cast_*` no cambian).
- Estado inicial: mago de Pyro con libro Rock, Heal, Skin of Stone, Freeze (sin Fireball). Acción: `spell_N` (Freeze) + clic en el Trogg → congelado; `spell_M` (Skin of Stone) → escudo sin clic. Contraprueba: `cast_pyro.tscn` sigue con el libro de Pyro.

## 3. Árbol
```
scenes/spells/
  [~] spell_type.gd          (e1) fuera flags*/amount2/count; + grupo «AI: who it may land on» (9 bool), AiUse ampliado (append-only), AiPhase, ai_phase, ai_only_on_self, ai_worth, max_targets
  [~] spell_target.gd        (e2) + Who.OWN_OR_SELF, Who.NOT_OWN; + alive_only := true; + static same_owner(wizard, body)
  [+] launch_point.gd        (e2) LaunchPoint (static): from_hand, from_hand_facing, projectile_data ≤60
  [~] spellbook.gd           (e4) @export var wizard: WizardBody; current_book(); rebuild por (book, level)
  [~] caster.gd              (e3) action_for(tag) instancia spell.action; empareja por `spell`
  [~] fireball_projectile.*, rock_projectile.*, swarm_projectile.*  (e5) hijo Mesh en el .tscn; fuera _add_visual
  [~] README.md              (e3) Check: spell_field_cases, book_cases, spell_link_cases
  actions/
    [~] spell_action.gd      (e2) + aim_at_body(wizard, spell, point, funds, body) -> Aim   (e3) var spell: SpellType (tag pasa a getter)
    [-] aimed_action.gd      (e2)
    [~] heal_action, pups_action (e2) extends SpellAction; target OWN_OR_SELF, alive_only=false; Heal: print → DebugLog
    [~] lightning_action, rock_action, thrown_action (e2) extends SpellAction; target NOT_OWN
    [~] wrath/fireball/swarm_action.tscn (e2) target embebido  (e3) sin `tag =`
    [~] afflict_action.gd    (e2) usa aim_at_body
    [~] carrier_action.gd    (e2) LaunchPoint.projectile_data
    [+] structure_action.tscn, desecrate_action.tscn, convert_action.tscn, guardian_action.tscn, teleport_action.tscn (e3)
    [~] *_action.tscn        (e3) fuera `tag = "…"`
  carrier/ [~] carrier_pulse.gd (e2) SpellTarget.same_owner · carrier_sync.gd (e2) · carrier_hunt.gd (e1) count → max_targets
scenes/wizards/ [~] wizard_body.gd (e4) @export var book + signal book_changed · wizard_body.tscn (e4) Spellbook.wizard; (e3) Caster/Actions vacío · README (e4)
scenes/gods/ [~] god_book.gd (e4) level_of(type: Resource) por identidad
scenes/core/catalog/ [~] game_data.gd (e4) creature_level() con level_of(type)
scenes/ai/ brains/ai_spell_eval.gd, wizard_brain.gd (e1) · brains/ai_line_of_fire.gd (e2) · brains/phases/attack_phase.gd, support_phase.gd (e1) · math/ai_rater.gd (e1, solo el bucle de hechizos)
tools/ bake/[+] spell_bits.gd (e1) · bake/[~] catalog_builder.gd (e1, solo make_spell) · migrate/[+] spell_fields_055e.py (e1)
data/catalog/spells/*.tres ×53 (e1 campos; e3 action en los 13)
debug/ spells/[+] book_override.tscn, mixed_book.tres (e4) · units/[~] rock_hit.gd (e4)
       suite/[+] spell_bits_055e.txt, legacy_spell_bits.gd, spell_field_cases.gd (e1), book_cases.gd (e4), spell_link_cases.gd (e3+e5)
       suite/[~] rules_suite.gd (COMPARTIDO), ai_cases, ward_cases, control_cases (e1), zone/cloud/tornado/stalk/level8_cases (e1), chain_cases (e2)
       ai/[~] expect_judge.gd (e1)
```
Compartidos: `rules_suite.gd` (una línea por corte), `tools/lint/baseline.txt` (solo el orquestador, al final), `catalog_builder.gd` (e1 solo `make_spell`), `ai_rater.gd` (e1 solo el bucle de hechizos). Ningún sub-corte toca `scenes/units/attacks|abilities`, `unit.tscn`, `unit_body.gd` ni el terreno.

## 4. Responsabilidades
| Pieza | Hace | No hace |
|---|---|---|
| `SpellType` | Números del hechizo y qué necesita saber la IA | Decidir |
| `GodBook` | Qué entra al libro y desde qué nivel | Cooldowns ni orden |
| `WizardBody.book` | Override del libro de este mago (banco, solo, servidor) | Replicarse |
| `Spellbook` | Libro del mago a su nivel, ordenado; cooldowns | Lanzar; buscar por texto |
| `Caster` | Maná, cooldown, cuadros; instancia `spell.action` | Saber qué hace cada hechizo |
| `SpellAction` | check/begin/started/finish/cancel; `aim_at_body` | Elegir el blanco (lo dice su `SpellTarget`) |
| `SpellTarget` | ¿Este cuerpo es un blanco válido para el clic? | Aplicar efectos |
| `LaunchPoint` | De dónde sale una bola y qué datos lleva un proyectil | Lanzar |
| `AiSpellEval` | Puntúa un hechizo sobre un blanco con campos con nombre | Lanzar; leer tags |
| `WizardBrain` | Qué hechizo usa para torre, Convert, Desecrate | Puntuar |
| `SpellBits` (tools) | Traducir bits del original a campos al hornear | Correr en el producto |

## 5–6. Composición, Resources y nodos
`AimedAction` desaparece: las 5 acciones pasan a `extends SpellAction` (profundidad 1); lo que variaba es un `SpellTarget` embebido + un chequeo propio de una línea (Heal pide `Health`; Speedup, que no haya otro `SpeedupEffect`). Las estáticas se reparten: lanzamiento → `LaunchPoint`; bando → `SpellTarget`. Las 13 acciones de `wizard_body.tscn` pasan a escenas propias referenciadas por `SpellType.action`. Resources de tipo: `SpellType`, `GodBook`, `BookUnlock`, `GodStructure`; embebido de instancia: `SpellTarget`. `@export` de instancia: `WizardBody.book`, `Spellbook.wizard`, los knobs de cada acción.

## 7. Los seis verbos
| Verbo | Qué abre / toca | Archivos |
|---|---|---|
| Entender | `data/catalog/spells/<tag>.tres` (grupos números / «AI: who it may land on» / «AI»); `action` lleva a la escena | 1–2 |
| Modificar | El `.tres` (costo, alcance, `ai_phase = NEVER`) o el `SpellTarget` de su `*_action.tscn` | 1 |
| Agregar | Duplicar un `.tres`; reusar una escena genérica o duplicar una `*_action.tscn`; arrastrarlo al `GodBook` del dios | 2 (3 con escena nueva) |
| Quitar | Sacarlo del `GodBook` o vaciar `action` | 1 |
| Crear un mago con su libro | `GodBook` nuevo; asignarlo en `WizardBody.book` o en `rock_hit.wizard_book` | 1–2 |
| Escalar | Un `.tres` por hechizo + escenas genéricas; la IA los toma por `ai_use`/`ai_phase` | lineal, sin código |

## 8. Contratos
### 8.1 `SpellType` (e1)
```gdscript
enum AiUse { NONE, SELF_GUARD, DISABLE_FOE, HIT_ONE, HIT_AREA, HEAL, SPEEDUP, CONVERT, DESECRATE }   # append-only
enum AiPhase { NEVER, ATTACK, SUPPORT }
@export_group("AI: who it may land on")
@export var targets_wizards := false       # flags bit 0
@export var targets_souls := false         # bit 1
@export var targets_creatures := false     # bit 2
@export var targets_corpses := false       # bit 3
@export var targets_structures := false    # bit 4
@export var only_free_manafounts := false  # bit 11
@export var only_allies := false           # bit 12
@export var never_allies := false          # bit 13
@export var targets_ground := false        # bit 14
@export_group("AI")
@export var ai_use := AiUse.NONE
@export var ai_phase := AiPhase.NEVER
@export var ai_only_on_self := false       # flags1 bit 4
@export var ai_worth := 0                  # era amount2
@export_group("")
@export var max_targets := 0               # era count (Death: 8)
```
Bits sin lector (se pierden, quedan en el CSV): flags 16–20; flags1 0, 1, 5; todo flags2. flags1 10..15 → `ai_phase` (11, 12, 14 → ATTACK; 10, 13, 15 → SUPPORT; ninguno lleva los dos).
**`ai_use` horneado:** SELF_GUARD: niks dlhs mrfe mrff rwsp · DISABLE_FOE: zerf eniv rapf htel · HIT_ONE: kcor ntil mrws ivob pavi · HIT_AREA: brif oalf clov cnef egar galp grfr laws lawv laww likc lwrf nrot ntlc olah pxef rifd rifr rtem tfir tpre zorf · HEAL: laeh rter ruah wobr · SPEEDUP: pups · CONVERT: ccas · DESECRATE: ucas · NONE: deda dnws elet erob htlm mrhc ndrg pcas pmcd taed.
**`ai_phase`:** ATTACK (33): brif clov cnef egar eniv galp grfr htel ivob kcor laws lawv laww likc lwrf mrhc mrws nrot ntil ntlc oalf olah pavi pxef rapf rifd rifr rtem taed tfir tpre zerf zorf · SUPPORT (12): dlhs elet laeh mrfe mrff ndrg niks pups rter ruah rwsp wobr · NEVER (8): ccas deda dnws erob htlm pcas pmcd ucas. `ai_only_on_self`: dlhs elet mrfe mrff niks olah rwsp.

### 8.2 `AiSpellEval` (e1)
`rating_fn(spell)` = `match spell.ai_use` (HIT_ONE → FN_SINGLE, HIT_AREA → FN_AREA, HEAL, SPEEDUP, SELF_GUARD → FN_GUARD, DISABLE_FOE → FN_DISABLE; NONE/CONVERT/DESECRATE → FN_NONE). `casts_in(spell, phase)` reemplaza a `accepts(spell, mask)` (se borran ATTACK_MASK y SUPPORT_MASK). `wants_acc(spell)` = `ai_phase != NEVER`. `find_best(caster, target, phase)`. `lands_on(spell, t)`: sin ninguno de los 9 bool → true; WIZ → targets_wizards; CRE/MAHO → targets_creatures; STR → targets_structures; NONE → false (exacto a la máscara de hoy). `can_cast_on`: solo si hay algún `targets_<kind>`; `only_free_manafounts` gana; después `only_allies` y `never_allies`, en ese orden. `rate`: `ai_only_on_self and caster != target` → 0.

### 8.3 Acciones (e2, e3)
```gdscript
# SpellTarget
enum Who { SELF, ALLY_OR_SELF, ENEMY, ANY, OWN_OR_SELF, NOT_OWN }   # append-only
@export var alive_only := true
static func same_owner(wizard: Node3D, body: Node) -> bool          # el viejo AimedAction.is_ally
# SpellAction
var spell: SpellType          # lo pone Caster al instanciar `spell.action`
var tag: String: get = ...    # spell.tag (id de red), solo lectura
func aim_at_body(wizard: WizardBody, spell: SpellType, point: Vector3, funds: String, body: Node3D) -> Aim
# LaunchPoint (static)
static func from_hand(wizard: WizardBody) -> Vector3
static func from_hand_facing(wizard: WizardBody, facing: Vector3) -> Vector3
static func projectile_data(wizard: Node3D, spell: SpellType, from: Vector3, target: Node3D, point: Vector3) -> Dictionary
```
`Caster.action_for(tag)` conserva su firma. `ThrownAction` y `RockAction` conservan `class_name` (`AiLineOfFire.flight_of` usa `is`).

### 8.4 Libro (e4)
```gdscript
# WizardBody
signal book_changed
@export var book: GodBook:      ## override de este mago; vacío: el del dios. No se replica
	set(value): book = value; book_changed.emit()
# Spellbook
@export var wizard: WizardBody
func current_book() -> GodBook  # wizard.book, si no wizard.god_type.book, si no null
```
`_rebuild()` usa `current_book().up_to(level)` y escucha `pick_changed` y `book_changed`. En red, con override: `push_warning` una vez. `GodBook.level_of(type: Resource) -> int` por identidad.

## 9. Sub-cortes
| Corte | Qué | Depende de | En paralelo con |
|---|---|---|---|
| **e1** campos con nombre + IA | §8.1, §8.2, migración python, `SpellBits`, CSV, paridad, casos ajustados | — | e2, e4, e5 |
| **e2** fuera `AimedAction` | §8.3 (SpellTarget, aim_at_body, LaunchPoint), 5 acciones, AfflictAction, carrier, AiLineOfFire | — | e1, e4, e5 |
| **e4** libro override | §8.4, `book_override.tscn`, `book_cases` | — | e1, e2, e5 |
| **e5** proyectiles en escena | Mesh en `.tscn` de Fireball, Rock, Swarm | — | e1, e2, e4 |
| **e3** una sola forma de enchufar | `action` en los 13 `.tres`, 6 escenas nuevas, `Caster/Actions` vacío, `tag` → `spell`, README | e1, e2, e4 | — |
| **e6** habilidades y orden del libro | `AbilityType.flags*/amount2/args` → campos; `spell_order` → nivel + posición. Plan corto propio | 055c3 cerrado | — |

e1: (1) `spell_fields_055e.py` congela `debug/suite/spell_bits_055e.txt` y reescribe los 53 `.tres`; (2) `spell_type.gd`; (3) `legacy_spell_bits.gd` (copia literal de la lógica de bits de hoy); (4) `spell_field_cases.gd`; (5) `ai_spell_eval`, `wizard_brain`, fases, `ai_rater`; (6) `carrier_hunt`, `level8_cases`; (7) casos de debug; (8) `SpellBits` + `make_spell`; (9) lint.
e2: (1) `SpellTarget`; (2) `aim_at_body` + `LaunchPoint`; (3) las 5 acciones y sus `.tscn`; (4) `AfflictAction`, carrier, `AiLineOfFire`, `chain_cases`; (5) borrar `aimed_action.gd`; (6) lint.
e4: (1) `WizardBody.book` y señal; (2) `Spellbook.wizard`, `current_book`, rebuild; (3) socket en `wizard_body.tscn`; (4) `GodBook.level_of(type)` y `GameData.creature_level`; (5) `rock_hit.wizard_book`, `mixed_book.tres`, `book_override.tscn`; (6) `book_cases`.
e5: (1) hijo `Mesh` con los mismos números de hoy y `%Mesh`; (2) fuera `_add_visual`; (3) Rock: `rock_mesh` → `Mesh.mesh`, esfera de respaldo como sub-recurso.
e3: (1) las 6 escenas copiando los knobs de `wizard_body.tscn:298-334` (Guardian con el mismo `rules`); (2) `action` en los 13 `.tres`; (3) vaciar `Caster/Actions`; (4) `tag` → `spell`, fuera `tag =`; (5) `Caster.action_for` por `spell`; (6) `spell_link_cases`; (7) README.

## 10. Pruebas (orquestador, al final; determinismo pospuesto)
Import → lint (ningún conteo sube) → `rules_suite --fixed-fps 600` → casos del corte → `run_net_quick.sh`.
- **`spell_field_cases` (e1):** campo por campo contra el CSV; decisión por decisión `LegacySpellBits` (CSV) vs `AiSpellEval` (`SpellType`): `rating_fn`, `casts_in(ATTACK/SUPPORT)` vs `accepts(mask)`, `wants_acc`, `ai_only_on_self`, `lands_on` (WIZ/CRE/STR/NONE), tupla de `can_cast_on`, torre de `wizard_brain` en los 5 libros, inclusión en `ai_rater`. Nombre `<tag>_<decisión>`; al fallar imprime los dos valores. «Builder igual a datos»: `SpellBits.apply` sobre el CSV da los booleanos del `.tres`.
- **`book_cases` (e4):** sin override el libro de Pyro a nivel 3; con `mixed_book`, sus 4 hechizos + la torre; `book = null` vuelve al del dios; `up_to` por índice; `book_changed` reconstruye una vez.
- **`spell_link_cases` (e3 + e5):** los 53 con `action` de profundidad 1; `Caster/Actions` vacío; `action_for(tag)` con `spell` correcto; Fireball, Rock y Swarm con `%Mesh`.
- Siguen verdes sin cambios de comportamiento: ai, ward, control, chain, zone, cloud, level8, soul, wall, stalk, tornado, tower, guardian, teleport, convert, action.
- Visibles (e4, e5): F6 en `book_override.tscn`; `cast_pyro`, `cast_charnel`, `cast_heal` con las bolas iguales; `match_shots --cast=brif|mrws|kcor` contra antes (tamaño de esfera ±1 px).

## 11. Riesgos
1. `ai_use` horneado con el `effect_range_m` de hoy (buscado). 2. Bits sin lector se pierden (quedan en CSV y git). 3. Paridad de `SpellTarget`: `OWN_OR_SELF`/`NOT_OWN` comparan `owner_slot` como hoy; `alive_only = false` en Heal y Speedup. 4. e3 instancia en diferido 13 acciones (sin física ni `_process`). 5. e1 y e3 editan los mismos 13 `.tres`; e3 va después. 6. Casos que afirman `ai_use == NONE` se cambian en e1 a «rating_fn igual al legado». 7. El override del libro no viaja por red (aviso). 8. `AiUse` y `Who` se guardan como enteros: solo agregar al final. 9. `bake_catalog` sigue siendo destructivo. 10. Rarezas conservadas a propósito (Meanstalks y Rainbow como HEAL; Halo de ataque solo sobre sí; Charm y Death en ataque con FN_NONE): entrada para 055f.
Fuera de alcance: `AbilityType`/`spell_order` (e6), unificar blancos IA/clic (055f), `SpellSpawner.projectiles` (fase 3), FX por texto (055x), nombres humanos de los `.tres` (055i), partir `caster.gd`/`wizard_body.gd`, `PlayerStart.book`.

## 12. Checklist de los 41 (Shrine + niveles 2–8)
| # | Hechizo | Dios · nv | Acción | ai_use · fase | Caso |
|---|---|---|---|---|---|
| 1 | Shrine (pcas) | todos · 3 | structure_action.tscn (e3) | NONE · NEVER | tower_cases |
| 2 | Skin of Stone (niks) | James · 2 | ward_action | SELF_GUARD · SUPPORT | ward_cases |
| 3 | Air Shield (dlhs) | Stratos · 2 | ward_action | SELF_GUARD · SUPPORT | ward_cases |
| 4 | Ethereal Form (mrfe) | Persephone · 2 | ward_action | SELF_GUARD · SUPPORT | ward_cases |
| 5 | Fireform (mrff) | Pyro · 2 | ward_action | SELF_GUARD · SUPPORT | ward_cases |
| 6 | Protective Swarm (rwsp) | Charnel · 2 | ward_action | SELF_GUARD · SUPPORT | ward_cases |
| 7 | Freeze (zerf) | Stratos · 3 | freeze_action | DISABLE_FOE · ATTACK | control_cases |
| 8 | Grasping Vines (eniv) | Persephone · 3 | grasping_vines_action | DISABLE_FOE · ATTACK | control_cases |
| 9 | Rings of Fire (rapf) | Pyro · 3 | rings_of_fire_action | DISABLE_FOE · ATTACK | control_cases |
| 10 | Slime (htel) | Charnel · 3 | slime_action | DISABLE_FOE · ATTACK | control_cases |
| 11 | Soul Mole (pmcd) | James · 3 | soul_mole_action | NONE · NEVER | soul_cases |
| 12 | Animate Dead (deda) | Charnel · 4 | animate_dead_action | NONE · NEVER | animate_dead_cases |
| 13 | Soul Wind (dnws) | Stratos · 5 | soul_wind_action | NONE · NEVER | soul_cases |
| 14 | Chain Lightning (ntlc) | Stratos · 4 | chain_lightning_action | HIT_AREA · ATTACK | chain_cases |
| 15 | Rainbow (wobr) | Persephone · 4 | rainbow_action | HEAL · SUPPORT | chain_cases |
| 16 | Dragonfire (rifd) | Pyro · 4 | dragonfire_action | HIT_AREA · ATTACK | chain_cases |
| 17 | Halo of Earth (olah) | James · 5 | halo_action | HIT_AREA · ATTACK (solo sobre sí) | chain_cases |
| 18 | Explosion (pxef) | Pyro · 5 | explosion_action | HIT_AREA · ATTACK | zone_cases |
| 19 | Frozen Ground (zorf) | Stratos · 6 | frozen_ground_action | HIT_AREA · ATTACK | zone_cases |
| 20 | Demonic Rift (tfir) | Charnel · 5 | demonic_rift_action | HIT_AREA · ATTACK | rift_cases |
| 21 | Healing Aura (ruah) | Persephone · 6 | healing_aura_action | HEAL · SUPPORT | aura_cases |
| 22 | Firewall (lwrf) | Pyro · 6 | firewall_action | HIT_AREA · ATTACK | wall_cases |
| 23 | Wall of Spikes (laws) | James · 6 | wall_of_spikes_action | HIT_AREA · ATTACK | wall_cases |
| 24 | Wailing Wall (laww) | Charnel · 6 | wailing_wall_action | HIT_AREA · ATTACK | wall_cases |
| 25 | Vinewall (lawv) | Persephone · 7 | vinewall_action | HIT_AREA · ATTACK | wall_cases |
| 26 | Fence (cnef) | Stratos · 7 | fence_action | HIT_AREA · ATTACK | wall_cases |
| 27 | Rain of Frogs (grfr) | Persephone · 5 | rain_of_frogs_action | HIT_AREA · ATTACK | cloud_cases |
| 28 | Rain of Fire (rifr) | Pyro · 7 | rain_of_fire_action | HIT_AREA · ATTACK | cloud_cases |
| 29 | Plague (galp) | Charnel · 7 | plague_action | HIT_AREA · ATTACK | cloud_cases |
| 30 | Cloudkill (likc) | Stratos · 8 | cloudkill_action | HIT_AREA · ATTACK | cloud_cases |
| 31 | Bombardment (rtem) | James · 7 | bombardment_action | HIT_AREA · ATTACK | cloud_cases, dent_cases (abolladuras pendientes) |
| 32 | Charm (mrhc) | Persephone · 8 | charm_action | NONE · ATTACK | level8_cases |
| 33 | Blind Rage (egar) | Pyro · 8 | blind_rage_action | HIT_AREA · ATTACK | level8_cases |
| 34 | Intestinal Vaporization (pavi) | Charnel · 8 | vaporization_action | HIT_ONE · ATTACK | level8_cases |
| 35 | Bovine Intervention (ivob) | James · 8 | bovine_intervention_action | HIT_ONE · ATTACK | level8_cases |
| 36 | Death (taed) | Charnel · 8 | death_action | NONE · ATTACK | level8_cases (`max_targets = 8`) |
| 37 | Meanstalks (rter) | Persephone · 8 | meanstalks_action | HEAL · SUPPORT (rareza) | stalk_cases |
| 38 | Tornado (nrot) | Stratos · 8 | tornado_action | HIT_AREA · ATTACK | tornado_cases (visual pendiente) |
| 39 | Erupt (tpre) | James · 4 | erupt_action | HIT_AREA · ATTACK | terrain_cases |
| 40 | Volcano (clov) | Pyro · 8 | volcano_action | HIT_AREA · ATTACK | terrain_cases (visual a pulir) |
| 41 | Bore (erob) | James · 8 | bore_action | NONE · NEVER | bore_cases |
Los 12 de siempre (kcor, ntil, mrws, brif, oalf, laeh, pups, htlm, ndrg, ccas, ucas, elet) no son parte de los 41: e3 les da `action` y e2 los pasa a profundidad 1.

## 13. Preguntas (recomendaciones aprobadas)
1. Fase de la IA: enum `AiPhase { NEVER, ATTACK, SUPPORT }`. 2. Bits sin lector: se borran (quedan en el CSV). 3. Rarezas de la IA: no se corrigen (e1 es paridad); van a 055f. 4. `PlayerStart.book` y override en red: no por ahora. 5. `bake_catalog` escribe los campos por `SpellBits`. 6. `AbilityType` y `spell_order`: e6, después de 055c3. 7. Blancos IA y clic duplicados: se unifican en 055f. 8. `SpellAction.tag` → `spell` con `tag` getter: sí. 9. Guardian conserva su `rules`. 10. La checklist vive en este plan + una línea en RFC-055 §12.2.
