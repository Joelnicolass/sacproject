# Auditoría de calidad del código: arquitectura y detalle

2026-10-28 · rama `refactor/new-systems` · solo lectura (no se editó nada; `bash tools/lint/conventions.sh` da verde, sin cambios en el árbol).

Este informe **complementa** `docs/AUDIT-godot-standard.md` y no repite sus métricas globales (tags, cantidad de comentarios con RFC, scripts sueltos, idioma, GUT/CI, docs). Va un nivel más abajo: recorridos concretos, arquitectura y ejemplos con `file:line`.

**La vara de medir son estándares externos**, no las convenciones propias (`CONVENTIONS.md`, reglas C1–C25, RULES). Cuando una convención propia contradice el estándar, lo digo en el §4 y recomiendo el estándar.

## 0. Fuentes (el «estándar» de este informe)

| # | Fuente | Qué se usa |
|---|---|---|
| S1 | [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) | Orden del código, nombres, menos de 100 columnas, una sentencia por línea, dos líneas en blanco entre funciones |
| S2 | [GDScript documentation comments](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html) | `##` es la documentación de la API: aparece en la ayuda y como tooltip del inspector |
| S3 | [Static typing in GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) | `Dictionary[K, V]`, avisos `UNSAFE_PROPERTY_ACCESS` / `UNSAFE_METHOD_ACCESS` / `UNTYPED_DECLARATION` |
| S4 | [Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | Escenas sin dependencias, inyección desde el padre, el ancestro media entre hermanos, Main/World/GUI |
| S5 | [When to use scenes versus scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html) | Los conceptos propios del juego «should always be a scene» |
| S6 | [Autoloads versus regular nodes](https://docs.godotengine.org/en/4.7/tutorials/best_practices/autoloads_versus_regular_nodes.html) | Un autoload solo si «is managing its own information»; `static var` y `class_name` como alternativas |
| S7 | [Godot interfaces](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_interfaces.html) | `@export` antes que rutas; el duck typing por grupos «require good documentation» |
| S8 | [Logic preferences](https://docs.godotengine.org/en/stable/tutorials/best_practices/logic_preferences.html) | Sin `preload` en el valor por defecto de un `@export`; partir escenas grandes |
| S9 | [Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html) | Agrupar los assets «as close to scenes as possible», todo en snake_case |
| S10 | [Scene unique nodes](https://docs.godotengine.org/en/stable/tutorials/scripting/scene_unique_nodes.html) · [Groups](https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html) | `%Nombre` dentro de la escena; grupos globales declarados en Project Settings |
| S11 | [Import process](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html) | Los `.import` se versionan: «Make sure to commit these files» |
| S12 | gdtoolkit: [linter](https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter) y [defaults](https://github.com/Scony/godot-gdscript-toolkit/blob/master/gdtoolkit/linter/__init__.py) | `max-file-lines: 1000`, `max-line-length: 100`, `max-public-methods: 20`, `max-returns: 6`, `class-definitions-order` |
| S13 | GUT: [Quick start](https://gut.readthedocs.io/en/latest/Quick-Start.html) · [Command line](https://gut.readthedocs.io/en/latest/Command-Line.html) | `res://test/unit`, `test_*.gd`, `extends GutTest`, `gut_cmdln.gd … -gexit` |
| S14 | [GDQuest GDScript guidelines](https://gdquest.gitbook.io/gdquests-guidelines/godot-gdscript-guidelines) · [Event bus](https://www.gdquest.com/library/pattern_event_bus_singleton) | Código autoexplicativo y comentarios escasos; el bus de eventos con moderación |
| S15 | [godot-demo-projects](https://github.com/godotengine/godot-demo-projects) (`3d/platformer/player/player.gd`) | Referencia: unas 200 líneas, 11 comentarios con `#`, ninguno con `##`, ninguna referencia externa |

## Resumen

1. **El tipado es al 100 % de nombre, no de hecho.** Sí, toda `var` y toda `func` tienen tipo. Pero hay 269 `Dictionary` sin tipar contra 41 tipados, 199 `Array` sin tipar, 67 funciones que devuelven `Dictionary`, 269 `.get("prop")`, 26 `.set("prop", …)`, 57 `"prop" in obj` y 37 llamadas `# dynamic:` con `has_method` / `call`. Gran parte del flujo entre sistemas pasa por texto. Los avisos `UNSAFE_*` de Godot (S3) están apagados: `project.godot` no tiene ninguna clave `gdscript`.
2. **Cada criatura carga todos los componentes posibles y los apaga según los datos.** `unit.tscn` tiene 126 nodos, y 52 son el subárbol `Afflictions`, copiado a mano en `wizard_body.tscn` (47 de sus 91 nodos). `FireShield`, `LightningCharge`, `DamagePassive`, `LifeShield`, `DevourGrowth` y `DeathCloudSpawner` están en todas las criaturas y cada uno pregunta `type.has_passive(...)`.
3. **Hay un «contrato de cuerpo» implícito**, sin tipo, entre `UnitBody`, `WizardBody`, `DoctorBody` y las estructuras. Son `is_targetable`, `facing_flat`, `display_name`, `is_dead`… 33 de las 37 llamadas dinámicas son a ese contrato.
4. **Hay estado global escondido fuera de los autoloads**: 45 `static var` que no son cachés (`MatchClock`, `MatchSeed`, `MatchSky`, `SideRelations`, `ActiveMatch`, `DebugLog`). Además hay dos catálogos para lo mismo: el autoload `GameData` (3 usos) y `GameCatalog.shared()` (14).
5. **Hay referencias por convención de nombre**, invisibles en el inspector: `data/shots/<tag>.tscn`, `data/targeting/<tag>.tres`, `scenes/structures/buildings/<archivo>.tscn`, `projectile_kind = "Fireball"`. El lint propio, basado en grep, no las ve (C18c da 0).
6. **Hay código muerto** que confunde: `AiAudit` (480 líneas más 32 enganches) no se instancia en ninguna escena; `SpellAction.prompt` está cargado en 48 escenas y nunca se dibuja; los `debug_*` de los cuerpos no tienen llamadores; hay señales que «solo escucha el banco».
7. **Algunas convenciones propias empeoran la legibilidad frente al estándar** (§4):
   - el tope de 150 líneas: 31 scripts miden exactamente 150 y hay código comprimido para entrar;
   - el `## Ref:` obligatorio en comentarios de documentación, que lo vuelve tooltip del inspector en 222 `@export`;
   - `##` en todos lados: 284 dentro de funciones;
   - la separación `data/` y `scenes/`: el Firefist está repartido en 13 carpetas y 4 nombres.

---

## 1. Recorridos de un recién llegado

Para cada sistema elegí una tarea típica. «Abrir» cuenta los archivos que hay que leer para entender y cambiar. «Ideal» es lo que haría falta en un proyecto Godot estándar.

### 1.1 Una criatura: «que la furia del Firefist pegue más»

| # | Archivo | Por qué hay que abrirlo |
|---|---|---|
| 1 | `data/catalog/creatures/firefist.tres` | `on_damage = ahtf.tres`; nada dice «furia» |
| 2 | `data/catalog/abilities/ahtf.tres` | Es un `AbilityType` «Firefist Passive» con `mana_cost = 10`, `cast_range_m = 100`, `cooldown_s = 1.25` y `effect` vacío. Ninguno de esos números es la furia |
| 3 | grep `ahtf` → `data/passives/firefist_fury.tres` | Acá está el número (`outgoing_melee_per_missing = 1.5`) y apunta **de vuelta** a `ahtf.tres` |
| 4 | `scenes/units/unit.tscn:274-278` | `DamagePassive.types` lista a mano `taurock_hide.tres` y `firefist_fury.tres` |
| 5 | `scenes/units/passives/damage_passive.gd:64-74` | Búsqueda inversa: recorre `types` hasta que `candidate.ability == body.type.on_damage` |
| 6 | `scenes/units/passives/damage_passive_type.gd:28-33` | La fórmula |
| 7 | `scenes/units/weapons/melee_weapon.gd` | Quién llama a `outgoing_melee_factor` |

**Abrir: 7 archivos y un grep. Ideal: 2** (`firefist.tres` y su recurso de pasiva).

Qué confunde:
- **El dato está invertido.** La criatura apunta a una habilidad vacía, y el recurso con el número apunta a esa habilidad. Una pasiva nueva exige tocar `unit.tscn`, que es la escena de todas las criaturas.
- **Todas las criaturas cargan todos los componentes**, y cada uno se apaga solo:
  - `fire_shield.gd:154-156` (`_carries()`);
  - `lightning_charge.gd:214`;
  - `damage_passive.gd:61`;
  - `unit_mana_support.gd:24`.
  
  `fire_shield.gd:10-11` lo admite: «the other creatures carry it and ignore it».
- **El Firefist vive en 13 carpetas con 4 nombres**: `firefist`, `ftrl` (modelo), `lrtf` (criatura) y `ahtf` (pasiva). Las carpetas son `data/catalog/creatures`, `data/catalog/abilities`, `data/passives`, `data/audio/creatures`, `scenes/units/bodies` (frame y look), `scenes/bodies/models`, `scenes/bodies/models/firefist_model_clips`, `scenes/bodies/materials`, `assets/original/models`, `assets/original/textures/ftrl`, `assets/surfaces/ftrl`, `assets/original/ui/icons` y `assets/original/audio/voice/ftrl`.
- **El ataque a distancia se resuelve por nombre de archivo.** `RangedWeapon.setup` (`ranged_weapon.gd:46`) llama a `ShotSpawner.default_look(attack)`, que arma `"res://data/shots/" + ability.tag + ".tscn"` y lo carga si existe (`shot_spawner.gd:24-31`). Ningún inspector muestra ese vínculo.

### 1.2 Un hechizo de punta a punta: la Bola de fuego

Tarea: «más daño, que vuele más lento y cambiar su explosión».

| # | Archivo | Qué aporta / qué confunde |
|---|---|---|
| 1 | `data/catalog/spells/fireball.tres` | `damage = 625`, `speed_m_s = 30`, `damage_range_m = 10`, `effect_range_m = 10`: ¿cuál es la explosión? |
| 2 | `scenes/spells/actions/fireball_action.tscn` | `ThrownAction` con `projectile_kind = "Fireball"` (texto) y `prompt = "Elegí el blanco"` (muerto, ver §3 n.º 6) |
| 3 | `scenes/spells/actions/thrown_action.gd` | `projectile_kind` «names its scene in SpellSpawner» (línea 6) |
| 4 | `scenes/spells/actions/spell_action.gd` | El contrato `check / begin / started / finish / cancel`; los estados son `String` |
| 5 | `scenes/spells/launch_point.gd:23-34` | Arma el `Dictionary` con claves `"x" "y" "z" "tx" … "damage"` |
| 6 | `scenes/spells/spell_spawner.gd:12-32` | `"Fireball"` → `fireball_projectile.tscn` |
| 7 | `scenes/spells/fireball_projectile.tscn` | 4 nodos, `trail` y `explosion` |
| 8 | `scenes/spells/fireball_projectile.gd` | Lee `data["speed"]`, `data["damage_range"]`; mueve con `FPS` |
| 9 | `scenes/spells/rock_projectile.gd` | Lo usa como biblioteca a través de `_ROCK := preload(...)` (`pick_body`, `body_center`, `is_live_body`) |
| 10 | `scenes/spells/splash_damage.gd` | El daño en área |

Más `caster.gd` (472 líneas) para costo y cooldown. **Abrir: 10 u 11 archivos. Ideal: 2** (`brif.tres` y `fireball_projectile.tscn` con sus `@export`).

Qué confunde:
- **La escena del proyectil se elige con un texto** que es clave de un diccionario de otro nodo.
- **El contrato del proyectil es un `Dictionary` sin tipo**, documentado solo en un comentario (`spell_projectile.gd:4-6`).
- **El proyectil comparte código leyendo el script de otro proyectil** (`fireball_projectile.gd:7`, `launch_point.gd:6`).
- **Crea una `BoxShape3D` nueva en cada tick de física** para consultar choques (`fireball_projectile.gd:83-85`), en lugar de tener un `ShapeCast3D` o un `Area3D` en la escena.

### 1.3 El mago: «que gesticule menos en reposo y que pase a correr antes»

| # | Archivo | |
|---|---|---|
| 1 | `scenes/wizards/wizard_body.tscn` | 91 nodos, 47 de aflicciones |
| 2 | `scenes/wizards/wizard_body.gd` | 523 líneas: identidad, pick, teclas de red, caminar, warp, asiento, regeneración, clips, gestos y debug |
| 3 | `scenes/wizards/wizard_drive.gd` | Quién escribe el movimiento |
| 4 | `scenes/wizards/ghost_form.gd` | `can_move()`, `speed_factor()` |
| 5 | `scenes/units/afflictions/afflictions.gd:195-199` | `pose_role()` |
| 6 | `scenes/bodies/clip_playback.gd` / `body_animator.gd` | Qué es `ClipPose` |
| 7 | `scenes/wizards/wizard_type.gd` y `data/catalog/wizards/<x>.tres` | Velocidad |

**Abrir: 7 u 8 archivos. Ideal: 1 o 2** (un nodo `WizardClips` con sus `@export`).

Qué confunde:
- **Los umbrales están en el código y no en el inspector**: `GESTURE_EVERY := 5` (`wizard_body.gd:81`), `0.1` (`:482`), `1.6`, `20.0` y `6.0` (`:461-463`).
- **La misma tarea se resuelve distinto para las criaturas.** Allí hay un nodo `UnitClips` (`unit_clips.gd`) y regeneración (`Regeneration`) y asiento (`UnitAir`) en componentes. En el mago están inline en `wizard_body.gd:370-419`.
- **Un mismo nodo tiene tres nombres.** El nodo `ClipPose` usa el script `BodyAnimator`, se tipa como `ClipPlayback` y se guarda en `_clip_pose` (`wizard_body.gd:106`).
- **Es probable que haya un bug.** En un cliente, `_present_pose()` corre en `_process` (`:267-269`) y además en `_physics_process` (`:384-386`) con otro `delta`. El muestreo de velocidad se hace dos veces por frame.

### 1.4 La partida y su flujo: «cómo arranca Contra la IA y dónde se elige el mapa»

Cadena:
1. `scenes/core/boot.gd`
2. `scenes/core/flow/sacrifice_flow.gd` (autoload)
3. `addons/mp_kit/mp_flow.gd` (791 líneas, del kit)
4. `scenes/net/launch_flags.gd`
5. `scenes/core/flow/match_setup.gd`
6. `scenes/core/catalog/active_match.gd` (estado estático)
7. `map_catalog.gd` y `game_mode_catalog.gd`
8. `scenes/match/match.tscn` (74 nodos)
9. `scenes/match/match_world.gd`
10. `match_clock.gd`, `match_seed.gd` y `scenes/map/side_relations.gd` (los tres con estado estático)
11. `scenes/match/match_state.gd` (381 líneas)

**Abrir: 13 o 14 archivos, con 4 estados globales estáticos. Ideal: 4 o 5** (boot → flujo → `match.tscn` → `MatchState`).

Qué confunde:
- **Hay dos nodos `Match` en la misma escena**: la raíz (`match.tscn:109`, script `MatchWorld`) y su hijo (`match.tscn:256`, `MatchState`). `%Match` en `match_world.gd:80` es el hijo.
- **`_apply_match_choice()` se llama desde tres lugares** «porque es idempotente» (`sacrifice_flow.gd:103, 153, 158`).
- **`MatchWorld._bind_map()` asigna propiedades por texto**: `%Camera.set("ground", …)`, `%Nav.set("terrain", …)`, `$GraphicsApplier.set("rig", …)` (`match_world.gd:63-74`). La causa es que `world_camera.gd` y `selection.gd` no tienen `class_name`.
- **El doc de la clase está debajo de la `signal`** (`match_world.gd:4-9`), así que la ayuda del editor lo pega a `MAP_NODE`.

### 1.5 La IA: «que la IA difícil tire más hechizos de ataque»

Cadena:
1. `data/ai/tactics_hard.tres`, con comentarios `;` a mano que Godot borra al guardar desde el inspector
2. `scenes/ai/data/ai_tactics.gd`, para saber qué significa cada campo
3. `data/ai/difficulty_hard.tres` y `ai_difficulty.gd`
4. `brif.tres` (`ai_use`, `ai_phase`, `ai_worth`)
5. `scenes/ai/ai_side.tscn`
6. `brains/wizard_brain.gd`
7. `brains/phases/attack_phase.gd`
8. `brains/wizard_casting.gd`
9. `brains/ai_spell_eval.gd`
10. `math/ai_rater.gd`

**Abrir: 10 u 11 archivos. Ideal: `tactics_hard.tres` y un script.**

Qué confunde:
- **35 de los 68 scripts de `scenes/ai` son `RefCounted`** (2 525 líneas) que no aparecen en `ai_side.tscn`. El árbol muestra 23 nodos; la otra mitad del comportamiento no se ve.
- **`AiAudit` (480 líneas) y sus 32 enganches están muertos**: ninguna escena lo instancia (`ai_side.gd:28, 84, 92`; `ai_command_port.gd:18`).
- **`think(...) -> int` devuelve los códigos mágicos 0, 1 y 2** (`wizard_brain.gd:49`).
- **`ai_perception.gd:41-58` está comprimido para no pasar las 150 líneas**: `if` y `for` de una línea, líneas de 160 caracteres y `tracks_of(0..3)` en vez del enum `Relation`.

---

## 2. Arquitectura

### 2.1 Responsabilidades y dueños del estado

| Estado | Dueño hoy | Problema | Estándar |
|---|---|---|---|
| Tick, semilla, cielo y bandos de la partida | `static var` en `MatchClock`, `MatchSeed`, `MatchSky`, `SideRelations` y `ActiveMatch` | Son globales que no se ven en el árbol ni en la lista de autoloads. `MatchClock` guarda un `SceneTree` estático (`match_clock.gd:17-18`) y se engancha solo «lazily» (`:30-33`) | Lo de *esta* partida va en un nodo de la partida (S4: un subsistema por sección del árbol; S6: `static var` sirve para compartir entre instancias, no para esconder el estado de una ronda) |
| Catálogo de tipos | El autoload `GameData` (3 usos: `unit_spawner.gd:50`, `shot_spawner.gd:65, 68`) **y** `GameCatalog.shared()` (14 usos) | Dos puertas para lo mismo. `GameData` además sigue sin tipar (`game_data.gd:11-17`) y usa alias de `preload` en vez de `class_name` (`:6-9`) | Una sola: `GameCatalog` estático, o un Resource |
| Pick del mago | `WizardBody` escucha al autoload `SacrificeFlow.slot_picks_changed` (`wizard_body.gd:132, 137`; 9 usos) | El actor depende del flujo global y tiene dos ramas, servidor y cliente (`_apply_pick` / `_take_pick_type`, `:209-230`) | El padre inyecta (S4): `WizardSpawner` le da el `WizardPick` |
| Daño recibido | `Health` conoce 8 tipos de otros componentes (`health.gd:29-59`: `MatchRules`, `DamageDeflector`, `DamagePassive`, `Afflictions`, `Poisoning`, `Wards`, `Oiled`, `DevourGrowth`) y además `MatchState` por grupo (`:241`) y `SideRelations` | «Componente reutilizable» de nombre, pero acoplado a todo el juego | Health emite y cada modificador es un hijo (`DamageModifier`) que Health recorre |

### 2.2 Escenas demasiado grandes

- **`unit.tscn`: 126 nodos y 52 hijos directos de la raíz.** El subárbol `Afflictions` (Stunned, Petrified, Frozen con IceBlock y sonido, Vined con 16 instancias `VineNN`, RingsOfFire con 6 partículas y 3 sonidos, Slimed, BlindRaged…) son 52 nodos. El mismo subárbol está copiado en `wizard_body.tscn` (47 nodos). No existe un `afflictions.tscn`. Al extraerlo, `unit.tscn` baja a unos 75 nodos y `wizard_body.tscn` a unos 45. Además un cambio de look de una aflicción deja de hacerse dos veces. S8 pide partir las escenas grandes para reusarlas.
- **Hay nodos que nacen en runtime y no se ven en el árbol.** Las luces de cada aflicción las crea `AfflictionGlows.attach()` (`affliction_glows.gd:9-19`), llamado desde `afflictions.gd:51`. El `MpReplicate` de los proyectiles lo crea `fireball_projectile.gd:52-59`.
- **`match.tscn`: 74 nodos con más de 40 hijos directos** que mezclan mundo (`Units`, `Spells`, `Shots` y sus spawners), sistemas (`SoulSystem`, `SacrificeSystem`, `Match`, `Nav`, `AiRoster`), input (`Selection`, `Orders`, `MatchCommand`, `OrderRadial`), HUD y audio (`CommandVoice`, `MusicDirector`…). S4 propone la forma `Main` / `World` / `GUI`. Como ya hay 631 nodos con nombre único, reagrupar bajo padres `World`, `Systems`, `Input`, `Hud` y `Audio` es seguro para los `%Nombre`.

### 2.3 Herencia frente a composición

- **El contrato de cuerpo es implícito.** Cuatro clases independientes extienden `CharacterBody3D` (`UnitBody`, `WizardBody`, `DoctorBody`, y las estructuras con `cast_tower.gd`) y repiten la misma superficie:
  - `facing_flat` está en `unit_body.gd:171`, `wizard_body.gd:259` y `doctor_body.gd:154`, casi idéntico;
  - `is_targetable`, `display_name`, `is_obstacle` y `can_take_mana` se repiten igual.
  
  Los llamadores no pueden tipar, así que usan `has_method` y `call`. Son 13 `has_method("is_targetable")`, 6 `display_name` y 5 `facing_flat`, en archivos como `health.gd:295`, `rock_projectile.gd:139, 244, 267`, `unit_orders.gd:225, 256`, `melee_rules.gd:13, 21`, `path_follower.gd:246, 250` y `teleport_action.gd:77`. S7 acepta el duck typing pero advierte que «require good documentation». Acá la documentación es un comentario `# dynamic:` repetido 37 veces. El estándar es herencia de un nivel para el contrato mínimo (`class_name GameBody extends CharacterBody3D`) o un componente hijo común.
- **Los Resources repiten campos.** `SpellType` (`spell_type.gd:16-42`), `AbilityType` (`ability_type.gd:7-29`) y `CreatureType` (`creature_type.gd:5-48`) repiten `tag`, `display_name`, `icon`, `mana_cost`, `cooldown_s` y `casting_time_s`. Las dos primeras repiten además `cast_range_m`, `speed_m_s`, `acceleration_m_s2`, `damage`, `damage_range_m`, `effect_range_m`, `duration_s` y los `targets_*`; `SpellType` y `CreatureType` comparten además `book_level` y `book_slot`. Como no hay un tipo común, `Caster` y `CastTime` reciben `entry: Resource` y leen con `entry.get("mana_cost")` (`caster.gd:49, 455-456`; `cast_time.gd:18-22`). Una base `BookEntry extends Resource` (un nivel de herencia, para datos) es lo normal.

### 2.4 Helpers estáticos que esconden comportamiento

- **`static func of(node)`: 28 localizadores**, con 128 llamadas a `X.of(`. Recorren los hijos buscando el tipo (`health.gd:85-89`, `afflictions.gd:61-65`) o el árbol buscando el grupo (`shot_spawner.gd:20-21`, `terrain.gd:42-44`). Funcionan, pero cambian una referencia visible (`@export`) por una búsqueda en runtime. Para hijos de la misma escena, lo estándar es `@export` o `%Nombre` (S7, S10).
- **Hay «Facts» leídos del `SceneState`.** `BodyFacts`, `ReachFacts`, `SacrificeFacts` y `SceneStateReader` leen marcadores y formas de un `PackedScene` sin instanciarlo (`body_facts.gd:45-53`, `scene_state_reader.gd:9-25`) para no crear objetos de física. Es una técnica legítima pero muy rara para un dev de Godot. La alternativa estándar es guardar las medidas en un Resource que lean la escena y las reglas, o leerlas de la instancia que `BodyMount` ya viste. Necesita diseño; mientras tanto conviene documentarlo en `docs/architecture.md`.
- **Un script se usa como biblioteca de otro**: `fireball_projectile.gd:7` y `launch_point.gd:6` cargan `rock_projectile.gd` para usar sus `static func`. Lo genérico va a su propio script con nombre (`ProjectileMath`) o a un nodo compartido.
- **Lo que sí está bien**: las reglas puras (`death_rules.gd`, `captive_rules.gd`, `vision_rules.gd`, `cast_time.gd`, `damage_passive_type.gd`). S6 avala `class_name` con `static func` como «libraries of helper functions», y son justo lo que se prueba con GUT.

### 2.5 Flujo de datos entre sistemas

| Patrón | Medido | Ejemplo | Estándar |
|---|---|---|---|
| Contratos `Dictionary` | 269 `Dictionary` sin tipar, 67 funciones que devuelven `Dictionary` | `UnitSpawner.spawn_unit` documenta sus 11 claves en un comentario (`unit_spawner.gd:23-24`); `LaunchPoint.projectile_data` (`launch_point.gd:23-34`); `UnitBody.melee_profile()` (`unit_body.gd:187-188`) | Una clase tipada (`UnitSpawnData` con `to_dict()` / `from_dict()`) en el único borde donde la red exige `Variant` (S3) |
| Ids de texto en la API | — | `Caster.request_cast(tag: String…)`, `action_for(tag)`, `_spell_of(tag)` (`caster.gd:165-216, 433-438`); `UnitBody.died(tag: String, …)` (`unit_body.gd:9`) | Pasar el `SpellType` o `CreatureType`; el texto solo en el cable |
| Convención de nombre como búsqueda | 4 | `shot_spawner.gd:24-31`, `kill_estimate.gd:83-89`, `building_type.gd:36-39`, `spell_spawner.gd:12-32` (`"Fireball"`) | `@export var x: PackedScene` (S7, S8) |
| Grupos | 22 nombres de texto; 4 formas de pedir el mismo servicio | `"shot_spawner"` literal en 5 habilidades (`lightning_strike.gd:64`, `quake_wave.gd:65`, `breath_of_life_ability.gd:41`, `halo_of_earth_ability.gd:17`, `divine_sight.gd:26`) teniendo `ShotSpawner.GROUP` y `ShotSpawner.of()`; `"match_state"` literal (`health.gd:241`, `ritual_drain.gd:62`) frente a `MatchState.GROUP` y un `@export var match_state_group` (`gameplay_tab.gd:21`) | Una constante del dueño y el grupo declarado como **Global Group** en Project Settings (S10). `project.godot` no declara ninguno |
| Reflexión sobre tipos conocidos | 269 `.get`, 26 `.set`, 57 `in` | ver §3 | Acceso tipado; activar `UNSAFE_PROPERTY_ACCESS` (S3) |
| Señales | 156 nombres, casi todos en pasado; bien | — | — |

### 2.6 Autoloads

| Autoload | Veredicto según S6 y S14 |
|---|---|
| `MpKit` | Bien: es un servicio aislado del kit |
| `MpLobby` | Ya lo cubre la auditoría anterior: se carga aunque el servidor de salas está apagado |
| `GameData` | **Sacarlo.** Envuelve a `GameCatalog`, que ya es estático, y tiene 3 usos. Es justo el caso de «static functions / static var» de S6 |
| `SacrificeFlow` | Bien como flujo, porque maneja su propio estado. Pero no debería escucharlo un actor (`wizard_body.gd`); que lo use la UI, el spawner y `MatchWorld` |
| `FxBus`, `SoundBus` | Aceptables: es el patrón bus o servicio de GDQuest (S14), que avisa de no abusar. 145 usos de `FxBus` en 96 archivos. Para que el editor los tipe, les falta `class_name` en el script. Hoy `sprite_emitter.gd:96` hace `has_method(&"next_particle_seed")` porque «FxBus is an autoload without a class_name» |
| `AgentKit` | Ya lo cubre la auditoría anterior: es una herramienta de desarrollo cargada en el producto |

### 2.7 Idle y physics

- **Hay 9 `const FPS := 60.0` sueltas** que reemplazan a `delta`: `fireball_projectile.gd:9`, `rock_projectile.gd:18`, `swarm_projectile.gd:9`, `wrath_strike.gd:13`, `heal_effect.gd:15`, `speedup_effect.gd:14`, `caster.gd:22`, `ranged_weapon.gd:25` y `teleport_rings.gd:13` (`TICKS_PER_S`). Mientras tanto `MatchClock.TICKS_PER_SECOND_F` lee `Engine.physics_ticks_per_second` y otros dos scripts lo leen directo (`petrify_impact.gd:36`, `stunned.gd:180`). Son tres maneras de saber la frecuencia; si alguien cambia el tick en Project Settings, 9 scripts se rompen sin aviso.
- **El paso de física orquestado por `UnitBody._physics_process`** (`unit_body.gd:116-132`; los hijos no procesan solos) es un patrón válido para una simulación determinista. Conviene conservarlo y documentarlo. La alternativa nativa sería `process_physics_priority`.

---

## 3. Calidad local: 24 ejemplos

**1. Código muerto: `AiAudit`.**
`scenes/ai/ai_audit.gd` tiene 480 líneas; ningún `.tscn` ni `.gd` lo instancia. Sin embargo `ai_side.gd:28, 84, 92`, `ai_command_port.gd:18-22`, `ai_orders_out.gd:16, 85`, `ai_order_issue.gd:73, 115` y `ai_cast_out.gd:31` lo pasan y lo consultan.
Qué hacer: borrarlo junto con sus 32 referencias. Si un banco lo necesita, que viva en `agent/` y no en el producto.

**2. Señales que solo escuchaba el banco.**
`wizard_brain.gd:12-13` (`replanned`, «nothing in the game does») y `ai_task_board.gd:13`. En total hay 59 menciones a banco o «check scene» en 42 scripts del producto.
Qué hacer: borrarlas; el historial queda en git.

**3. Métodos de debug sin llamadores.**
`unit_body.gd:182-184` y `wizard_body.gd:507-523` (`debug_set_clip_state`, `debug_clip_info`), y `unit_clips.gd:105` (`set_debug_role`). Un `git grep` no encuentra llamadores fuera de los RFC.

**4. Mismo nodo, dos veces, y por texto.**
`wizard_body.gd:108` ya tiene `@onready var _caster: Caster = $Caster`, pero `:411` vuelve a hacer `get_node_or_null("Caster") as Caster`. Lo mismo pasa con `"PathFollower"` (`:311`) y `"WarpSnap"` (`:346`).
```gdscript
@export var follower: PathFollower   # set in wizard_body.tscn
@export var warp_snap: WarpSnap
```

**5. Conectar por texto una señal que el tipo declara.**
`wizard_body.gd:125-126`:
```gdscript
# Before
if _clip_pose.has_signal("clip_looped"):
	_clip_pose.connect("clip_looped", _on_clip_looped)
# After (ClipPlayback declares it: clip_playback.gd:12)
_clip_pose.clip_looped.connect(_on_clip_looped)
```

**6. Dato obligatorio que no se usa.**
`spell_action.gd:45` (`prompt`) y `:55-56`: un aviso del inspector exige escribir `prompt`. Hay 48 escenas de `actions/` que lo llenan en español sin `tr()`. Pero `command_log.gd:32-38` dice «kept in `text` and not drawn», y `CommandLog.text` no tiene lectores.
Qué hacer: borrar el campo, el aviso y los 48 valores.

**7. Reflexión sobre un tipo conocido.**
En `caster.gd:459-472`, `_wizard` ya es `WizardBody`, que tiene `mana: ManaPool` y `souls: SoulPurse` (`wizard_body.gd:103-104`):
```gdscript
# Before
func _mana() -> float:
	var pool := _wizard.get_node_or_null("ManaPool")
	return float(pool.get("current")) if pool else 0.0
# After
func _mana() -> float:
	return wizard.mana.current
```
Además `caster.gd:185-190` castea `_wizard as WizardBody`, que ya es `WizardBody`.

**8. Un hijo que nombra a su padre.**
`caster.gd:69`, `summoner.gd:35` y `unit_orders.gd:48` hacen `@onready var _wizard: WizardBody = get_parent()`. S4 dice que el padre inyecta:
```gdscript
@export var wizard: WizardBody   # with a configuration warning when empty
```

**9. Cadena de alias de constantes.**
`caster.gd:29-38` redefine `NO_MANA := SpellAction.NO_MANA`, y `spell_action.gd:17-22` redefine `NO_MANA := Refusal.NO_MANA`. Son tres nombres para `&"no_mana"`, y además los estados se guardan como `String` (`Aim.status := ""`, `spell_action.gd:27`) mientras `Refusal` usa `StringName`.
Qué hacer: usar `Refusal.NO_MANA` directamente y tipar `status: StringName`.

**10. Elegir una escena con un texto.**
`thrown_action.gd:11-12` define `@export var projectile_kind := ""`, `fireball_action.tscn:13` lo llena con `"Fireball"`, y `spell_spawner.gd:12-32` tiene un diccionario con 19 claves.
```gdscript
# After: the designer drags the scene; the spawner derives the wire id (its index in `projectiles`)
@export var projectile: PackedScene
```
`spell_spawner.gd:12-32` además usa `preload` en el valor por defecto de un `@export`. S8 dice que ese `preload` se desperdicia, y aquí también provoca el ciclo que explica el comentario de `:33-34`.

**11. Contrato `Dictionary` de un proyectil.**
`fireball_projectile.gd:34-44` lee 10 claves con `float(data["x"])…`, según un contrato que solo existe en `launch_point.gd:23-34`.
```gdscript
class_name ProjectileLaunch
extends RefCounted
## What a spell projectile is told when it leaves. Travels as a Dictionary only inside SpellSpawner.
var from: Vector3
var aim: Vector3
var target: NodePath
var caster: NodePath
var slot: int
var speed_m_s: float
var damage: float
var damage_range_m: float

func to_dict() -> Dictionary: ...
static func from_dict(data: Dictionary) -> ProjectileLaunch: ...
```

**12. Recursos que se crean en cada frame.**
`fireball_projectile.gd:83-85` crea `BoxShape3D.new()` en cada `_physics_process`. Lo estándar es un `ShapeCast3D` o un `Area3D` hijo en `fireball_projectile.tscn`, con el tamaño `SIZE` en el inspector.

**13. Una regla atada a un tag.**
`cast_time.gd:14` define `const BASILISK := "guls"` y `:22` compara `str(entry.get("tag")) == BASILISK` para aplicar 19/20.
```gdscript
# CreatureType (or BookEntry)
@export_range(0.5, 1.0, 0.01) var cast_time_factor := 1.0   ## Basilisk: 0.95
```

**14. El doc de clase cuenta el motor original en vez del juego.**
`fire_shield.gd:3-13` son 11 líneas con `passiveOnDamage`, `updateCreatureStats`, `canShield`, `SPEL`, `dealFireDamage`, `peirceShield` y `movingObjectById`. Cumple la regla C24 (la cita va al final) y aun así un dev nuevo no lo entiende. S2 y S14 piden explicar qué hace la API con palabras propias:
```gdscript
## Burns every non-allied body that touches the Phoenix, costing its mana per burn.
## Only acts on creatures whose `on_damage` is `passive`.
```

**15. `## Ref:` como tooltip del inspector.**
`damage_passive_type.gd:23-24` pone `## Ref: sacengine dealRawDamage state.d:9011-9015.` justo encima de `@export var incoming_base`. Como `##` es documentación (S2), esa cita aparece al pasar el mouse en el inspector. Pasa en 222 `@export`.
Qué hacer: pasarlo a `#` o sacarlo (§4).

**16. `##` dentro de funciones.**
Hay 284 líneas `##` dentro de cuerpos, en 133 archivos, contra 85 `#`. Por ejemplo `wizard_body.gd:121, 212, 296, 390` y `match_world.gd:29, 32, 37, 43`. S2 reserva `##` para miembros; dentro de una función va `#`.

**17. Doc de clase fuera de lugar o ausente.**
- `match_world.gd:4-9` va después de `signal`;
- `creature_type.gd` no tiene doc de clase;
- `match_rules.gd`, `wizard_type.gd` y `character_select.gd` tienen el mismo problema.

S1 y S2 dicen que el doc de clase va justo después de `extends`.

**18. Valores mágicos.**
- `wizard_body.gd:461-463, 482`: `1.6`, `20.0`, `6.0` y `0.1`;
- `ai_perception.gd:58`: `tracks_of(0)…tracks_of(3)` en lugar de `AiTrack.Relation`, y `forced.emit(1)`;
- `fireball_projectile.gd:118`: máscara de colisión `1`;
- `wizard_brain.gd:49`: devuelve `0`, `1` o `2`.
```gdscript
enum Thought { NOTHING, ACTED, CAPTURING }
func think(wizard: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> Thought:
```

**19. Código comprimido para no pasar el tope.**
`ai_perception.gd:41-58` (150 líneas justas) tiene `if` y `for` con el cuerpo en la misma línea, líneas de 150 a 190 caracteres y una sola línea en blanco entre funciones. S1 pide una sentencia por línea, menos de 100 columnas y dos líneas entre funciones. Hay 31 scripts de exactamente 150 líneas y 63 entre 140 y 150.

**20. Duplicados.**
- `facing_flat` aparece 3 veces;
- `const FPS := 60.0`, 9 veces;
- el subárbol `Afflictions`, 2 veces;
- buscar el nombre de un cuerpo con `str(body.call("display_name")) if body.has_method("display_name") else str(body.name)`, 6 veces (`death_cloud.gd:48`, `shot_impact.gd:44`, `heal_effect.gd:111`, `rock_projectile.gd:267`, `affliction.gd:85`, `target_info.gd:87`);
- `REST_FACING` está en `wizard_body.gd:75` y se vuelve a escribir literal en `:263`.

Hay líneas repetidas incluso en la documentación: `scenes/spells/README.md:9-10` («Zones on the ground…» dos veces) y `:14` / `:16` («Jumping spells…» dos veces).

**21. Miembros declarados después de las funciones.**
- `health.gd:202-208` (`_deflecting`, `deflected_last`, `_match` en mitad del archivo);
- `ranged_weapon.gd:25` y `boot.gd:8` tienen una `const` después de los `@export`;
- `orders.gd:85` y `nav_regions.gd:200` tienen el mismo problema.

S1 y la regla `class-definitions-order` de gdlint (S12) fijan el orden: signals, enums, consts, exports, vars y onready.

**22. Nombres que no coinciden.**
11 `class_name` no coinciden con su archivo:

| Clase | Archivo |
|---|---|
| `AiWizardBrain` | `wizard_brain.gd` |
| `AiCastQueue` | `cast_queue.gd` |
| `AiWizardCasting` | `wizard_casting.gd` |
| `AiKillEstimate` | `kill_estimate.gd` |
| `SoundEmitter3D` | `sound_emitter_3d.gd` |
| `MatchResultBanner` | `match_result.gd` |
| `DevourAbility` | `devour.gd` |
| `QuakeAbility` | `quake.gd` |
| `RendSoulAbility` | `rend_soul.gd` |
| `GroundHug` | `ground_hug_flight.gd` |
| `ShotSplit` | `split_flight.gd` |

También hay nodos con nombre distinto a su clase de modo confuso: los dos `Match` y `ClipPose` / `BodyAnimator`. S9 y GDQuest (S14) piden que el archivo se llame como la clase o el nodo raíz.

**23. Idioma mezclado en superficies de desarrollador.**
- `print` en español en código en inglés: `wizard_body.gd:445` («mago %d volvio al altar»), `match_world.gd:45, 79, 87`, `sacrifice_flow.gd:75, 82, 217`, `game_data.gd:37`;
- avisos del inspector en español: `afflictions.gd:297-299`, `thrown_action.gd:24`, y 123 avisos «Falta…» en total;
- grupos del inspector en español: `ai_tactics.gd:17, 25` (`@export_group("Ritmo del mago")`, `"Ataque"`).

S1 pide un solo idioma para el código; el jugador sigue viendo español por `tr()`.

**24. Ruido numérico y datos frágiles.**
- `ai_tactics.gd:28, 32`: `0.3333333432674408` y `0.7142857313156128` son restos de `float32`; mejor `1.0 / 3.0` y `5.0 / 7.0`.
- 7 `.tres` (`data/ai/*.tres`) tienen 79 líneas de comentario `;` escritas a mano. Godot reescribe el archivo entero al guardar desde el inspector y no conserva esos `;`.
- `match_rules.gd:11` usa `preload` en el valor por defecto de un `@export` (S8).

**Manejo de errores, en general.**
- Hay 0 `assert`, 26 `push_error` y 70 `push_warning`.
- Las dependencias que faltan suelen fallar en silencio. Por ejemplo, `thrown_action.gd:52-54` retorna sin aviso si no hay spawner, y la bola de fuego desaparece.
- Las 212 clases con `_get_configuration_warnings()` están bien. Falta el paso siguiente que propone S7: que en runtime una dependencia obligatoria vacía haga `push_error` (o `assert` en debug) en vez de retornar callada.
- Los errores de dominio viajan como `String` vacío o con texto (`SpellAction.finish() -> String`, `UnitBody.use_ability() -> String`). Deberían ser `StringName` de `Refusal`, o un enum.

**Proyecto, menor.**
`game/.gitignore:3` ignora `*.import` salvo en 4 carpetas. Así quedan 58 assets versionados sin su `.import`, la mayoría PNG de flora en `scenes/map/maps/*/flora`. S11 pide versionar los `.import`.

---

## 4. Convenciones propias que contradicen el estándar

| Convención propia | Estándar | Efecto medido | Recomendación |
|---|---|---|---|
| **C1: un script ≤150 líneas** | gdlint `max-file-lines: 1000` (S12); S1 no fija tope; GDQuest tampoco (S14) | 825 scripts con promedio de 89 líneas, 197 de menos de 40, 31 de exactamente 150; código comprimido (§3 n.º 19); una clase cohesiva partida en 3 o 4 `RefCounted` | Retirar C1a y usar gdlint con `max-file-lines` entre 500 y 1000, `max-public-methods: 20` y `max-returns: 6`. Partir por responsabilidad, no por líneas |
| **C9 / C24: la cita al original va en `## Ref:`** | S2: `##` es la API que se ve en la ayuda y en el inspector; S14: comentar poco; S15: un demo oficial no tiene referencias externas | 1 102 líneas `## Ref:`; 222 tooltips de `@export` que terminan en una cita | Sacarlas del código (a `docs/original-mapping.md`, como ya proponía la fase A de la auditoría anterior) o, si quedan, en `#` y no en `##` |
| **`##` como único estilo de comentario** | S1 y S2: `#` para notas de implementación | 284 `##` en cuerpos de función | `#` dentro de las funciones |
| **README por sistema con «What / Not / Talks to / Edit»** | Un README raíz y un documento de arquitectura; los READMEs de carpeta solo cuando dicen algo que el código no dice | 56 READMEs; `units/README.md` tiene 5 KB, `spells/README.md` 4,5 KB con líneas repetidas, `map/terrain/README.md` 10 KB; 15 son bilingües con `---` | Un `docs/architecture.md` de una página y READMEs de 3 a 5 líneas |
| **`data/` separado de `scenes/`** («los `.tres` viven en `data/`, no acá», `scenes/README.md`) | S9: «as close to scenes as possible», carpeta por entidad | Un Firefist ocupa 13 carpetas | A futuro, una carpeta por entidad (`creatures/firefist/`) después del renombrado humano (fase B anterior) |
| **Lint propio con grep (25 reglas)** | gdtoolkit (S12), que analiza el AST, y los avisos del compilador (S3) | C18c da 0 aunque existen `projectile_kind = "Fireball"`, `Dictionary[String, PackedScene]` y `default_look` por ruta | gdlint, gdformat y los avisos `UNSAFE_*`; de las reglas propias, quedarse con las que el estándar no cubre (C12 red, C13 assets originales, C25 InputMap) |
| **`<sistema>_rules.gd` static RefCounted** | S6 lo avala para funciones puras | Bien para reglas puras; mal cuando la clase guarda estado (`static var`) | Mantener para funciones puras y prohibir `static var` de estado |

En lo que sí coinciden con el estándar: InputMap, `snake_case`, señales en pasado, sockets `@export` con avisos y Resources como plantillas de tipo.

---

## 5. Lo que está bien y no hay que tocar

- **Tipos declarados** en toda `var` y `func`, aunque falte tipar el contenido de `Dictionary`, `Array` y el acceso (§2.5).
- **838 sockets `@export` tipados** (`@export var x: Tipo`), **212 clases con `_get_configuration_warnings()`**, **631 nodos únicos** y 498 referencias `%Nombre`. Esto es exactamente S4, S7 y S10.
- **FSM con FsmKit**: `UnitState extends FsmState` y `UnitStates extends FsmMachine`, un estado por modo, en lugar de un `match` gigante.
- **InputMap**: 0 `KEY_*` en el juego (fuera de la etiqueta de tecla).
- **Señales tipadas y casi todas en pasado** (156 nombres); tabs, LF, `snake_case` en archivos y `PascalCase` en nodos.
- **Resources de datos con unidades en el nombre** (`vision_m`, `cooldown_s`, `run_speed_m_s`), `@export_range`, `@export_group` y enums con nombre (`AiUse`, `AiPhase`, `UnitBody.Mode`).
- **Reglas puras ya separadas** (`DeathRules`, `CaptiveRules`, `VisionRules`, `CastTime`, `DamagePassiveType`): son el primer lote para GUT.
- **El paso de física explícito** en `UnitBody` y la disciplina de azar por stream (`MatchSeed.seed_rng(rng, [system, id])`). Son buen diseño; solo hay que moverlos de lugar (§2.1).
- **Textos del jugador con `tr()` y `strings.csv`**; `.uid` versionados; `.godot/` ignorado.
- **Uso de `MultiplayerSpawner` y de `is_multiplayer_authority()`** para decidir quién simula.

---

## 6. Plan priorizado

El orden va por impacto en la legibilidad para un dev nuevo. Los cortes son chicos e independientes, salvo donde se indica. **M** = mecánico (no cambia comportamiento). **D** = necesita diseño (presentar el árbol antes). Complementa el plan A–G de la auditoría anterior; donde se superpone, se dice.

**Verificación común a todos los cortes:**
1. `bash tools/lint/conventions.sh` en verde.
2. gdlint cuando exista (Q2).
3. Una sola importación headless al final del lote, para atrapar errores de parseo.
4. La prueba en el editor que indica cada corte.

| Corte | Tipo | Qué cambia | Archivos (aprox.) | Riesgo | Cómo se verifica |
|---|---|---|---|---|---|
| **Q1 Código muerto** | M | Borrar `AiAudit` y su cableado; las señales `replanned`; los `debug_*` de los cuerpos y `UnitClips.set_debug_role`; `SpellAction.prompt`, su aviso y los 48 valores; `CommandLog.text` | 10 `.gd`, 48 `.tscn` | Bajo. Algún flujo de `agent/` podía llamar a los `debug_*`, pero son descartables | `git grep` sin referencias; abrir `ai_side.tscn` y `fireball_action.tscn` sin avisos; F5 «Contra la IA» 1 minuto |
| **Q2 Herramientas estándar** | M | `gdlintrc` (`max-line-length 100`, `max-file-lines 1000`, `max-public-methods 20`, `max-returns 6`), `gdformat` de una pasada y avisos GDScript `UNSAFE_PROPERTY_ACCESS`, `UNSAFE_METHOD_ACCESS`, `UNSAFE_CAST` y `UNTYPED_DECLARATION` en «warn». Retirar C1a y C1b. Se suma a la fase F anterior (GUT y CI) | `gdlintrc`, `project.godot`, `tools/lint/` y todo lo que formatee gdformat | Bajo, porque gdformat respeta el AST. Antes, confirmar que la versión de gdtoolkit parsea la sintaxis de 4.7 (`Dictionary[K, V]`) | `gdformat --check` y `gdlint` en verde; el conteo de avisos `UNSAFE_*` es la nueva línea de base y solo puede bajar |
| **Q3 Comentarios de documentación** | M | `##` → `#` dentro de funciones (284); sacar `## Ref:` de los docs de `@export` (222) y del resto, a `docs/original-mapping.md`; doc de clase justo tras `extends` (5 archivos); `print`, avisos y `@export_group` en inglés. Se superpone con las fases A y G anteriores; este corte agrega el criterio del tooltip | Unos 570 `.gd` | Nulo: solo comentarios y textos de log | Un diff que solo toque comentarios y strings (script que compara el AST sin comentarios); revisar 3 tooltips en el inspector |
| **Q4 Acceso tipado y una sola puerta** | M | `class_name` en `world_camera.gd` y `selection.gd`, y `@export` en `MatchWorld` en vez de `.set("…")`; `Caster`, `WizardBody`, `UnitSpawner`, `LaunchPoint`, `CreatureType.icon_of` y `FireShield._carries` con acceso tipado; grupos literales → `X.GROUP` y Global Groups; `FPS` → `MatchClock.TICKS_PER_SECOND_F` o `delta`; renombrar los 11 archivos cuyo nombre no coincide con su `class_name`, y el hijo `Match` → `MatchState` (desde el editor, para que se conserven los uid) | Unos 30 `.gd`, `match.tscn`, `project.godot` | Bajo. `FPS` toca la simulación, pero con el mismo valor a 60 Hz | Baja el conteo de `.get("` y `.set("` y de avisos `UNSAFE_*`; F6 sobre `match.tscn`; una partida corta: bola de fuego, roca y wrath |
| **Q5 `afflictions.tscn`** | D chico | Extraer el subárbol `Afflictions` (con `Cues`, `VineLook`, `RingsLook` y las luces de `AfflictionGlows` como hijos visibles) a una escena empaquetada; los sockets que salen de la escena (`clip_pose`, `tilt`, `visual`, `mesh`, `wards`) quedan como `@export` asignados en la instancia | `afflictions.tscn` nuevo, `unit.tscn`, `wizard_body.tscn`, `affliction_glows.gd`; los `sync_extra` de `MpActor` | Medio: las rutas replicadas `Afflictions:shown` y los `NodePath` cruzados | `unit.tscn` baja de 126 a unos 75 nodos; F6 con stun, congelar, enredaderas y anillos sobre criatura y mago; una prueba LAN de 2 procesos (`shown` replica) |
| **Q6 Contrato de cuerpo** | D | Base `GameBody extends CharacterBody3D` (o componente `BodyStatus`) con `owner_slot`, `is_targetable`, `is_dead`, `is_obstacle`, `facing_flat`, `display_name`; quitar las 33 llamadas `has_method` / `call`; compartir entre unidad y mago la elección de clip, la regeneración y el asiento; corregir el doble `_present_pose` | `unit_body.gd`, `wizard_body.gd`, `doctor_body.gd`, `cast_tower.gd` y unos 25 llamadores | Medio | `# dynamic:` queda en 0 o 4 (los del kit y el editor); `wizard_body.gd` baja a menos de 300 líneas; F6 con el mago caminando y en reposo |
| **Q7 `BookEntry`** | D chico | Base de Resource con los campos comunes de `SpellType`, `AbilityType` y `CreatureType`; `Caster` y `CastTime` tipados; `BASILISK` → `cast_time_factor` | 3 `*_type.gd`, `caster.gd`, `cast_time.gd`, `basilisk.tres` | Bajo: los `.tres` conservan sus campos | Los `.tres` abren sin errores; GUT de `CastTime.seconds` (Q10) antes y después |
| **Q8 Referencias explícitas** | D | `ThrownAction.projectile: PackedScene`; `AbilityType.shot_look: PackedScene` en vez de `data/shots/<tag>.tscn`; la política de blanco por referencia (`kill_estimate.gd`); `BuildingType.scene` como `@export`; contratos tipados de spawn (`UnitSpawnData`, `ProjectileLaunch`) con `to_dict` y `from_dict` | `spell_spawner.gd`, `shot_spawner.gd`, `unit_spawner.gd`, `launch_point.gd`, los proyectiles, unos 33 `data/shots` y las escenas de acción | Medio: el formato del cable de red | Ningún `load(` armado con texto en `scenes/`; LAN de 2 procesos: lanzar hechizos y disparos de criatura |
| **Q9 Componentes por criatura** | D | `CreatureType.on_damage` apunta directo a su recurso de pasiva (que ya trae su número), o la criatura trae sus componentes (`FireShield` solo en el Fénix) en su escena; el `unit.tscn` genérico deja de cargar los 6 componentes dormidos | `unit.tscn`, `passives/*`, `creature_type.gd`, unos 10 `.tres` | Medio-alto: los componentes tienen que existir igual en todos los peers | Requiere Q10 (GUT de las fórmulas de pasivas) y una pasada de las criaturas con pasiva |
| **Q10 GUT con reglas puras** | M | `addons/gut`, `res://test/unit/test_*.gd` con: `CastTime.seconds`, `DamagePassiveType.incoming` / `outgoing_melee`, `MatchClock.ticks_for`, `DeathRules.leaves_soul` / `on_carrier_lost`, `CaptiveRules.on_change`, `VisionRules.covers` / `in_cone` / `lapsed`, `CreatureType.order_key` / `is_hybrid_flier`, `AbilityType.needs_target`. Detalla la fase F anterior | 1 addon y unos 8 tests | Nulo | `godot -s addons/gut/gut_cmdln.gd -d --path "$PWD" -gdir=res://test/unit -gexit` (S13) en headless, una corrida |
| **Q11 Partida en el árbol** | D | Agrupar `match.tscn` en `World`, `Systems`, `Input`, `Hud` y `Audio`; sacar el autoload `GameData` (3 usos → `GameCatalog`); `WizardSpawner` le inyecta el pick al mago | `match.tscn`, `match_world.gd`, `wizard_body.gd`, `wizard_spawner.gd`, `unit_spawner.gd`, `shot_spawner.gd`, `project.godot` | Medio: `NodePath` y `spawn_path` | F5 solo, «Contra la IA» y LAN; el árbol de `match.tscn` se lee en 5 grupos |
| **Q12 Estado global → nodo de partida** | D, alto | `MatchClock`, `MatchSeed`, `MatchSky`, `SideRelations` y `ActiveMatch` pasan a ser propiedad de un nodo de la partida (o de `MatchState`), inyectado o encontrado por una constante | Unos 60 llamadores | Alto: todo lo lee, y el determinismo depende de esto | Después de Q10; dos corridas con la misma semilla dan los mismos eventos; LAN |
| **Q13 `Health` como cadena de modificadores** | D, alto | Cada modificador (escudos, aflicciones, pasiva, aceite, crecimiento) pasa a ser un hijo `DamageModifier` que Health recorre en orden; Health ya no conoce 8 tipos | `health.gd` y unos 8 componentes | Alto: la matemática del daño | Después de Q10, con GUT de daño por tipo, resistencia y escudo antes y después |
| **Q14 Una carpeta por entidad** | M con herramienta, masivo | Después del renombrado humano (fase B anterior): `creatures/<nombre>/` con `.tres`, frame, look, clips e ícono | Cientos de archivos | Medio: uids y referencias. Mover desde el editor o con `tools/migrate` | Importación limpia; `git grep` de rutas viejas vacío |

**Orden recomendado:** Q1 → Q2 → Q3 → Q4 → Q10 → Q5 → Q7 → Q6 → Q8 → Q11 → Q9 → Q12 → Q13 → Q14.

- **Q1 a Q4** son mecánicos y quitan la mayor parte de la confusión de lectura: código muerto, texto donde hay tipos, comentarios que no son documentación.
- **Q10** da la red de seguridad antes de tocar comportamiento.
- **Q5, Q7 y Q6** son los cambios de estructura con mejor relación entre impacto y riesgo.
- **Q12 y Q13** quedan para el final porque tocan el centro de la simulación.

Archivos de referencia citados (todos bajo `/Users/joelsartori/Development/sacproject/game/`):

- **Criaturas:** `scenes/units/unit.tscn`, `scenes/units/unit_body.gd`, `scenes/units/creature_type.gd`, `scenes/units/passives/damage_passive.gd`, `scenes/units/passives/fire_shield.gd`, `scenes/units/afflictions/afflictions.gd`, `scenes/units/afflictions/affliction_glows.gd`, `scenes/units/attacks/shot_spawner.gd`, `scenes/units/unit_spawner.gd`.
- **Mago:** `scenes/wizards/wizard_body.gd`, `scenes/wizards/wizard_body.tscn`.
- **Hechizos:** `scenes/spells/caster.gd`, `scenes/spells/actions/spell_action.gd`, `scenes/spells/actions/thrown_action.gd`, `scenes/spells/actions/fireball_action.tscn`, `scenes/spells/spell_spawner.gd`, `scenes/spells/launch_point.gd`, `scenes/spells/fireball_projectile.gd`, `scenes/spells/cast_time.gd`, `scenes/orders/command_log.gd`.
- **Partida y flujo:** `scenes/match/match.tscn`, `scenes/match/match_world.gd`, `scenes/match/match_clock.gd`, `scenes/core/catalog/game_data.gd`, `scenes/core/flow/sacrifice_flow.gd`, `scenes/components/health.gd`.
- **IA:** `scenes/ai/ai_audit.gd`, `scenes/ai/ai_side.tscn`, `scenes/ai/brains/wizard_brain.gd`, `scenes/ai/perception/ai_perception.gd`, `scenes/ai/data/ai_tactics.gd`, `data/ai/tactics_hard.tres`.
- **Datos y proyecto:** `data/catalog/creatures/firefist.tres`, `data/catalog/abilities/ahtf.tres`, `data/passives/firefist_fury.tres`, `.gitignore`, `project.godot`.
