# Plan 055f: la IA (percepción sobre `Vision`, nombres y tácticas en `.tres`)

> **Ajuste del orquestador (2026-10-25), por «deja determinismo y pruebas de Godot para el final»:**
> - No se graba nada entre cortes. f0 deja solo el código del grabador, en un commit propio.
> - En la pasada final, la base `before/`/`before_b/` se graba desde un `git worktree` en el commit de f0. `after_f4/` se graba desde un worktree en el commit de f4, y `after_design/` desde la punta.
> - Si `after_f4` difiere, se bisecta f1–f4 por commit, como dice §10.1.
> - f5 y f6 se desarrollan sin esperar la pasada de paridad.
> - e6 ya está integrado (7d80072e). f5 lee las habilidades con los campos con nombre de e6 a través de `AiBody`, y f7 puede corregir las citas de `ai_rater.gd`.

> **Aprobado de antemano (2026-10-25):** el usuario dio por buenas las recomendaciones de §13 («sigue y da por bueno el siguiente rfc»). Lo guarda el orquestador.

Base: `main` en 4410f875 (055c2, 055c4, 055c5, 055r y 055e e1 a e5 integrados). Autoridad: CONVENTIONS (C1–C23, §2c) > decisiones del usuario en RFC-055 (2026-10-23/24) > PRD > RULES > RFC-055 (fila «`AiPerception`, cerebros por tag», §13.2b C-8c) > plan 055e §11 > este plan. En paralelo, y a evitar: 055x (FX) y 055e e6 (`AbilityType`, lectores de habilidades, `spell_order`).

Fuentes leídas:
- todo `scenes/ai/` (6 247 líneas, 37 scripts), `ai_side.tscn` y `data/ai/*.tres`;
- `scenes/units/vision/*`, `creature_type.gd`, `unit_mana_support.gd`, `spell_target.gd`;
- `debug/ai/ai_match.gd`, `debug/suite/ai_cases.gd`, `bench_rules.gd`;
- `minimap_markers.gd`;
- los `.tres` de los 15 hechizos especiales;
- `RULES.md` «IA» y `PRD.md:33-34`.

## 0. Contradicciones (y cuál gana)
| # | Dice | Dice otra cosa | Gana |
|---|---|---|---|
| 1 | RFC: «`wizard_brain.gd:240` compara `spell.tag == "ccas"`» | 055e e1 lo borró. Quedan por tag: `MAHO_TAG := "oham"` (`ai_perception.gd:31,142`, `wizard_brain.gd:226`, `debug/ai/oscillation_probe.gd:176`, `debug/suite/tower_cases.gd:277`) | El código: 055f borra `MAHO_TAG` |
| 2 | C-8c: «237 citas; `AiProfile` 41 `@export`» | Hoy: 277 citas en 30 archivos, 37 `@export` en `AiProfile` y C9 = 32 en `scenes/ai` | Los conteos de hoy |
| 3 | RFC: «`AiPerception` 700 líneas» | 669 | El código |
| 4 | PRD:33-34: «Se porta de la IA del original (`shiny.d`)», «Normal usa los números del original» | Decisión del usuario (RFC-055 §13.2, 2026-10-24): «percepción y tácticas con diseño propio»; human first | El usuario. Los cortes f1–f4 conservan los números. f5 y f6 cambian conducta. En f7 se ajusta una frase del PRD |
| 5 | RULES «IA»: «sin trampa en ninguna dificultad» | `difficulty_hard.tres: perfect_information = true`: lee posición, vida y maná de lo que su bando no ve | RULES. Lo arregla f6 (§13.2) |
| 6 | `minimap_markers.gd:7`: el humano ve todo dentro del círculo del minimapa (no hay niebla) y una flecha a cada mago | Normal y Fácil solo saben lo que ve su `Vision`: la IA sabe *menos* que el humano | Ni uno ni otro. f6 define «lo que ve un humano» (§13.3) |
| 7 | Memoria: «probar todo al final», determinismo pospuesto | El pedido exige una estrategia de paridad | Excepción chica, con el precedente de 055g g0: f0 graba la base una vez y hay una pasada headless de paridad al juntar f4 (§10) |
| 8 | Usuario: «055f en un solo corte» | Tamaño L | Un plan, una fila del RFC y sub-cortes internos, como 055e |
| 9 | RFC: «tácticas en `.tres`» | §2c «nada disperso, sin cadenas de `.tres`». Hoy hay 7 `profile_*.tres` idénticos y una cadena asiento → dificultad → tácticas | Se borra `AiProfile`. Queda un `tactics_*.tres` por dificultad, con sub-recursos **embebidos**. Se mantiene el único salto dificultad → tácticas, que ya existe |
| 10 | El pedido cita «055e §11.10» | Son las rarezas del riesgo 10 de §11 del plan 055e | El plan 055e |
| 11 | La IA lee habilidades (`AiRater.fill_from_object`: `ability.flags1 & 0x4000`, `ability.flags & 4`, `amount2`) | e6 es dueño de los lectores de habilidades | e6. 055f no toca `math/ai_rater.gd` hasta que e6 integre. Las citas de ese archivo las arregla f7 |

## 1. Objetivo
- **Paridad primero.** Los cortes f1–f4 no cambian ninguna decisión: el registro de decisiones de N partidas IA contra IA con semilla da `diff` vacío contra la base de f0 (§10).
- **Nombres de diseño.**
  - `AiTrack` sin bits: `Kind`, `Relation` y `Site` con nombre, booleanos `seen`, `fights`, `ready` y `free_fount`.
  - Órdenes como `AiOrder` y comandos como `AiTask.Kind`.
  - El Manahoar se reconoce por su habilidad (`mana_source: AbilityType`), no por `"oham"`.
  - Ningún hexadecimal de `shiny.d` en `scenes/ai`.
- **La percepción escucha a `Vision`.**
  - Un emisor único (`VisionSides.events.learned`) reemplaza el sondeo de `seen_by` y de `_lost`.
  - `AiPerception` queda como índice de ≤150 líneas, con hijos `SightIntake`, `Belief` y `Souls`.
- **Tácticas en `.tres`.**
  - `AiProfile` y sus 7 `.tres` desaparecen.
  - `tactics_easy|normal|hard.tres` agrupan por fase todo lo que un humano ajusta, en segundos y metros, con `## Ref:` al final.
  - El reloj de 6 ranuras pasa a periodos con nombre en `ai_side.tscn`.
- **La IA usa todos sus hechizos** (f5): Halo, Charm, Death, Meanstalks, Rainbow, Healing Aura, Animate Dead, Soul Wind, Soul Mole, Teleport, Guardian y Shrine. Bore queda como excepción documentada. Antes de soltar el hechizo, la IA pregunta lo mismo que un clic (`Caster.action_status`).
- **Sin trampa** (f6): ninguna dificultad lee el estado real de lo que su bando no ve. `unseen_reads = 0` en las tres.

## 2. Escena de prueba
- **Visible (f5):** `res://debug/ai/ai_spells_lab.tscn`. Es una instancia de `debug/ai/ai_match.tscn` con:
  - `default_rules = debug/rules/ai_spells_lab.tres` (`BenchRules`) y `follow_slot = 2`;
  - el mundo `scenes/match/high_noon.tscn`, que ya instancia `ai_match`;
  - semilla 7, sin NPC.
- **Asiento IA (slot 2):** `debug/ai/ai_spells_lab_seat.tres` (`AiSeat`):
  - Persephone, `book = debug/ai/ai_mixed_book.tres`, `start_active = false`;
  - `ai_mixed_book.tres` (`GodBook`): `olah`, `mrhc`, `taed`, `rter`, `wobr`, `ruah`, `deda`, `dnws`, `pmcd`, `elet`, `ndrg`, más la torre `pcas`;
  - nivel 8 y maná lleno con los campos de `MatchRules` que ya usa `cast_wards.tres`; `--souls=20`.
- **Escenario.** Las tropas son `BenchGroup`:
  - slot 1: 4 Troggs a 35 m del mago IA;
  - slot 2: 2 Troggs con vida 1 junto a ellos (al morir dejan cadáver y alma para Animate Dead y Soul Wind);
  - el mago humano pasivo, a 60 m.
- **Estado inicial:** el mago IA quieto junto a su altar. **Todavía no pasa:** ninguno de esos hechizos se lanza (hoy dan `FN_NONE` o 0).
- **Acción:** `check_tick` (Enter) arranca la IA.
- **Criterio (`expects` de `ExpectJudge`):** en ≤4 min hay `cast_noted` de `olah`, `mrhc`, `taed`, `rter`, `wobr`, `deda` y `dnws`, y 0 líneas `reject`.
- **Variante del mismo script** (otro `.tres`, no otro `.gd`): `ai_spells_lab_threat.tres`, con 8 Troggs enemigos encima del mago: Teleport (`elet`) y Guardian (`ndrg`).
- **Paridad (f0, sin ventana):** `ai_match.tscn` con `--decisions=<archivo>` y la lista `debug/ai/decision_cases.txt` (§10). f1–f4 no tienen nada visible: cierran con banco y review.

## 3. Árbol
`[+]` nuevo · `[~]` cambia · `[-]` se borra · **(C)** compartido con otro corte
```
scenes/ai/
  [~] README.md                       (f7) cinco líneas What/Not/Talks to/Edit/Check
  [~] ai_side.gd / ai_side.tscn       (f4) raíz ≤150: setup, cableado, AiPlay; hijos nuevos Clock y los de Perception
  [+] ai_clock.gd                     (f4) AiClock: 6 trabajos con periodo en s, enum Wake, orden fijo, tiempos de diagnóstico
  [+] ai_side_report.gd               (f4) static: ms_stats, slot_stats, summary (salen de ai_side.gd)
  [+] ai_play.gd                      (f4) AiPlay (RefCounted): tactics + difficulty + aggression + ages_for(s)
  [~] ai_roster.gd                    (f4) print → DebugLog; aplica AiSeat.book y AiSeat.tactics
  [ ] ai_audit.gd                     fuera de alcance (banco; C1b se queda)
  perception/
    [~] ai_track.gd                   (f1) enums y booleanos con nombre; sin constantes de bits
    [+] ai_track_facts.gd             (f1) static: setup de un track, site_of(node), rate; la tabla de §8.1
    [+] ai_body.gd                    (f1) static: cómo lee la IA un cuerpo (health, mana, souls, book, caster, is_dead tipado)
    [~] ai_perception.gd              (f2) índice ≤150: tracks, add/remove/find, listas, sort, relation; fachada pos_of/health_of/mana_of/sees/knows_live
    [+] ai_sight_intake.gd            (f2) SightIntake: escucha VisionSides.events, drena en discover y en update; _forget_checked, _lost, leak_count
    [+] ai_belief.gd                  (f2) Belief: posición congelada, snapshot de vida/maná, unseen_reads   (f6: knowledge)
    [+] ai_souls.gd                   (f2) Souls: soul_track, find_best_near (Soul.GROUP)
    [+] ai_rituals.gd                 (f2) static: desecration_against, own_desecration, has_home_altar, closest_enemy_altar_in_range
  brains/
    [~] wizard_brain.gd               (f3) ≤150: think, replan de fases, ghost, rebuild_spells; + signal replanned (f0)
    [+] wizard_casting.gd             (f3) Brain/Casting: execute_best_cast, light_can_cast, cast_refusal, intervalo y reserva
    [+] ai_shot_check.gd              (f3) static: línea de tiro, salpicadura propia, caminar para tener línea
    [+] ai_futile_targets.gd          (f3) RefCounted: marcas y vetos de «hechizo inútil»
    [+] ai_capture_casts.gd           (f3) RefCounted: bloque de captura, pick_guard_creature, cast_cached_in_range
    [~] ai_spell_eval.gd              (f3) ≤150: despacho, lands_on, can_cast_on, find_best   (f5: usos nuevos)
    [+] ai_area_rating.gd             (f3) _area, own_splash (salen de ai_spell_eval)
    [+] ai_heal_rating.gd             (f3) _heal, _speedup, still_worth
    [~] creature_brain.gd, manahoar_brain.gd, ai_line_of_fire.gd, cast_queue.gd, ai_guard.gd, ai_disable.gd (f1 nombres; f3 AiBody)
    phases/ [~] *.gd                  (f1 nombres; f4 play.tactics)
    ratings/                          (f5) un evaluador por USO, no por hechizo
      [+] ai_self_area.gd             Halo: valor de los enemigos dentro de effect_range alrededor del mago
      [+] ai_take_foe.gd              Charm: valor de la criatura enemiga (no mago)
      [+] ai_raise_dead.gd            Animate Dead: alma propia con cadáver dentro del alcance
      [+] ai_gather_souls.gd          Soul Wind, Soul Mole: almas fuera del alcance de toque y dentro del de lanzamiento
      [+] ai_escape.gd                Teleport: amenaza ≥ escape_threat y un sitio propio lejos
      [+] ai_guard_site.gd            Guardian: estructura propia amenazada y una criatura libre
      [+] ai_heal_area.gd             Rainbow, Healing Aura: suma de lo que les falta a los propios dentro del área
  command/
    [~] ai_command_port.gd            (f3) ≤150: lanzar, cola de demora, bind, can_aim
    [+] ai_orders_out.gd              (f3) Port/Orders: order_if_changed, _issue, variantes de radio; enum AiOrder
  groups/ [~] ai_groups.gd            (f1 nombres; f3 AiBody; f4 play.tactics.crowd)
  stance/ [~] ai_stance.gd            (f1 nombres; f4 play.tactics.senses)
  tasks/  [~] ai_task.gd (f1: command() → Kind), ai_task_board.gd (f1, f3: ≤150 con AiRecordRunner), capture/focus/guard/idle (f1, f4)
          [+] ai_record_runner.gd     (f3) record_update, _proximity_trigger, node_slot19 (salen de ai_task_board)
          [~] ai_record.gd            (f1) flags → capture: bool; required_status/status_or con nombre
  math/   [ ] ai_rater.gd             NO SE TOCA hasta que e6 integre (f7: solo citas)
          [~] ai_field.gd             (f1) attack_weight(distance, thr, foe: AiTrack); (f5) rareza corregida
  data/
    [-] ai_profile.gd                 (f4)
    [~] ai_tactics.gd                 (f4) decisiones del mago, agrupadas por fase (≤150) + crowd + senses embebidos
    [+] ai_crowd_tactics.gd           (f4) grupos, registros, foco, captura, recarga, distancias de guardia
    [+] ai_senses.gd                  (f4) rerate_s, status_s, souls_snapshot_s, threat_s, threat_near_m/far_m
    [~] ai_difficulty.gd              (f4) sin apply_to(profile)   (f6: perfect_information → knowledge)
    [~] ai_seat.gd                    (f4) - profile; + tactics (override), + book (override); difficulty_of() lee la lista
    [+] ai_difficulty_list.gd         (f4) AiDifficultyList: Array[AiDifficulty]
scenes/units/vision/
  [~] vision_sides.gd, vision_memory.gd   (f2) + VisionSides.events (VisionEvents) y emisión de learned
  [+] vision_events.gd                (f2) class_name VisionEvents extends Object; signal learned(side, node)
  [~] README.md                       (f2) Talks to: + learned
scenes/gods/ [~] god_type.gd          (f4) - ai_profile
data/ai/
  [-] profile_original|charnel|james|persephone|pyro|stratos.tres
  [~] tactics_easy|normal|hard.tres   (f4) + los valores de profile_original (idénticos en los tres) + crowd y senses embebidos
  [~] difficulty_hard.tres            (f6) knowledge
  [+] difficulties.tres               (f4) [easy, normal, hard]
data/gods/*.tres ×5                   (f4) - línea ai_profile
data/catalog/spells/*.tres ×13        (f5) ai_use, ai_phase (ver §12)   (C) con 055x por línea
data/catalog/abilities/hmba.tres      (f1) solo se referencia (mana_source) desde ai_side.tscn
debug/ai/
  [+] decision_log.gd                 (f0) DecisionLog: escucha AiSide y AiAudit; una línea por decisión
  [~] ai_match.gd                     (f0) --decisions=<archivo>, --gods=a,b
  [+] decision_cases.txt              (f0) los 12 casos de §10
  [+] ai_spells_lab.tscn, ai_spells_lab_seat.tres, ai_mixed_book.tres (f5)
  [~] oscillation_probe.gd            (f1) sin MAHO_TAG
debug/rules/ [+] ai_spells_lab.tres, ai_spells_lab_threat.tres (f5)
debug/suite/
  [+] ai_names_cases.gd + legacy_track_bits.gd (f1) · ai_sight_cases.gd (f2) · ai_tactics_cases.gd (f4)
  [+] ai_spell_use_cases.gd (f5) · ai_knowledge_cases.gd (f6)
  [~] rules_suite.gd (C, una línea por corte), ai_cases.gd (f1, f4), spell_field_cases.gd (f1), tower_cases.gd (f1),
      stalk/ward/cloud/control/zone/tornado/time_unit_cases.gd (f4: profile_original → tactics_normal), catalog_cases.gd (f4)
agent/
  [+] run_ai_decisions.sh             (f0) recorre decision_cases.txt; <before|after> → agent/out/055f/<fase>/<caso>.log
  [+] flows/055f_spells_lab.json      (f5) playtest con ventana
tools/lint/baseline.txt               (C) solo el orquestador, al final
```
Ningún sub-corte toca:
- `scenes/units/abilities`, `attacks`, `unit_body.gd` ni `unit.tscn`;
- `scenes/spells/actions` ni FX;
- `math/ai_rater.gd`, hasta que e6 integre.

## 4. Responsabilidades
| Pieza | Hace | No hace |
|---|---|---|
| `AiSide` | Arma el lado: asiento → `AiPlay`; cablea hijos y puerto | Decidir; contar ticks |
| `AiClock` | Corre los 6 trabajos en orden, con su periodo y sus despertares (`Wake`) | Saber qué hace cada trabajo |
| `AiPlay` | Con qué juega este lado (tácticas, dificultad, agresión, edades) | Mutar un `.tres` |
| `AiPerception` | Qué cuerpos conoce el lado (índice) y en qué relación | Mirar (`Vision`); recordar posiciones (`Belief`) |
| `SightIntake` | Toma lo que `Vision` aprende y olvida lo que ya no está donde se lo vio | Ver; decidir |
| `Belief` | Qué cree la IA de un cuerpo que no ve (posición, vida, maná) | Leer el estado real de lo no visto (f6) |
| `Souls` | Almas candidatas para tocar o convertir | Lanzar |
| `AiBody` | El único lugar donde la IA lee un cuerpo | Escribir en él |
| `AiTrackFacts` | Qué es un cuerpo para la IA (`Kind`, `Site`, `fights`, `ready`) | Seguirlo en el tiempo |
| `AiWizardBrain` | Replanea (fases) y elige entre almas, captura, lanzar o mandar | Puntuar; pedir al juego |
| `Casting` | Recorre la cola y lanza lo que puede pagar y el juego aceptaría | Puntuar |
| `AiSpellEval` + `ratings/` | Puntúa un hechizo sobre un blanco según su `ai_use` | Leer tags; lanzar |
| `AiPhase` (hijos) | Llena la cola en su fase | Lanzar |
| `AiTask` (hijos) | Registra blancos y reclama criaturas | Mover cuerpos |
| `AiCommandPort` + `Orders` | Única salida: `request_*`, `Orders.apply_for`, `request_walk` | Tocar vida, maná o almas |
| `AiTactics` (+ `crowd`, `senses`) | Cómo juega una dificultad, en segundos y metros | Cambiar en partida |
| `AiDifficulty` | Ritmo, demora, conocimiento y qué tácticas usa | Bonificar recursos |
| `VisionSides.events` | Avisa cuando un lado aprende un cuerpo nuevo | Decidir qué sabe la IA |
| `DecisionLog` (debug) | Escribe cada decisión para comparar antes y después | Correr en el producto |

## 5. Composición
- Todo es composición; la herencia se queda en profundidad ≤1 (`AiPhase`, `AiTask`).
- Los hijos nuevos (`Clock`, `Perception/SightIntake|Belief|Souls`, `Brain/Casting`, `Port/Orders`) son nodos de `ai_side.tscn`, con socket `@export` desde el padre que los usa y aviso si falta. Ningún hijo nombra a su padre (C4).
- Sacar un hijo apaga su conducta:
  - sin `AttackPhase`, el mago es pacífico;
  - sin `SightIntake`, la IA solo conoce lo del escaneo inicial y lo propio;
  - sin `FocusTask`, no hay foco.
- `AiPlay` reemplaza a `node.set("profile", …)`: cada hijo tiene `var play: AiPlay` tipado y `AiSide.setup` lo asigna una vez. Es el único dueño, derivado e idempotente.
- El Manahoar es un `AiTrack.Kind.MANAHOAR` cuando `type.has_passive(perception.mana_source)`. `mana_source` es un `@export` de `Perception` en `ai_side.tscn` que apunta a `data/catalog/abilities/hmba.tres`, el mismo `.tres` que usa `UnitManaSupport.source`.

## 6. Resources vs nodos (tácticas como `.tres`)
- **Resources de tipo** (nunca se mutan): `AiTactics`, que embebe `AiCrowdTactics` y `AiSenses` como `sub_resource` del mismo archivo (sin cadena de archivos). También `AiDifficulty`, `AiDifficultyList`, `AiSeat`, `SpellType` (`ai_use`, `ai_phase`) y `GodBook`.
- **Nodos con `@export` de instancia** (en `ai_side.tscn`):
  - `AiClock`: `status_every_s = 0.2`, `stance_every_s = 1.0`, `perception_every_s = 0.1`, `groups_every_s = 0.1`, `replan_every_s = 1.0`, `think_every_s = 0.2`, que hoy son 12/60/6/6/60/12 ticks;
  - `Perception.mana_source`;
  - los sockets entre hijos.
- **Runtime en el nodo:** tracks, registros, colas, marcas de inútil, `AiPlay`.
- **Qué va a `AiTactics`.** Lo que un diseñador ajustaría: distancias, umbrales, pesos y tiempos.
  - Pasan los 34 números de `AiProfile` y los literales de código: `guard_pick_near_m = 10`, `guard_pick_far_m = 3620`, `ghost_wait_m = 256`, `build_reach_factor = 5`, `wizard_stop_m = 10`, `range_slack = 1.4`.
  - Para f5: `escape_threat`, `self_area_min_foes`, `heal_area_min_missing`.
  - **No pasan** (quedan como `const` con nombre y `## Ref:`): los pesos internos de las fórmulas de captura (0.8/0.2/0.99/0.9/0.1/0.4), los tamaños del acumulador de `AiRater` y `SAME_POS_SQ`.

## 7. Los seis verbos («cómo lo hace un humano»)
| Verbo | Qué abre / toca | Lugares |
|---|---|---|
| Entender | `scenes/ai/ai_side.tscn`: el árbol es la IA (Perception, Stance, Groups, Brain y sus fases, Tasks y sus tareas, Port). `data/ai/tactics_normal.tres` agrupa por fase (Ataque, Apoyo, Convocar, Convertir, Captura, Foco, Grupos, Sentidos). README | 1–2 |
| Modificar | Un número de `tactics_<dificultad>.tres` (p. ej. `heal_below_ratio`) o de `difficulty_<x>.tres` (`period_scale`, `request_delay_s`) | 1 |
| Agregar | Que la IA use un hechizo nuevo: `ai_use`/`ai_phase` en su `.tres`, sin código si el uso existe. Una conducta nueva: un hijo `AiPhase`/`AiTask` en `ai_side.tscn` y su script | 1 (2 con conducta) |
| Quitar | Sacar el hijo de `ai_side.tscn`, o `ai_phase = NEVER` en el hechizo | 1 |
| Crear | Una dificultad o personalidad: duplicar `difficulty_normal.tres` y `tactics_normal.tres` y arrastrarla a `difficulties.tres`. Un asiento con personalidad propia: `AiSeat.tactics` | 2 |
| Escalar | N hechizos por `ai_use`, N dificultades por `.tres`, N lados por `AiRoster`; un evaluador por uso, no por hechizo | lineal, sin código |

## 8. Contratos
### 8.1 `AiTrack` y `AiTrackFacts` (f1)
```gdscript
enum Kind { NONE, WIZARD, CREATURE, MANAHOAR, STRUCTURE }     # mismo orden que WIZ/CRE/MAHO/STR
enum Relation { OWN, ALLY, NEUTRAL, ENEMY }                   # = el índice de category() de hoy
enum Site { NONE, ALTAR, FOUNT, MANALITH, SHRINE }
var relation := Relation.NEUTRAL
var seen := false        # SEEN 0x80
var fights := false      # status ACTIVE (1): tiene habilidades o aggressiveness != 0; el mago siempre
var ready := false       # READY 0x1000: Manahoar que puede canalizar / estructura con el tope libre
var free_fount := false  # UNBUILT 0x8000
var site := Site.NONE
func is_wizard() -> bool        # status & 0x2/0x4/0x8/0x20000 (solo los magos llevan esos bits)
func is_altar() -> bool         # flags ALTAR 0x200
func is_tower() -> bool         # MANALITH, o 0x40000 sin ALTAR = Manalith o Shrine (capture_task:64)
func capturable() -> bool       # CAPTURABLE: true en las 4 clases de estructura (0xc17 da ≠0 en todas)
func category() -> int          # se queda como alias de relation (los suite cases la usan)
# AiTrackFacts (static)
static func site_of(node: Node) -> AiTrack.Site
static func setup(t: AiTrack, perception: AiPerception) -> void
static func refresh_structure(t: AiTrack) -> void
```
Tabla de verdad de hoy, que `ai_names_cases` congela contra `legacy_track_bits.gd`, una copia literal de `_bldg_flags` y `_status_of_structure`:
| Site (BLDG) | ALTAR 0x200 | CAPTURABLE | READY | MANALITH | 0x40000 | UNBUILT |
|---|---|---|---|---|---|---|
| ALTAR (0x1407) | sí | sí | tope libre | no | sí | no |
| FOUNT (0x2810) | no | sí | tope libre | no | no | si está libre |
| MANALITH (0x55a0) | no | sí | tope libre | sí | no | no |
| SHRINE (0x15a6) | no | sí | tope libre | no | sí | no |

Otros reemplazos, todos con la misma aritmética:
- `status & 9` y `status & 0x3` → `fights`; `& 0xc` y `& 0x20000` → `is_wizard()`;
- `AiField.attack_weight(d, thr, foe)`: `not foe.is_wizard()` → ×`weight_passive`; `not foe.ready` → ×`weight_no_ability`;
- `AiRecord.flags & 2` → `capture`;
- `distances_to(from, category, mask)` → `distances_to_altars(from, relation)`.

### 8.2 Órdenes y comandos (f1)
```gdscript
enum AiOrder { MOVE_NEAR = 2, GUARD = 3, MOVE = 4, REFILL = 5, ATTACK = 6, ADVANCE = 7, TAKE_SOUL = 34 }  # mismos enteros (logs)
# AiTask.command() -> Kind     (IDLE ya no devuelve 0x64692e70: ningún cerebro lo lee; se compara Kind.CAPTURE)
```

### 8.3 Percepción sobre `Vision` (f2)
```gdscript
# scenes/units/vision/vision_events.gd
class_name VisionEvents extends Object
signal learned(side: int, node: Node3D)          # un Vision del lado `side` (o una exposición) aprendió `node`
# VisionSides
static var events := VisionEvents.new()
static func hears(from: int, side: int, rules: MatchRules) -> bool    # el _hears de hoy, público
# VisionMemory.take_in / expose_to: emiten learned para cada id que NO estaba conocido en `now`
# (ausente, o presente pero vencido por lapsed(): el borrado de _older es perezoso)
```
`SightIntake` hace tres cosas:
- `pending: Dictionary[int, Node3D]` se llena con `learned` cuando `hears(from, slot)`.
- `drain_new()`, llamado desde `discover()`, agrega lo pendiente que `VisionSides.sees(slot, n)` y no está seguido, ordenado por `VisionRules.by_name`. Lo que rechaza `_should_track` por región **se queda pendiente** mientras se siga viendo (hoy se reintenta en cada replan).
- `drain_lost()`, llamado desde `update_nodes`, hace lo mismo pero solo con lo olvidado (`_lost`).

El ojo de Divine Sight entra solo, porque su `Vision` emite como cualquier otra. `seen_by()` queda solo para `leak_count` y la suite.

### 8.4 Tácticas y reloj (f4)
```gdscript
class AiPlay extends RefCounted:
	var tactics: AiTactics; var difficulty: AiDifficulty; var aggression: float
	var age_ticks: int                          # periodo base de perception_every_s, sin escalar (= profile.age_period_ticks)
	func ages_for(seconds: float) -> int        # MatchClock.ticks_for(seconds) / age_ticks
# AiClock
enum Wake { REPLAN = 1, STATS = 2, STANCE = 4, SCAN = 8, TASKS = 0x20 }   # = los bits de forceFlags; FORCE_MASKS con nombre
@export var status_every_s := 0.2 … @export var think_every_s := 0.2
func ticks(job: int) -> int                     # floor(ticks_for(s) * difficulty.period_scale + 1e-4), mínimo 1
# AiSeat
@export var tactics: AiTactics                  # override; vacío = difficulty.tactics_or_normal()
@export var book: GodBook                       # override del libro del mago (banco y solo; no viaja por red)
static func difficulty_of(id: String) -> AiDifficulty   # busca en data/ai/difficulties.tres por nombre de archivo
```
Los arranques escalonados `[0, 0, 1, 3, 0, 6]` quedan como `const START_TICKS` en `AiClock`, con su explicación.

### 8.5 Usos nuevos (f5, `SpellType.AiUse`, solo se agrega al final)
`SELF_AREA, TAKE_FOE, RAISE_DEAD, GATHER_SOULS, ESCAPE, GUARD_SITE, HEAL_AREA`.
- `rating_fn` despacha a `ratings/` (FN 7..13).
- `Casting` pide `Caster.action_status(tag, point, picked)` para **todo** hechizo antes de `start_casting`, no solo para las estructuras. `lands_on` y `can_cast_on` quedan como filtro barato.

### 8.6 Conocimiento (f6)
```gdscript
enum Knowledge { SIGHT, SIGHT_AND_MAP }   # AiDifficulty.knowledge reemplaza perfect_information
```
- `SIGHT` = la regla de hoy en Normal.
- `SIGHT_AND_MAP` = `SIGHT` más la posición (nunca vida ni maná) de los cuerpos dentro de `tactics.senses.map_sight_m` del mago propio y de los magos enemigos. Es lo que el humano ve en el minimapa. Un caso compara `map_sight_m` con el radio del minimapa.

## 9. Sub-cortes
| Corte | Qué | Depende de | En paralelo con |
|---|---|---|---|
| **f0** grabador | `AiWizardBrain.replanned(wizard, queue)` y `AiTaskBoard.replanned(tasks)`: señales sin cambio de conducta. `DecisionLog`, `--decisions`, `--gods`, `decision_cases.txt`, `run_ai_decisions.sh`. **El orquestador graba la base dos veces** (§10.1) | — | 055x, e6 |
| **f1** nombres | §8.1, §8.2, `AiTrackFacts`, `AiBody` (lectura central, C7 4→0), `mana_source` en lugar de `MAHO_TAG`, `legacy_track_bits` y `ai_names_cases`, ajuste de los casos que usan bits | f0 grabado | 055x, e6 (no toca `ai_rater`) |
| **f2** percepción | §8.3, el emisor en `scenes/units/vision`, `AiPerception` partida (`SightIntake`, `Belief`, `Souls`, `AiRituals`), `ai_sight_cases`, README de `vision` | f1 | f3 |
| **f3** cerebros y salida | `wizard_brain` partido (`Casting`, `ShotCheck`, `FutileTargets`, `CaptureCasts`), `ai_spell_eval` partido, `Port/Orders`, `AiRecordRunner` | f1 | f2 |
| **f4** tácticas en `.tres` | §8.4: `AiProfile` fuera (7 `.tres` y `GodType.ai_profile`), `AiTactics`/`AiCrowdTactics`/`AiSenses` con los valores de hoy, `AiClock`, `AiPlay`, `ai_side_report`, `difficulties.tres`, `AiSeat.tactics` y `book`, todos los `profile.` → `play.tactics.…`, `ai_tactics_cases` | f2, f3 | — |
| — | **Pasada de paridad** (orquestador, headless): registro `after_f4` vs `before` | f4 | — |
| **f5** todos los hechizos | §8.5, `ratings/`, 13 `.tres` (§12), rareza de `attack_weight` (usa `fights` y la habilidad lista de verdad), laboratorio, `ai_spell_use_cases`, flujo | pasada f4 | f6 |
| **f6** sin trampa | §8.6, `Belief` con `Knowledge`, escaneo inicial con la regla (§13.3), `difficulty_hard.tres`, `ai_knowledge_cases` | pasada f4 | f5 |
| **f7** cierre | README de `scenes/ai` (cinco líneas, `Check:`), `## Ref:` al final (C9 32 → 0 en lo tocado), `print` → `DebugLog` (C14 11 → 0), C6 2 → 0 (`Soul.GROUP`, `UnitSpawner.GROUP`), C12 3 → 2 (fuera `MpKit.` de `ai_perception`), citas de `ai_rater` si e6 integró, una frase del PRD, fila del RFC y baseline | f5, f6 (y e6 para `ai_rater`) | — |

Orden dentro de cada corte (el developer no corre Godot):
- **f1:** `AiTrack` → `AiTrackFacts` + `AiBody` → reemplazos carpeta por carpeta → `legacy_track_bits` + caso → lint.
- **f2:** emisor en `vision` → `SightIntake` → `Belief`/`Souls`/`AiRituals` → nodos en `ai_side.tscn` → caso → lint.
- **f3:** `Casting` → `ShotCheck`/`FutileTargets`/`CaptureCasts` → `ai_spell_eval` partido → `Port/Orders` → `AiRecordRunner` → lint.
- **f4:** `AiSenses`/`AiCrowdTactics`/`AiTactics` con los valores de `profile_original` copiados uno a uno → `AiPlay` → `AiClock` → lectores → borrar `AiProfile` y sus `.tres` → casos → lint.

Reglas para f1–f4: mover líneas sin cambiar la aritmética ni el orden; ningún `f32()` agregado ni quitado; los literales que pasan a `.tres` se copian con todos sus dígitos (p. ej. `0.7142857313156128`).

## 10. Pruebas
### 10.1 Registro de decisiones (paridad, estilo 055g)
- **Línea del registro**, una por decisión, con los flotantes a 1e-4:
  - `tick slot replan i phase spell target score range obj`: cada entrada de la cola después de un replan;
  - `tick slot task kind target score members leader`: los registros después de `claim_pass`;
  - `tick slot know +|- name origin`: `tracked` y `untracked`;
  - `tick slot stance enemy_ratio threat`: en cada corrida del trabajo de postura;
  - más las líneas del audit `cast|summon|reject|lapse|order|manalith|desecrate|died|purse`.
- **12 casos** (`decision_cases.txt`, `--headless --fixed-fps 60`, un proceso por caso, Godot de a uno):
  1. `ai_duel_seeded` s3 pyro,charnel;
  2. s7 persephone,stratos;
  3. s11 james,pyro;
  4. `ai_easy_vs_normal` s7;
  5. `ai_duel_seeded --difficulties=hard,normal` s5;
  6. `ai_convert`;
  7. `ai_guard`;
  8. `ai_defend`;
  9. `ai_2v2_flat4` s2;
  10. `ai_ffa4_flat4` s4;
  11. `ai_npc_load`;
  12. `f372_ai_heal` y `f373_ai_finish_normal`.

  Todos con `--minutes=4`, salvo los dos últimos, que usan su propio tiempo.
- **f0 (base):** cada caso dos veces, `before/` y `before_b/`.
  - Si `diff` da vacío, el caso es **estricto**.
  - Si no, el caso es **agregado**: cuentas por clase de línea y por hechizo en ventanas de 30 s, ±0 en las de la IA, mismo ganador. Se anota cuál y por qué.
- **Pasada f4:** `after_f4/`. Criterio: `diff` vacío en los estrictos y agregados iguales en el resto. Si algo difiere, se bisecta por sub-corte (f1, f2, f3 y f4 son commits separados) antes de seguir.
- **f5 y f6 cambian conducta a propósito:** se graba `after_design/` y se anota una tabla en el F con cuentas por uso, `reject = 0`, `unseen_reads = 0` en las tres dificultades, ganador por caso y `ai_ms` p99 ≤ 2 ms (adenda 1.2 de RFC-024).

### 10.2 Suite (`rules_suite --fixed-fps 600`)
- **`ai_names_cases` (f1):**
  - las 4 clases de estructura y 3 de cuerpo, campo con nombre contra bit legado;
  - `attack_weight` por tipo de enemigo, idéntico al bit;
  - `Kind.MANAHOAR` sale de `has_passive(hmba)` en los 72 tipos, igual que `tag == "oham"`.
- **`ai_sight_cases` (f2):**
  - escena guionada con 2 lados, un enemigo que entra, sale, vuelve, cambia de región y lo revela un golpe;
  - `SightIntake` contra la referencia de sondeo (copia literal de `_take_in_seen` y `_recall_seen`): mismos tracks en los mismos ticks;
  - un id vencido y no borrado vuelve a emitir.
- **`ai_tactics_cases` (f4):**
  - cada campo nuevo igual al literal de `profile_original` de hoy;
  - `AiClock.ticks` en Fácil, Normal y Difícil = 24/120/12/12/120/24, 12/60/6/6/60/12 y 9/45/4/4/45/9;
  - edades 16/8/32/8/16/8;
  - `1/(guard_pick_far_m − guard_pick_near_m)` en f32 igual a `0.0002770083083305508`.
- **`ai_spell_use_cases` (f5):** cada uno de los 13 de §12 puntúa > 0 en su situación y 0 en la contraria (Halo sin enemigos cerca, Charm sobre un mago, Animate Dead sin cadáver…).
- **`ai_knowledge_cases` (f6):** `unseen_reads = 0` en Difícil; `SIGHT_AND_MAP` da posición y nunca vida ni maná.
- Siguen verdes sin cambios: `ai_cases` (ajustada en f1 y f4), `spell_field`, `ward`, `control`, `chain`, `zone`, `cloud`, `stalk`, `tornado`, `tower`, `time_unit`, `catalog`.

### 10.3 Lo demás
- Import → lint (ningún conteo sube; en `scenes/ai` bajan C9, C14, C7, C6, C5, C1a y C1b) → NET QUICK PASS (la IA no agrega RPC; el cable no cambia).
- Con ventana, solo f5: `ai_spells_lab.tscn` + `agent/flows/055f_spells_lab.json`, con un PNG por hechizo lanzado y el criterio `expects` de §2.

## 11. Riesgos
1. **La base puede no reproducirse:** sin banco de determinismo, dos corridas pueden diferir. Mitigación: doble grabación y casos agregados (§10.1).
2. **Paridad del emisor de `Vision`:** borrado perezoso de `_older`, reintento por región, ojo de Divine Sight, exposición. Mitigación: contrato §8.3 y `ai_sight_cases`.
3. **float32:** un literal copiado sin todos sus dígitos o un `f32()` movido cambia una decisión. Lo cubren `ai_tactics_cases` y el registro.
4. **f1 toca casi todos los archivos de `scenes/ai`:** va solo y primero; f2 y f3 parten de él por carpetas disjuntas.
5. **e6** reescribe los lectores de habilidades: `ai_rater.gd` no se toca; f5 lee `fights` y la habilidad lista por `AiBody`, no por bits de `AbilityType`.
6. **055x** puede tocar los mismos `data/catalog/spells/*.tres`: f5 cambia solo las líneas `ai_use`/`ai_phase` (merge por línea); si choca, f5 se rebasa sobre 055x.
7. **Borrar `GodType.ai_profile`:** sin quitar la línea de los 5 `data/gods/*.tres`, Godot avisa al cargar. Se quitan en el mismo commit; `catalog_cases` cambia de control.
8. **f5 y f6 cambian cuán fuerte juega la IA:** tabla de §10.1 con ganadores; no hay criterio de victoria, solo «sin `reject`, sin `unseen_reads`, p99 ≤ 2 ms».
9. **`AiSeat.book`** no viaja por red (como `WizardBody.book`): `push_warning` si se usa con red.
10. **Ids de dificultad en salas** (`easy`, `normal`, `hard`): no cambian; `difficulties.tres` los resuelve por nombre de archivo.
11. **Efectos de Soul Mole, Guardian y Shrine para la IA:** verificar con `SoulAction`, `GuardianAction` y `StructureAction` antes de fijar `ai_use`; lo no confirmado se marca NO VERIFICADO en §12 y queda `NEVER`.

**Fuera de alcance:** `ai_audit.gd` (banco, C1b), las fórmulas de `AiRater` (e6), sockets tipados en `WizardBody` (`caster`, `spellbook`, `mana_pool`, `soul_purse`; los reemplaza `AiBody` hasta un corte de `wizards`), Bore (057), personalidad por dios (RFC de contenido), fórmulas de captura y foco más allá de los nombres, `VillagerBrain` (NPC).

## 12. Hechizos que la IA no usa hoy (f5)
| Hechizo | Hoy | Queda | Evaluador | Caso |
|---|---|---|---|---|
| Halo of Earth (olah) | HIT_AREA·ATTACK, solo sobre sí → nunca | SELF_AREA·ATTACK | `ai_self_area` (≥ `self_area_min_foes` en `effect_range_m`) | lab |
| Charm (mrhc) | NONE·ATTACK | TAKE_FOE·ATTACK | `ai_take_foe` (criatura, no mago, `SpellTarget.neutral_allowed`) | lab |
| Death (taed) | NONE·ATTACK | HIT_AREA·ATTACK (`max_targets = 8` acota) | `_area` | lab |
| Meanstalks (rter) | HEAL·SUPPORT (rareza) | HIT_AREA·ATTACK | `_area` | lab |
| Rainbow (wobr) | HEAL (un solo blanco) | HEAL_AREA·SUPPORT | `ai_heal_area` | lab |
| Healing Aura (ruah) | HEAL | HEAL_AREA·SUPPORT | `ai_heal_area` | aura_cases |
| Animate Dead (deda) | NONE·NEVER | RAISE_DEAD·SUPPORT | `ai_raise_dead` | lab |
| Soul Wind (dnws) | NONE·NEVER | GATHER_SOULS·SUPPORT | `ai_gather_souls` | lab |
| Soul Mole (pmcd) | NONE·NEVER | GATHER_SOULS·SUPPORT (NO VERIFICADO) | `ai_gather_souls` | soul_cases |
| Teleport (elet) | NONE·SUPPORT, solo sobre sí | ESCAPE·SUPPORT | `ai_escape` | lab_threat |
| Guardian (ndrg) | NONE·SUPPORT | GUARD_SITE·SUPPORT (NO VERIFICADO) | `ai_guard_site` | lab_threat |
| Shrine (pcas) | NONE·NEVER | por `CaptureCasts`, si `only_free_manafounts`; si no, NEVER (NO VERIFICADO) | — | tower_cases |
| Bore (erob) | NONE·NEVER | NEVER, excepción documentada hasta 057 | — | — |

Rareza de `AiField.attack_weight` (f5): hoy toda criatura pesa ×0,5 «pasiva» y ×1/3 «sin habilidad lista», porque los bits que se leen solo los tiene el mago o el Manahoar listo. Queda ×`weight_passive` si `not foe.fights` y ×`weight_no_ability` si no tiene una habilidad con maná suficiente (leída por `AiBody`).

## 13. Preguntas (recomendaciones aprobadas)
1. **Alcance de la paridad.** f1–f4 son paridad estricta; solo f5 y f6 cambian conducta. Sí.
2. **Difícil con información perfecta.** Se elimina: `Knowledge.SIGHT_AND_MAP` (f6). Difícil conserva ritmo ×0,75 y demora 0.
3. **Escaneo inicial.** Quedan estructuras y magos (el humano los ve en el minimapa o con su flecha). Criaturas, solo dentro de `map_sight_m` en `SIGHT_AND_MAP`, ninguna en `SIGHT`. Es f6, cambio de conducta.
4. **`AiProfile`.** Se borra con sus 7 `.tres` y `GodType.ai_profile`. La personalidad va por `AiSeat.tactics`.
5. **Reloj.** En `AiClock`, nodo de `ai_side.tscn`, en segundos. La dificultad lo escala.
6. **Forma de las tácticas.** Un `.tres` por dificultad con `crowd` y `senses` embebidos (no archivos aparte).
7. **Rarezas de 055e.** Se corrigen en f5 según §12.
8. **Bore.** Queda NEVER hasta 057. Shrine, Soul Mole y Guardian se verifican antes de fijar el uso.
9. **Blancos IA y clic.** Unificados: `action_status` para todo hechizo es la última palabra; el filtro de `SpellType` queda solo para puntuar barato.
10. **Emisor de `Vision`.** `VisionSides.events` (un `Object` con señal) en `scenes/units/vision`, emitido desde `VisionMemory`.
11. **Libro por asiento.** `AiSeat.book` para el banco y solo; con red, aviso.
12. **Lista de dificultades.** `data/ai/difficulties.tres` en lugar de `DIFFICULTY_TAGS` y una ruta armada con texto.
13. **`ai_audit.gd` (476 líneas).** Queda fuera; es del banco.
14. **PRD:33-34.** Se ajusta en f7: «La IA es un jugador más… con diseño propio; el original es referencia».
15. **Base.** f0 la graba el orquestador antes de integrar f1, y la pasada de paridad corre al juntar f4: son las dos excepciones a «probar todo al final».
16. **`AiRater` y e6.** 055f no lo toca; si e6 no integró al cerrar, sus citas quedan para 055z.
