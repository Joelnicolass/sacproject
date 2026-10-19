# Auditoría «editor first» — Sacrifice port (Godot 4.7.2, rama `editor-first`)

Fecha: 2026-10-18. Autor: tech lead (Opus). Solo lectura: no se corrió Godot ni se editó el repo.
Medido con `grep`/`wc` sobre `game/`. «Producto» = `scenes/` (398 `.gd`, 44 978 líneas, 231 `.tscn`); `debug/` (84 `.gd`, 140 `.tscn`), `agent/` (106 `.gd`, 66 `.tscn`), `tools/` (12 `.gd`) y `addons/` (50 `.gd`) aparte.
Autoridad: decisión del usuario (este pedido) > PRD > FEATURES > RULES > VISUAL > RFC-035/036 > este informe.

---

## 1. Resumen ejecutivo

1. **El hallazgo más grave: los 599 `.tres` de `data/catalog/<tipo>/` no se usan.** `game_catalog.tres` (346 KB) trae los 599 tipos embebidos como `sub_resource` y no tiene ni un `ext_resource` hacia ellos. Si un diseñador edita `data/catalog/creatures/ahcr.tres`, la partida no cambia. Pero `tools/bake_body_scenes.gd:20-21,75,85` sí lee esos archivos, así que hoy hay dos fuentes de verdad.
2. La composición de los actores es buena: `unit.tscn` tiene 60 nodos, con 30 componentes, 10 aflicciones y 11 estados `FsmState`. Las habilidades usan `AbilityCatalog.tres` (tag → escena). Las formaciones, aflicciones, perfiles de IA y la calidad visual son `.tres`.
3. **Los hechizos no siguen ese patrón.** `caster.gd` tiene 7 tags fijos (`IMPLEMENTED`, l. 18-25) y 13 ramas `spell.tag ==`. `spell_spawner.gd` crea los proyectiles con `script.new()` y un `match kind`. Sumar un hechizo exige tocar 3 o 4 scripts.
4. **Agregar un segundo mapa hoy no es posible sin tocar código.** Hay rutas `HIGH_NOON_*` en `original_assets.gd:23-26`, `side_relations.gd:17`, `ground_material.gd:10`, `nav_service.gd:19`, `terrain.gd:9` y `sacrifice_room_rules.gd:10`. Además, `high_noon.tscn` mezcla el mapa, los sistemas de partida y el HUD en 64 nodos.
5. **Lo que se ve en el editor no siempre es lo que pasa en juego.** Los 69 edificios de `high_noon_layout.tscn` guardan una rotación identidad, y `MapBuilding._ready` (l. 63-65) los rota con `facing_deg` recién en runtime. El gizmo de rotación no sirve.
6. **Localización bloqueada por diseño.** Hay 0 llamadas a `tr()`, 241 literales en español en 98 scripts y 85 `text =` en `.tscn`. Además, el texto en español funciona como clave del protocolo: `command_cues.tres` mapea «Sin maná» → `refused`, y `match_command.gd:98` compara el texto del feedback con `spell.display_name`.
7. Hay mucho acoplamiento por cadenas: 455 líneas con `.call("…")` en 106 archivos, 120 `has_method`, 44 `get_node_or_null("Health")` y 36 `get_first_node_in_group("…")` con nombres sueltos. Hay tipos sin `class_name` (`spellbook.gd`, `summoner.gd`, `caster.gd`), y también se llama por cadena a clases que sí lo tienen (`$RangedAttack.call("setup")` en `unit_body.gd:218`).
8. **Los horneados son todos por CLI.** Son 6 (`bake_catalog`, `bake_body_scenes`, `bake_map_layout`, `bake_nav`, `terrain_glb_export`, `import_terrain`). Solo el navmesh avisa en el editor cuando quedó viejo (`map_nav_region.gd:14-22`). Fuera de los addons no hay `EditorPlugin`, y hay un solo `@export_tool_button` (`look_rig.gd:18`).
9. **La red de seguridad castiga al diseñador.** `debug/catalog_cases.gd` exige que cada `.tres` sea igual al JSON, así que cualquier cambio de balance lo hace fallar. No hay un validador de referencias (ability_tags, books). Hay 62 `run_*.sh` con nombres de F/pt y ningún índice.
10. **Documentación:** FEATURES.md (3 129 líneas, 201 F) es un registro, no una guía. No hay ningún «cómo agregar X». Solo hay 6 README, todos en addons/assets/deploy; ninguno en `scenes/` ni en `data/`. Prioridad: arreglar el catálogo (P0), pasar los hechizos a escenas, separar Mapa/Partida y sacar el texto del protocolo; después vienen las herramientas del editor y las guías.

---

## 2. Scorecard

| # | Área | Hoy (1–5) | Qué sería un 5 |
|---|---|---|---|
| 1 | Autoría de contenido | **2** | Cada tipo es un `.tres` propio que el juego realmente lee; un hechizo, criatura, mapa o dios nuevo es «duplicar `.tres`/`.tscn` y asignar», sin tocar `.gd` |
| 2 | Estructura de escenas | **3,5** | Actores ya compuestos; faltan proyectiles como `.tscn`, Mapa separado de Partida, rotación WYSIWYG y variantes por criatura |
| 3 | Datos y Resources | **2,5** | Una sola fuente por dato, referencias tipadas (`CreatureType`, no `"ycro"`), sin `Dictionary` anidados para el diseñador |
| 4 | Arquitectura de código | **3** | Sin `.call("…")` sobre tipos conocidos; servicios por socket `@export` o accessor tipado; ningún archivo de más de 400 líneas de producto con más de 2 responsabilidades |
| 5 | Descubribilidad y docs | **2** | README por carpeta clave, guía «cómo agregar X», FEATURES corto (estado) y log aparte |
| 6 | Herramientas y pipeline | **2,5** | Horneados con botón en el inspector o plugin «Sacrifice», con aviso de dato viejo en cada artefacto horneado |
| 7 | Pruebas y red de seguridad | **2,5** | Un comando «validar contenido» que el diseñador corre (o un warning en el editor), separado del banco de determinismo |
| 8 | Escalabilidad | **2** | `MapDefinition.tres`, slots desacoplados de los bandos del mapa, `GameMode` como Resource, `tr()` + CSV |

---

## 3. Hallazgos por área

### 3.1 Autoría de contenido

| Contenido | Pasos hoy | Archivos | ¿Solo editor? | Qué bloquea |
|---|---|---|---|---|
| **Criatura (cambiar números)** | Abrir `data/catalog/game_catalog.tres` → `creatures` (Array de 71 sin etiqueta, solo índice) → buscar a mano | 1 (346 KB) | Sí, pero penoso | **Editar `data/catalog/creatures/<tag>.tres` no hace nada** (no está referenciado). `catalog_cases` falla con cualquier cambio |
| **Criatura nueva** | `.tres` CreatureType + meterlo en `GameCatalog.creatures` + agregar el tag a `books[god].creatures` y `books[god].levels` (Dictionary anidado) + modelo `.glb` + correr `bake_body_scenes.gd` (CLI) + `BodySize` en `body_sizes` | 4–6 + CLI | No | Diccionarios de animación en `CreatureType` (`stance_animation`, `melee_animations: Array[Dictionary]`…, `creature_type.gd:33-77`) que solo una herramienta llena; `books` sin tipo |
| **Hechizo (efecto nuevo)** | Constante + `IMPLEMENTED` + ramas `if spell.tag ==` en `caster.gd` (l. 18-25, 297-303, 364-373, 450-471) + `spawn_<x>` y `match kind` en `spell_spawner.gd:20-66` + script de proyectil sin `.tscn` | 3–4 `.gd` | No | Tags en código. **Ya existe el patrón correcto**: `SpellAction` hijo de `wizard_body.tscn/Actions` (5 acciones: manalith, convert, desecrate, guardian, teleport). Los 7 hechizos de combate no lo usan |
| **Mago** | `WizardType.tres` + catálogo + `bake_body_scenes` + `sacrifice_flow.gd:11` (pick por defecto `"cwa0"`, `"jnwr"`) | 3 + CLI | Casi | El mismo problema del catálogo |
| **Dios/bioma** | `GODS` repetido en `game_data.gd:11`, `theme_applier.gd:7`, `look_rig.gd:14` y `@export_enum` en `look_rig.gd:17`; `data/themes/<god>.tres`, `data/look/<god>.tres`, `data/fx/cast_<god>.tres`, `data/ai/profile_<god>.tres`, `books[<god>]` | 3 `.gd` + 5 `.tres` | No | No hay `GodType.tres` que junte tema, look, partícula de lanzamiento, perfil de IA y libro |
| **Edificio** | Nodo `map_building.tscn` en `high_noon_layout.tscn` con `tag` (String) + `BuildingType` en el catálogo | 1–2 | Sí, con trampas | `tag` se escribe a mano (`map_building.gd:19`); **la rotación es `facing_deg` y pisa el gizmo** (`map_building.gd:63-65`; 69 edificios con `facing_deg`, transform identidad); no es `@tool`, así que no se ve rotado |
| **Mapa** | Duplicar `high_noon.tscn` (64 nodos, con sistemas y HUD), crear un layout, terreno glb, `sides.tres`, nav horneado, luz | 6+ y código | No | Rutas `HIGH_NOON_*` en 6 scripts (ver §3.8); `bake_nav.gd` y `bake_map_layout.gd` apuntan a High Noon |
| **NPC** | Nodo `npc_spawn.tscn` en el layout con `tag` y `side` (`npc_spawn.gd:10-19`) | 1 | Sí | `tag` como texto; `side` es un número SIDS, no un slot |
| **Habilidad** | Escena bajo `scenes/world/units/abilities/` + entrada en `data/abilities/ability_catalog.tres` | 2 | **Sí** (si el efecto existe) | Bien resuelto: es el modelo a copiar |
| **FX (partícula)** | `.tres` en `data/fx/` (60) y `FxBus.play("nombre")` desde código | 1 + código | A medias | El disparo se hace por nombre en código (71 llamadas `FxBus.`); en el dato no hay un socket «fx de muerte/impacto» |
| **Sonido** | — | — | **No existe** | 0 `AudioStream` en `scenes/`, no hay `default_bus_layout`, 0 archivos de audio. PRD l. 21 lo deja fuera de alcance |
| **Pantalla de UI** | `.tscn` nuevo + ruta en `sacrifice_flow.gd:15-38` (constantes) | 2 | Casi | No hay `Theme`: 133 `theme_override` sueltos en `.tscn`; los textos están fijos en español |

### 3.2 Estructura de escenas

- **Nodos armados en código: pocos.** Son 21 `X.new()` de nodos del motor: 9 `MeshInstance3D`, 3 `Node3D`, 2 `SubViewport`, entre otros, y casi todos son mallas generadas (pasto, terreno, marcadores). Los casos que importan son los **proyectiles de hechizo**, que son `script.new()` sin `.tscn`: `spell_spawner.gd:56-62` (`_WRATH`, `_FIREBALL`, `_SWARM`, `_ROCK`), `shot_spawner.gd:51`, y `caster.gd:453,488` (`HealEffect`, `SpeedupEffect`). Ninguno se puede abrir ni tunear en el editor.
- **`owner = null`:** queda 1 sola línea. RFC-036g resolvió los modelos: hay 73 escenas `scenes/bodies/models/<tag>.tscn` y `BodyRig` es `@tool` con preview.
- **`@tool`:** está en 104 de 398 scripts y `_get_configuration_warnings` en 69, concentrados en `sacrifice/`, `fx/`, `look/` y `minimap/`. **Ninguno de los 7 archivos más grandes de gameplay es `@tool` ni avisa nada** (`unit_body`, `wizard_body`, `caster`, `match_command`, `ai_perception`). Por ejemplo, `Caster` necesita `spellbook`, `summoner` y `actions` (`caster.gd:52-55`) y no avisa si faltan.
- **Escenas de un solo nodo:** hay 86. La mayoría son componentes lógicos (abilities, impacts, death_clouds) y está bien. No hay escenas de producto que abran rotas a la vista.
- **`%Unique` contra paths:** hay 515 `unique_name_in_owner` y 421 usos de `%`; esto está bien. Hay 241 `get_node("…")`/`get_node_or_null` y 29 `$` (4 archivos). El patrón malo es buscar un componente por nombre **desde otro nodo**: `get_node_or_null("Health")` ×44, `"Collision"` ×15, `"ManaPool"` ×13, `"SoulPurse"` ×10.
- **Herencia y variantes:** en el producto hay solo 6 escenas heredadas; en `debug/` hay 65, y ahí se usa bien. **No hay variantes por criatura**: las 71 usan `unit.tscn`, con los 30 componentes en todas, y cada componente se prende comparando un tag (`fire_shield.gd:24 passive_tag := "rifl"`). Es una decisión válida para replicar por tag. El costo es que el diseñador no ve en el árbol qué tiene cada criatura.
- **`high_noon.tscn` como god-scene:** mezcla Sky, Look, Terrain, el layout y MapProps (mapa) con Wizards, UnitSpawner, SoulSystem, SacrificeSystem, Match, Nav, Vision, Selection, MatchCommand y AiRoster (partida), además de Hud con 13 hijos y PauseMenu (UI). Para un segundo mapa hay que copiarla entera.

### 3.3 Datos y Resources

- **Dato duplicado, crítico:** `game_catalog.tres` tiene 599 `sub_resource` y solo 7 `ext_resource`, todos scripts. Comparé 124 entradas de criaturas y hechizos: son idénticas a los archivos sueltos. `bake_catalog.gd:83` guarda con `FLAG_CHANGE_PATH` y el comentario dice «so the catalog references it», pero el resultado guardado no los referencia. Además, `tools/bake_body_scenes.gd:20-21` lee los archivos sueltos y el juego lee los embebidos. Hay también 2 archivos con sufijo por mayúsculas (`EHTH_2.tres`, `RAMH_2.tres`).
- **Hay una tercera fuente:** `assets/original/data/*.json` (6 archivos) sigue en el repo como entrada de `bake_catalog`. Correr `--force` borra todas las ediciones.
- **JSON en runtime:** queda uno, `original_material.gd:83-90`, que lee `textures/index.json` para elegir el material por modelo y etiqueta. El resto (`room_server`, `match_ticket_glue`) es `JSON.stringify` para logs, y eso está bien.
- **Referencias por texto en el inspector:** hay 88 `@export var …tag/model/god/kind… : String`, por ejemplo `unit_body.gd:35 creature_tag := "ycro"`, `structure_body.gd:14,19`, `doctor_body.gd:30`, `player_start.gd:25`, `spike_field.gd:25`, `beam_type.gd:14`. Un typo solo aparece en runtime. Tiene una razón (el tag es lo que se replica), pero el inspector podría ofrecer un `CreatureType` y derivar el tag.
- **Dictionaries que edita un humano:** `GameCatalog.books` (god → {creatures, spells, structures, levels}), 9 diccionarios de animación en `CreatureType`, `AbilityType.args` (`{"fMFt":0.4,…}`) y `CueSet.refusals` (texto → acción).
- **Constantes fijas:** hay 564 `const` de nivel superior en 172 archivos, por ejemplo `caster.gd` con 26 (`FPS := 60.0`, `HAND_HEIGHT := 0.65`, `MANA_EPSILON`). Además, 14 scripts repiten `static var TICKS := float(MatchClock.TICKS_PER_SECOND)` (`fire_shield`, `life_shield`, `lightning_charge`, `tumbling`, `oiled`, `halo_of_earth`, …).
- **Usabilidad del inspector:** es buena donde se trabajó. Hay 1 915 `@export` en 275 archivos, 268 `@export_range` y 119 `@export_group` (48 archivos). `MatchRules` tiene 80 knobs en grupos en español. Faltan: **0 `@icon`** en las 326 clases, **72 scripts sin `class_name`** y docs `##` en los catálogos que citan `sacobject.d:424` en vez de explicar el efecto en juego. Hay 1 140 referencias a sacengine en 238 archivos; son útiles para el porteo y ruido para el diseñador.

### 3.4 Arquitectura de código

- **God-files (producto):**

| Archivo | Líneas | `func` | `.call`/`has_method` | Responsabilidades mezcladas |
|---|---|---|---|---|
| `scenes/world/match_command.gd` | 795 | 59 | 30 | atajos, selección por clic, armado de hechizo, estructura, habilidad, órdenes, minimapa, raycasts, textos `ORDER_TEXT` (l. 20-27) |
| `scenes/look/grass/grass_field.gd` | 740 | 48 | 6 | pasto (diferido al final por decisión del usuario) |
| `scenes/world/unit_body.gd` | 720 | 69 | 29 | física, setup de 15 componentes por `$X.call("setup")` (l. 208-222, 469-491), modo replicado `enum Mode` (l. 30) **además** de los 11 `FsmState` |
| `scenes/world/ai/perception/ai_perception.gd` | 701 | 47 | 8 | percepción de la IA (regla; queda) |
| `scenes/world/spells/caster.gd` | 647 | 45 | 40 | validación, cobro, 7 hechizos fijos, spawn de efectos |
| `scenes/world/wizard/wizard_body.gd` | 547 | 45 | 39 | — |
| `scenes/world/sacrifice/sacrifice_system.gd` | 489 | 34 | 2 | (bien: `@tool` y warnings) |

- **Cadenas en lugar de tipos:** `.call("is_dead")` ×32, `"is_targetable"` ×17, `"setup"` ×15, `"facing_flat"` ×15 y `"display_name"` ×15. `caster.gd:91-116` hace `spellbook.call("spell_at", index)` porque `spellbook.gd` no tiene `class_name` y el socket es `@export var spellbook: Node`. GDScript 4.7 admite referencias cíclicas entre `class_name`, así que ya no hay motivo técnico.
- **Service locator por grupos:** hay 36 `get_first_node_in_group` con texto suelto (`"spell_spawner"` ×4 en `caster.gd:497-566`, `"shot_spawner"` ×7 en abilities, `"match_state"`). No hay constantes para los nombres de grupo.
- **Señales:** 116 declaradas, 132 `emit` y 279 `connect`. Están razonablemente en pasado (`feedback`, `held_changed`, `result_changed`).
- **Autoloads (7):** `MpKit`, `MpLobby` y `AgentKit` vienen del addon y está bien. `SacrificeFlow` (296 líneas) es el flujo y la elección local, y está bien. `GameData` es catálogo y libros; aceptable, pero podría ser un `static` de `GameCatalog`. `FxBus` (281 líneas) es un pool de partículas; aceptable. **`BodyLibrary` es una fachada legacy de 24 líneas**: su propio doc dice que el código nuevo usa `BodyCatalog`, y tiene 22 usos.
- **Estado estático:** `side_relations.gd:20-23` (bandos del mapa), `match_seed.gd:14`, `match_clock.gd:14-15`, `map_building.gd:46-48`, `body_catalog.gd:16-21`. Un proceso por partida lo tolera; dos mundos en el mismo proceso, no (un editor con preview, o tests en paralelo).
- **Debug y banco en producto:** `DebugLog` aparece 88 veces en 43 archivos; está bien (un solo interruptor). Pero quedan **210 `print(` en `scenes/`**, 46 de ellos en español (`high_noon.gd:23 "en high noon slot"`, `l. 29 "mundo listo"`). Hay chequeos `get_first_node_in_group("walk_order")` de una escena de debug dentro de `match_command.gd:107,547` y `order_radial.gd:54`, y acciones de debug en el InputMap (`check_tick`, `debug_anim_cycle`, `fx_*` ×5). **`debug/*` no está en `exclude_filter`** (`export_presets.cfg:11`), así que las 140 escenas de debug viajan en el export.
- **Código muerto:** el barrido de scripts sin referencia dio solo `scenes/world/terrain_probe.gd` (29) y `scenes/bodies/obj_mesh.gd` (217). Hay poco código muerto, y eso es bueno.
- **Carpetas:** `scenes/world/` tiene 34 scripts sueltos en la raíz (`body_*`, `match_*`, `orders.gd`, `selection.gd`, `sky.gd`…) junto a subcarpetas temáticas. `scenes/data/` guarda Resources de tipo, pero se llama igual que `data/` (instancias).

### 3.5 Descubribilidad y docs

- README: `../README.md` (159 líneas, buena entrada: clonar, controles, estructura y pruebas) y 6 más en `addons/*`, `assets/original`, `assets/mm` y `tools/deploy`. **No hay ninguno en `scenes/`, `scenes/world/`, `data/`, `data/catalog/`, `debug/`, `agent/` ni `tools/`.**
- No existe ninguna guía «cómo agregar X». El conocimiento está en los comentarios `##` y en las F. Lo más cercano es el doc de `ability_catalog.gd:7` («A new ability is a new entry here…»).
- **FEATURES.md es un registro.** Tiene 3 129 líneas: el inventario real (Must/Should/Won't) ocupa las líneas 1-278 y el resto son 201 entradas F cronológicas, fuera de orden (F185 aparece después de F223, l. 3056-3117). Tiene 26 RFC y 13 planes/investigaciones. Sirve para auditar, no para aprender.
- **Mezcla de idiomas:** código y `##` en inglés (bien, según RULES). La UI está en español (bien). Pero **101 de 118 `_get_configuration_warnings` están en español** y algunos `push_warning` en inglés (`structure_body.gd:61`), mientras que `map_building.gd:68` está en español. Los `print` están mezclados. Conviene elegir una regla: los warnings del editor en español, para el diseñador, y los logs en inglés.

### 3.6 Herramientas y pipeline

| Horneado | Entrada | Salida | Cuándo re-correr | ¿Avisa si quedó viejo? |
|---|---|---|---|---|
| `tools/bake_catalog.gd` | `assets/original/data/*.json` | `data/catalog/**` | Nunca más (o `--force`, que borra ediciones) | No |
| `tools/bake_body_scenes.gd` | `index.json` + **`data/catalog/creatures/*.tres` (los huérfanos)** | 73 `body/models/*.tscn` | Al cambiar un clip o un modelo; **pisa las ediciones a mano** (l. 4-5) | No |
| `tools/bake_map_layout.gd` | `ntts.json`, `widgets.json` | `high_noon_layout.tscn`, `sides.tres` | Nunca más (`--check` compara) | No |
| `tools/bake_nav.tscn` | nodos `nav_source` + `nav_bake.tres` | `data/nav/high_noon_nav.res` | Al mover un edificio o el terreno | **Sí**: `map_nav_region.gd:14-22` (hash) |
| `tools/terrain_glb_export.gd` / `terrain_import.gd` | `terrain.res`/bin | `terrain.glb` / `terrain.res` | Una vez; después se edita en Blender | No |
| Minimapa (`MinimapBake` en `high_noon.tscn`) | terreno | textura | — | No verificado |

- La importación desde los WAD se hace con 13 scripts Python (`import_*.py`, `export_*.py`, `fx_catalog.py`…). Ya no la necesita quien edita, porque `assets/original/` está versionado en LFS (RULES §Datos), pero no hay README en `tools/` que diga qué es pasado (porteo) y qué es presente (horneado).
- **No hay `EditorPlugin` propio.** Hay un solo `@export_tool_button` (`look_rig.gd:18`, «Vista previa del bioma»). Candidatos a botón: «Re-hornear navmesh» en `MapNavRegion`, «Re-hornear escena de modelo» en `BodyModel`, «Validar catálogo» en `GameCatalog` y «Aplicar `facing_deg`» en `MapBuilding`.

### 3.7 Pruebas y red de seguridad

- **Cómo prueba un humano:** el README (l. 140-148) da 2 comandos, `agent/run_determinism.sh quick` y `debug/rules_suite.tscn` (16 suites, `rules_suite.gd:5-21`). Hay además 62 `agent/run_*.sh` con nombres como `run_f79_net.sh` o `run_pt113.sh`, sin índice, y 3,2 GB en `agent/out` (sin versionar, bien).
- **Qué se rompe si un diseñador edita un `.tres`:**
  - (a) En el catálogo suelto: nada, y ese es justamente el problema.
  - (b) En `game_catalog.tres`: falla `catalog_cases.gd` («every type equals the one built from the original JSON») y se mueven los digests de `quick`. RULES permite regrabar, pero el diseñador no sabe que tiene que hacerlo.
  - (c) Un `ability_tags` o un `books[*].creatures` que apunte a un tag que no existe: nadie lo valida, y falla en silencio en runtime.
- **Warnings en el editor:** hay 69 scripts con avisos (bien). Faltan en los sockets críticos de `Caster`, `UnitBody`, `WizardBody` y `MatchCommand`, y en los tags por texto. Por ejemplo, `body_visual.gd:94` sí avisa por un modelo sin `BodySize`, y ese es el patrón a copiar.

### 3.8 Escalabilidad

- **Segundo mapa:** está bloqueado por 6 rutas fijas: `original_assets.gd:23-26`, `side_relations.gd:17`, `ground_material.gd:10`, `nav_service.gd:19` (`DEFAULT_NAVMESH`), `terrain.gd:9,105-107` y `sacrifice_room_rules.gd:10` (`WORLDS = ["high_noon"]`). Hay que duplicar `high_noon.tscn` con sus sistemas y su HUD. `OriginalAssets.map(map_name, file)` ya existe (l. 88) y sirve de base.
- **2v2:** `SideRelations` usa `slot = side + 1` (l. 6-9): Farmers = 3 y Taurocks = 4. Esos son justo los slots que tomarían los jugadores 3 y 4. `sacrifice_flow.gd:45` tiene `max_players = 2`, y `local_server_host.gd:18-19` tiene `HOST_SLOT/RIVAL_SLOT`. `wizard_spawner.gd:87` reparte con `starts[(slot-1) % size]`, lo cual sirve. Hace falta separar «asiento de jugador» de «bando del mapa».
- **Modos de juego:** no hay ningún `GameMode`. La victoria vive en `MatchState`/`DefeatRule`. PRD l. 21 deja fuera `slaughter`, `domination` y `soul-harvest`. Para que escale: `MatchRules.mode: GameMode` (un Resource con su regla de derrota).
- **Localización:** tiene 0 `tr()`, no hay CSV ni `.po`, ni `internationalization/locale` en `project.godot`. Son 241 literales en 98 scripts y 85 `text =` en `.tscn`. **Peor:** el texto de pantalla es identificador. `spell_action.gd:16-21` (`NO_MANA := "Sin maná"`…) se compara en `spell_action.gd:91`, `command_cues.tres` usa el texto como clave, y `match_command.gd:98,353,415` compara con `display_name`. Traducir rompería la lógica.
- **Guardado y ajustes:** `user_settings.gd` (ConfigFile en `user://settings.cfg`, con sandbox para AgentKit) está bien. No hay remapeo de teclas en Opciones, aunque el InputMap ya es semántico (79 acciones). No hay partidas guardadas, ni hacen falta en un RTS de escaramuza.

---

## 4. Backlog priorizado

Tamaño: S < 150 líneas tocadas, M 150–600, L > 600. Riesgo: chance de mover gameplay o digests.

### Fase 0 — Quick wins (1–2 días, sin cambio de comportamiento)

| ID | Título | Valor para un humano | Riesgo | Tam. | Depende |
|---|---|---|---|---|---|
| EF-01 | **Catálogo con referencias reales**: re-guardar `game_catalog.tres` con `ext_resource` a los 599 `.tres` sueltos (o borrar los sueltos y dejar uno solo); `bake_body_scenes` lee del mismo lugar | Editar `creatures/<tag>.tres` cambia el juego. Sin esto, todo lo demás es mentira | Bajo (mismos valores; `quick` igual) | S | — |
| EF-02 | `catalog_cases` pasa de «.tres == JSON» a «el catálogo es válido»: tags referenciados existen (abilities, books, `ranged_attack_tag`, `passive_*`), rangos sanos, `BodySize` presente | Un diseñador corre un comando y ve qué rompió | Bajo | S | EF-01 |
| EF-03 | `MapBuilding`/`NpcSpawn` `@tool`, con `facing_deg` aplicado en el editor (o migrado a la rotación del transform y `facing_deg` borrado) | El editor muestra el mapa real; el gizmo funciona | Medio (rotación de 69 edificios; nav) | S | — |
| EF-04 | `debug/*` al `exclude_filter`; acciones `check_tick`, `debug_anim_cycle` y `fx_*` fuera del InputMap del producto (o con prefijo `debug_`); chequeo `walk_order` reemplazado por `WorldInput` | Producto limpio; menos ruido en Project Settings | Bajo | S | — |
| EF-05 | `class_name` en `spellbook.gd`, `summoner.gd`, `caster.gd` (y los 72 sin nombre que sean socket); sockets tipados; `$X.call("setup")` → `$X.setup()` | Autocompletado, errores en el editor, «ir a definición» | Bajo | M | — |
| EF-06 | Borrar `BodyLibrary` (autoload fachada), `terrain_probe.gd`, `obj_mesh.gd`; `TICKS` estático repetido ×14 → `MatchClock.TICKS_PER_SECOND` directo | Menos piezas que entender | Bajo | S | — |
| EF-07 | `@icon` para los Resources de tipo (`CreatureType`, `SpellType`, `AbilityType`, `WizardType`, `BuildingType`, `MatchRules`, `ParticleType`) | Se distinguen en el FileSystem y el inspector | Nulo | S | — |

### Fase 1 — Autoría de contenido (el núcleo del pedido)

| ID | Título | Valor | Riesgo | Tam. | Depende |
|---|---|---|---|---|---|
| EF-10 | **Hechizos como `SpellAction`**: los 7 de `caster.gd` (pups, laeh, kcor, oalf, brif, ntil, mrws) pasan a hijos `Actions/*` como ya hacen Manalith y Teleport; `IMPLEMENTED` desaparece (un hechizo está implementado si tiene acción) | Un hechizo nuevo es una escena + un `.tres`, no 4 scripts | Medio (combate) | L | EF-05 |
| EF-11 | **Proyectiles como `.tscn`**: `rock`, `wrath`, `fireball`, `swarm`, `shot`, `heal_effect`, `speedup_effect`; `SpellSpawner` con `@export var scenes: Dictionary[StringName, PackedScene]` en vez del `match kind` | Tunear un proyectil en el inspector | Medio | M | EF-10 |
| EF-12 | **`GodType.tres`**: tema, look, `cast_<god>` FX, perfil IA, libro (creatures/spells/structures con nivel, como `Array[BookEntry]` tipado); `GODS` ×4 y `books` Dictionary desaparecen | Un dios nuevo es un `.tres`; el libro se edita con listas | Medio | M | EF-01 |
| EF-13 | Referencias tipadas en el inspector: `@export var creature: CreatureType` en `UnitBody`/`DoctorBody`/`PlayerStart`/`NpcSpawn`, `building: BuildingType` en `MapBuilding`; el `tag` replicado se deriva | Sin typos; arrastrar y soltar | Medio (red: el tag sigue en el cable) | M | EF-01 |
| EF-14 | `CreatureType`: los 9 Dictionaries de animación salen a la escena del modelo (ya existe `models/<tag>.tscn`) o a un `CreatureClips.tres`; el `CreatureType` queda en números de juego | La ficha de criatura se lee en una pantalla | Medio | M | EF-01 |
| EF-15 | Botones `@export_tool_button` y avisos de dato viejo: «Hornear navmesh» (`MapNavRegion`), «Re-hornear modelo» (`BodyModel`, con advertencia de que pisa), «Validar» (`GameCatalog`, llama a EF-02) | No hace falta la terminal para el día a día | Bajo | M | EF-02 |

### Fase 2 — Estructura y escala

| ID | Título | Valor | Riesgo | Tam. | Depende |
|---|---|---|---|---|---|
| EF-20 | **Partir `high_noon.tscn`** en `match.tscn` (sistemas + HUD + PauseMenu) y `maps/high_noon/map.tscn` (Sky, Look, Terrain, Layout, MapProps, NavRegion); un `MapDefinition.tres` (escena, navmesh, sides, luz, tiles, biome por defecto) | Un mapa nuevo = carpeta + `.tres`; la partida se reusa | Alto (orden de `_ready`, red, flows) | L | EF-03 |
| EF-21 | Las 6 rutas `HIGH_NOON_*` leen del `MapDefinition` activo; `sacrifice_room_rules.WORLDS` lista `MapDefinition`s | Segundo mapa sin tocar código | Medio | M | EF-20 |
| EF-22 | **Texto fuera del protocolo**: `SpellAction`/`Caster` devuelven `StringName` de razón (`&"no_mana"`); `CueSet.refusals` se indexa por razón; `MatchCommand` compara por tag, no por `display_name`; un `ui_strings.gd`/CSV traduce | Habilita la localización; borra una clase de bugs | Medio | M | — |
| EF-23 | `tr()` + `translations/ui.csv` (es) para los 241 literales y 85 `text =` | Traducible; textos en un solo lugar | Bajo | M | EF-22 |
| EF-24 | `Health.of(body)` / `ManaPool.of(body)` estáticos tipados (44 + 13 lookups por nombre); constantes para los grupos de servicio (`Groups.SPELL_SPAWNER`) o sockets `@export` desde el mundo | Renombrar un nodo no rompe 44 archivos en silencio | Bajo | M | EF-05 |
| EF-25 | Partir `match_command.gd` (795): `HotkeyInput` (atajos), `ClickTargeting` (raycast y picking), `ArmedAction` (hechizo/estructura/habilidad armada); `MatchCommand` solo orquesta | Entender una sola cosa por archivo | Medio | M | EF-22 |
| EF-26 | `UnitBody`: retirar `enum Mode` como fuente doble (el `FsmState` activo es la verdad; un `StringName` replicado reemplaza el enum) | Agregar un estado = agregar un nodo | Alto | L | — |
| EF-27 | Bandos del mapa separados de los asientos: `MapSides` declara NPC sides; `SeatTable` mapea asiento → bando | Base para 2v2 | Alto | M | EF-21 |
| EF-28 | `Theme.tres` del juego (fuentes, StyleBox) en lugar de 133 `theme_override` | Restyling global de la UI | Bajo | M | — |

### Fase 3 — Docs y proceso

| ID | Título | Valor | Riesgo | Tam. | Depende |
|---|---|---|---|---|---|
| EF-30 | `docs/how-to/` en español: agregar criatura, hechizo, habilidad, mago, dios, edificio, NPC, FX, pantalla, mapa (cada guía ≤ 1 página, con archivos y capturas) | El «cómo» deja de vivir en las F | Nulo | M | EF-10…EF-21 (se escribe al cerrar cada una) |
| EF-31 | README por carpeta: `scenes/world/`, `scenes/ui/`, `data/`, `data/catalog/`, `debug/`, `agent/`, `tools/` (qué hay, qué no tocar, qué está horneado) | Orientación en 2 minutos | Nulo | S | — |
| EF-32 | FEATURES.md partido: `FEATURES.md` (Must/Should/Won't + estado, ≤ 300 líneas) y `CHANGELOG.md`/`features/log/` (las 201 F, ordenadas) | Doc usable | Nulo | S | — |
| EF-33 | `agent/README.md` + `agent/run.sh <suite>` con un índice de las 62 corridas; archivar las de RFC cerrados | Un humano sabe qué correr | Bajo | S | — |
| EF-34 | Regla de idioma en RULES: warnings del editor en español, `print`/`push_error` en inglés y por `DebugLog`; los 210 `print` de `scenes/` pasan a `DebugLog` o se borran | Salida limpia | Bajo | M | — |
| EF-35 | Reordenar `scenes/world/` raíz (34 scripts sueltos) en subcarpetas (`camera/`, `selection/`, `match/`, `map/`); renombrar `scenes/data/` → `scenes/types/` (o `scenes/data_types/`) | Encontrar por intuición | Medio (paths, uids) | M | Al final, con el editor abierto (Godot mueve los uid) |

---

## 5. RFCs propuestos

| RFC | Título | Items | Cortes sugeridos |
|---|---|---|---|
| **RFC-040** | Catálogo único y validado | EF-01, EF-02, EF-07, EF-15 (botón Validar) | 040a referencias reales (`quick` igual) · 040b validador · 040c iconos y botón |
| **RFC-041** | Hechizos y proyectiles como escenas | EF-10, EF-11, EF-05 | 041a `class_name` y sockets · 041b-h un hechizo por corte (empezar por `pups`, el más simple) · 041i proyectiles `.tscn` + spawner por diccionario |
| **RFC-042** | Dioses y libros como Resources | EF-12, EF-14 | 042a `GodType` + `BookEntry` · 042b ficha de criatura sin animación |
| **RFC-043** | El editor muestra el mapa real | EF-03, EF-13, EF-15 (nav) | 043a rotación WYSIWYG + re-hornear nav · 043b referencias tipadas |
| **RFC-044** | Mapa y Partida separados (`MapDefinition`) | EF-20, EF-21, EF-27 | 044a partir la escena (mismo mapa) · 044b `MapDefinition` · 044c asientos vs bandos · 044d mapa de prueba vacío como segundo mapa |
| **RFC-045** | Textos traducibles | EF-22, EF-23, EF-28 | 045a razones por `StringName` · 045b `tr()` + CSV · 045c `Theme` |
| **RFC-046** | Higiene y descubribilidad | EF-04, EF-06, EF-24, EF-25, EF-30…EF-35 | cortes S independientes; las guías al cerrar cada RFC de arriba |
| (RFC-047) | `UnitBody` sin `enum Mode` | EF-26 | solo con OK del usuario; después de la v1 si el banco lo hace caro |

Orden recomendado: 040 → 043 → 041 → 042 → 045 → 044 → 046 (046 en paralelo a ratos). RFC-039 (web) no choca con nada de esto, salvo 044, que conviene hacer antes de achicar texturas por mapa.

---

## 6. Qué NO cambiar (y por qué)

- **La composición de `unit.tscn`** (30 componentes + `Afflictions` + `States`) y el patrón `AbilityCatalog`: ya son lo que pide la skill. Son el modelo a copiar para los hechizos.
- **Un solo `unit.tscn` para las 71 criaturas, con tag replicado:** crear 71 escenas heredadas multiplica el mantenimiento y complica `MultiplayerSpawner`. La editabilidad sale de EF-13/EF-14, no de las variantes.
- **El tag de 4 letras en el cable** (`creature_tag`, `spell_tag`): es barato de replicar y estable. Se cambia el inspector, no el protocolo.
- **`MatchSeed`, `MatchClock` y su estado estático:** es lo que hace reproducible una partida con IA (RULES §IA) y hay un proceso por partida (RULES §Red). Se revisa solo si llega un test o un editor con dos mundos.
- **`ai_perception.gd` (701), `side_vision.gd`:** son reglas de juego (RFC-036 A17), no motor. Partirlos no le sirve al diseñador.
- **`grass_field.gd` (740):** el pasto está diferido al final por decisión del usuario. No se toca hasta entonces.
- **`addons/mp_kit`, `agent_kit`, `fsm_kit`:** son kit genérico (RULES §Red). Nada de esto entra ahí.
- **`assets/original/` en LFS, y los `.py` de importación:** son el pasado del porteo y sirven para regenerar. Se documentan en EF-31, no se borran.
- **El banco de determinismo:** RULES §Fidelidad ya lo bajó a prueba de humo. Lo único que cambia es `catalog_cases` (EF-02), para que deje de castigar el balance.
- **`CPUParticles3D` y `FxBus` como pool:** decisión ya razonada en RFC-036 §3.
- **Los textos en español en pantalla:** RULES §Idioma. EF-23 los mueve a un CSV `es`, no los traduce.
