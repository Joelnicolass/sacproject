# Plan 055a-5: el cautivo como ragdoll y los 54 ragdolls que faltan

> **Aprobado (2026-10-25)** con todas las recomendaciones de §16: el usuario las aprobó de antemano («sigue y da por bueno el siguiente rfc»). Lo guarda el orquestador.

Estado: plan del tech lead, 2026-10-25. Base: `main` con 055s cerrado (s1–s6).
Autoridad: CONVENTIONS (nivel RULES) > RFC-055 §16 / §5 > 055s §14 > este plan.

## 0. Contradicciones encontradas (y cuál gana)
1. **RFC §16 pone un `AnimatableBody3D` Anchor como hijo del cuerpo**, pero la lección 1 de 055s dice que un nodo de física en la escena del cuerpo crea objetos en el servidor y mueve los digests. Lo que el RFC busca se mantiene: solo presentación, nada en la simulación lo lee. Lo que cambia es el lugar: **el ancla vive dentro del modelo** (`<name>_model.tscn`), que solo arma el cliente. Hay que corregir el texto de §16.
2. **RFC §16 manda los modelos que fallen «a una lista en un `.tres`»**, y eso choca con CONVENTIONS §2c («nada disperso») y con C18 (contenido buscado por texto). Gana CONVENTIONS: el modelo que falla lo dice en su propia escena (`BodyModel.hang_bone` vacío, cuelga con sus clips) y la galería lo informa en su salida.
3. **055s §14 dice que la aguja es `HandR/Socket` en `sacd.tscn`**, pero no existe: la aguja es el `Marker3D` `CarryRope/Needle` de `doctor.tscn`, puesto a ojo. No hace falta para 055a-5 (la cuerda termina en el anillo, que está en `Sockets/Center`) y queda para 055g.
4. **RFC §5.4 dice que el bake no pisa lo existente sin `--force`**, pero `bake_ragdolls.gd` reemplaza siempre el `Ragdoll`. Gana el RFC y lo corrige s2.
5. **RFC §16 habla de «72 modelos»**, pero hay 74: 20 con `Ragdoll` y 54 sin él. Se hornean 53 (todos menos `sac_doctor_model`, porque el doctor muere por su estado `Dying` y nunca cae como ragdoll) y quedan 73 con ragdoll. `testmonster` entra.
6. **055s §14 dice que el bake recorre las escenas de cuerpo, no los tags**, pero hoy recorre tags (`BodyModel.scene_path(tag)`). El bake pasa a aceptar el nombre del archivo del modelo (`trogg_model`) o `--missing`.

## 1. Objetivo (criterios de RFC §16, sin extras)
- Mientras un doctor **carga** a una criatura (HELD: Desecrate y el acarreo de Convert), la criatura **cuelga como ragdoll**: un hueso ancla sigue al cuerpo y el resto cuelga por física. Si el modelo no tiene ragdoll o no puede colgar, usa los clips de hoy (`rise → held → thrash`).
- Mientras lo **bombea** (REVIVING, Convert), el cadáver sigue siendo el ragdoll que cayó: no se para en el lugar.
- Al **soltarlo**: si vive, vuelve a sus clips (`reset`); si muere, sigue `CorpseLook` con el mismo ragdoll ya corriendo.
- **Solo presentación.** La simulación sigue moviendo `body.global_position`; el servidor y el servidor de salas nunca crean un hueso físico; quick 28/28 da digests idénticos.
- **Los 54 modelos sin ragdoll se hornean** (53, sin el doctor). Hay una galería con métricas automáticas: velocidad máxima de hueso a los 3 s < 0,5 m/s, extensión < 2× la altura, sin NaN, y el ancla aguanta 11 m/s sin estirarse.

## 2. Escena de prueba
- `debug/sacrifice/desecrate_carry.tscn`: `high_noon.tscn` + `debug/rules/desecrate.tres` + la criatura `Offering` (druid). Hoy, al tomarla hace los clips `rise/held/thrash`; tiene que colgar como ragdoll. Acción: Desecrate sobre `Offering` con el HUD de hoy.
- `debug/sacrifice/convert_ritual.tscn`: Killer1 y Killer2 matan a Victim. El cadáver tiene que seguir tirado mientras lo bombean y aparecer colgado al tomarlo. Acción: pestaña Estructuras, `spell_3`, clic sobre el alma roja.
- `debug/sacrifice/convert_pump_kill.tscn` (el doctor muere bombeando: el cadáver sigue tirado y no salta) y `convert_carry_kill.tscn` (el doctor muere cargando: el ragdoll que colgaba cae y se asienta).
- **Nueva, solo para verificar los 73:** `debug/bodies/ragdoll_gallery.tscn` (F6). Arma las apariencias directo, sin unidades, en una grilla. `--mode=hang`: cada celda se mueve a 11 m/s y se frena; `--mode=fall`: cada cuerpo muere en el piso. Con `--metrics` corre headless e imprime una línea por modelo. Sin InputMap: arranca sola.

## 3. Diseño en una página
- **`RagdollDriver` es el único dueño del esqueleto físico.** Pose objetivo idempotente `set_pose(Pose.OFF | FALL | HANG)`. Se ata al modelo cuando el rig lo monta (`BodyRig.look_mounted`) y lee referencias tipadas del modelo (`BodyModel.ragdoll`, `BodyModel.hang_bone`), sin `find_children`. Mientras la pose no es `OFF` congela los clips (`ClipPlayback.frozen`): un solo escritor de ese congelado por ragdoll.
- **`CorpseLook`** decide la muerte y la disolución: `laid_down → set_pose(FALL)`, o el clip, o `TippingFall`. Deja de escuchar `stood_up`.
- **`CaptiveLook`** (nuevo, hermano de `CorpseLook`) decide «un doctor lo tiene, y la vuelta». Escucha solo `body.mode_changed(was, now)` y `RagdollDriver.bound`, y le pregunta a `CaptiveRules.on_change(...)` qué mostrar. Es el **único escritor de `body.captive_role`**: la secuencia `rise/held/thrash` sale de `Captive`, que queda solo con simulación y el anillo.
- **`BodyVisual.fade_to(target, s)`** es el único dueño del tween de transparencia (lo llaman `CorpseLook` y `CaptiveLook`; `set_fade` directo lo corta).
- **Cómo cuelga** (lo decide el spike s0):
  - **A (preferida):** simulación parcial: `physical_bones_start_simulation(todos menos hang_bone)`; el hueso ancla no simula, sigue la pose congelada del clip y viaja con el modelo. Sin nodos nuevos.
  - **B (respaldo):** el bake agrega dentro del modelo `Ragdoll/Hook` (`AnimatableBody3D`, capa 0, máscara 0, sin forma, `sync_to_physics`) en la pose de reposo del hueso ancla, y `Hook/Pin` (`Generic6DOFJoint3D`, todos los ejes trabados). El driver pone `node_b` del joint solo en `HANG`.

| Cambio de `mode` | Con ragdoll que cuelga | Sin ragdoll (o `hangs = false`) | Quién |
|---|---|---|---|
| vivo → HELD | `HANG` (sin fundido) | clips `rise→held→thrash` | CaptiveLook |
| REVIVING → HELD | `HANG` + aparecer (`appear_s`) | clips | CaptiveLook |
| DEAD → REVIVING | sigue tirado (`FALL` congelado, sin tocar) | `tipping.stand_up` + aparecer + clip `rise` | CaptiveLook |
| HELD → vivo | `OFF` + clips (golpe seco) | `captive_role = ""` | CaptiveLook |
| REVIVING → vivo (FastRevive) | `OFF` + `idle` + aparecer | `captive_role = ""` | CaptiveLook |
| cualquiera → DEAD | `FALL` (desde `HANG`: suelta el ancla y cuenta `settle_s`) | clip de muerte o `TippingFall` | CorpseLook |
| join tarde con HELD (`bound`) | `HANG` sin fundido | clips | CaptiveLook |

## 4. Árbol de archivos
`[+]` nuevo · `[~]` cambia · `[>]` se mueve con `git mv` (conserva el uid) · `[-]` se borra

```
scenes/bodies/
  ragdoll_driver.gd            [>][~] desde scenes/units/. Pose OFF/FALL/HANG, set_pose idempotente, bind_model, señal bound,
                                      sockets rig + clip_pose, knob hang_damping. <=150 líneas
  ragdoll_pose.gd              [+]    static RefCounted: guardar/poner la pose congelada (por profundidad), freno de deriva. ~60
  body_model.gd                [~]    @export_group("Ragdoll"): ragdoll, hang_bone (+ hang_pin solo con B) + avisos. +~12
  body_visual.gd               [~]    fade_to(target, seconds): dueño único del tween; set_fade corta el tween. +~15
  models/<name>_model.tscn x53 [~]    Skeleton3D/Ragdoll (lo escribe el bake) + exports ragdoll / hang_bone en la raíz
  models/<name>_model.tscn x20 [~]    solo los exports (el Ragdoll existente no se toca sin --force)
  README.md                    [~]    What/Talks to/Edit/Check: ragdoll, hang bone, galería
scenes/units/
  captive_look.gd              [+]    ~130. Sockets: body, ragdoll, tipping, visual, clip_pose, light. Knobs: hangs, appear_s
  captive_rules.gd             [+]    ~50. static on_change(was, now, can_hang, lies_as_ragdoll) -> Look (la tabla de §3)
  captive.gd                   [~]    sale la secuencia de clips (-~45). Quedan la simulación y el anillo
  corpse_look.gd               [~]    set_pose(FALL); sale _on_stood_up, revive_fade_s y _ragdolled; fundidos con visual.fade_to
  corpse.gd                    [~]    sale la señal stood_up; stand_up() sigue (simulación)
  unit.tscn                    [~]    RagdollDriver y TippingFall hijos directos de Unit; CaptiveLook después de Captive;
                                      Captive sin clip_pose; CorpseLook sin revive_fade_s. Ningún nodo de simulación se reordena
  README.md                    [~]    Talks to: CaptiveLook escucha mode_changed y pide la pose a RagdollDriver
scenes/wizards/
  wizard_death_look.gd         [~]    set_pose(FALL/OFF); fuera bind(skeleton) y el frozen a mano
  wizard_body.tscn             [~]    DeathLook/RagdollDriver: rig + clip_pose cableados
tools/bake/
  ragdoll_baker.gd             [+]    static RefCounted: huesos, cápsulas, joints, espejo + hang_bone (cuerpo raíz) + Hook/Pin
                                      solo con B + chequeo de ida y vuelta. ~170
  bake_ragdolls.gd             [~]    CLI ~70: <stem|res://...tscn>..., --missing, --skip=<stem>, --force; resumen
  new_creature.gd              [~]    llama a RagdollBaker.add_to(root) antes de guardar el modelo nuevo
addons/sacrifice_tools/
  plugin.gd                    [~]    Tools > «Sacrifice: Hornear ragdolls que faltan» (--missing) y «… de un modelo…»
debug/bodies/
  hang_spike.gd                [+]    s0. SceneTree headless: trogg_model, A y B, 11 m/s; SPIKE A/B PASS|FAIL + números
  ragdoll_gallery.gd/.tscn     [+]    F6 / --metrics / --mode=hang|fall / --only= / --out= (PNG). ~140
  ragdoll_cell.gd/.tscn        [+]    Hook (Node3D) + la apariencia + RagdollDriver. ~50
  ragdoll_metrics.gd           [+]    static: max_speed, extent_ratio, stretch_ratio, anchor_error_m, drop_ratio, top_ratio,
                                      drift_m, has_nan. ~90
  rig023e/rig023e_shots.gd     [~]    imprime las métricas del cautivo junto a cada PNG
debug/suite/
  captive_look_cases.gd        [+]    casos headless con el modelo montado a mano. ~150
  death_cases.gd               [~]    bind(skeleton) -> bind_model(model)
  rules_suite.gd               [~]    registra CAPTIVE_LOOK_CASES después de DEATH_CASES
rfcs/RFC-055-human-first-refactor.md [~] §13.2 «Muerte por Tween» -> Hecho; §16 con las desviaciones 1, 2 y 5 de §0
tools/lint/baseline.txt        [~]    solo si algún conteo baja
```

## 5. Mapa de responsabilidades
| Pieza | Hace | No hace |
|---|---|---|
| `RagdollDriver` | Único dueño del esqueleto físico: prende, cuelga, suelta, congela, resetea; congela los clips mientras rige | Decidir cuándo; leer el `mode`; crear huesos; correr en el servidor |
| `RagdollPose` | Matemática de la pose congelada y del freno de deriva | Tocar nodos que no le pasan |
| `CorpseLook` | Look de la muerte y de la disolución | Lo del doctor; la vuelta a la vida |
| `CaptiveLook` | Look de HELD / REVIVING y la vuelta; único escritor de `captive_role` | Tomar o soltar; la muerte; escribir en la simulación |
| `CaptiveRules` | La tabla de §3 como función pura | Nodos |
| `Captive` | Simulación: tomar, soltar, revivir, mover el cuerpo al cuelgue; el anillo (pasa a 055g) | Clips y ragdoll |
| `BodyVisual.fade_to` | Único tween de transparencia del cuerpo | Decidir cuándo aparece |
| `BodyModel.ragdoll / hang_bone` | Dicen en la escena del modelo con qué cae y de dónde se lo toma | Lógica |
| `RagdollBaker` / `bake_ragdolls.gd` | Escribir una vez el esqueleto físico, elegir el ancla, verificar la ida y vuelta | Correr en la partida; pisar lo editado sin `--force` |
| `ragdoll_gallery` + `ragdoll_metrics` | Medir los 73 colgados y caídos; PNG | Editar (se edita en el modelo) |

## 6. Composición o herencia
Todo composición. `CaptiveLook` es un `Node` hijo de `unit.tscn` con sockets `@export` a sus hermanos. `RagdollDriver` y `TippingFall` pasan a hijos directos de `Unit` porque los usan dos looks. Sin herencia nueva. A y B no son dos clases: son lo que el bake deja en el modelo.

## 7. Resources o nodos
- **Nodos (en el `.tscn`, con gizmo):** `Skeleton3D/Ragdoll` con sus `PhysicalBone3D`; con B, `Ragdoll/Hook` y `Hook/Pin`. El ancla es una referencia `@export`.
- **`@export` de instancia:** `RagdollDriver` (`push_back_m_s`, `settle_s`, `max_drift_m`, `bone_damping`, `hang_damping`), `CaptiveLook` (`hangs`, `appear_s`), `BodyModel.ragdoll` / `hang_bone`.
- **Resources:** ninguno nuevo. Sin lista de fallas en un `.tres`. `MatchRules` no se toca.
- **Estado:** la pose en `RagdollDriver`; `captive_role` en `UnitBody` (no se replica).

## 8. Cómo lo hace un humano (los seis verbos)
| Verbo | Qué abre y qué toca | Lugares |
|---|---|---|
| Entender | `scenes/units/README.md` y `CaptiveLook` en `unit.tscn`; `<name>_model.tscn` → `Skeleton3D/Ragdoll` y «Hang Bone» en la raíz; F6 en `ragdoll_gallery.tscn` | 1–2 |
| Modificar | `RagdollDriver.hang_damping` o `CaptiveLook.appear_s` en `unit.tscn`; por modelo, el gizmo de una cápsula, los límites, o el `Hang Bone` | 1 |
| Agregar | Project > Tools > «Sacrifice: Hornear ragdoll de un modelo…» | 1, sin código |
| Quitar | Borrar `Skeleton3D/Ragdoll` o vaciar `Hang Bone`; todos: destildar `CaptiveLook.hangs` | 1 |
| Crear | `new_creature.gd` (o el menú) ya hornea el ragdoll y el ancla | 0 extra |
| Escalar | «Hornear ragdolls que faltan» + galería `--metrics` | 1 |

## 9. Contratos
```gdscript
# scenes/bodies/ragdoll_driver.gd
class_name RagdollDriver extends Node
enum Pose { OFF, FALL, HANG }
signal bound(available: bool)
@export var rig: BodyRig
@export var clip_pose: ClipPlayback
func bind_model(model: BodyModel) -> void
func available() -> bool
func can_hang() -> bool
func pose() -> Pose
func is_running() -> bool
func set_pose(next: Pose, push := Vector3.ZERO) -> void   # idempotente

# scenes/bodies/body_model.gd
@export_group("Ragdoll")
@export var ragdoll: PhysicalBoneSimulator3D
@export var hang_bone: PhysicalBone3D
# solo con B: @export var hang_pin: Generic6DOFJoint3D

# scenes/bodies/body_visual.gd
func fade_to(target: float, seconds: float) -> void

# scenes/units/captive_rules.gd
class_name CaptiveRules extends RefCounted
enum Look { NONE, HANG, HANG_APPEAR, KEEP_LYING, CLIPS, STAND_APPEAR, LET_GO }
static func on_change(was: UnitBody.Mode, now: UnitBody.Mode, can_hang: bool, lies_as_ragdoll: bool) -> Look
```
Transiciones de `set_pose`: `→ OFF` para la física, apaga el simulador, `reset_bone_poses()` y descongela; `OFF → FALL` todos simulan, empujón, cuenta `settle_s`; `HANG → FALL` el ancla también simula (A) o se vacía `node_b` (B), reloj de nuevo, sin empujón; `FALL → FALL` nada; `OFF → HANG` todos menos el ancla (A) o todos + joint (B), nunca congela; `FALL → HANG` para, resetea, como desde `OFF`.

## 10. Sub-cortes
| # | Qué | Carpetas | Depende de |
|---|---|---|---|
| s0 | `debug/bodies/hang_spike.gd` (A y B sobre `trogg_model`, 11 m/s 2 s y frenado). Lo corre el orquestador una vez, headless | `debug/bodies/` | — |
| s1 | `RagdollDriver` movido y extendido, `ragdoll_pose.gd`, exports de `BodyModel`, `fade_to`, `CorpseLook` y `WizardDeathLook` migrados, `wizard_body.tscn`, `death_cases`, README de bodies | `scenes/bodies`, `scenes/wizards`, `corpse_look.gd`, `death_cases.gd` | s0 (rama HANG) |
| s2 | Bake: `ragdoll_baker.gd`, CLI, `new_creature.gd`, plugin | `tools/bake`, `addons/sacrifice_tools` | §9; s0 si va B |
| s3 | `CaptiveLook` + `CaptiveRules`; `Captive` más chico; `corpse.gd` sin `stood_up`; todas las ediciones de `unit.tscn`; README de units | `scenes/units` | s1 |
| s4 | Galería, celda, métricas, `captive_look_cases.gd`, suite, métricas en `rig023e_shots` | `debug/bodies`, `debug/suite` | §9 |
| s5 | Pasada única de pruebas (§11); los que fallen la galería → s5b (retoque o `hang_bone` vacío) | `models/` | s1–s4 |

Criterio del spike s0 por variante: error del ancla ≤ 0,02 m por tick; estiramiento ≤ 1,3; velocidad máxima a los 3 s del frenado < 0,5 m/s; extensión < 2× altura; sin NaN. A si pasa; si no, B; si ninguna, parar y avisar con los números.

## 11. Pruebas (en s5, en este orden)
1. Import una vez.
2. Bake `--missing --skip=sac_doctor_model`: 53 horneados, 20 con exports completados, 0 fallas, ida y vuelta OK (cápsulas con alto ≥ 2·radio + 0,01; `transform`, `body_offset` y límites, tolerancia 1e-5).
3. Galería headless: `--mode=hang --metrics` → `RAGDOLL HANG PASS 73/73` (`max_speed@3s < 0.5`, `extent_ratio < 2.0`, `stretch_ratio <= 1.3`, `anchor_error_m <= 0.05`, `drop_ratio >= 0.3`, sin NaN); `--mode=fall --metrics` → `RAGDOLL FALL PASS 73/73` (`top_ratio < 0.45`, `drift_m <= max_drift_m + 0.5`, congelado a los `settle_s`, sin NaN). Informativo: tiempo de física con 73 colgados.
4. Lint: ningún conteo sube; C1a en 98.
5. `rules_suite --fixed-fps 600` PASS (PRESENTATION REFS 87/87 leaks=0, CLIP STRIP sin malos, WIRE CONFIG igual) + `captive_look_cases`: `pure_table`, `hang`, `let_go_alive`, `dies_hanging`, `convert_keeps_lying`, `late_join`.
6. quick 28/28 idénticos sin regrabar. Si alguno se mueve, parar.
7. NET QUICK PASS con cable idéntico.
8. Dedicado exportado ≤ 3,0 s y ≤ 380 MB (hoy 2,13 s / 373 MB); `PhysicalBone3D` en el árbol del servidor = 0.
9. Capturas con ventana: galería `--mode=hang --out=<dir>` con la tabla de métricas; `rig023e_shots` en take +0,5/1/2/3 s con métricas, y diff ≥ 2 % en la caja de la criatura contra antes del corte; playtest de las cuatro escenas de §2.

## 12. Riesgos
- Simulación parcial en 4.7 (el hueso estático se mueve sin velocidad y puede estirar): lo cubren s0 y B.
- Saltos de interpolación en el cliente (el ancla latiguea): `hang_damping` y `stretch_ratio`.
- Determinismo: ningún nodo de física en `unit.tscn` ni `doctor.tscn`; lo nuevo va después de `Captive`; `captive_role` no lo lee la simulación; los huesos de `captive_look_cases` se crean después de `DETERMINISM_CASES`.
- Golpes secos al soltarlo vivo o al tomarlo tras bombear (aceptado, preguntas 4 y 5).
- `ClipPlayback.frozen` también lo escribe `Petrified`: deuda previa, fuera de alcance (055c).
- Cambio de modelo mientras cuelga: lo cubre `late_join`.
- Los 20 ya horneados pueden tener retoques: sin `--force` no se tocan.
- 53 `.tscn` más grandes: se mide el `.pck` del dedicado (margen 373/380 MB).
- Costo: los colgados no se congelan; el tope es la cantidad de doctores que cargan.

## 13. Fuera de alcance
El anillo y la aguja como `BoneAttachment3D` (055g); sacudidas procedurales; levantarse del ragdoll; ragdoll del Sac Doctor; `Petrified` como dueño del congelado (055c); sangre (RFC-060).

## 14. Orden
1. s0 → el orquestador lo corre → A o B. 2. s1, s2, s4 en paralelo. 3. s3 sobre s1. 4. s5 (§11), s5b si hace falta. 5. Cierre: RFC-055 §13.2 «Hecho», §16 corregido, READMEs con «Check:».

## 15. Cómo lo verifica un humano en el editor
- `scenes/bodies/models/druid_model.tscn`: `Skeleton3D/Ragdoll` con sus huesos; «Hang Bone» en la raíz apunta a la cadera (con B: `Ragdoll/Hook/Pin`).
- `scenes/units/unit.tscn`: `CaptiveLook` sin avisos; `RagdollDriver` y `TippingFall` hijos directos de `Unit`.
- F6 en `debug/bodies/ragdoll_gallery.tscn`: los 73 cuelgan, se mueven y se frenan; `--mode=fall` caen y se congelan.
- F6 en `desecrate_carry.tscn` y `convert_ritual.tscn` con lo esperado de §2.
- Destildar `CaptiveLook.hangs`: vuelven los clips.

## 16. Preguntas abiertas (recomendaciones aprobadas)
1. Cómo cuelga: **A**; si el spike falla, **B**. Siempre dentro del modelo, solo cliente.
2. Ancla por defecto: **el cuerpo raíz** (sin joint).
3. ¿Se para mientras lo bombean? **No**: sigue tirado y aparece colgado con fundido.
4. FastRevive: se para con el fundido de hoy.
5. Al soltarlo vivo: golpe seco a los clips, sin «get-up».
6. ¿Lista de fallidos en `.tres`? **No**.
7. Se hornean **53** (sin `sac_doctor_model`, con `testmonster`): quedan 73.
8. La secuencia de clips del cautivo pasa a `CaptiveLook`: **sí**. El anillo queda en `Captive` hasta 055g.
9. Sacudidas procedurales: **no** en este corte.
10. El bake sin `--force` conserva el `Ragdoll` y solo completa los exports: **sí**.
11. Aguja del doctor como hueso: 055g.
12. Spike antes de la pasada final: **sí** (una corrida headless de ~1 min).
13. `RagdollDriver` a `scenes/bodies/`: **sí** (`git mv`).

## 17. Resultado del spike s0 (2026-10-25, orquestador)
Sobre `trogg_model`: 11 m/s durante 2 s y frenado; medido 7 s. El spike original no habilitaba el simulador, que los modelos guardan con `process_mode = DISABLED` (`RagdollDriver` lo prende); se corrigió en el spike.
| Variante | anchor_err máx | stretch máx | speed@3s | Lectura |
|---|---|---|---|---|
| A (ancla sin simular) | 0,000 | 1115 | 49 m/s | Las articulaciones hacia un hueso que no simula no existen: el resto cae libre |
| B (Hook + Pin) | 22,0 | 1108 | 49 m/s | El Hook no arrastra al ancla y el resto cae libre |
| C (control: todos simulan, sin mover) | — | 1,000 | 49 m/s | Caída libre conjunta: no prueba las articulaciones |
| D (todos simulan; el ancla sigue por velocidad) | 0,183 (0,003 al final) | 1115 | 49 m/s | El ancla sigue bien; el resto igual se va: las articulaciones no sostienen peso |
| F (muerte sobre un piso) | — | 2,42 | 0,48 m/s | Se asienta casi armado: el contacto con el piso disimula articulaciones flojas |
**Decisión:** ninguna variante pasa. La rama HANG queda **apagada** (`CaptiveLook.hangs = false` en `unit.tscn`; el cautivo sigue con los clips `rise/held/thrash`) hasta que se arreglen las articulaciones de los ragdolls horneados. Se sigue con s1–s4 tal cual: la API HANG queda implementada y probada en la suite con `hangs` prendido a mano, y la galería `--mode=fall` va a medir si las articulaciones flojas también afectan la muerte de los 73.
**Pendiente (055a-5j):** por qué las articulaciones no sostienen peso (¿`joint_type` cono sin `joint_offset` coherente con `body_offset`, o el espejado del modelo?). La prueba: la variante D del spike tiene que dar stretch ≤ 1,3. Cuando pase, prender `hangs` y correr la galería en modo hang.

### 17.1 Diagnóstico de las articulaciones (055a-5j, orquestador)
- **E** (sin reflexión en `body_offset`) y **H** (además, el `.glb` girado 180° en vez de espejado: los 19 huesos con determinante +1) dan lo mismo que D, así que **el espejado no es la causa**.
- **Por par (D):** se sueltan **solo las 3 articulaciones que cuelgan de `root`** (`bone_01`, `bone_04` y `bone_16`, todas cono). Las otras 15 aguantan. Los hijos de la raíz se desprenden y caen.
- **I** (D, y después de arrancar se rearma cada articulación, poniendo `joint_type` en NONE y de vuelta): aparecen todas, pero el cuerpo explota (stretch 34, 140 m/s). El marco de la articulación hacia la raíz (`joint_offset`/`joint_rotation` del bake contra el `body_offset` de `root`) parece estar mal, y Godot no la arma al arrancar.
- **Siguiente paso de 055a-5j:** revisar cómo `ragdoll_bones.gd` calcula `joint_offset` para los hijos directos de la raíz y probar con `hang_spike.gd -- d`. Criterio: `loose 0/18` y stretch ≤ 1,3. Eso también arregla la muerte: hoy los 3 miembros que cuelgan de la raíz se sueltan, y el piso lo disimula (F: stretch 2,4).

### 17.2 Bake y galería de caída (s5)
- **Bake:** `--missing --skip=sac_doctor_model` dio `baked=53 completed=20 failed=0`, y una segunda corrida `baked=0`. El chequeo de ida y vuelta fallaba en el hueso raíz, que no tiene articulación y por eso devuelve sus límites en null; se corrigió en `ragdoll_check.gd` y los 53 se rehornearon con `--force`, esta vez con el chequeo completo.
- **Galería `--mode=fall`:** `RAGDOLL FALL FAIL 65/73`. Los 8 que fallan lo hacen por `top_ratio` (caen y quedan medio parados): scythe, blight, ikarus, pyrodactyl, jabberocky, ent, cog y taurock.
  - **Los 7 nuevos se quedan SIN ragdoll** y siguen muriendo con su clip, como hasta hoy: scythe, blight, ikarus, pyrodactyl, jabberocky, ent y cog.
  - **taurock no se toca:** ya tenía ragdoll antes del corte, así que se ve como siempre.
  - **Pendiente:** marcar en la escena del modelo que no lleva ragdoll, para que `--missing` no lo vuelva a hornear. Hasta entonces, se pasan con `--skip`.
