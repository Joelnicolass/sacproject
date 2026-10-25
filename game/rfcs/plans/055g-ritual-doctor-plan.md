# Plan 055g: el ritual y el doctor

> **Aprobado de antemano (2026-10-25):** el usuario dio por buenas las recomendaciones de §13 («sigue y da por bueno el siguiente rfc»). Lo guarda el orquestador.

Base: `main` en c5446b15 (055c2 integrado; 055a-5 cerrado). Autoridad: CONVENTIONS > RFC-055 (§13.2 «Ritual y doctor», §15, §16) > 055a-5 §13/§16 > 055s §14 > este plan. En paralelo: 055c3, 063-1, 055e.

## 0. Contradicciones (y cuál gana)
1. **«Ritual como FSM con nodos y `.tres`», pero el ritual ya es una FSM** (`Phases`: Off/Setup/Walk/Shoot/Wait/Ended; el doctor y el recado también). Lo calcado es otra cosa: tres archivos dios (`sacrifice_system.gd` 494, `doctor_body.gd` 401, `ritual.gd` 311), los lugares como números en `MatchRules`, las ramas `if kind == DESECRATE` y los nodos armados con código en `RitualFx`. Gana la intención: no se rehace la FSM; el `.tres` es `RitualType`, los lugares van a una escena y los archivos dios se parten en hijos.
2. **055s §14: la aguja es `HandR/Socket`**, pero no existe. sacengine usa el hueso 16 con desvío (0, 0, 2,2) y el eje z del hueso (`sacobject.d:360-366`). Gana el original: `Needle` (`BoneAttachment3D`, `bone_16`) + `Tip` (`Marker3D`) en `sac_doctor_model.tscn`, publicado como `BodyModel.tool_socket`. La conversión del eje al `.glb` es **NO VERIFICADA** y se cierra con §11.7.
3. **C20 («un radio es un `CollisionShape3D`») vs. `BodyFacts`** (un `Area3D` instanciado mueve la simulación). Se cumplen las dos: los radios viven en `sacrifice_places.tscn`, que la simulación **nunca instancia** y lee por `SceneState`. `ritual.tscn` y `doctor.tscn` no ganan física.
4. **C-5 le da los 17 C20 a 055r; §15 dice que 055g absorbe los marcadores del ritual.** Gana §15: 055g se lleva los 9 C20 del sacrificio (`doctor_drop_height`, `doctor_drop_distance`, `desecrate_pickup_distance`, `carry_height`, `carry_distance`, `ritual_start_distance`, `ritual_radius`, `ritual_creature_height`, `ritual_push_radius`) y 4 distancias que el lint no cuenta (`doctor_exit_depth`, `ritual_walk_shrink`, `ritual_push_inner`, `convert_reach`). 055r se queda con los otros 8.
5. **«Probar todo al final» vs. comparar antes y después.** Excepción chica (precedente: el spike de 055a-5): g0 graba la base una vez, headless, antes de integrar g1.
6. El README de `scenes/sacrifice` no tiene las cinco líneas: se corrige en g6.
7. Los presets del banco mezclan reglas y lugares (`ritual_barrier.tres`): la variante queda en dos piezas (reglas + escena heredada de lugares). Aceptado.

## 1. Objetivo
- **Las reglas no cambian:** tiempos de fases, rondas, vida y maná drenados por ronda, puntos del anillo, caída del doctor, cuelgue del cautivo, empuje, resultado y almas pagadas iguales a la base (línea de tiempo de g0, §11.3).
- **Los lugares del sacrificio se ven y se mueven con el gizmo** en una sola escena. `MatchRules` queda con tiempos y balance (C20 17 → 8).
- **Desecrate y Convert se distinguen por un `RitualType` (.tres)**, no con `if kind ==`. El ritual se arma con hijos que se pueden sacar (`Lift`, `Watch`, `Drain`, `Payoff`, `Push`, `Fx`).
- **`SacrificeSystem`, `Ritual` y `DoctorBody` quedan como raíces flacas**; su API pública no cambia (§9.1).
- **La aguja es un hueso del modelo** (`BodyModel.tool_socket`) y **el anillo del cautivo es `CaptiveRing`**, centrado en el `Center` del cuerpo.

## 2. Escena de prueba
- Para editar: `scenes/sacrifice/sacrifice_places.tscn` (grupos `Ritual`, `Carry`, `Drop`).
- Para jugar: `debug/sacrifice/desecrate_carry.tscn` (`spell_3` + clic sobre `Offering`, flujo `agent/flows/pt59_zoom.json`): la cuerda sale de la punta de la jeringa en `run`, `cast` y `attack`. `debug/sacrifice/convert_ritual.tscn` + `rfc020e_convert_solo.json` / `pt61b_ritual_close.json`.
- Banco: `ritual_barrier.tscn` pasa a `debug/sacrifice/barrier_places.tscn` (heredada, `Push` 24 m).
- Medir (nuevo): `debug/sacrifice/ritual_timeline.tscn` (headless, `-- --case=<c> --out=<f>`).

## 3. Árbol
`[+]` nuevo · `[~]` cambia · `[>]` git mv · **(C)** compartido
```
scenes/core/
  scene_state_reader.gd        [+] static: nodos de un SceneState, forma o marcador por la ruta exportada en la raíz, mm(). ~50
  debug_log.gd                 [~] (C) categoría &"ritual"
scenes/bodies/
  body_facts.gd                [~] usa SceneStateReader (mismo resultado)
  body_model.gd                [~] (C) @export var tool_socket: Node3D
  body_rig.gd                  [~] (C) func tool_socket() -> Node3D
  models/sac_doctor_model.tscn [~] Model/Skeleton3D/Needle (BoneAttachment3D bone_16) + Needle/Tip; tool_socket = Tip
scenes/match/match_rules.gd    [~] (C) g1: + sacrifice_places: PackedScene; g6: − los 13 campos de lugar
scenes/sacrifice/
  README.md                    [~]
  sacrifice_places.tscn        [+] escena de lugares (§5.1). Nunca se instancia
  sacrifice_frame.gd           [+] @tool raíz: sockets + avisos. ~60
  sacrifice_facts.gd           [+] RefCounted: lugares en metros desde el SceneState, cacheados. ~90
  sacrifice_ground.gd          [+] static: altura y «hay suelo» (único punto de suelo del sistema). ~25
  sacrifice_system.gd/.tscn    [~] fachada ≤150; + hijos Spawns, Targets, Casts, Starter (los MpSpawner y raíces NO se mueven)
  sacrifice_spawns.gd          [+] arma y replica doctores, vórtices, rituales; contadores de nombres. ~130
  sacrifice_targets.gd         [+] preguntas: altares, sitios, estado de Desecrate/Convert, wizard_of. ~110
  sacrifice_casts.gd           [+] ciclo del lanzamiento: vórtice, salida, aterrizaje, finish/cancel. ~140
  ritual_starter.gd            [+] empieza el ritual cuando llega el portador; cola de espera. ~90
  ritual.gd/.tscn              [~] raíz ≤150; + Lift, Watch, Drain, Payoff (ANTES de Phases); types; marcadores de Fx; blood_fx
  ritual_type.gd               [+] Resource (§9.2). ~25
  ritual_lift.gd, ritual_watch.gd, ritual_drain.gd, ritual_payoff.gd [+]
  ritual_push.gd, ritual_fx.gd, ritual_step.gd, ritual_states/*.gd [~]
  doctor_body.gd               [~] raíz ≤200; señal pose_changed
  doctor_motor.gd              [+] caminar, girar, evitación, move_and_slide; PathFollower por @export. ~120
  doctor_look.gd               [+] clip por pose y trabajo; fundido al morir (presentación). ~80
  doctor.tscn, carrier_doctor.tscn, ritual_doctor.tscn, doctor_states/*, errand_states/*, errand_step.gd, carry_errand.gd, stuck_guard.gd [~]
  carry_rope.gd                [~] g4: aguja = rig.tool_socket(); g5: anillo = CaptiveRing
data/sacrifice/desecrate_ritual.tres, convert_ritual.tres [+]
scenes/units/ (g5, después de 055c3)
  captive.gd                   [~] sin anillo; cuelgue de SacrificeFacts; health/orders por @export
  captive_ring.gd              [+] anillo mientras está HELD; CaptiveRing.of(unit). ~70
  unit.tscn (C), README.md     [~]
debug/sacrifice/ritual_timeline.gd/.tscn [+] (g0) · barrier_places.tscn [+]
debug/rules/ritual_barrier.tres [~] (g6)
debug/suite/sacrifice_places_cases.gd, ritual_parts_cases.gd [+] · sacrifice_cases.gd, convert_cases.gd [~] (g6) · rules_suite.gd [~]
```
Se borra el nodo `CarryRope/Needle` de `doctor.tscn`.

## 4. Responsabilidades
| Pieza | Hace | No hace |
|---|---|---|
| `SacrificeSystem` | Puerta única: señales, API de hoy, `_rules()` | Lógica propia; spawnear |
| `SacrificeSpawns` | Arma doctores, vórtices, rituales; un contador por tipo | Decidir dónde ni cuándo |
| `SacrificeTargets` | Qué se puede profanar o convertir; altar o sitio más cercano; `wizard_of(slot)` | Escribir estado |
| `SacrificeCasts` | Del inicio al fin del lanzamiento | Empezar el ritual |
| `RitualStarter` | Del portador que llegó al ritual; espera si el sitio está ocupado | Las rondas |
| `SacrificeGround` | Altura y «hay suelo» | Nada más |
| `SacrificeFrame` / `SacrificeFacts` | Lugares con gizmo / en metros, una vez por escena | Correr en partida / instanciar |
| `Ritual` | Estado replicado; begin, finish_round, complete, abort; avanza los hijos en orden fijo | Drenar, pagar, mover la criatura |
| `RitualType` | Qué distingue una clase de ritual | Números de balance |
| `RitualLift` / `Watch` / `Drain` / `Payoff` | Subir y sostener / cancelar / drenar y caída del altar / pagar al completar | — |
| `DoctorBody` / `DoctorMotor` / `DoctorLook` | Estado y verbos / paso en el suelo / clips | — |
| `CarryRope` / `Captive` / `CaptiveRing` | Cuerda desde `tool_socket` / tomar, soltar, revivir / anillo en HELD | Simulación (Rope, Ring) |

## 5. Composición
Todo composición; herencia ≤1. Desecrate y Convert son dos `.tres` de un mismo `ritual.tscn` (el cable no cambia). **Orden de simulación sin cambios:** `Ritual._physics_process` llama `lift.step(delta)` y después `watch.step()`; después `Phases` y `Push`. `SacrificeSystem._physics_process` llama `starter.retry_waiting()` antes de sus hijos. Los hijos nuevos no tienen `_physics_process` propio.

### 5.1 La escena de lugares
```
SacrificePlaces (Node3D, SacrificeFrame @tool)   ← nunca se instancia; se lee por SceneState
├── Ritual (Node3D)              origen = centro del sitio
│   ├── Bounds (Area3D)          monitoring/monitorable off, capa y máscara 0
│   │   ├── Ring        CylinderShape3D r 20   anillo de los doctores
│   │   ├── RingEnd     CylinderShape3D r 17   cierre en el último quinto de la caminata
│   │   ├── Push        SphereShape3D   r 20   borde del empuje
│   │   ├── PushCore    SphereShape3D   r 5    núcleo del empuje
│   │   └── CarrierStop SphereShape3D   r 20   el portador pide el ritual adentro
│   └── Hang (Marker3D)          (0, 15, 0)     criatura sobre el sitio
├── Carry (Node3D)               origen = pies del doctor, mira a +Z
│   ├── Bounds (Area3D) / Pickup CylinderShape3D r 10 · PumpReach CylinderShape3D r 2
│   └── Hang (Marker3D)          (0, 3,5, −2,7)
└── Drop (Node3D)                origen = el blanco; el lanzador hacia −Z
    └── Vortex (Marker3D)        (0, 15, −20)
        └── Exit (Marker3D)      (0, −2,25, 0)
```
Las medidas pasan por `SceneStateReader.mm()`: dan los mismos doubles que `MatchRules` hoy.

## 6. Resources y nodos
Nodos con gizmo: todo §5.1; en `ritual.tscn` los marcadores de Fx y las cuerdas; `Needle/Tip` en el modelo. Resources: `RitualType` en `data/sacrifice/*.tres` (asignados en `Ritual.types`); `ParticleType` por `@export` (`blood_fx`, `heal_fx`). `@export` de instancia: `MatchRules.sacrifice_places`; clips de `DoctorLook`. `MatchRules` se queda con `ritual_*_s`, `desecrate_*_per_round`, `convert_*`, `doctor_death_s`, `doctor_stuck_abort_s`, `carry_speed_factor`, `ritual_push_speed`, `ritual_push_edge_speed`.

## 7. Los seis verbos
| Verbo | Qué abre y qué toca | Lugares |
|---|---|---|
| Entender | README → `ritual.tscn` (hijos y `Phases`) → `sacrifice_places.tscn` | 1–2 |
| Modificar | Manijas en `sacrifice_places.tscn`; tiempos en `data/match_rules.tres`; aguja en `sac_doctor_model.tscn`; la diferencia entre rituales en su `.tres` | 1 |
| Agregar | Una parte: nodo hijo en `ritual.tscn` que escuche `round_tortured`. Una clase: duplicar un `.tres` + una línea en `Ritual.Kind` (id de red) + el hechizo (055e) | 2 (+1 línea) |
| Quitar | Borrar el hijo (Push, Drain, Fx, CarryRope, CaptiveRing) | 1 |
| Crear | Escena heredada de `sacrifice_places.tscn` asignada en `MatchRules.sacrifice_places` | 2 |
| Escalar | Un `RitualSite` más en la escena del altar o del Shrine | 1 |

## 8. Compartido con los cortes en paralelo
`match_rules.gd` (g1 agrega un export; g6 borra líneas del grupo Sacrificios) · `body_model.gd`, `body_rig.gd` (agregados de 3–4 líneas) · `unit.tscn` (**g5 después de 055c3**) · `debug_log.gd` (una categoría) · suelo (063-1 ya integró `GroundSurface`: `sacrifice_ground.gd` usa `GroundSurface.of`) · `desecrate/convert_action.gd`, `ai_perception.gd`, `fast_revive.gd`, `guardian_action.gd`: **no se tocan**.

## 9. Contratos
### 9.1 Lo que no cambia
`SacrificeSystem`: `GROUP`, `Cast`, `NO_ALTAR`, `FAR_FROM_ALTAR`, `BAD_TARGET`, `carrier_arrived`, `souls_converted`, `announce_conversion`, `closest_enemy_altar`, `altar_status`, `sacrifice_status`, `closest_own_site`, `convert_arm_status`, `convert_status`, `desecration_against`, `desecration_by`, `begin_cast`, `begin_convert_cast`, `cancel_cast`, `finish_cast`, `wizard_of`, `start_ritual`. `Ritual`: `GROUP`, `Kind`, `Phase`, `Outcome`, `kind`, `caster_slot`, `target_slot`, `creature_path`, `phase`, `round_index`, `outcome`, `rules`, `phase_changed`, `round_tortured`, `ended`, `is_running()`, `center()`, `is_part()`, `begin(unit, site, ring, wizard)`; la `SceneReplicationConfig`, idéntica. `DoctorBody`: `GROUP`, `Pose`, `Work`, `type`, `owner_slot`, `pose`, `work`, `carried`, `rules`, `health`, `mount`, señales, verbos y preguntas de hoy, replicación idéntica. Diccionarios de spawn y nombres `Doctor%d` / `Vortex%d` / `Ritual%d`, sin cambios.

### 9.2 Lo nuevo
```gdscript
class_name SceneStateReader extends RefCounted
static func nodes_of(state: SceneState) -> Dictionary
static func shape(nodes: Dictionary, root: Dictionary, prop: String) -> Shape3D
static func marker(nodes: Dictionary, root: Dictionary, prop: String) -> Vector3
static func mm(value: float) -> float

class_name SacrificeFacts extends RefCounted
var ring_m := 20.0; var ring_end_m := 17.0; var push_m := 20.0; var push_core_m := 5.0
var carrier_stop_m := 20.0; var hang_up_m := 15.0
var carry_up_m := 3.5; var carry_back_m := 2.7; var pickup_m := 10.0; var pump_reach_m := 2.0
var drop_out_m := 20.0; var drop_up_m := 15.0; var exit_down_m := 2.25
static func of(scene: PackedScene) -> SacrificeFacts        # cacheado; get_state(), NUNCA instantiate()
static func of_rules(rules: MatchRules) -> SacrificeFacts
func walk_shrink_m() -> float

class_name RitualType extends Resource
enum Ending { TARGET_WIZARD_GONE, CREATURE_HEALTH_ROUNDS }
@export var kind := Ritual.Kind.DESECRATE
@export var ending := Ending.TARGET_WIZARD_GONE
@export var drains_target_wizard := true
@export var collapses_target_altar := true
@export var marks_target_ghost := true
@export var counts_as_conversion := false

# Ritual (agregados)
@export var types: Array[RitualType]
@export_group("Parts")
@export var lift: RitualLift
@export var watch: RitualWatch
@export var drain: RitualDrain
@export var payoff: RitualPayoff
var system: SacrificeSystem
func type() -> RitualType
func simulates() -> bool

# DoctorBody (agregados)
signal pose_changed(pose: Pose, work: Work)
@export var motor: DoctorMotor
@export var errand: CarryErrand
func simulates() -> bool

class_name DoctorMotor extends Node
@export var body: DoctorBody
@export var path_follower: PathFollower
func walk_to(point: Vector3) -> void
func begin_walk(point: Vector3) -> void
func advance_on_ground(horizontal: Vector3, delta: float) -> void
func turn_toward(direction: Vector3, delta: float) -> void

# BodyModel / BodyRig
@export var tool_socket: Node3D
func tool_socket() -> Node3D

class_name CaptiveRing extends Node      # g5
@export var body: UnitBody
@export var portal_scene: PackedScene
static func of(unit: Node) -> CaptiveRing
func ring() -> Node3D
```
Las fórmulas siguen en `SacrificeMath`, con los metros de `SacrificeFacts`. `Captive.hang_point(at, facing, carry_up_m, carry_back_m)` mantiene la firma.

## 10. Sub-cortes
| # | Qué | Depende de |
|---|---|---|
| g0 | Grabador `ritual_timeline` (7 casos de §11.3) + volcado de `BodyFacts`. **El orquestador lo corre una vez sobre la base** y guarda `agent/out/055g/before/*.jsonl` | — |
| g1 | `SceneStateReader` (`BodyFacts` migrado), `SacrificeFrame`, `SacrificeFacts`, `sacrifice_places.tscn`, `MatchRules.sacrifice_places`, `barrier_places.tscn`, `sacrifice_places_cases` | g0 grabado |
| g2 | `SacrificeSystem` partido (Spawns/Targets/Casts/Starter) + `SacrificeGround`; `doctor.errand`; `ritual.system` | contratos de g1, g3, g4 |
| g3 | Partes del ritual, `RitualType` y `.tres`, estados, `RitualPush`, `RitualFx`, `blood_fx`, DebugLog, `ritual_parts_cases` | contrato de g1 |
| g4 | Doctor: Motor, Look, `errand`/`path_follower`, alcances de `SacrificeFacts`, `heal_fx`, aguja y `CarryRope` desde el hueso | contrato de g1 |
| g5 | `CaptiveRing`, `Captive` sin anillo, cuelgue de `SacrificeFacts`, `CarryRope` → `CaptiveRing` | g4 y 055c3 integrados |
| g6 | Cierre: borrar los 13 campos, `ritual_barrier.tres`, casos, README, baseline, RFC | g1–g5 |
g2, g3 y g4 en paralelo apenas entra g1. Reglas: mover líneas sin cambiar aritmética ni orden; nada de `MpKit.` nuevo fuera de `SacrificeSpawns` (el resto pregunta `simulates()`); ningún `instantiate()` de `sacrifice_places.tscn`; ningún nodo de física nuevo en `ritual.tscn`, `doctor.tscn`, `unit.tscn`; `## Ref:` al final de cada doc tocado; README con `Check:`.

## 11. Pruebas (pasada única al final; g0 es la excepción)
1. Import.
2. Lint: ningún conteo sube (C1a 97 → ≤93, C1b 21 → 18, C20 17 → 8, y bajas en C5, C6, C9, C12, C14, C15, C16, C17). `--update-baseline`.
3. **Línea de tiempo antes/después** (`--headless --fixed-fps 600 res://debug/sacrifice/ritual_timeline.tscn -- --case=<c> --out=<f>`, un proceso por caso): `desecrate_complete`, `desecrate_doctor_killed`, `desecrate_site_falls`, `convert_complete`, `convert_pump_kill`, `carry_kill`, `push`. Cada línea: tick, evento, fase, ronda, vida y maná del blanco (1e-6), posiciones del cautivo, doctores y vórtice (1e-4 m), almas. **Criterio: `diff` vacío contra `before/`.**
4. `BodyFacts` antes/después: el volcado de g0 da idéntico.
5. `rules_suite --fixed-fps 600` PASS, con `sacrifice_places_cases` (`facts_match_old_rules`, `barrier_variant`, `never_instanced`, `cached`, `frame_warnings`) y `ritual_parts_cases` (`types_table`, `rounds_by_type`, `lift_reaches_hang`, `watch_aborts`, `payoff_purse`, `no_drain_without_part`); PRESENTATION REFS sin fugas.
6. NET QUICK PASS con el cable idéntico.
7. Con ventana: aguja en idle a ≤0,35 m del marcador viejo (0; 1,45; 0,6); la cuerda arranca a ≤0,02 m de `tool_socket` en cada clip (PNG por clip); anillo con |y − `BodyFacts.center.y`| ≤ 1e-3; playtest `pt59_zoom.json` y `rfc020e_convert_solo.json`.
8. Dedicado exportado: tiempo y memoria ±2 %; 0 `Area3D` de lugares en el servidor.

## 12. Riesgos
Orden dentro del tick (paso explícito, medido en §11.3) · física instanciada (solo `SceneState`; caso `never_instanced`) · liberar cuerpos que simulan (HANG ya está prendido desde 055a-5j: `Payoff` y los casos deben pasar `RagdollDriver` a OFF y liberar con `queue_free` junto al doctor) · float32 (`mm()` a 1 mm) · eje de la aguja NO VERIFICADO (§11.7) · merges en `match_rules.gd`, `body_*`, `unit.tscn` · banco con dos archivos por variante (aceptado) · C5 que no bajan sin tocar otros cortes.
Fuera de alcance: pool de chispas de `CarryRope` y `FxBus` por texto (055x), radios de almas/manantial/altar/Manahoar/guardián (055r), la IA que lee `desecration_*` (055f), sangre por ronda (RFC-060).

## 13. Preguntas (recomendaciones aprobadas)
1. 055r no se fusiona: 055g deja `SceneStateReader` y 055r lo reusa. 2. Lugares en escena aparte leída por `SceneState`. 3. La apunta `MatchRules.sacrifice_places`. 4. Agregar una clase de ritual pide una línea en el enum (id de red). 5. El balance se queda en `MatchRules`. 6. Lugares por sitio: no por ahora. 7. `CarryRope/Needle` se borra. 8. `DoctorBody` ≤200. 9. g0 se corre al principio. 10. Las ramas de `Approach` no pasan a `RitualType`. 11. Los 13 campos viejos se borran en g6. 12. El anillo se centra en el `Center` del cuerpo.

## 14. Cierre (g6): qué cambió respecto del plan
- Se borraron los 13 campos de lugar de `MatchRules` (grupo «Sacrificios»); todo lector pasa por `SacrificeFacts.of_rules(rules)`. `facts_match_old_rules` compara contra los mismos valores como literales. `debug/rules/ritual_barrier.tres` apunta a `debug/sacrifice/barrier_places.tscn` en vez de `ritual_push_radius`. C20: 17 -> 8 (los 8 que quedan son de 055r).
- `ritual.gd` quedó en 223 líneas: es la raíz de un actor replicado (tope 200 de CONVENTIONS §1 para esas raíces; el exceso lo carga la sincronización y queda anotado).
- `doctor_body.gd` quedó en 195 (dentro del tope de 200).
- La aguja de la cuerda va sobre +Y del hueso `bone_16` (la mano), no en un marcador aparte; `CarryRope/Needle` se borró como decía la pregunta 7.
- `CaptiveRing` es el último nodo hijo de la escena del cautivo (el orden importa: se centra en el `Center` del cuerpo ya instanciado).
- El README de `scenes/sacrifice` tiene las cinco líneas (What / Not / Talks to / Edit / Check).
