# 055R: legibilidad medida del codebase y convenciones propuestas

Informe del tech lead, 2026-10-23. Medido con `wc`, `grep` y `find` sobre `game/scenes/` (480 `.gd`, 53 033 líneas). Los addons suman aparte 51 `.gd` y 7 624 líneas. Rutas relativas a `game/`.

## 1. Medición

| Métrica | Valor |
|---|---|
| Scripts >500 / >300 / >150 líneas | 5 / 25 / 114 (366 miden 150 o menos: 76 %) |
| Autoloads | 7: `MpKit`, `MpLobby`, `AgentKit` (addons); `GameData`, `SacrificeFlow` (424), `FxBus` (309), `SoundBus` (450) |
| `class_name` por base | Node 103 · Resource 70 · RefCounted 66 · Node3D 40 · base propia 104 · sin `class_name` 54 |
| Herencia propia de profundidad 2 | 5 casos, todos `*_action.gd → AimedAction → SpellAction` |
| `@export` en `scenes/units` | 613 en 133 scripts (4,6 promedio); `creature_type.gd` 44, `unit_body.gd` 23 |
| `@export` String que son referencias (`tag`, `kind`, `god`, `model`) | 67 |
| Encabezado `##` que abre citando RFC/F, sacengine o WAD | 376 de 479 (78 %) |
| Citas a sacengine | 1 439 líneas en 280 de 480 archivos; 844 citas `RFC-`/`F###`; 280 palabras del WAD |
| `print(` en producto | 232 en 107 archivos (frente a 98 `DebugLog`) |

### 1.1 Los 25 scripts más grandes

| Líneas | Script | Qué hace |
|---|---|---|
| 750 | `scenes/units/unit_body.gd` | Criatura: física, modo, combate, habilidades, formas especiales, clips (12 responsabilidades) |
| 698 | `scenes/ai/perception/ai_perception.gd` | Lo que sabe un bando de la IA |
| 679 | `scenes/look/grass/grass_field.gd` | Pasto (diferido) |
| 547 | `scenes/wizards/wizard_body.gd` | Mago: input, caminar, altar, fantasma, pose |
| 545 | `scenes/look/vegetation/mesh_planter.gd` | Flora en anillos de celdas |
| 492 | `scenes/sacrifice/sacrifice_system.gd` | Puerta de los rituales |
| 475 | `scenes/ai/ai_audit.gd` | Registro del banco dentro del producto |
| 462 | `scenes/map/terrain/terrain.gd` | Terreno: malla, normales, índice, alturas, material, colisión |
| 450 | `scenes/audio/sound_bus.gd` | Autoload de sonido |
| 450 | `scenes/ai/brains/wizard_brain.gd` | Cerebro del mago IA |
| 449 | `scenes/spells/caster.gd` | Valida, cobra, RPC, línea de tiempo y FX |
| 424 | `scenes/core/flow/sacrifice_flow.gd` | Flujo de boot y sala |
| 406 | `scenes/sacrifice/doctor_body.gd` | Sac Doctor |
| 400 | `scenes/units/abilities/halo_of_earth.gd` | Una habilidad |
| 381 | `scenes/ai/command/ai_command_port.gd` | Puerto de órdenes de la IA |
| 378 | `scenes/souls/soul.gd` | Alma |
| 370 | `scenes/orders/selection.gd` | Selección y grupos |
| 370 | `scenes/match/match_state.gd` | Altares, derrota, ganador |
| 366 | `scenes/ui/radial/radial_menu.gd` | Menú radial |
| 360 | `scenes/map/nav/nav_service.gd` | Pathfinder |
| 356 | `scenes/net/match_ticket_glue.gd` | Lado Sacrifice del dedicado |
| 336 | `scenes/units/attacks/ranged_attack.gd` | Disparo |
| 317 | `scenes/orders/orders.gd` | Órdenes RTS |
| 311 | `scenes/sacrifice/ritual.gd` | Ritual en curso |
| 309 | `scenes/fx/fx_bus.gd` | Pool de partículas |

### 1.2 Citas al original por dominio (citas por 100 líneas)

units 4,9 · match 4,8 · ai 4,5 · souls 4,1 · wizards 4,0 · fx 3,4 · spells 3,1 · sacrifice 2,9 · orders 1,9 · ui 1,0 · map 0,5 · look/audio/net/core ≈0,2. Lo escrito «como persona» casi no cita; lo portado cita una vez cada 20 líneas.

### 1.3 Acoplamiento

| Patrón | Líneas / archivos |
|---|---|
| `signal` / `.emit(` / `.connect(` | 134 / 151 / 341 |
| `get_node("Nombre")` hacia otro nodo | 229 / 106 (`"Health"` ×73, `"Collision"` ×15, `"ManaPool"` ×13) |
| `get_first_node_in_group` / `get_nodes_in_group` | 35 / 92 (`"wizard"` ×21, `"unit"` ×14) |
| `get_parent()` | 82 / 51 (los `../` son 2: bien) |
| `.call("…")` / `has_method(` | 56 / 46 |
| `MpKit.` | 206 / 98 (la red en el 20 % del producto) |
| `is_server()` / `simulates()` | 120 |
| `submit_*` / `@rpc` | 8 / 16 (el wrapper está concentrado: bien) |

Unas 490 búsquedas de otro nodo por texto contra 341 conexiones de señal.

## 2. Tres recorridos de un recién llegado (el benchmark)

**(a) «Que una criatura vea 5 m más lejos»**: 1 archivo editado y 12 leídos. `unit.tscn` tiene 64 nodos y ninguno es la visión; `creature_tag = "ycro"` no dice que es el Trogg; `sight_range` se lee en 6 lugares con su propio fallback; la regla real vive en `targeting/side_vision.gd:175`. **Meta: 2** (`Vision` como `Area3D` en `unit.tscn` o `vision_m` en el `.tres`; los lectores preguntan `vision.can_see()`).

**(b) «Una variante de bola de fuego para Pyro»**: unos 13 archivos en 6 carpetas. `brif.tres` con `flags = 8213`, `flags1 = 16449` (de eso depende que la IA lo lance); `projectile_kind` de texto; dos maneras de enganchar la acción; lista de proyectiles en código y en escena; `pyro.tres` con dos listas; ícono, cue y FX por nombre; `ai_spell_eval.gd` con `match spell.tag`; herencia de 2 niveles. **Meta: 3** (`.tres` con campos con nombre, una escena heredada de proyectil, una fila en el libro).

**(c) «Mover un edificio 10 m en Peaks y verlo en el editor»**: 7 (2 editados, 2 horneados por CLI, 3 leídos). `PeaksLayout` es una instancia sin «Editable children»; `Bld008_car1` nombra el tag del WAD; `car1.tres` con `flags`, `folder`, `components`; `nav.res` se re-hornea por CLI; `flora.res` no esquiva edificios. **Meta: 2** (mover el nodo en `map.tscn` y botón «Hornear navmesh»).

## 3. God files y división propuesta (meta 150 líneas por script)

| Sistema | Hoy | División |
|---|---|---|
| `unit_body.gd` | 750, 12 responsabilidades | `UnitBody` ≈200 (raíz con 21 props replicadas: 150 no es realista) · `CreatureLink` 80 · `Locomotion` 150 (compartido con el mago) · `Vision` (`Area3D`) 80 · `Engagement` 120 · `AbilityUser` 60 · `SpecialForms` 100 · `Regeneration` 40 · `UnitClips` absorbe idle y debug |
| `wizard_body.gd` | 547 | `WizardBody` 180 · `WizardDrive` 100 · `Locomotion` · `AltarReturn` 60 · `WizardLook` 100 |
| `caster.gd` | 449 | `Caster` 150 · `CastRules` static 100 · `CastPort` 120 · `CastFx` 50 |
| Cielo y look | 41 gd / 4 699 líneas, 3 escritores del `Environment` | 055b |
| IA | 35 gd / 5 324, despacho por tag y `flags1` | `ai_audit.gd` a `debug/ai/` · `AiPerception` 250 + `ThreatRules` + `TrackTable` · despachar por `SpellType.ai_role`. Límite 300 en IA. |
| Mapa | `terrain.gd` 462 · `map_building.gd` 238 con caché de `Dictionary` · `BuildingType` crudo · `FloraMap` en bytes · `MapDefinition` con rutas de horneado | `TerrainShape` (RefCounted) 150 · `Terrain` 150 · `TerrainMaterial` 80 · `TerrainCollision` 50 · `MapBuilding` 120 · `BuildingType` humano · `MapSides` con `Array[SideRow]` |
| Pipeline de hechizos | texto → texto → `Dictionary` → `setup(Dictionary)` → FX por nombre → IA por tag | `SpellType.projectile: PackedScene`; `setup(launch: ProjectileLaunch)`; FX como `@export var burst: ParticleType` |
| Glue MpKit | 98 archivos | `Authority.simulates(node)` único; `MpKit` solo en `scenes/net/`, dueños de `submit_*` y spawners. Meta ≤15 archivos. |

## 4. Borrador de CONVENTIONS.md

### 4.1 Carpeta = sistema
```
scenes/<system>/
  README.md            10 lines: what · who talks to whom · how to add one · debug scene
  <system>.tscn        the composed scene (root = thin node)
  <system>.gd          ≤150 lines (root of a replicated actor: ≤200)
  <part>.gd/.tscn      one child component per responsibility
  <system>_rules.gd    static, RefCounted, no tree (testable)
  states/              only if ≥3 states (FsmKit)
data/<system>/*.tres   instances with human names (trogg.tres, not ycro.tres; the tag stays a field)
debug/<system>/        F6 scenes + .tres variants
```

### 4.2 Reglas

| # | Regla | Verificación |
|---|---|---|
| C1 | Script ≤150 líneas; >300 es error salvo allowlist con fecha | `wc -l` |
| C2 | Una clase, una responsabilidad: el `##` dice en una frase qué hace y qué no | Revisión |
| C3 | Nodos y clases sustantivos; métodos verbos; privado con `_`; señales en pasado | Revisión |
| C4 | Señales hacia arriba, llamadas hacia abajo; un hijo no nombra a su padre ni a sus hermanos | sin `get_parent()` fuera de `@tool` |
| C5 | Entre escenas `@export var health: Health` con warning; dentro `%UniqueName`; prohibido `get_node("Health")` desde otro nodo | lint |
| C6 | Servicios por `@export` o `const GROUP` en la clase dueña; prohibido `get_first_node_in_group("texto")` | lint |
| C7 | Prohibido `.call("…")` y `has_method(` sobre tipos con `class_name` | lint con ratchet |
| C8 | Resources con nombres humanos y unidad (`vision_m`, `cooldown_s`); prohibidos `flags*`, `folder`, `components: Array[Dictionary]`, referencias String cuando existe el tipo | lint en `*_type.gd` |
| C9 | Doc: primero qué pasa en el juego en palabras simples; la cita al original al final en `## Ref: state.d:…`, nunca abre | lint |
| C10 | FSM solo con ≥3 estados; command/interactor solo con ≥2 llamadores | Revisión |
| C11 | Herencia propia de profundidad ≤1 | lint por `extends` |
| C12 | `MpKit.` solo en la allowlist (`scenes/net/`, dueños de `submit_*`, spawners) | lint con ratchet |
| C13 | El producto no lee formatos del original (`assets/original/**/*.json`, `OriginalAssets.`, `res://tools`) | lint |
| C14 | Logs con `DebugLog`, sin `print(` en `scenes/` | lint |

### 4.3 Encabezado de sistema (README, ≤10 líneas)
```
# units/vision
What: a creature sees foes inside its Vision area; the side remembers them for `memory_s`.
Not: who to attack (Engagement), what the AI knows (AiPerception).
Talks to: Vision.seen(foe) ↑ UnitBody → Engagement; SideVision listens to every Vision.seen.
Edit: unit.tscn/Vision radius_m · data/creatures/<name>.tres vision_m.
Debug: debug/units/vision_range.tscn (F6).
```

### 4.4 Datos antes y después

`BuildingType` hoy: `flags = 2147491848`, `ground = true`, `tileset = "char"`, `folder = "joby.WAD!/ch_a.FLDR"`, `components = [{destroyed, facing, kind, spell, tag, x, y, z}]`. Después:
```gdscript
class_name BuildingType extends Resource
## A building on the map: how it looks, how hard it is to destroy, who hides in it.
@export var display_name := "Casa"
@export_range(0, 20000) var max_health := 0        ## 0 = cannot be destroyed
@export var shelters_peasants := false
@export var flattens_ground := false
@export var scene: PackedScene                       ## the parts as child nodes, placed with the gizmo
@export var ruin_scene: PackedScene                  ## what stays when it falls (empty = nothing)
@export var tag := ""                                ## network id, derived; read-only in the inspector
```
Las partes pasan a ser nodos hijos de `scene`; la colisión sale de la escena; `to_record()` y `MapBuilding.bldg()` desaparecen.

`FloraMap` hoy: `tags = ["CAH1", …]`, `counts: Array[PackedByteArray]` 320×320. Después:
```gdscript
class_name FloraLayer extends Resource
## Where one kind of plant grows on a map. Paint `density` in any image editor (white = dense).
@export var species: VegetationSpecies
@export var density: Texture2D        ## grayscale PNG, 1 px = cell_m
@export var cell_m := 8.0
@export var max_per_cell := 6
```
A mano: nodo `VegetationPatch` (`species`, `radius_m`, `count`, `seed`). La flora no planta dentro de un `nav_source`.

### 4.5 Cómo se hace cumplir
- `tools/lint/conventions.sh`: grep, awk y wc, sin Godot, <2 s. Cubre C1, C5, C6, C7, C8, C9, C11, C12, C13, C14. **Ratchet**: `tools/lint/baseline.txt` guarda el conteo de hoy por regla; falla si algún conteo sube; cada corte que baja uno lo reescribe.
- Checklist del reviewer por corte: ¿script nuevo >150? ¿el encabezado dice qué hace y qué no? ¿un hijo nombra a su padre o hermano? ¿socket sin warning? ¿campo crudo en un `.tres`? ¿escena `debug/<sistema>/` con F6? ¿README con quién habla con quién? ¿`MpKit.` nuevo fuera de la allowlist? ¿lint verde? ¿bajó el conteo de los 3 recorridos?

## 5. Herramientas de importación

Regla: `tools/import/` es el único lugar que conoce formatos del original; escribe solo en `assets/original/`. Las conversiones a Resources son de una sola vez y después se borran. Hoy el runtime lee el original en 16 usos de `OriginalAssets.` en 6 archivos, 31 literales `assets/original` y `scenes/bodies/original_material.gd:88` (parsea `index.json` en runtime).

| Herramienta | Decisión |
|---|---|
| `tools/import/sac_formats/*`, `import_*.py`, `export_skeletal*.py`, `export_stats.py`, `fx_catalog.py`, `land_themes.py` | Congelar en `tools/import/legacy/` con README «necesita el original» |
| `tools/import/import_themes.py` | Borrar después de 055b (pisa `GodEnvi`; `LookProfile` será la fuente) |
| `migrate_particle_atlas.py` / `classify_ground_tiles.py` / `sample_grass_palette.py` | Borrar / congelar / congelar |
| `tools/import/scaffold_map.py` | Mantener |
| `tools/bake/bake_catalog.gd` + `catalog_builder.gd` | Borrar después de 055c/055d (re-correrlo borra ediciones) |
| `bake_map_layout.gd`, `migrate_layout_043.*` | Borrar después de 055d |
| `bake_flora_map.gd`, `flora_map_builder.gd`, `plant_clears.gd` | Congelar; borrar en 055d tras convertir a `FloraLayer` |
| `bake_body_scenes.gd` | Congelar |
| `new_creature.gd` (698) | Mantener y partir: es el camino de contenido propio |
| `import_terrain.gd`, `terrain_glb_export.gd` | Congelar |
| `make_flat_terrain.gd`, `bake_nav.*`, `creature_icon*.gd`, `clip_slide.gd` | Mantener; `bake_nav` pasa a un botón en `MapNavRegion` |
| `bake_sound_sets.gd`, `sound_set_writer.gd` | Congelar |
| `tools/audit/audit_models.py`, `audit_skeletal*.gd`, `check_original_assets.sh` | Congelar |
| `check_layout_transforms.*` + baseline | Borrar |
| `check_map_models/starts.*`, `check_icon_files.gd` | Mantener y fundir en un validador de contenido |
| `tools/skeletal_post_import.gd`, `tools/terrain_import.gd` | Mantener (85 `.import` los nombran) |
| `tools/move_map*` | Congelar al cerrar 055 |
| `MapDefinition.ntts_path` / `widgets_path` | Sacar del Resource de runtime en 055d |

## 6. Riesgos

| Riesgo | Cortes | Mitigación |
|---|---|---|
| Orden de `_physics_process` al partir `UnitBody` | 055c | Los componentes no procesan solos: la raíz los llama en orden fijo; regrabar con la causa |
| `Area3D` de visión no determinista | 055c2 | `Vision` ordena por id estable antes de emitir |
| Caída por ticks / doctor | 055a | Regrabar; `fall_ticks` fijo en tierra |
| 21 props replicadas por `NodePath` en `unit.tscn` | 055a, 055c | Mover props con su `SceneReplicationConfig` en el mismo commit; no renombrar `Health`, `Corpse`, `Flight` |
| 566 flows en `agent/flows/` | todos | No renombrar nodos en 055a/b; `PeaksLayout` queda como raíz |
| Proyectiles como `Dictionary` en `spawn()` | 055e | `ProjectileLaunch.to_dict()` en el cable |
| Terreno deformable | RFC-057 | `DeformLog` replicado por tick; chunks; `NavRebake` en un tick |

Refactors que entran en un solo corte por dueño compartido: (1) `mode` + `DeadState` + `Captive` + `Corpse` + `HealthBar.visible` + caída del doctor → 055a; (2) los 3 escritores del `Environment` → 055b; (3) `SpellType.flags*` + `ai_spell_eval.gd` + lectores de `.flags` → 055e; (4) `BuildingType.components → scene` + `MapBuilding` + 196 `.tres` → 055d; (5) `Locomotion` fuera de `UnitBody` y `WizardBody` a la vez → 055c; (6) `TerrainShape` delante de los 25 llamadores de `ground_height` → 055d-t.

## 7. Preguntas abiertas
- P1. ¿El cargado muere al caer aunque estuviera vivo (Desecrate lleva una criatura viva propia)? Recomendación: `carried_dies_when_dropped = true` en `MatchRules`, apagable.
- P2. ¿Los `.tres` del catálogo pasan a nombres humanos (`trogg.tres`)? Recomendación: sí en 055c1; el tag sigue siendo un campo y viaja por la red.
- P3. ¿El lint corre en pre-commit o solo lo corre el reviewer? Recomendación: reviewer primero; hook cuando el baseline baje a la mitad.
