# Plan 055r: los radios de lugar que quedan en `MatchRules`

> **Aprobado de antemano (2026-10-25):** el usuario dio por buenas las recomendaciones de §13. Lo guarda el orquestador.

Base: `main` en 5d3ca91e (055g cerrado, C20 = 8). Autoridad: CONVENTIONS (C16, C20, §2b, §2c) > RFC-055 (§13.2b C-5, §15) > 055g (§0.3, §13 preguntas 1, 2, 3 y 6) > 055s > este plan. En paralelo: **055c4** (`unit.tscn`, `unit_body.gd`, `Locomotion`…), que este corte no toca.

## 0. Contradicciones (y cuál gana)
1. C-5 y las auditorías piden la forma con gizmo en la escena del altar, el manantial y el doctor; un `Area3D` instanciado mueve la simulación. Gana la lección (precedente 055g): los radios viven en una escena aparte que la partida **nunca instancia** y se lee por `SceneState`. `altar.tscn`, `manafount.tscn` y `unit.tscn` no ganan física.
2. `tower.tscn` ya tiene `ManaSource/Reach` (Area3D, 50 m) instanciado: está en la base; no se toca ni se copia (§13.6).
3. «8 campos»: `guardian_leash` (50 m) es el mismo tipo de dato aunque el lint no lo cuente. Se mueven **9 campos**; C20 8 → 0.
4. Los dos 0,9 fijos del guardián: el lazo lee un `Marker3D` `Guardian/LeashFrom` (0; 0,9; 0) para que la simulación dé lo mismo; el rayo (presentación) pasa a `BodyFacts.of_body(creature).center`.
5. Excepción a «probar todo al final»: r0 graba la base de la línea de tiempo antes de integrar r3.
6. `scenes/match/README.md` gana las cinco líneas en r4.
7. RFC-021 y el CHANGELOG nombran los campos viejos: historia, no se reescriben.

## 1. Objetivo
- **Las reglas no cambian:** almas, maná del manantial y del altar, aura y rampa del Manahoar, armar Guardian, correa y vuelta del guardián, bit a bit. Los 9 valores salen como los mismos doubles (`SceneStateReader.mm`).
- **Los 9 alcances con gizmo** en `scenes/match/reach_places.tscn`. `MatchRules` queda con tasas y balance (C20 8 → 0).
- Nada por tick hace `load()`/`find()`: `ReachFacts.of_rules(rules)` es una búsqueda en un diccionario después de la primera vez.
- La escena nunca se instancia (caso de la suite; el dedicado no gana `Area3D`).
- C16 29 → 27 (los dos 0,9).

## 2. Escenas
- Editar: `scenes/match/reach_places.tscn`.
- Jugar (ya existen): `debug/map/mana_fount.tscn`, `debug/sacrifice/soul_pickup.tscn`, `debug/spells/guardian_altar.tscn`.
- Variante de suite: `debug/match/far_reach_places.tscn` (heredada, solo `Mana/Bounds/Fount` en 80 m).
- Medir: `debug/sacrifice/ritual_timeline.tscn`.

## 3. Árbol
```
scenes/core/scene_state_reader.gd   [~] + radius() y half_height() (sale de SacrificeFacts._radius)
scenes/core/place_warnings.gd       [+] static: avisos de un frame de lugares. Lo usan SacrificeFrame y ReachFrame. ~35
scenes/sacrifice/sacrifice_facts.gd [~] _radius → SceneStateReader.radius (mismo resultado)
scenes/sacrifice/sacrifice_frame.gd [~] avisos → PlaceWarnings.check (mismos textos)
scenes/match/reach_places.tscn      [+] §5.1; nunca se instancia
scenes/match/reach_frame.gd         [+] @tool raíz: sockets tipados + avisos. ~55
scenes/match/reach_facts.gd         [+] RefCounted: los 9 alcances desde el SceneState, cacheados. ~80
scenes/match/match_rules.gd         [~] (C) r2: + reach_places · r4: − 9 campos
scenes/match/README.md              [~] cinco líneas
scenes/souls/soul_system.gd         [~] radio en el plano y mitad de la altura desde ReachFacts
scenes/map/props/mana_source.gd     [~] FOUNT/ALTAR desde ReachFacts
scenes/units/unit_mana_support.gd   [~] (C) aura, pico y fin desde ReachFacts; setup() igual
scenes/spells/actions/guardian_action.gd   [~] radio para armar desde ReachFacts
scenes/spells/guardian/guardian_bond.gd    [~] (C) correa, vuelta y LeashFrom desde ReachFacts; − CENTER_HEIGHT
scenes/spells/guardian/guardian_tether.gd/.tscn [~] extremo = BodyFacts.of_body(creature).center; − center_height
debug/match/far_reach_places.tscn   [+]
debug/suite/reach_places_cases.gd   [+] ~90
debug/suite/rules_suite.gd          [~] (C)
debug/suite/guardian_cases.gd       [~] RULES.guardian_* → ReachFacts.of_rules(RULES)
debug/rules/*.tres (23) + agent/fixtures/rfc022c_rules_persephone.tres, pt97_heal_rules_persephone.tres [~] r4: − soul_collect_distance, manafount_radius, altar_radius
tools/lint/baseline.txt             [~] al cerrar
rfcs/RFC-055-human-first-refactor.md [~] C-5: 055r hecho
```
No se tocan: `unit.tscn`, `unit_body.gd`, `creature_fx.gd`, `wizard_body.gd`, `altar.tscn`, `manafount.tscn`, `tower.tscn`, `map_props.gd`, `guard_post.gd`, `sacrifice_places.tscn`.

## 4. Responsabilidades
| Pieza | Hace | No hace |
|---|---|---|
| `reach_places.tscn` / `ReachFrame` | Muestra los 9 alcances con gizmo; avisa si falta algo | Correr en partida |
| `ReachFacts` | Lee la escena por `SceneState` y da metros (`mm`) y `leash_from` | Decidir, elegir escena |
| `SceneStateReader` | Nodos, forma, marcador, radio, mitad de la altura | Saber qué significa un lugar |
| `PlaceWarnings` | Avisos comunes de un frame de lugares | Leer `SceneState` |
| `MatchRules.reach_places` | Qué escena de alcances usa una regla | Guardar radios |
| Lectores (SoulSystem, ManaSource, UnitManaSupport, GuardianAction, GuardianBond) | Usan el alcance como hoy | Guardar el número |
| `GuardianTether` | Rayo hasta el `Center` del cuerpo | Leer la correa |

## 5. Composición
Todo composición, herencia ≤1. Ningún `_physics_process` nuevo; cada lector cambia una expresión (`rules.x` → `ReachFacts.of_rules(rules).x_m`).

### 5.1 La escena
```
ReachPlaces (Node3D, ReachFrame @tool)   ← nunca se instancia
├── Souls / Bounds (Area3D off) / Collect  CylinderShape3D r 5, altura 10   (radio en el plano; la mitad de la altura arriba y abajo)
├── Mana / Bounds / Fount SphereShape3D r 50 · Altar SphereShape3D r 50
├── Manahoar / Bounds / Aura r 40 · Peak r 50 · End r 1000   (esferas)
└── Guardian
    ├── Bounds / Arm CylinderShape3D r 50, altura 2 · Leash SphereShape3D r 50 · Return SphereShape3D r 20
    └── LeashFrom (Marker3D) (0; 0,9; 0)
```
Solo se lee el radio (y la mitad de la altura en `Collect`).

## 6. Resources y nodos
Nodos con gizmo: §5.1. `@export`: `MatchRules.reach_places` y los sockets de `ReachFrame`. Sin Resources nuevos. Quedan en `MatchRules`: `manafount_rate`, `altar_rate`, `manahoar_rate`, `guardian_attack_factor`, `guardian_spell_factor`, `guardian_ranged_factor`, `guardian_heal_per_s`. `ManaSource.CUSTOM` y la torre sin cambios.

## 7. Los seis verbos
| Verbo | Qué abre y qué toca | Lugares |
|---|---|---|
| Entender | `scenes/match/README.md` → `reach_places.tscn` | 1–2 |
| Modificar | Manija o `radius` en `reach_places.tscn`; tasas en `data/match_rules.tres` | 1 |
| Agregar | Otra fuente de maná: un `ManaSource` CUSTOM con su `reach` en la escena del edificio. Un alcance nuevo: nodo + `@export` en `ReachFrame` + una línea en `ReachFacts._read` | 1 / 2 (+1 línea) |
| Quitar | Sacar el hijo (`ManaSupport`, `GuardianBond`, `ManaSource`); sin forma, el frame avisa y vale el de fábrica | 1 |
| Crear | Escena heredada asignada en `MatchRules.reach_places` | 2 |
| Escalar | Alcances por edificio o criatura: no por ahora (§13.1, §13.6) | 2 |

## 8. Compartido
055c4: `unit_mana_support.gd` (3 expresiones y el doc; la API y `setup` quedan), `guardian_bond.gd` (solo `_keep_near` y la constante), `guardian_tether.gd` (necesita que `UnitBody.mount` siga existiendo: **055c4 no renombra `mount`**). Otros: `match_rules.gd`, los `.tres` de reglas, `rules_suite.gd`, `baseline.txt`, una celda del RFC. 055g: `sacrifice_facts.gd` y `sacrifice_frame.gd` solo delegan (`sacrifice_places_cases` PASS).

## 9. Contratos
### 9.1 Lo que no cambia
`ManaSource` (`Kind`, `rate`, `radius`, `reach`, `reach_m()`, `reaches()`, `source_name()`, grupo `mana_source`, comparación estricta `<`); `UnitManaSupport` (API y rampa `d ≤ near → peak·d/near`; `near < d < far → peak·(far−d)/(far−near)`); `SoulSystem._try_collect` (`> r²` en el plano y `abs(dy) > h`, mismo orden); `GuardianAction.arm_status` (`FAR_FROM_BUILDING` con `GuardPost.closest(..., arm_m)`); `GuardianBond._keep_near` (`gap = pos + leash_from − attach`, `≤ leash²`, `spot = attach + return·gap.normalized()`); cable y replicación.

### 9.2 Lo nuevo
```gdscript
# SceneStateReader
static func radius(nodes: Dictionary, root: Dictionary, prop: String, fallback: float) -> float
static func half_height(nodes: Dictionary, root: Dictionary, prop: String, fallback: float) -> float

class_name PlaceWarnings extends RefCounted
static func check(shapes: Dictionary[String, CollisionShape3D], marks: Dictionary[String, Marker3D]) -> PackedStringArray

@tool
class_name ReachFrame extends Node3D
@export_group("Souls")    @export var soul: CollisionShape3D
@export_group("Mana")     @export var fount: CollisionShape3D ; @export var altar: CollisionShape3D
@export_group("Manahoar") @export var manahoar_aura / manahoar_peak / manahoar_end: CollisionShape3D
@export_group("Guardian") @export var guardian_arm / guardian_leash / guardian_return: CollisionShape3D ; @export var guardian_leash_from: Marker3D

class_name ReachFacts extends RefCounted
var soul_m := 5.0; var soul_up_m := 5.0
var fount_m := 50.0; var altar_m := 50.0
var manahoar_aura_m := 40.0; var manahoar_peak_m := 50.0; var manahoar_end_m := 1000.0
var guardian_arm_m := 50.0; var guardian_leash_m := 50.0; var guardian_return_m := 20.0
var guardian_leash_from := Vector3(0.0, 0.9, 0.0)
static func of(scene: PackedScene) -> ReachFacts        # cacheado; get_state(), NUNCA instantiate()
static func of_rules(rules: MatchRules) -> ReachFacts

# MatchRules (r2; los 9 campos se borran en r4)
@export var reach_places: PackedScene = preload("res://scenes/match/reach_places.tscn")
```
Reglas: ningún `instantiate()` de `reach_places.tscn`; nada de `load()` por tick; no cachear `ReachFacts` en `setup()` (`team_cases` asigna `rules` sin `setup`); misma aritmética y orden; `## Ref:` al final; README con `Check:`.

## 10. Sub-cortes
| # | Qué | Depende de |
|---|---|---|
| r0 | **El orquestador** graba la base de los 7 casos de `ritual_timeline` en `agent/out/055r/before/` | — |
| r1 | `SceneStateReader.radius/half_height`, `PlaceWarnings`; `SacrificeFacts` y `SacrificeFrame` delegan | — |
| r2 | `reach_frame.gd`, `reach_facts.gd`, `reach_places.tscn`, `MatchRules.reach_places` (sin borrar), `far_reach_places.tscn`, `reach_places_cases.gd` + suite | r1 |
| r3a | `soul_system.gd`, `mana_source.gd`, `unit_mana_support.gd` | r2 |
| r3b | `guardian_action.gd`, `guardian_bond.gd`, `guardian_tether.gd/.tscn`, `guardian_cases.gd` | r2 |
| r4 | Borrar los 9 campos; quitar las 3 líneas de los 25 `.tres`; grep sin restos; README; baseline; RFC; §14 | r1–r3 |

## 11. Pruebas
1. Import. 2. Lint: C20 8 → 0, C16 29 → 27, nada sube. 3. Línea de tiempo del ritual, 7 casos, **diff vacío contra `agent/out/055r/before/`** (`altar_radius` toca el maná del blanco). 4. `reach_places_cases`: `facts_match_old_rules` (9 valores con `!=` contra 5, 5, 50, 50, 40, 50, 1000, 50, 50, 20 y `leash_from == Vector3(0, 0.9, 0)`), `far_variant`, `never_instanced`, `cached`, `frame_warnings`; `sacrifice_places_cases` sigue PASS. 5. `rules_suite --fixed-fps 600` PASS (soul, guardian, team). 6. NET QUICK PASS. 7. Rayo del guardián: |y − (pies + center.y)| ≤ 1e-3 en `guardian_altar.tscn` + PNG. 8. Dedicado: 0 `Area3D` de lugares; tiempo y memoria ±2 % (hoy 2,34 s / 332 MB).

## 12. Riesgos
Física instanciada (`never_instanced`) · float32 (todos exactos; 0,9 como `Vector3` de 32 bits como hoy) · `team_cases` sin `setup` · `.tres` con campos borrados (grep vacío) · merges con 055c4 · `UnitBody.mount` · dos lugares para el alcance del maná (torre) · valor de fábrica silencioso (lo cubre el aviso). Fuera de alcance: `Reach` de la torre, el `Center` real en la correa, otros 0,9 de C16, la IA, el banco, `sacrifice_places.tscn`.

## 13. Preguntas (recomendaciones aprobadas)
1. Una sola escena con grupos por sistema. 2. Nombres `reach_places.tscn`, `ReachFrame`, `ReachFacts`, `MatchRules.reach_places`. 3. Incluir `guardian_leash` (9 campos). 4. La correa sigue desde 0,9 (`LeashFrom`); pasar al `Center` real es otra decisión. 5. El rayo usa `BodyFacts.center`. 6. El `Reach` de la torre no se muda en 055r. 7. El alma como cilindro con altura. 8. No se fusiona con `sacrifice_places.tscn`. 9. Base nueva de la línea de tiempo en r0. 10. Limpiar los 25 `.tres` con `sed` en r4. 11. Variante `far_reach_places.tscn` solo para la suite. 12. `PlaceWarnings` y `SceneStateReader.radius` compartidos.

## 14. Cierre (r4)
Hecho: los 9 campos ya no existen en `MatchRules`; los radios salen de `reach_places.tscn` vía `ReachFacts`. C20 8 -> 0.

Cambios respecto del plan:
- Al borrar, el grep no encontró lectores restantes fuera de `reach_places_cases` (r1-r3 los habían movido todos, IA y debug incluidos).
- Los `.tres` guardaban solo 3 de los 9 campos (`soul_collect_distance`, `manafount_radius`, `altar_radius`, todos en su valor por defecto): se quitaron esas 3 líneas, textuales, de 25 archivos (23 de `debug/rules/` más los 2 fixtures de `agent/`; el grep no halló otros).
- `reach_places_cases.facts_match_old_rules` conserva solo los literales (5, 5, 50, 50, 40, 50, 1000, 50, 50, 20 y `leash_from` 0,9); se quitó la parte que leía los campos viejos.
- `guardian_leash` y similares siguen como nombres de nodo/socket de `ReachFrame` y `reach_places.tscn`: no son campos de reglas.
- `scenes/match/README.md` con las cinco líneas y `Check:`. El baseline del lint lo actualiza el orquestador.
- No se corrió Godot ni banco en r4 (orden del orquestador); la verificación en ejecución queda para la pasada final.
