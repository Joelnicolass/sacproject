# RFC-036 — Godot estándar (plan paraguas)

Estado: plan del tech lead (Opus), pendiente de OK. Arquitectura **estándar**. MP **online con dedicado** (sin RPC nuevos salvo que un corte lo diga). Para el plan no se corrió Godot: todo sale de leer el código.
- **Decisión del usuario (2026-10-18):** el port pasa a Godot estándar donde se reimplementó algo del motor para copiar a sacengine. Todo editable en el editor y armado con sistemas del motor. Del original se copia solo lo que nota el jugador: números de daño, hechizos y reglas. La fidelidad exacta espera a la v1.
- **Autoridad:** decisión del usuario 2026-10-18 > PRD > FEATURES > RULES (§Fidelidad y pruebas) > VISUAL > RFC-035 > este plan.
- **Features:** las asigna el orquestador (una F por corte, desde la siguiente libre después de F201).

### Contradicciones (y cuál gana)
- **RFC-035 §0/§5.4 dice «evasión apagada; la separación es de `BodySeparation`».** RULES §Fidelidad (misma fecha, posterior) dice «navegación, física y animación usan lo del motor». Gana RULES, pero **sin pisar 035**: 035g–i se hacen con la evasión apagada (un cambio a la vez) y 036f la prende y borra `BodySeparation`. Se anota en 035j.
- **RULES §Datos: «sacengine aporta los datos y los números del juego (mapa, paso medido, órdenes)».** Sigue valiendo para números y reglas. Lo que cambia es la forma: los números pasan de JSON leído en runtime a `.tres` (036c). Se edita en 036k.
- **RULES §IA: «las partidas con IA son reproducibles con `match_seed`».** Se mantiene (ver §3, `MatchSeed`). Reproducible = mismo binario, misma máquina, banco de humo; no byte a byte.

## 1. Auditoría

Tamaño: S < 150 líneas tocadas, M 150–600, L > 600. Valor: E = editable en el editor, S = más simple (menos código propio).

| # | Archivos | Qué hace hoy | Estándar Godot que lo reemplaza | Valor | Riesgo | Tam. |
|---|---|---|---|---|---|---|
| A1 | `scenes/world/body_separation.gd` (507), `body_grid.gd` (120), `make_way.gd` (218); llamada en `unit_body.gd:_physics_process`, `wizard_body.gd`, `doctor_body.gd` | Copia de `positionAfterCollision`: cajas AABB, dos pasadas, empuje capado a 5 m/s, sorteo de empates con `MatchSeed`, grilla de 2,5 m, más los desvíos `make_way` y `wizard_passes_own` como `static var` | `NavigationAgent3D` con evasión (RVO) por cuerpo (`radius`, `avoidance_priority`, `avoidance_layers/mask`) y `velocity_computed`; los cuerpos siguen sin chocar entre sí por física (máscara solo suelo) | S (−850 líneas), E (radio y prioridad en el inspector) | **Alto** (multitudes, tipi, escolta) | L |
| A2 | `scenes/world/nav/nav_grid.gd` (482), `nav_service.gd` | A* sobre `AStarGrid2D` de 5 m | `NavigationRegion3D` + `query_path` | — | — | **Ya en RFC-035 (035f–i).** No se duplica |
| A3 | `scenes/world/ground_guard.gd` (96) | Copia de `moveOnGround`: 8 deslizamientos de brújula para no salir del suelo, `has_fallen` | Después de 035i: el navmesh ya excluye huecos; `NavigationServer3D.map_get_closest_point` para el borde y la colisión del glb (paredes) para el resto. `has_fallen` queda (es regla: gib) | S | Medio | S–M |
| A4 | `scenes/world/sac_float.gd`, `units/afflictions/affliction.gd:27-32`, `frozen.gd`, `abilities/quake_wave.gd:100-116` | Redondeo a float32 de cada paso para empatar ticks con sacengine | Float de GDScript directo | S | Bajo (±1 tick en una duración; nadie lo nota) | S |
| A5 | `body/body_rig.gd` (388), `body/clip_clock.gd` (146), `body/body_animator.gd` (131), `body/unit_clip_roles.gd`, `data/body_clips.gd`, `assets/original/models/index.json` | El rig **ya usa `AnimationTree`**, pero el modelo y la librería `role/*` se arman en runtime con `owner = null`: no se ve ni se edita en el editor. `ClipClock` es un segundo reloj del clip (frames, impacto) leído de `index.json`, que corre también en el dedicado | Una escena por modelo que instancia su `.glb` (heredada o instanciada) con `AnimationPlayer` + `AnimationTree` (`AnimationNodeStateMachine`) guardados; eventos con pistas de método o marcadores de `Animation`; el cliente maneja el árbol desde el `mode` replicado. Sin `ClipClock` | E (ver y ajustar animaciones), S | Medio (impacto visual del golpe, híbridos estáticos) | M–L |
| A6 | `addons/agent_kit/determinism/det_recorder.gd`; `ai/ai_audit.gd:13,60` | Grabador de digests del banco | Nada que reemplazar: es herramienta de prueba en el addon | — | — | **Queda** (§3) |
| A7 | 30 archivos con `static var log_*` (`melee_attack`, `fire_shield`, `soul`, `pulling`, …) y `static var measure/use_grid/make_way/wizard_passes_own` en `body_separation.gd` | Ganchos del banco dentro del gameplay, prendidos por flags de CLI | Un solo nodo/categoría de log: `DebugLog` estático con categorías leídas de un `ProjectSettings` propio (`sacrifice/debug/log`) o de `OS.get_cmdline_user_args()` en un solo lugar; los `static var` de comportamiento desaparecen con A1 | S | Bajo | M (muchos archivos, cambio mecánico) |
| A8 | `scenes/world/tick_check.gd`, `state_tick_check.gd`, `move_order_check.gd`, `walk_order.gd`, `state_tick.tres`, `move_order.tres`, `walk_step.tres`, `idle_order.tres`, `advance_order.tres` | Nodos de prueba viviendo en `scenes/world/` | Se mueven a `debug/` (los usan solo `debug/*_tick.tscn`, `walk_order.tscn`, `move_order.tscn`) | S (el árbol del producto queda limpio) | Bajo | S |
| A9 | `scenes/world/match_clock.gd`, `match_seed.gd` | Contador de ticks sobre `physics_frame`; RNG por sistema y nombre estable | Ya es `_physics_process` + `RandomNumberGenerator`. Solo `TICKS_PER_SECOND` duplica el setting del proyecto | S (leer `Engine.physics_ticks_per_second`) | Bajo | S |
| A10 | `scenes/data/game_data.gd` (autoload, 244), `assets/original/data/{creatures,spells,wizards,abilities,books}.json`, `map/map_building.gd:17` (`buildings.json`), `body_catalog.gd` (`sizes.json`) | Arma `CreatureType` (71), `SpellType` (53), `WizardType` (15), `AbilityType` (63) y los edificios (196) desde JSON en cada arranque. Los tipos ya tienen `@export` pero no hay `.tres`: no se pueden ver ni editar | `.tres` por tipo en `data/creatures/`, `data/spells/`, `data/wizards/`, `data/abilities/`, `data/buildings/`, horneados una vez por una herramienta; un `GameCatalog.tres` con las listas; `GameData` solo carga el catálogo | **E (el más alto: daño, maná, vida en el inspector)**, S | Medio (precisión al guardar floats; orden de iteración) | L |
| A11 | `scenes/fx/fx_atlas.gd`, `particle_type.gd` (`key` en `fx.json`), `fx_bus.gd`, `sprite_particles.gd`, `sprite_emitter.gd` | `CPUParticles3D` + `ParticleType.tres` (ya estándar y `@tool`); el atlas se busca por una clave de `fx.json` | `ParticleType` con `Texture2D` y `hframes/vframes` en vez de la clave JSON. **No** pasar a `GPUParticles3D` (§3) | E (poco) | Bajo | S–M |
| A12 | `scenes/ui/spell_book.gd:163-172`, `selection_roster/selection_roster.gd:135-149` | Crean `TextureRect`/`Panel`/`StyleBoxFlat` por código para cada slot | `PackedScene` de slot (`spell_slot.tscn` ya existe; una `roster_plate.tscn`) con su `StyleBox` en el `.tscn` | E | Bajo | S |
| A13 | `scenes/world/unit_body.gd` (1033) | `enum Mode` de 11 estados + `match mode` en `_physics_process`, más vuelo, regeneración, golpe | `FsmMachine` + `FsmState` (addon `fsm_kit`, ya usado por el doctor) | E (estados visibles), S por archivo | **Alto** (todo el combate pasa por acá) | L |
| A14 | Constantes de sacengine sueltas: `BodySeparation.BLOCK_SLACK/FIXUP_SPEED`, `GroundGuard` (gibDepth), `UnitBody.SUMMONING_ALPHA/COWER_SCALE/ROCK_FORM_DAMAGE`, `Orders` (`row_size`, distancia de formación) | Números fijos en código | `@export` en el nodo (look) o `MatchRules.tres` (reglas). Se hace **dentro** del corte que toca cada archivo, no en un corte aparte | E | Bajo | — |
| A15 | Red: `MpReplicate`/`MultiplayerSynchronizer`, `MultiplayerSpawner` del addon, RPC `submit_*` | Ya es el estándar | — | — | — | **Queda** |
| A16 | UI general (`hud.tscn`, lobby, opciones, menús) | Ya en `.tscn` | — | — | — | **Queda** |
| A17 | `scenes/world/vision/side_vision.gd`, `ai/perception/ai_perception.gd` | Cola de una criatura por lado por tick que marca lo visto | Es regla de juego (niebla/IA); un `Area3D` por criatura costaría más con 150 cuerpos | — | — | **Queda** (revisar después de la v1) |

## 2. Cortes (036a…)

Regla de orden con RFC-035:
- **035b–035e no se interrumpen con cortes que muevan digests** (035 exige «`quick` igual» hasta 035e). Entre medio solo entran cortes de 036 que también dan «`quick` igual».
- Lo que toca cuerpos y caminos (A1, A3) espera a **035i** (NavGrid borrada, un solo dueño de caminos).
- Cada corte: `quick` en el corte; si un digest cambia a propósito se regraba con una línea de causa en el F (RULES §Fidelidad). Review separada solo en 036f, 036g y 036j.

| Corte | Qué | Cuándo | Prueba barata | Regraba |
|---|---|---|---|---|
| **036a** | **Mago IA trabado en su Manalith** (hallazgo del usuario). Diagnóstico primero: `structure.tscn` es `StaticBody3D` en la capa 1, que es la `ground_mask` de los cuerpos, y `NavGrid` bloquea el disco con el mago adentro. Arreglo estándar: `Caster`/`StructureAction.check` rechaza un punto cuya huella (radio + margen) pisa un cuerpo vivo («Lugar ocupado»), y la IA (`ai_command_port`/`wizard_brain`) elige el punto a radio + 3 m del mago, en dirección contraria a la fuente | Ya (independiente de 035) | `debug/manalith_self.tscn` (§4): el mago llega a 20 m del Manalith en ≤ 10 s; y el caso humano: clic sobre el propio mago da «Lugar ocupado». `quick` | Sí si la IA cambia de punto (causa: sitio del Manalith) |
| **036b** | Limpieza sin cambio de comportamiento: A8 (checks a `debug/`), A9 (`TICKS_PER_SECOND` del setting), A7 (un `DebugLog` con categorías; los 30 `static var log_*` salen) | Entre 035b y 035e | `quick` igual; `grep -rn "static var log_" scenes` vacío; el banco imprime las mismas líneas con `--log=<cat>` | No |
| **036c** | **Catálogo en `.tres`** (A10): `tools/bake_catalog.gd` hornea los JSON a `.tres` una vez; `GameData` lee `data/catalog/game_catalog.tres`; `MapBuilding` y `BodyCatalog` leen `BuildingType`/`BodySize` `.tres`. Los JSON quedan solo como entrada de la herramienta (como `ntts.json` en 035d) | Entre 035d y 035e (mismo patrón que 035d) | `quick` **igual** (es refactor; un digest movido es bug). Caso headless `debug/catalog_cases.gd`: cada tipo del `.tres` == el armado desde JSON, campo a campo. `grep -rn "creatures.json\|spells.json" scenes` vacío | No |
| **036d** | **Topes parametrizables** (hallazgo del usuario): `MatchRules.max_creatures_per_player` (0 = sin tope) chequeado en `Caster._try_summon` del servidor, con el rechazo «Límite de criaturas» por el mismo camino de cue; la IA lo respeta porque pasa por `request_summon`. El tope de selección sigue en `Selection.max_size` (`@export`, ya existe) y se expone también en `MatchRules.max_selected` solo si el usuario lo quiere por partida (P2) | Después de 035e | `debug/creature_cap.tscn` (§4): con tope 3, la cuarta convocatoria da «Límite de criaturas» y no cobra maná. `quick` igual (default 0) | No |
| **036e** | `SacFloat` fuera (A4) | Después de 035e | `rules_suite` de aflicciones (Frozen, Vined, Quake) PASS con tolerancia de 1 tick. `quick` | Sí (causa: float64) |
| — | **035f–035i** (navegación) | — | (según RFC-035) | (según RFC-035) |
| **036f** | **Separación por evasión de Godot** (A1): `NavigationAgent3D` por cuerpo con `avoidance_enabled`, `radius` = caja de hoy, `avoidance_priority` del mago > sus criaturas (reemplaza `wizard_passes_own`), `velocity_computed` → `move_and_slide`. Se borran `BodySeparation`, `BodyGrid`, `MakeWay`. `project.godot`: evasión prendida, en un hilo | Después de 035i | `crowd_150` (≤ +20 % de tiempo, 0 trabadas), `crowd_tipi` (llegan ≤ 25 s), `crowd_rock`, `debug/escort_jam.tscn` (el mago no retrocede), Ctrl+Espacio con 4 Trogg (1–2,5 m entre ellos). Playtest corto con ventana | Sí (causa: evasión) |
| **036g** | **Animación en el editor** (A5): `scenes/world/body/models/<tag>.tscn` por modelo (glb + `AnimationTree` guardado, generado una vez por `tools/bake_body_scenes.gd`); `BodyClips` pasa a ser el mapeo rol → animación dentro de esa escena; `ClipClock` y `index.json` salen; el impacto visual es una pista de método | Después de 036f (o en paralelo si el orquestador quiere; no toca la sim) | `anim_wizard_trogg.tscn` y `body_gallery.tscn`: cada rol se ve (capturas). Abrir `models/ycro.tscn` en el editor: el árbol de animación se ve y se previsualiza. `quick` igual (la sim no lee animación) | No |
| **036h** | `GroundGuard` → navmesh + colisión (A3); `has_fallen` queda | Después de 036f | `rules_suite` `ground_*` y un caso nuevo: cuerpo empujado hacia un hueco no cae (o cae y muere si lo tiran, Tumbling). `quick` | Sí |
| **036i** | FX y UI chicos (A11, A12) | Cualquier momento | `biome_gallery`/`cast_*` capturas iguales a ojo; HUD igual en `pt80` | No |
| **036j** | `UnitBody` → `FsmKit` (A13), un estado por corte interno (Idle/Move primero) | Al final, solo con OK del usuario (P3) | `rules_suite` completo + `ai_match` corto. `all` | Sí |
| **036k** | Cierre: RULES (§Datos, §Fidelidad: evasión y animación de Godot), FEATURES, README de `assets/original` | Último | `all` PASS; playtest de partida de 3 min | — |

## 3. Qué queda custom (y por qué)

- **`MatchSeed`**: un `RandomNumberGenerator` por sistema y nombre estable. Es Godot puro y es lo que hace reproducible una partida con IA (RULES §IA). Cuesta 59 líneas.
- **`MatchClock`**: contar `physics_frame` es la forma estándar de un reloj de simulación; solo se saca la constante duplicada (036b).
- **`DetRecorder` y el banco** (`addons/agent_kit/determinism/`): herramienta de prueba, fuera del gameplay. Baja a prueba de humo, no se borra.
- **Red** (`MpKit`, `MultiplayerSynchronizer`, `submit_*`): ya es el estándar.
- **`CPUParticles3D`** en vez de `GPUParticles3D`: las partículas son sprites de atlas en ráfagas chicas y en pool; CPU es más predecible (semilla fija) y anda igual en todas las GPU. Pasar a GPU no da editabilidad nueva.
- **Visión y percepción de la IA** (A17): son reglas, no un sistema del motor.
- **Reglas del original** (daño, maná, enfriamientos, hechizos en `spells/actions/`): es lo que el usuario pidió conservar.
- **`has_fallen`** (gib al caer en un hueco): regla visible.

## 4. Escenas de prueba

- **036a `res://debug/manalith_self.tscn`**: instancia `high_noon.tscn` con `MatchRules` de `debug/rules/manalith_self.tres` (un asiento IA en `james`, maná lleno, `match_seed` fijo). Estado inicial: el mago IA junto a una fuente, sin Manalith. **No está todavía:** el mago saliendo del Manalith que construyó. Sin acción del InputMap: la IA decide sola; el caso registra la distancia mago–Manalith cada segundo. Variante humana: el mismo `.tscn` con otro `.tres` (sin IA), el playtester pulsa la tecla del libro de estructuras y hace clic sobre su propio mago (`select`/clic izquierdo).
- **036d `res://debug/creature_cap.tscn`**: instancia `high_noon.tscn` con `debug/rules/creature_cap.tres` (`max_creatures_per_player = 3`, maná y almas de sobra). Estado inicial: el mago local con 0 criaturas. **No está todavía:** el rechazo «Límite de criaturas». Acción: la acción `creature_1` (convocar) cuatro veces.
- **036c, 036b**: sin escena nueva; el criterio es headless (`debug/catalog_cases.gd` y `quick`).
- **036f, 036h**: escenas existentes (`crowd_*`, `escort_jam`, `rules_suite`), cada umbral en un `.tres` de reglas, no otro `.gd`.
- **036g**: `debug/anim_wizard_trogg.tscn` y `debug/body_gallery.tscn` existentes.

## 5. Árbol de archivos y responsabilidades

```
game/
├── data/
│   ├── catalog/game_catalog.tres          [+] 036c listas de tipos (verdad)
│   ├── creatures/<tag>.tres  ×71           [+] 036c CreatureType
│   ├── spells/<tag>.tres     ×53           [+] 036c SpellType
│   ├── wizards/<tag>.tres    ×15           [+] 036c WizardType
│   ├── abilities/<tag>.tres  ×63           [+] 036c AbilityType
│   ├── buildings/<tag>.tres                [+] 036c BuildingType (de buildings.json)
│   └── match_rules.tres                    [~] 036d max_creatures_per_player
├── scenes/data/
│   ├── game_data.gd                        [~] 036c solo carga game_catalog.tres
│   ├── game_catalog.gd                     [+] 036c Resource con las listas y búsqueda por tag
│   ├── building_type.gd                    [+] 036c
│   └── match_rules.gd                      [~] 036d
├── scenes/world/
│   ├── body_separation.gd, body_grid.gd, make_way.gd   [-] 036f
│   ├── ground_guard.gd                     [~] 036h solo has_fallen (o se renombra FallCheck)
│   ├── sac_float.gd                        [-] 036e
│   ├── match_clock.gd                      [~] 036b
│   ├── tick_check.gd, state_tick_check.gd, move_order_check.gd, walk_order.gd, *_order.tres, state_tick.tres, walk_step.tres  [→ debug/] 036b
│   ├── unit_body.gd, wizard/wizard_body.gd, sacrifice/doctor_body.gd  [~] 036f NavigationAgent3D; 036j FSM
│   ├── units/unit.tscn, wizard/wizard_body.tscn, sacrifice/doctor.tscn  [~] 036f hijo Avoidance (NavigationAgent3D)
│   ├── spells/caster.gd                    [~] 036a «Lugar ocupado»; 036d «Límite de criaturas»
│   ├── ai/command/ai_command_port.gd       [~] 036a sitio del Manalith
│   ├── map/map_building.gd                 [~] 036c BuildingType
│   ├── body_catalog.gd                     [~] 036c tamaños desde .tres
│   └── body/
│       ├── body_rig.gd, body_animator.gd   [~] 036g instancian models/<tag>.tscn
│       ├── clip_clock.gd, unit_clip_roles.gd  [-] 036g
│       └── models/<tag>.tscn               [+] 036g glb + AnimationTree guardado
├── scenes/world/components/debug_log.gd    [+] 036b categorías de log del banco
├── scenes/ui/spell_book.gd, selection_roster/*  [~] 036i slots como packed scene
├── scenes/fx/particle_type.gd, fx_atlas.gd [~] 036i Texture2D en vez de clave de fx.json
├── tools/
│   ├── bake_catalog.gd                     [+] 036c JSON → .tres, idempotente, no pisa ediciones sin --force
│   └── bake_body_scenes.gd                 [+] 036g glb → models/<tag>.tscn
├── debug/
│   ├── manalith_self.tscn + rules/manalith_self*.tres  [+] 036a
│   ├── creature_cap.tscn + rules/creature_cap.tres     [+] 036d
│   └── catalog_cases.gd                    [+] 036c
├── project.godot                           [~] 036f evasión prendida, un hilo
└── RULES.md, FEATURES.md                   [~] 036k
```

| Pieza | Responsabilidad | No hace |
|---|---|---|
| `GameCatalog` (`.tres`) | Lista de tipos; búsqueda por tag | Leer JSON |
| `CreatureType`/`SpellType`/… `.tres` | Números del original, editables | Mutarse en runtime |
| `bake_catalog.gd` | Pasar JSON a `.tres` una vez | Correr en partida |
| `NavigationAgent3D` (hijo `Avoidance`) | Separar cuerpos (RVO) | Pedir caminos (eso es `NavService`) |
| `Caster` | Validar convocatoria y estructura en el servidor (topes, lugar) | Elegir sitio por la IA |
| `AiCommandPort` | Elegir el sitio de la estructura de la IA | Saltear la validación del `Caster` |
| `models/<tag>.tscn` | Modelo + animaciones editables | Leer la simulación |
| `DebugLog` | Prender categorías de log del banco | Cambiar comportamiento |

## 6. Resource de tipo, nodo, `@export` de instancia

- **Resources** (no se mutan): `GameCatalog`, `CreatureType`, `SpellType`, `WizardType`, `AbilityType`, `BuildingType`, `ParticleType`, `BodyClips`, `MatchRules`.
- **Nodos:** `Avoidance` (`NavigationAgent3D`) bajo cada cuerpo; `models/<tag>.tscn` bajo `BodyRig`; slots de UI como packed scenes.
- **`@export` de instancia:** `NavigationAgent3D.radius`, `avoidance_priority`, `max_speed`; `Selection.max_size` (ya existe); `MapBuilding.type: BuildingType`.
- **Reglas de ronda en `MatchRules.tres`:** `max_creatures_per_player`, y si el usuario quiere (P2) `max_selected`.

## 7. Riesgos

- **R1. Evasión RVO con 150 cuerpos (036f).** Puede oscilar, rodear de más o dejar cuerpos trabados contra el tipi. Criterio numérico en `crowd_*` y `escort_jam`; si falla, se ajustan `time_horizon_agents`, `neighbor_distance` y `max_neighbors` en el inspector antes de tocar código. Si sigue fallando, se para y se pregunta (no se vuelve a `BodySeparation` sin OK).
- **R2. Reproducibilidad de la evasión.** El servidor de evasión puede usar varios hilos. Se fija en un hilo en `project.godot` (verificar el nombre del setting en 4.7.2) y `quick` corre dos veces seguidas con el mismo digest.
- **R3. Floats en `.tres` (036c).** Si un número del `.tres` no vuelve igual que el del JSON, `catalog_cases` lo nombra. Como es refactor, el gate es «`quick` igual».
- **R4. Animación en el dedicado (036g).** Hoy `ClipClock` corre en el dedicado; hay que confirmar que ninguna regla lee `impact`/`frame` (los comentarios dicen que no). `grep` de `clip_clock` en `units/` y `spells/` antes de borrar.
- **R5. 036a es un diagnóstico «probable».** Primero se reproduce con `manalith_self.tscn` y log de `find_path`/`is_on_floor`; si la causa es otra, el corte cambia y se avisa.
- **R6. Motor de física.** `project.godot` no fija el motor 3D. Si un corte prende colisión entre cuerpos, se fija explícito (fuera de alcance hoy: 036f no hace chocar cuerpos por física).

**Fuera de alcance (otros RFCs):**
- **RFC-037 Minimapa** (hallazgo del usuario): no existe nada hoy. Es UI nueva con `SubViewport` + cámara ortográfica o textura del terreno, y marcas por lado desde `SideVision`. RFC aparte.
- **RFC-038 Menú radial de órdenes y formaciones** (hallazgo del usuario): FEATURES F80 dice que el menú «avance/guardia/retirada» no ejecuta su acción, y `Orders` solo tiene la formación en línea. RFC aparte (UI `.tscn` + `FormationType.tres` por formación).
- PBR, pasto, otros mapas (RFC-035).

## 8. Orden de implementación

1. 036a (bug del Manalith; reproduce y arregla).
2. 035b → 036b → 035c → 035d → 036c → 035e.
3. 036d, 036e.
4. 035f → 035g → 035h → 035i.
5. 036f (review) → 036h.
6. 036g, 036i (sin orden entre sí).
7. 035j y 036j (si hay OK) → 036k.

## 9. Verificación humana en el editor

1. Abrir `data/creatures/ycro.tres`: se ven vida, daño y velocidad; cambiar la vida a 2000, F5, convocar un Trogg: la barra muestra 2000. Deshacer.
2. Abrir `data/match_rules.tres`: `max_creatures_per_player = 2`, F6 sobre `debug/creature_cap.tscn`, convocar tres veces: la tercera dice «Límite de criaturas».
3. F6 sobre `debug/manalith_self.tscn`: el mago IA construye y se aleja.
4. Abrir `units/unit.tscn`: hijo `Avoidance` con radio y prioridad en el inspector.
5. Abrir `scenes/world/body/models/ycro.tscn`: elegir el `AnimationTree` y previsualizar `run` y `attack`.

## 10. Preguntas abiertas (con recomendación)

- **P1. ¿036f quita también la regla de «el mago no es empujado por sus criaturas»?** Recomendación: no; pasa a `avoidance_priority` (mismo efecto, del motor).
- **P2. ¿Tope de selección por partida (`MatchRules`) o por escena (`Selection.max_size`)?** Recomendación: por escena, como hoy; el de criaturas por partida, porque es regla del servidor.
- **P3. ¿Se hace 036j (FSM de `UnitBody`) antes de la v1?** Recomendación: solo si después de 036f `unit_body.gd` sigue por encima de 800 líneas; es el corte más riesgoso y no cambia lo que ve el jugador.
- **P4. ¿Valor por defecto de `max_creatures_per_player`?** Recomendación: 0 (sin tope) hasta que el usuario elija un número.

## Decisión 2026-10-18 (orquestador, cola delegada por el usuario)

Se aplican las recomendaciones P1–P4. Se arranca por 036a.

**036a diferido (2026-10-18, usuario).** Una escena de prueba con la IA a 12, 25 y 40 m de la fuente, sin arreglo, no reprodujo el mago trabado: nunca quedó inmovilizado. Por decisión del usuario no se corrige ahora. Se revisa en una partida contra la IA cuando 035i deje la navegación con navmesh, y se abre un corte solo si se vuelve a ver.

## Cierre 2026-10-18 (036k)

- **Hechos:** 036b–036i (F197, F198, F205–F210).
- **Diferidos:**
  - 036a se revisa jugando contra la IA, ahora que la navegación es el navmesh.
  - 036j (`UnitBody` a FsmKit) espera el OK del usuario (P3).
- **Verificación:**
  - RULES §Fidelidad actualizada.
  - `all` DETERMINISM PASS.
  - Partida con ventana (`pt035e` → `agent/out/pt036k/`): AGENT_OK, sin errores.
