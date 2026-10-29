# RFC-048 — Estructura de carpetas por dominio

Estado: propuesto (plan del tech lead, sin código). Fecha: 2026-10-19. Rama: `editor-first`.
Corre **después** de que entren RFC-041 (hechizos como escenas), RFC-042 (dioses y libros) y RFC-043 (el editor muestra el mapa real), en un solo tramo y **sin nadie más trabajando** (ni otros worktrees ni el editor abierto).
Autoridad: pedido del usuario («organizar el código en algo que un humano pueda entender y escalar fácil») > PRD > FEATURES > RULES > VISUAL > RFC-040…047 > este plan.

Medido el 2026-10-19 sobre `game/` (solo lectura):

- `scenes/`: 399 `.gd`. Hay archivos sueltos en la raíz de `scenes/world` (34 `.gd`, 41 archivos en total), `scenes/ui` (13 `.gd`, 23 en total) y `scenes/data` (21 `.gd`). `scenes/world/units/` tiene 63 archivos en la raíz.
- `debug/`: 74 `.gd` sueltos, 209 archivos en la raíz y `debug/rules/` con 87 `.tres`. `agent/`: 106 `.gd`, 62 `run_*.sh` en la raíz y 562 flows. `tools/`: 12 `.gd` más los scripts de Python y shell.
- `data/`: unos 800 `.tres`. **Ya está ordenado por tipo** (`data/catalog/<tipo>/`, `data/look/`, `data/fx/`…).
- **2 378 de los 2 544 `ext_resource`** de los `.tscn`/`.tres` no tienen `uid=`, solo `path=`. Para esos, la ruta es el único vínculo.
- 142 líneas de código de producto con `res://scenes|data|debug` (en 94 archivos). Los 562 flows tienen 155 rutas `res://` distintas; `boot.tscn` aparece en 128. Hay 150 archivos `.sh`/`.py` con rutas y 11 `#include` de shader.
- En `assets/` hay 85 `.import` que apuntan a `res://tools/skeletal_post_import.gd` (84) y a `res://tools/terrain_import.gd` (1). Otros 11 `.tres` apuntan a scripts y shaders de `scenes/world/`.
- Todas las rutas que se arman en código (`"res://data/…/%s.tres" % x`) caen bajo `data/`. Ninguna cae bajo `scenes/`.
- `export_presets.cfg` (solo `dedicated_server`) excluye `agent/*` y `tools/*`, pero **no** `debug/*`.

---

## 0. Contradicciones entre artefactos (y cuál gana)

| Choque | Gana |
|---|---|
| El kit (`godot-studio-workflow/file-tree.md`) dice que las escenas de prueba van planas: `res://debug/<feature>_<slug>.tscn`. El usuario pide `debug/<feature>/`. | El pedido del usuario. La convención nueva es `res://debug/<feature>/<slug>.tscn`. Se anota en RULES y en el README de `debug/`. El kit no se toca en este RFC (ver P9). |
| RULES: «Escenas en `scenes/`». El ejemplo del pedido es plano (`game/core/`, `game/units/`…). | Se mantiene `scenes/` como paraguas; adentro, carpetas por dominio. Va como decisión en §2.1 y pregunta P1. |
| El kit dice que `res://debug/` no entra en el export. Hoy el export dedicado lo incluye (`--world=res://debug/…` en `sacrifice_flow.gd:37`). | RULES y el kit coinciden: `debug/` queda fuera del export (048l). Ver P4. |

---

## 1. Objetivo y criterios de aceptación

1. Un recién llegado entiende la raíz `res://` en un minuto: cada carpeta de primer nivel tiene un `README.md` que dice qué vive ahí y cómo agregar uno.
2. El código va por dominio: cada script vive al lado de su escena y de su clase de datos. No queda ningún archivo suelto en `scenes/world/`, `scenes/data/` ni en la raíz de `scenes/ui/` (esas tres carpetas desaparecen).
3. El producto y lo que es solo de desarrollo quedan separados: `debug/`, `agent/` y `tools/` no entran en el export, y el producto no referencia `res://debug|agent|tools` (eso se verifica con un chequeo).
4. Es **solo una mudanza**. No se renombra ningún archivo, `class_name` ni nodo, así que los digests de `quick` no cambian (no se regraba nada) y los flows con rutas de nodo siguen andando.
5. Al terminar cada corte el juego corre: hay dos imports limpios, `rules_suite` pasa, `quick` da igual y `boot.tscn` abre.

### Escena de prueba

No hace falta una nueva. El criterio se ve en las escenas que ya existen: `res://scenes/core/boot.tscn` (F5, la escena principal después de 048d) y `res://debug/suite/rules_suite.tscn` (el banco). Para el playtester no hay acción de InputMap. Este RFC no cambia nada que se vea, así que según la memoria «Playtest solo si es visible» se cierra con banco y review, sin ventana.

---

## 2. Árbol objetivo (después de 041/042/043 y 048)

### 2.1 Paraguas `scenes/` o plano: se queda el paraguas

Decisión: **se queda `scenes/` como único paraguas del producto, con dominios planos adentro.** Desaparecen los paraguas internos `scenes/world/` y `scenes/data/`.

Por qué:

- Si fuera plano, la raíz tendría unas 27 carpetas: 18 dominios más `addons`, `assets`, `data`, `debug`, `agent`, `tools`, `docs`, `rfcs`, `reviews`, `changes`, `visual` y `script_templates`. Así no se entiende en un minuto. Con el paraguas, la raíz se lee en tres grupos (producto, contenido, desarrollo) y la regla es una sola: «el juego está en `scenes/`».
- RULES, los skills del kit (`res://debug/`, `scenes/`) y 60 menciones en FEATURES ya hablan de `scenes/`, así que se reescriben menos documentos.
- El problema real nunca fue `scenes/`. Eran `world/`, un segundo paraguas con casi todo adentro, y `data/`, que separa las clases de su dominio. Esos dos sí desaparecen.
- La alternativa plana queda como P1, por si el usuario la prefiere. El script y la tabla de este RFC sirven igual: cambia solo el prefijo de destino.

### 2.2 Raíz `res://` (primer nivel)

```text
res://
├── README.md          # mapa de la raíz en 3 grupos (nuevo)
├── project.godot / export_presets.cfg
├── addons/            # kits genéricos (mp_kit, fsm_kit, agent_kit). NO se mueve
├── assets/            # arte y datos del original y CC0 (LFS). NO se mueve
├── data/              # contenido .tres por tipo (catálogo, look, fx, ui, ai…). Casi no se mueve
├── scenes/            # el juego: un dominio por carpeta
├── debug/             # escenas de prueba y banco, por dominio (dev, fuera del export)
├── agent/             # AgentKit: flows, harness, fixtures, runs (dev, fuera del export)
├── tools/             # importadores y horneados por CLI (dev, fuera del export)
├── script_templates/  # plantillas del editor. NO se mueve
└── docs/ docs/archive/rfcs/ docs/archive/reviews/ docs/archive/changes/ visual/   # documentos (fuera del export). NO se mueven
```

### 2.3 `scenes/`: un dominio por carpeta

```text
scenes/
├── README.md        # lista de dominios y regla «script + escena + clase de datos juntos»
├── core/            # arranque y servicios globales: boot, flow, catálogo, autoloads
│   ├── boot.tscn/.gd
│   ├── debug_log.gd
│   ├── flow/        # sacrifice_flow (autoload), match_setup
│   └── catalog/     # game_data (autoload), game_catalog, original_assets
├── match/           # una partida: reloj, semilla, reglas, estado, derrota, bioma
│   └── high_noon.tscn/.gd   # mundo raíz hasta que RFC-044 lo parta en map/ + match/
├── gods/            # GodBooks (+ GodType y BookEntry de RFC-042)
├── bodies/          # cómo se ve un cuerpo: rig, modelo, animador, catálogo de cuerpos
│   └── models/      # 73 escenas horneadas por tools/bake/bake_body_scenes.gd
├── components/      # piezas que usan unidades, magos y edificios: Health, ManaPool, SoulPurse, GroundSnap
├── units/           # criaturas: UnitBody, unit.tscn, spawner, órdenes de la criatura, CreatureType
│   ├── states/  abilities/  afflictions/  death_clouds/  impacts/  strikes/   # ya existen
│   ├── attacks/     # cuerpo a cuerpo, disparos, olas, gotas
│   ├── passives/    # pasivas al recibir y al pegar: escudos, carga, drenaje
│   ├── status/      # lo que se pega a un cuerpo: fuego, veneno, pegotes, ritmo
│   ├── movement/    # vuelo, cápsula, empujes, evasión, borde, caída, warp
│   └── targeting/   # a quién se puede atacar, visión por bando, políticas de blanco
├── wizards/         # WizardBody, forma fantasma, spawner, WizardType, WalkStep
├── spells/          # hechizos (árbol de RFC-041) + SpellType, CastTime
│   ├── actions/     # ya existe
│   └── guardian/    # guard_post, damage_deflector, bond, tether (venía de world/guardian)
├── structures/      # edificios: structure.tscn, StructureBody, spawner, BuildingType, inspector
├── sacrifice/       # ritual y Sac Doctors (sin cambios internos)
├── souls/           # almas y su sistema
├── map/             # el mapa: layout, edificios del mapa, spawns, bandos
│   ├── terrain/     # terrain, map_terrain_data, terrain_probe
│   ├── nav/         # navmesh y caminos (venía de world/nav)
│   └── props/       # altares, founts, plantas, starts, map_props, mana_source
├── ai/              # la IA como jugador (estructura interna sin cambios)
├── camera/          # world_camera
├── orders/          # órdenes, selección, comando del mundo, radial del mundo, world_input
│   └── formations/  # (venía de world/orders)
├── look/            # look del mundo: rig, calidad, piedra
│   ├── theme/       # god_theme, god_envi, theme_applier
│   ├── sky/  ground/  grass/  light/  fx/
├── fx/              # efectos sueltos y FxBus (sin cambios de ruta)
├── net/             # glue de red del juego (sin cambios de ruta)
└── ui/              # pantallas y HUD
    ├── hud/              # hud, iconos, escala, dígitos, avisos, resultado
    ├── spell_book/       # libro y páginas
    ├── character_select/ # selección de mago + preview + botón
    └── command_cue/ lobby/ local_server/ minimap/ options/ pause_menu/ radial/ selection_roster/ wizard_stats/   # ya existen
```

Regla de lugar (la que va en el README de `scenes/`): **un script va donde vive la escena que lo usa; una clase `Resource` va con el dominio que la consume, no en una carpeta `data/` de clases.** Si una pieza tiene tres usuarios de dominios distintos, va a `components/`, y si sirve fuera de Sacrifice, a `addons/`.

### 2.4 `data/`: queda como está

`data/` ya está ordenado por tipo, y `GameCatalog` lo recorre por convención (`DIR + folder`). Todas las rutas dinámicas del código caen ahí, y el diseñador ya lo conoce (RFC-040). **En 048 no se mueve ningún `.tres` de `data/`.** Solo se agrega `data/README.md`, con la tabla «carpeta → clase → dominio de `scenes/` que la lee». Lo de renombrarlo a `content/` queda como P2.

### 2.5 Tabla de destino: cada archivo y carpeta suelta de hoy

Las rutas son relativas a `res://`. «(+tscn)» quiere decir que el `.tscn` del mismo nombre va al mismo lugar. Cada `.uid` va con su archivo.

**Carpetas que se mudan enteras** (la estructura interna no cambia salvo lo que se indica):

| Hoy | Destino |
|---|---|
| `scenes/flow/` | `scenes/core/flow/` |
| `scenes/world/ai/` (todo el subárbol) | `scenes/ai/` |
| `scenes/world/body/` (7 archivos) | `scenes/bodies/` |
| `scenes/world/body/models/` (73) | `scenes/bodies/models/` |
| `scenes/world/guardian/` | `scenes/spells/guardian/` |
| `scenes/world/look/` (raíz y subcarpetas) | `scenes/look/` (con `sky/`, `ground/`, `grass/`, `light/` y `fx/` iguales) |
| `scenes/world/map/` | `scenes/map/` |
| `scenes/world/nav/` | `scenes/map/nav/` |
| `scenes/world/props/` | `scenes/map/props/` |
| `scenes/world/match/` | `scenes/match/` |
| `scenes/world/orders/` (formaciones) | `scenes/orders/formations/` |
| `scenes/world/sacrifice/` | `scenes/sacrifice/` |
| `scenes/world/souls/` | `scenes/souls/` |
| `scenes/world/spells/` (árbol de 041) | `scenes/spells/` |
| `scenes/world/structures/` | `scenes/structures/` |
| `scenes/world/units/{states,abilities,afflictions,death_clouds,impacts,strikes}/` | `scenes/units/<igual>/` |
| `scenes/world/vision/side_vision.gd` | `scenes/units/targeting/` |
| `scenes/world/wizard/` | `scenes/wizards/` |
| `scenes/fx/`, `scenes/net/`, `scenes/ui/<sub>/` | **no se mueven** |

**`scenes/world/` raíz (41 archivos):**

| Destino | Archivos |
|---|---|
| `scenes/units/` | `unit_body.gd` |
| `scenes/units/movement/` | `body_avoidance.gd` (+tscn), `edge_clamp.gd`, `fall_check.gd`, `warp_snap.gd` |
| `scenes/units/targeting/` | `attackable.gd`, `target_rules.gd` |
| `scenes/wizards/` | `walk_step.gd`, `walk_step.tres` (solo los usa `wizard_body`) |
| `scenes/bodies/` | `body_box.gd`, `body_catalog.gd`, `body_library.gd` (autoload), `body_visual.gd`, `obj_mesh.gd`, `original_material.gd` |
| `scenes/match/` | `high_noon.gd` (+tscn), `match_clock.gd`, `match_seed.gd`, `match_biome.gd` |
| `scenes/orders/` | `orders.gd`, `order_radial.gd`, `selection.gd`, `match_command.gd`, `command_log.gd` |
| `scenes/map/terrain/` | `terrain.gd`, `map_terrain_data.gd`, `terrain_probe.gd` |
| `scenes/map/props/` | `map_props.gd`, `mana_source.gd` |
| `scenes/look/theme/` | `god_theme.gd`, `god_envi.gd`, `theme_applier.gd` |
| `scenes/look/ground/` | `sacrifice_ground.gdshader` (5 `.tres` de `assets/` lo usan; se reescriben) |
| `scenes/look/sky/` | `sky.gd` (+tscn), `sky_band.gdshader`, `sky_clouds.gdshader` |
| `scenes/structures/` | `structure_inspector.gd` |
| `scenes/camera/` | `world_camera.gd` |

**`scenes/world/units/` raíz (63 archivos):**

| Destino | Archivos |
|---|---|
| `scenes/units/` (se quedan 16) | `unit.tscn`, `unit_air.gd`, `unit_clips.gd`, `unit_orders.gd`, `unit_spawner.gd`, `unit_mana_support.gd`, `unit_health_bar.gd` (+tscn, +gdshader), `peasant.tscn`, `peasant_behavior.gd`, `grudge_memory.gd`, `captive.gd`, `corpse.gd` + `creature_type.gd` (de data) + `unit_body.gd` (de world) |
| `scenes/units/attacks/` | `melee_attack.gd`, `melee_on_hit.gd` (+tscn), `ranged_attack.gd`, `ranged_shot.gd`, `shot_aim.gd`, `shot_dropper.gd` (+tscn), `shot_impact.gd`, `shot_in_flight.gd`, `shot_look.gd`, `shot_spawner.gd`, `split_flight.gd` (+tscn), `ground_hug_flight.gd` (+tscn), `growing_wave.gd`, `wave_touch.gd`, `ignite_touch.gd`, `freeze_touch.gd`, `frost_wave.tscn`, `gargoyle_wave.tscn`, `spitfire_wave.tscn`, `mite_hop.gd` (+tscn), `droplet_rain.gd` (+tscn) |
| `scenes/units/passives/` | `damage_passive.gd`, `life_shield.gd` (+tscn), `fire_shield.gd` (+tscn), `shield_bubble.gdshader` (+tscn), `lightning_charge.gd` (+tscn), `life_drain.gd` |
| `scenes/units/status/` | `burning.gd`, `poisoned.gd`, `poisoning.gd`, `damage_over_time.gd` |
| `scenes/units/movement/` | `flight.gd`, `body_collider.gd`, `body_nudge.gd` |
| `scenes/units/targeting/` | `target_picker.gd` |
| `scenes/units/abilities/` | `ability_effect.gd`, `active_ability.gd` |
| `scenes/units/death_clouds/` | `death_cloud.gd`, `death_cloud_spawner.gd` |

Hay que confirmar al armar el CSV leyendo la cabecera `##` de cada uno: `split_flight` y `ground_hug_flight` son disparos (la cabecera habla de rocas y de «Spikey Death»), no vuelo de unidad. `mite_hop` y `droplet_rain` van con los disparos que los generan.

**`scenes/world/components/` (14):**

| Destino | Archivos |
|---|---|
| `scenes/components/` | `health.gd`, `mana_pool.gd`, `soul_purse.gd`, `ground_snap.gd` |
| `scenes/units/status/` | `clinging.gd` (+tscn), `cling_bomb.tscn`, `cling_mite.tscn`, `pace_factors.gd` (+tscn), `devour_growth.gd` (+tscn) |
| `scenes/bodies/` | `clip_playback.gd` (es el contrato del animador) |
| `scenes/core/` | `debug_log.gd` |

**`scenes/data/` (21 + lo de 042):**

| Destino | Archivos |
|---|---|
| `scenes/core/catalog/` | `game_data.gd` (autoload), `game_catalog.gd`, `original_assets.gd` |
| `scenes/match/` | `match_rules.gd` |
| `scenes/gods/` | `god_books.gd` + `god_type.gd`, `book_entry.gd` (RFC-042, si nacen en `scenes/data/`) |
| `scenes/bodies/` | `body_size.gd`, `body_pose_override.gd`, `body_pose_overrides.gd` |
| `scenes/units/` | `creature_type.gd` |
| `scenes/units/abilities/` | `ability_type.gd`, `ability_catalog.gd` |
| `scenes/units/afflictions/` | `affliction_type.gd` |
| `scenes/units/death_clouds/` | `death_cloud_type.gd` |
| `scenes/units/passives/` | `damage_passive_type.gd`, `on_hit_passive_type.gd` |
| `scenes/units/targeting/` | `target_policy.gd`, `wounded_ally_policy.gd` |
| `scenes/spells/` | `spell_type.gd`, `cast_time.gd` |
| `scenes/wizards/` | `wizard_type.gd` |
| `scenes/structures/` | `building_type.gd` |

**`scenes/ui/` raíz (23):**

| Destino | Archivos |
|---|---|
| `scenes/core/` | `boot.gd` (+tscn) (escena principal: `project.godot` y 128 flows) |
| `scenes/ui/hud/` | `hud.gd` (+tscn), `hud_icons.gd`, `hud_scale.gd`, `bitmap_digits.gd`, `text_readout.gd`, `frame_piece.tscn`, `ritual_notice.gd` (+tscn), `match_result.gd` (+tscn) |
| `scenes/ui/spell_book/` | `spell_book.gd` (+tscn), `spell_slot.gd` (+tscn) |
| `scenes/ui/character_select/` | `character_select.gd` (+tscn), `wizard_preview.gd` (+tscn), `pick_button.tscn` |
| `scenes/orders/` | `world_input.gd` (decide si el input llega al mundo) |

Los archivos nuevos que traigan 041, 042 y 043 se mapean con la misma regla. Si algo queda sin mapear bajo una carpeta que se vacía, el script falla (§3.2).

### 2.6 `debug/` por dominio

Convención nueva: `res://debug/<dominio>/<slug>.tscn`, con el mismo nombre de dominio que en `scenes/`. Un `.tres` de debug va al lado de su escena. Los nombres de archivo **no** cambian; los `f<NNN>_*` se quedan como están.

| Destino | Regla / archivos |
|---|---|
| `debug/suite/` | Banco headless: `rules_suite.gd` (+tscn), todos los `*_cases.gd` (+`catalog_edit_cases.tscn`), `bench_*.gd`, `village_rules.gd`, `tick_check.gd`, `tick_order.gd`, `state_tick*.{gd,tres,tscn}`, `move_order_check.gd`, `idle_tick.tscn` + `idle_order.tres`, `advance_tick.tscn` + `advance_order.tres` |
| `debug/rules/` | **No se mueve** (87 `.tres`; `det_cases.txt` y los flows lo usan) |
| `debug/ai/` | `ai_match.gd` (+tscn; es `DET_SCENE` en `agent/det.cfg`), `ai_*.tscn` |
| `debug/units/` | `f1[0-9][0-9]_*.tscn` (bestiario y habilidades, RFC-030), `ability_spit*.{gd,tscn}`, `melee_duel`, `creature_cap`, `rock_hit`, `roster_hit`, `summon_unit`, `target_pick`, `goal_marker.gd` |
| `debug/wizards/` | `wizard_ghost.tscn`, `wizard_slope.{gd,tscn}` |
| `debug/spells/` | `cast_*.tscn`, `wrath_splash*.tscn`, `teleport_home.tscn`, `guardian_altar.tscn`, `guardian_manalith.tscn` |
| `debug/sacrifice/` | `convert_*.tscn`, `desecrate_*.tscn`, `doctor_bench.tscn`, `doctor_path.{gd,tscn}`, `ritual_*.tscn`, `soul_pickup.tscn` |
| `debug/orders/` | `move_order.{gd,tres,tscn}`, `walk_order`, `orders_group`, `orders_radial`, `selection_many*`, `retreat_spacing`, `escort_jam` |
| `debug/map/` | `nav_*`, `hole_edge`, `village*` (menos `village_net`), `crowd_*`, `five_by_five_arena`, `mana_fount`, `mana_probe`, `ground_probe`, `terrain_normals_probe`, `terrain_reference.res`, `structure_siege` |
| `debug/match/` | `match_defeat.tscn` |
| `debug/look/` | `biome_*`, `grass_lab*`, `look_bench`, `look_gallery`, `sky_motion`, `sky_probe`, `mm_preview` + el `quality_medium_fx_legacy.tres` que ya está |
| `debug/fx/` | `fx_*`, `vfx_lab`, `fount_fx_probe` + el `heal_slow.tres` que ya está |
| `debug/bodies/` | `body_gallery`, `body_pose_bench`, `gallery_body`, `anim_wizard_trogg`, `npc_anim_gallery`, `unit_parity_gallery`, `capsule_preview`, `f134_hybrid_pose_*` (excepción a la regla `f1xx`), `rig023c…f/` |
| `debug/camera/` | `camera_edges` |
| `debug/net/` | lo que ya está + `join_once`, `late_join`, `village_net` |
| `debug/catalog/` | `data_book` (+ las escenas de chequeo que traiga RFC-040/043 si son escenas para abrir y no banco) |

Al terminar, la raíz de `debug/` queda solo con `README.md`.

### 2.7 `agent/` y `tools/`

`agent/` cambia lo mínimo, porque los flows, los runs y 996 menciones en los documentos apuntan a `agent/run_determinism.sh`:

```text
agent/
├── README.md                 # cómo correr quick/all, 034e, un flow; índice de runs
├── run_determinism.sh        # se queda en la raíz (punto de entrada canónico)
├── det.cfg det_cases.txt det_baseline.txt   # se quedan (los lee run_determinism)
├── runs/                     # los otros 61 run_*.sh + runs/README.md (una línea por script, sacada de su cabecera)
├── scripts/                  # mkflow*.py, editor_capture.sh, grass_bench_metrics.py, shade_metric_022e4b.py
├── fixtures/                 # + las carpetas por F sueltas: f037b/ f037c/ f038d/ f208/ f220/ → fixtures/<f>/
├── flows/ harness/ tools/ perf/ editor/      # no se mueven
└── out/                      # no se toca (ignorado, 7,8 GB)
```

Ojo: 17 `run_*.sh` calculan `ROOT="$(cd "$(dirname "$0")/.." && pwd)"`. Al mudarlos a `runs/` hay que pasarlos a `/../..`. El script lo hace como regla explícita para `agent/runs/*.sh` y lo verifica con un `grep`. `model_eval.md` va a `docs/`.

`tools/`:

```text
tools/
├── README.md
├── skeletal_post_import.gd   # NO se mueve: 84 .import de assets/ lo nombran
├── terrain_import.gd         # NO se mueve: 1 .import lo nombra
├── move_map.py               # nuevo (048a)
├── move_map/                 # 048.csv (el mapa viejo → nuevo, queda versionado como índice histórico)
├── import/                   # todos los .py que importan sac_formats + sac_formats/ (van juntos): import_*.py, export_skeletal*.py, export_stats.py, fx_catalog.py, land_themes.py, classify_ground_tiles.py, migrate_particle_atlas.py, sample_grass_palette.py
├── bake/                     # bake_catalog, bake_body_scenes, bake_map_layout, bake_nav (+tscn), catalog_builder, terrain_glb_export, import_terrain.gd
├── audit/                    # audit_skeletal*.gd, check_icon_files.gd, check_original_assets.sh (+ check_layout_transforms y su baseline de 043)
├── material/                 # mm_export.sh, mm_gen_grass.py
└── deploy/                   # no se mueve
```

`tools/migrate_layout_043.gd` es de una sola vez: va a `tools/bake/` o se borra con el OK de 043 (P10).

### 2.8 Convenciones de nombres (van en `scenes/README.md` y en RULES)

- **Archivos:** `snake_case`, en inglés. La escena y su script comparten nombre (`hud.tscn` + `hud.gd`). Un shader vive al lado de la escena que lo usa, y su `.gdshaderinc` en la misma carpeta.
- **Tipos de contenido:** `<cosa>_type.gd` con `class_name <Cosa>Type extends Resource`, en el dominio que lo consume. Los `.tres` van en `data/catalog/<cosa>s/<tag>.tres`. Las políticas y catálogos chicos se llaman `<x>_policy.gd` y `<x>_catalog.gd`.
- **`class_name`:** PascalCase igual al nombre del archivo (`soul_purse.gd` → `SoulPurse`). Todo script de producto que se instancia en una escena reusable lo tiene. Hoy 327 de 399 lo tienen; los 72 que faltan no se tocan en 048 (es trabajo de RFC-046).
- **Estados FSM:** `<nombre>_state.gd` bajo `states/` del actor. Las excepciones históricas (`sacrifice/*_states/`) se quedan.
- **Nodos:** PascalCase. Componentes por rol (`Health`, `ManaPool`, `States`). Lo que se toca desde el script de la propia escena va con `%UniqueName`. **048 no renombra ningún nodo** (los flows usan `/root/HighNoon/MapProps/…`).
- **Debug:** `debug/<dominio>/<slug>.tscn`. Un atajo es otro `.tres` del mismo script. El producto no referencia nunca `res://debug|agent|tools` (lo verifica `move_map.py --lint`).
- **Excepciones que se quedan:** los modelos horneados se llaman por el tag del original (`AArc.tscn`, `ABRX.tscn`), igual que los `.tres` del catálogo.

### 2.9 README por carpeta de primer nivel

Uno en cada una de `res://`, `scenes/`, `data/`, `debug/`, `agent/` y `tools/`. `addons/<kit>/` y `assets/` ya tienen el suyo; se agrega uno de una línea en `addons/` y otro en `assets/` que apunte a esos. Y uno corto (5 a 10 líneas) por dominio de `scenes/` (ver P8). Plantilla fija:

```text
# <carpeta>
Qué vive acá: …            (una frase)
Qué NO vive acá: …         (y dónde va)
Piezas principales: tabla «archivo → responsabilidad» (máx. 10 filas)
Cómo agregar uno: 3–6 pasos (duplicar .tres / instanciar .tscn / dónde registrar)
Cómo verificarlo: escena de debug o comando
```

### 2.10 Mapa de responsabilidades (archivos nuevos)

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `tools/move_map.py` | Aplicar un CSV de mudanza: `git mv` + reescritura + chequeo | Script CLI (dev) | Se reusa en cada corte y para rebasar ramas viejas |
| `tools/move_map/048.csv` | Ser la única fuente del mapeo viejo → nuevo | Dato (CSV) | Se revisa antes de aplicar y queda como índice histórico |
| `*/README.md` | Explicar una carpeta | Doc | Uno por carpeta, cerca de lo que describe |
| `RULES.md` (§Arquitectura) | Regla de lugar y nombres | Doc | La autoridad del proyecto |

No hay Resources ni nodos nuevos. No cambia ningún `@export` ni ningún `.tres` de tipo (solo su `path=`).

---

## 3. Método de migración (seguro en Godot 4.7)

### 3.1 Reglas

- **Con el editor cerrado y sin otros worktrees activos.** El editor abierto vuelve a guardar las escenas con las rutas viejas, y su caché pisa `.godot/`.
- **Solo `git mv`.** Cada archivo se muda con su `<archivo>.uid` y su `<archivo>.import` si existen. En `scenes/` y `debug/` no hay `.import` versionados (`.gitignore` ignora `*.import` fuera de `assets/`), pero el script los mueve igual si aparecen.
- **Se reescribe `path=` aunque haya `uid=`.** Godot resuelve por UID primero, pero acá el 93 % (2 378 de 2 544) de los `ext_resource` no tiene UID. **No** se agregan los `uid=` que faltan (P7).
- **Se reescriben todas las rutas en texto:** `preload`/`load`, las constantes de carpeta (`SCENE_DIR` en `body_model.gd`, `OUT_DIR` en `tools/bake_body_scenes.gd`, `TYPES_DIR` y `LOOKS_DIR` si cambiaran, `ROOT` de `OriginalAssets`, que no cambia), los `#include` de shader, los flows `.json`, `det_cases.txt`, `det.cfg`, los `.sh`, los `.py` y `tools/deploy/room_server.service`.
- **Configuración:** en `project.godot`, los autoloads `SacrificeFlow`, `GameData` y `BodyLibrary` (`FxBus` no cambia) y `run/main_scene`. En `export_presets.cfg`, `exclude_filter` suma `debug/*` y `script_templates/*` (048l). `.gitattributes` y `.gitignore` (los del repo y los de `game/`) no tienen hoy rutas de `scenes/`, `debug/` ni `tools/`, pero el script los revisa igual.
- **Documentos vivos** (`PRD.md`, `FEATURES.md`, `RULES.md`, `VISUAL.md`, `docs/`, `../README.md`, `agent/**/README.md`): se reescriben. **Historia** (`docs/archive/rfcs/`, `docs/archive/reviews/`, `docs/archive/changes/`, `agent/out/`): no se toca; para eso queda el CSV versionado (P3).
- **No se renombra nada** (archivo, `class_name`, nodo). Una mudanza no puede cambiar la simulación: si `quick` cambia, hay un bug en la mudanza y se para.
- Un commit por corte, con el mensaje `RFC-048x: mover <dominio> (solo rutas)`. Los hashes se suman a `.git-blame-ignore-revs`. Como cada archivo cambia poco (una o dos líneas de ruta), git detecta los renames y `git log --follow` sigue andando.

### 3.2 `tools/move_map.py` (contrato)

```text
python3 tools/move_map.py <csv> [--dry-run] [--diff] [--apply] [--check] [--lint] [--rewrite-only]
```

- **CSV:** `old,new` relativos a `res://`. Si la fila termina en `/` mueve una carpeta; si no, un archivo. Las líneas con `#` son comentarios. Hay una directiva `@require-empty scenes/world/` que hace fallar el script si queda algún archivo sin mapear bajo esa carpeta. Hay otra, `@fix-root agent/runs/*.sh`, que pasa `dirname "$0")/..` a `/../..`.
- **Validación (antes de tocar nada):** todo `old` existe y ningún `new` existe. No hay dos `old` con el mismo `new`. No se mueve nada de la lista «NO mover» (§5). Cada `@require-empty` queda cubierto.
- **Mudanza:** se expanden las carpetas a archivos, se suman los `.uid`/`.import` hermanos, se hace `mkdir -p` y `git mv`.
- **Reescritura en una sola pasada:** una regex con todas las rutas viejas en alternancia, la más larga primero, con borde (`(?<![\w/.-])`). Así nunca se encadena A→B→C. Reconoce tres formas: `res://old`, `old` desnudo en `.sh`/`.py`/`.md`/`.service`, y el prefijo de carpeta `res://old/`. Recorre los archivos de texto que `git ls-files` lista en `game/` (`.gd .tscn .tres .gdshader .gdshaderinc .godot .cfg .json .txt .sh .py .md .service .import`) más `../README.md`, `../.gitattributes` y `../.gitignore`. Deja afuera `docs/archive/rfcs/`, `docs/archive/reviews/`, `docs/archive/changes/`, `agent/out/`, `addons/` y los binarios LFS.
- **`--check` (falla con exit 1):**
  1. `grep` de cada ruta vieja, en sus tres formas, sobre ese mismo conjunto: debe dar vacío.
  2. Escaneo de enlaces muertos: todo literal `res://…` sin `%`, `+` ni `{` en ese conjunto apunta a un archivo que existe.
  3. Todo `.gd` tiene su `.gd.uid` al lado.
  4. Los autoloads y `main_scene` de `project.godot` existen.
- **`--lint`:** el producto (`scenes/`, `data/`) no nombra `res://debug|agent|tools` (salvo comentarios), y la raíz de `scenes/` y de `debug/` no tiene archivos sueltos aparte del README.
- **`--dry-run` / `--diff`:** imprime las mudanzas, cuántas reescrituras hay por archivo y el diff; no escribe nada. **`--rewrite-only`:** aplica solo la reescritura (sirve para traer una rama vieja al árbol nuevo después de 048).
- Es idempotente: correrlo de nuevo sobre un árbol ya movido no hace nada y da exit 0.

### 3.3 Verificación por corte (en este orden, Godot de a uno)

1. `python3 tools/move_map.py tools/move_map/048.csv --check --lint` → exit 0.
2. `Godot --headless --import` **dos veces**. La segunda corrida no puede tener `ERROR`, `Failed loading`, `Invalid UID`, `Cannot open file` ni `Parse Error` (se filtra el log). La primera rehace `global_script_class_cache.cfg` y `uid_cache.bin`.
3. Abrir las escenas principales headless (`--headless --quit-after 60 <escena>`) sin errores: `scenes/core/boot.tscn`, `scenes/match/high_noon.tscn`, `scenes/match/match.tscn`, `scenes/units/unit.tscn`, `scenes/wizards/wizard_body.tscn`, `scenes/net/room_server.tscn` y la escena del dominio que se movió en ese corte.
4. `debug/suite/rules_suite.tscn` headless → PASS.
5. `bash agent/run_determinism.sh quick` → **digests iguales, sin regrabar**. Si alguno cambia, el corte se revierte.
6. `bash agent/runs/run_034e.sh` (o `agent/run_034e.sh` antes de 048k) en los cortes que tocan `core`/`net`/`match` (048d, 048h) y al final.
7. Flows con rutas de nodo, como muestra en headless: `f13_playable.json` (`boot.tscn`), uno con `/root/StructureSiege/HighNoon/MapProps/Founts/FountEast/…`, `f038d_radial.json` y `f037_minimap.json`. Los nombres de nodo no cambian, así que solo puede fallar la ruta de la escena, y eso ya lo cubre el paso 1.

---

## 4. Cortes (chicos, en orden de riesgo creciente; el juego corre después de cada uno)

| Corte | Qué | Por qué en este orden | Verificación extra |
|---|---|---|---|
| **048a** | `tools/move_map.py` + `tools/move_map/048.csv` completo + `--dry-run` en el árbol real. **No se mueve nada.** El usuario revisa el CSV. | El script se prueba sin riesgo. El CSV es el artefacto que se aprueba. | `--dry-run` sin filas sin mapear; un test del script sobre un repo de juguete en el scratchpad |
| **048b** | `look/` (con `theme/` y `sky/`), `camera/`, `scenes/fx` no cambia | Pocas referencias entrantes; prueba los `#include` de shader y los `.tres` de `assets/` que nombran `god_envi.gd` y `sacrifice_ground.gdshader` | Abrir `debug/look/look_gallery.tscn` (todavía en `debug/` raíz) |
| **048c** | `ui/hud/`, `ui/spell_book/`, `ui/character_select/`, `world_input` → `orders/` | Solo presentación; 97 referencias desde `.tscn` | `boot.tscn` abre y el HUD carga en `high_noon` |
| **048d** | `core/` (boot, flow, catalog, debug_log), `match/`, `gods/` + `project.godot` (autoloads y `main_scene`) | Es la base de los demás, pero tiene pocos archivos. Se reescriben 128 flows por `boot.tscn` | `run_034e` |
| **048e** | `bodies/` (+ `models/`, `SCENE_DIR`, `OUT_DIR` de bake) | 73 escenas con rutas armadas desde una constante | `bake_body_scenes --dry` si existe; si no, abrir 3 modelos |
| **048f** | `components/`, `units/` (con `attacks/`, `passives/`, `status/`, `movement/`, `targeting/` y los tipos de `scenes/data/`) | Es el corte más grande (unos 230 archivos y 623 referencias a `scenes/data`); entra con el script ya probado 4 veces | Abrir `debug/units/f111_bestiary.tscn` headless |
| **048g** | `wizards/`, `spells/` (+ `guardian/`), `structures/`, `sacrifice/`, `souls/` | Dependen de `units/` y `components/`, que ya se movieron | `rules_suite` cubre ritual, doctor y convert |
| **048h** | `map/` (+ `terrain/`, `nav/`, `props/`), `orders/`, `ai/`; `net/` no cambia de ruta | Vacía `scenes/world/` y `scenes/data/` (`@require-empty`) y borra esas carpetas | `run_034e`; `--lint` sin nada suelto en `scenes/` |
| **048i** | `debug/<dominio>/` (§2.6) | Toca 562 flows, `det.cfg` y `det_cases.txt`; es solo de desarrollo, no afecta el producto | `quick` lee `DET_SCENE` en la ruta nueva |
| **048j** | `tools/` (§2.7) | Las rutas de Python con `sac_formats` van juntas | `python3 tools/import/import_ui.py --help` (o el equivalente sin escribir) |
| **048k** | `agent/runs/`, `agent/scripts/`, `agent/fixtures/<f>/` + el arreglo de `ROOT` | Lo último: se reescriben los `run_*.sh` y los documentos los nombran | `bash agent/runs/run_034e.sh` |
| **048l** | READMEs (si no nacieron con su corte), `RULES.md` §Arquitectura, `export_presets.cfg` (`debug/*`), `.git-blame-ignore-revs`, entrada F en FEATURES | Cierre | Pasada completa: banco `all` (RULES lo pide al cerrar un RFC) |

Cada corte termina con el commit del corte. No hay review separada en los cortes chicos (memoria «Godot estándar antes que fidelidad»). Para 048f y 048h, como son de arquitectura, sí hay una review de una pasada, solo del CSV y del `--check`.

---

## 5. Qué NO mover, y riesgos

### No mover

- `addons/` entero (`mp_kit`, `fsm_kit`, `agent_kit`): son kits genéricos y sus rutas viven en `project.godot` y en el repo `godot-studio-skills`.
- `assets/` entero: LFS, `.import` versionados, rutas que usan los importadores y `OriginalAssets.ROOT`. Moverlo reimporta todo.
- `tools/skeletal_post_import.gd` y `tools/terrain_import.gd`: los nombran 85 `.import` de `assets/`. Cambiarlos obliga a reimportar 84 modelos (memoria: Godot puede colgar la Mac).
- `data/` (todo el contenido `.tres`): está ordenado por tipo, lo recorre `GameCatalog` por convención y es donde caen todas las rutas dinámicas (`%s`).
- `debug/rules/`, `agent/flows/`, `agent/harness/`, `agent/tools/`, `agent/out/`, `agent/run_determinism.sh` y `det.*`.
- `scenes/fx/`, `scenes/net/`, `scenes/ui/<sub>/` y la estructura interna de `scenes/world/ai/` y `scenes/world/sacrifice/` (solo cambia el prefijo).
- Nombres de archivo, `class_name` y nombres de nodo.
- `docs/`, `docs/archive/rfcs/`, `docs/archive/reviews/`, `docs/archive/changes/`, `visual/`, `script_templates/`.

### Riesgos

| Riesgo | Mitigación |
|---|---|
| El 93 % de los `ext_resource` dependen solo de `path=`: si falta una reescritura, la escena queda rota | `--check` con escaneo de enlaces muertos + import doble limpio + abrir las escenas principales |
| Ruta armada en código hacia una carpeta movida (`SCENE_DIR + tag + ".tscn"`) | Las constantes de carpeta van en el CSV como filas de carpeta; `--check` busca `res://…/"` con `+`/`%` y lista lo que quedó. Hoy todas las dinámicas caen en `data/` (no se mueve) salvo `SCENE_DIR`/`OUT_DIR` |
| Caché de `class_name` vieja (el playtester devuelve `CACHE_STALE`) | Import doble obligatorio. No se borra `.godot/` (se reconstruye solo) |
| Editor abierto o una rama en vuelo con rutas viejas | Corte sin nadie más. Una rama vieja se trae con `move_map.py 048.csv --rewrite-only` después de rebasar |
| Un `.sh` en `agent/runs/` calcula mal `ROOT` | Directiva `@fix-root` + `grep 'dirname "$0")/\.\."'` vacío en `runs/` |
| `.py` de importadores separados de `sac_formats` | Regla: todo `.py` que importa `sac_formats` va a `tools/import/` (lo valida el script) |
| Documentos de skills y memoria con rutas viejas (`.claude/skills/*` del kit y la memoria del usuario mencionan `scenes/world/body/models/`) | Los skills son del kit (ejemplos genéricos) y no se tocan. El orquestador actualiza la memoria del proyecto al cerrar 048 |
| La lista de `@require-empty` deja algo afuera por error de clasificación (por ejemplo, `split_flight` en `movement/` cuando es un disparo) | La clasificación no cambia el comportamiento, así que el costo es solo de lectura. Se corrige con otra fila del CSV en un corte posterior |
| `quick` cambia de digest | No debería pasar: no se renombra nada y `data/` no se mueve. Si pasa, se revierte el corte y se busca el orden que depende de la ruta (por ejemplo, un `list_directory`) |
| Sacar `debug/` del export rompe un dedicado de prueba en el VPS que usa `--world=res://debug/…` | Ese modo corre con el binario del editor, no con el export. Ver P4 |

---

## 6. Preguntas abiertas (cada una con recomendación)

- **P1. ¿Paraguas `scenes/` o plano en `res://`?** Recomiendo el paraguas (§2.1): la raíz queda en 12 entradas y no en 27, y RULES y el kit ya lo usan. Con el plano, el script y la tabla cambian solo el prefijo.
- **P2. ¿Renombrar `data/` a `content/`?** No: costaría 2 544 rutas, `GameCatalog` y las rutas dinámicas, y no gana claridad. Alcanza con el README.
- **P3. ¿Reescribir la historia (`docs/archive/rfcs/`, `docs/archive/reviews/`, `docs/archive/changes/`)?** No. Se reescriben solo los documentos vivos (PRD, FEATURES, RULES, VISUAL, docs, READMEs). El CSV versionado en `tools/move_map/048.csv` sirve para buscar una ruta vieja.
- **P4. ¿Sacar `debug/` del export dedicado?** Sí (en 048l), como piden el kit y la regla de producto y desarrollo. El modo `--world=res://debug/…` sigue andando con el binario del editor. Confirmar que nadie usa un export con debug en el VPS.
- **P5. ¿Sacar `agent_kit` del producto?** Todavía no: es un autoload y los flows lo necesitan. Va como RFC aparte: cargarlo solo con un flag de CLI y excluir `addons/agent_kit/*` del export.
- **P6. ¿Mover `skeletal_post_import.gd` y `terrain_import.gd` a `tools/import/`?** No en 048: obligaría a reimportar 84 modelos. Queda documentado en `tools/README.md` como excepción.
- **P7. ¿Agregar los 2 378 `uid=` que faltan?** No en 048, porque mezclaría la mudanza con cambios de contenido. Más adelante el editor los agrega solo al volver a guardar. Se puede hacer un RFC-046 aparte con un script, después de la v1.
- **P8. ¿Un README por dominio de `scenes/`, además de los de primer nivel?** Sí, cortos (5 a 10 líneas, con la plantilla de §2.9). Nacen en el corte que crea cada dominio.
- **P9. ¿Actualizar el kit (`godot-studio-workflow/file-tree.md`) a `debug/<feature>/`?** Sí, pero en el repo `godot-studio-skills` y después de que 048 cierre, siguiendo el flujo RC como con `mp_kit`. Hasta entonces, RULES del proyecto manda.
- **P10. ¿Qué pasa con `tools/migrate_layout_043.gd` (de una sola vez)?** Recomiendo borrarlo en 043 si ya corrió. Si no, va a `tools/bake/`.
- **P11. ¿048 antes o después de RFC-044 (partir `high_noon`)?** Antes. Así 044 nace en `scenes/map/` y `scenes/match/` y no se muda dos veces. `high_noon.tscn` queda provisorio en `scenes/match/`.
- **P12. ¿Archivar los `run_*.sh` viejos (por número de F/pt)?** No se borra ninguno. Van a `agent/runs/`, con un índice de una línea por script. Más adelante, con el OK del usuario, se puede hacer una limpieza aparte en `agent/runs/archive/`.
- **P13. ¿`wizards/` dentro de `units/`?** No: el mago tiene su propio cuerpo (`WizardBody`), su tipo y su spawner. Comparte `components/` y `units/movement/`, y eso alcanza.
