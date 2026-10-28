# 055R — Auditoría de lo que arrastramos del diseño del 2000

Fecha: 2026-10-24. Pedido del usuario: «¿por qué limitar a algo del Sacrifice original pudiendo hacerlo como cualquier juego moderno?» Hay que identificar **todo** lo que se calcó del original y **corregirlo**, no solo listarlo. Este documento es la evidencia. El registro que usa el reviewer está en RFC-055 §13.2 y §13.2b.

Método: `bash tools/lint/conventions.sh --verbose` (solo lectura, todo en OK contra la base), `grep`/`wc` sobre `scenes/`, `data/`, `tools/`, `debug/` y `agent/`, el historial de git y los planes `plans/061-spells-master-plan.md`, `plans/062-ground-roles-plan.md` y `plans/063-mesh-ground-plan.md`. Todos los conteos son de `main` al 2026-10-24 (commit `663438a3` y el plan 063 `a02e01d5`). Las rutas son relativas a `game/`.

Criterio para separar «calco que limita» de «decisión razonable»: algo **limita** cuando un humano no puede cambiarlo sin leer sacengine, cuando fija un número del original que no hace falta (tamaño, unidad, formato) o cuando hay dos caminos para lo mismo. Algo es **razonable** cuando es una regla de juego que define a Sacrifice o cuando es lo que haría igual un juego Godot de hoy.

---

## 0. Conteos de hoy (lint, todo en la base)

| Regla | Hoy | Dónde se concentra |
|---|---|---|
| C1a >150 líneas / C1b >300 | 103 / 24 | `ai_perception.gd` 700, `unit_body.gd` 783, `sacrifice_system.gd` 494, `caster.gd` 457, `wizard_brain.gd` 450, `doctor_body.gd` 418 |
| C8 campos crudos en `*_type.gd` | 24 | `CreatureType` 12 `Dictionary`, `WizardType` 6, `SpellType` 3 `flags*`, `AbilityType` 3 `flags*` + `args: Dictionary` |
| C9 doc que abre citando al original | 356 | units 117, ui 58, ai 34, audio 28, spells 24, orders 15, fx 15, map 11, sacrifice 10, bodies 9, look 8, match 7, core 7, net 5, resto ≤2 |
| C12 `MpKit.` fuera de la allowlist | 85 | units 29, ui 15, spells 7, sacrifice 7, map 6, resto ≤3 |
| C13 lecturas del original en `scenes/` | 40 | ui 13, bodies 9, fx 8, map 3, spells 2, core 2, audio 2, look 1 |
| C15 nodos de contenido con `.new()` | 43 | — |
| C16 alturas en código | 41 | units 14, spells 11, sacrifice 3 |
| C17 FX por texto | 26 | spells 17, units 7, sacrifice 2 |
| C18 contenido por tag de texto | 132 | ui 26, core 26 (`sacrifice_flow.gd` sola 25), units 24, ai 12, map 11 |
| C19 `.tres` de `data/` con posiciones | 328 | `data/catalog/body_sizes/` 320 |
| C20 radios en `MatchRules` | 17 | `match_rules.gd` |
| C21 `@export_file` | 5 | `god_type.gd`, `terrain_shape.gd`, `quake_wave.gd`, `ground_hug_flight.gd`, `spike_wave.gd` |

Citas al original en `scenes/` (líneas con `sacengine` o `<archivo>.d:<n>`): **1 529 en 373 archivos** (en §13.1 eran 1 439 en 280; subió por los hechizos de 061). Por sistema: units 660, ai 237, spells 198, fx 78, sacrifice 69, ui 56, match 56, orders 40, wizards 39, components 31, souls 27, map 12, bodies 9, look 4, core 4, camera 3, audio 3, structures 2, gods 1, net 0.

---

## 1. Estado de las filas que ya estaban en §13.2

| Fila | Estado | Evidencia | Qué queda |
|---|---|---|---|
| Muerte por Tween | **Hecho en lo central** (055a-1…3) | `Corpse` por ticks (`8c822083`), `CorpseLook` (`fae32914`), ragdoll (`702fd219`). 20 de 74 `models/*.tscn` tienen `PhysicalBoneSimulator3D` | Hornear los otros 54 (055a-5, después de 055s); `TippingFall` queda como respaldo, es razonable |
| Cielo con 3 escritores | **Hecho** (055b-1…3) | `4bcbd7db` borra `ThemeApplier`, `GodTheme`, `GodEnvi`, `LookApplier`, `SkyLayer`, `LightLayer`. Hoy `scenes/look/sky/` tiene `environment_layer.gd` y `sky_look.gd` | `import_themes.py` sigue (117 líneas) pero ahora solo escribe texturas en `assets/original/themes/`. Cerrado |
| `original_material.gd` y lecturas del original | **Pendiente** | `original_material.gd` (92 líneas) sigue leyendo `OriginalAssets.texture_index()` en runtime (líneas 37 y 86). C13 bajó de 47 a 40 | Ver §5 |
| `SideVision` | **Pendiente** (plan 055c aprobado) | `scenes/units/targeting/side_vision.gd` 273 líneas, `const SEEN_TICKS := 384`, `const GRID := 256` | 055c2 |
| `UnitBody` god file | **Peor** | 750 → 783 líneas; `enum Mode` de 11 valores en la línea 35 | 055c |
| `CreatureType` | **Pendiente** | 46 `@export` (eran 44); 12 `Dictionary`/`Array[Dictionary]` de clips; los `.tres` se llaman `EHTH_2.tres`, `ahcr.tres` (72) | 055c1 + 055i |
| Ataques que copian `state.d` | **Pendiente** | `ranged_attack.gd` 337 líneas, 27 citas | 055c3 |
| Aldeanos | **Pendiente** | `peasant_behavior.gd` 215 líneas, 9 citas, sin FSM | 055c |
| `BuildingType` crudo | **Hecho** (055d-d1/d2) | `building_type.gd` 56 líneas: `display_name`, `role`, `max_health`, `shelters_peasants`, `flattens_ground`, `ruin_scene`, `tag`. Los 196 edificios son escenas arrastrables (`19611460`); se borraron los `layout.tscn` y `bake_map_layout` (`fcf18cea`) | 114 de los 196 `data/buildings/*.tres` se llaman todavía `<dios>_<tag>` (`stratos_stt1.tres`) o `_<tag>` (`_cama.tres`). Va a 055i |
| `FloraMap` | **Hecho** (055d-d3) | `28b3b6a3`: `FloraLayer` + `VegetationPatch`; `FloraMap` borrado | — |
| Terreno con 5 representaciones | **A medias** | 055d-t1/t2: `TerrainShape` es el único dueño de alturas (`4687fd4b`) y `GroundRay` la única copia del rayo (`bd5b4ecb`). **Pero sigue siendo la grilla 256×256 de 10 m del original.** Ver §2 | RFC-063 |
| `SpellType.flags*`, `AimedAction` | **Pendiente, con convivencia** | `flags/flags1/flags2` siguen en `spell_type.gd:24-26`; `ai_spell_eval.gd` lee bits (`0xfc00`, `0x781f`, `1 << 11`, `0x10`); a la vez existe `ai_use: AiUse` (061b). 5 clases `extends AimedAction` | 055e |
| `AiPerception` | **Pendiente** | 700 líneas, 32 citas; `AiTrack` con bits del original (ver §3.8) | 055f |
| Ritual y doctor | **Pendiente** | `sacrifice_system.gd` 494, `ritual.gd` 311, `doctor_body.gd` 418 | 055g |
| Herramientas de bake | **A medias** | Borrados `bake_map_layout`, `bake_flora_map`, `migrate_layout_043`. Siguen `tools/bake/bake_catalog.gd` + `catalog_builder.gd` (re-correrlos pisa `data/catalog/`), `import_terrain.gd`, `terrain_glb_export.gd`, `make_flat_terrain.gd` | `bake_catalog` se congela con 055i; los de terreno se borran en 063-4 |
| `MpKit.` en 86 archivos | **Pendiente** | 85 hoy | Fase 3 |

**Hallazgo de proceso:** la regla §13.1.1 («nada de contenido nuevo sobre un sistema 1 a 1») se suspendió a pedido del usuario para los hechizos (plan 061 §0). Los 26 hechizos nuevos se apoyaron en `SpellType.flags*`, `MatchClock` en ticks y FX por texto, y por eso C17 y las citas subieron. No es un error, pero 055e y 055x crecieron.

---

## 2. Grupo B: el suelo y el terreno

### 2.1 Terreno en grilla 256×256
- **Qué es:** el mapa es la red del original de 256×256 vértices cada 10 m (2 560 m de lado). `MapDefinition` guarda `terrain: MapTerrainData` («el suelo como lo guarda el original») y `tiles: Image` 256×256 (`map_definition.gd:16-18`).
- **Evidencia:**
  - 340 líneas en 140 archivos nombran símbolos de la grilla (`TerrainRules|MapTerrainData|TerrainMeshArrays|TerrainCollision|tile_ids|terrain.res|DEFORM_CELL|TerrainShape`). 39 scripts de `scenes/` usan `TerrainShape`.
  - Tamaño fijo en código: `side_vision.gd:30 const GRID := 256`, `ground_scar_rules.gd` (4), `grass_height.gd`/`grass_field.gd` (`MAP_M 2560`), `minimap_terrain_bake.gd` («1024 over a 2560 m map»), `tile_layer_map.gd` y `ground_material.gd` (2 cada uno), `terrain_mesh_arrays.gd`, `terrain_rules.gd`.
  - 061k fija la deformación en la misma red (`TerrainDisplacement.SIDE`, `DEFORM_CELL`).
- **Por qué limita:** no hay mapas de otro tamaño, ni acantilados verticales de verdad, ni voladizos, ni arcos, ni cuevas. Un mapa nuevo necesita el original (`import_terrain.gd`).
- **Reemplazo:** RFC-063 (plan `a02e01d5`, pendiente de aprobación). `GroundSurface` como único punto de entrada; malla libre de Blender importada por `ground_import.gd` (un `EditorScenePostImport`); `GroundField` con `size` y `cell_m` propios; la grilla convive solo como backend de transición y se borra en 063-4. El criterio de cierre es que el grep de los símbolos de arriba dé 0.
- **Decisión que se mantiene:** el plan descarta Terrain3D con razón: es un heightmap, no admite voladizos, trae su propio dueño del suelo y complica el port web.

### 2.2 Suelo: atlas de baldosas, traducción entre dioses y luz de High Noon
- **Evidencia:** los 5 `assets/original/themes/<dios>/ground_classic.tres` apuntan a `assets/original/maps/high_noon/light.png`. El intento de corregirlo por mapa se revirtió en `e4d52f26`. Celdas sin baldosa al traducir: peasantville 725, alpine_meadow 31, tutorial_valley 5. Hay 19 celdas sueltas de roca de James en High Noon que `NATIVE_ROLES` manda a la piedra de Persephone (plan 062).
- **Por qué limita:** el suelo de un dios es el atlas de baldosas del original traducido por ids. Un mapa nuevo sin ids del original no tiene suelo, y todos los mapas comparten la luz horneada de uno solo.
- **Reemplazo:** plan 062, con 4 roles (abierto, tierra, roca, camino), `ground_roles.png` por mapa, `GodGround` con 4 `GroundRole` PBR, un único shader y la luz del mapa.
  - Hechos: corte 1 (`3a27f925`, `28262192`, `6176ea1b`) y corte 4 (variación de la flora, `9321d236`).
  - En curso: corte 2 (shader único).
- **Ajuste por 063:** `ground_roles.png` deja de ser 256² fijo y pasa a proyectarse en mundo con `ground_size_m`. Queda anotado en 063 §0 y hay que llevarlo a 062-2 antes de cerrarlo.

### 2.3 Dos sistemas de suelo en paralelo
- **Evidencia:** `scenes/look/ground/` tiene, por un lado, `sacrifice_ground.gdshader` + `ground_common` + `zone_splat` (clásico por atlas) y, por otro, `ground_pbr.gdshader` + `ground_set.gd` + `ground_layer.gd` (PBR, solo `persephone_ground.tres`, que el perfil no usa). Además están `native_ground.gd` (tutorial) y `tile_layer_map.gd` (solo High Noon, y lo lee el pasto). 30 archivos de `scenes/`/`data/` nombran `TileLayerMap|NativeGround|GroundSet|ground_classic`.
- **Reemplazo:** 062-2 borra los cuatro scripts y los tres shaders viejos (árbol de 062 §1, marcados `[-]`).

---

## 3. Grupo C

### 3.1 Identidad por tag de 4 letras del WAD
- **Dónde (C18, 132):**
  - Funciones: `GameData.ability` 20, `BodyCatalog.info` 18, `GameData.wizard` 14, `MapCatalog.active` 10, `GameData.creature` 8, `MapCatalog.shared` 7, `GameModeCatalog.shared` 7, `GameData.spell` 6, `GameData.gods` 5, `BodyCatalog.pose` 4, otros ≤4.
  - Archivos: `scenes/core/flow/sacrifice_flow.gd` 25 (fuera de la allowlist: la allowlist es `scenes/core/catalog/`), `character_select.gd` 5, `side_relations.gd` 5, `map_picker.gd` 4, `body_visual.gd` 4, `kill_estimate.gd` 4, `ai_perception.gd` 4, `wizard_body.gd`, `unit_body.gd`, `mode_picker.gd`, `ability_command.gd`, `terrain_shape.gd`, `ai_roster.gd` 3 cada uno, y unos 25 archivos de unidades con 1–2.
- **Datos con nombre de WAD:**
  - `data/catalog/creatures/` 72 (`EHTH_2.tres`, `ahcr.tres`), `spells/` 53 (`brif.tres`, `ccas.tres`), `abilities/` 63 (`!nur.tres`, `HRba_2.tres`), `wizards/` 15 (`cwa0.tres`), `body_sizes/` 396.
  - `data/audio/creatures/` usa los mismos tags.
  - `scenes/bodies/models/<tag>.tscn` (74).
  - 114 de 196 `data/buildings/`.
- **Referencias por texto dentro de los tipos:**
  - `CreatureType`: `god: String`, `model: String`, `ability_tags: PackedStringArray`, `ranged_attack_tag`, `active_ability_tag`, `passive_on_damage`, `passive_abilities` (33 lecturas fuera del tipo).
  - `WizardType`: `spell_tag`, `model`.
  - `GodType.cast_fx_path` (`@export_file`).
- **Tag en el código:**
  - `wizard_brain.gd:240-242` (`spell.tag == "ccas"`, `"ucas"`).
  - Tablas por tag: `ranged_attack.gd:28 FALLING_ACCELERATION := {"dkba": 10.0}`, `sacrifice_system.gd` (8 claves), `sacrifice_math.gd` (6), `rift_spawner.gd` (4), `melee_attack.gd` (3).
  - `SoundLibrary.creature(tag)` y `.wizard(tag)`.
- **Por qué limita:** una criatura propia hecha en Blender (memoria «contenido propio desde Blender») necesita inventarse un tag de 4 letras, registrarse en el catálogo y repetir ese texto en 5 campos. Un error de tipeo no da aviso en el editor.
- **Reemplazo:** referencias tipadas por `@export`:
  - `CreatureType.abilities: Array[AbilityType]`, `ranged: WeaponType` (055c3), `sounds: SoundSet`, `god: GodType`, `body: PackedScene` (la escena de la criatura, 055c).
  - `WizardType.spell: SpellType`.
  - `GodType.cast_fx: ParticleType`.
  - Archivos con nombre humano (`trogg.tres`).
  - El tag queda como **id de red derivado**, de solo lectura, y solo lo usan la frontera (spawners, `scenes/net/`, `scenes/core/catalog/`) y la persistencia de salas.
  - `sacrifice_flow.gd` recibe `GodType`/`WizardType`/`MapDefinition` ya resueltos por el lobby.
- **Corte:** **055i identidad por recursos** (nuevo, L). Va junto con 055c1 para `CreatureType` y con 055e para `SpellType`. Lo que se mantiene: el tag como id compacto en la red y en el snapshot. Es razonable, porque es lo que haría cualquier juego con un id estable.

### 3.2 Modelo de datos copiado de los registros SPEL/CRE8
- **`SpellType`** (33 líneas):
  - Crudos: `flags`, `flags1`, `flags2` (C8), `amount2` («SPEL u32 at 96», lo leen `ai_spell_eval.gd:138` y `ai_rater.gd` ×6), `count` (= `amount3`), `spell_order` (orden del EXE), `is_structure`.
  - Sin unidad en el nombre (C8): `duration` (segundos, 13 lectores que la pasan a ticks), `speed`, `acceleration`, `cast_range`, `damage_range`, `effect_range`.
  - Con nombre: `cooldown_s`, `casting_time_s`, `action: PackedScene`, `ai_use`.
  - **Conviven duplicados:** `ai_use` (061b) y los bits de `flags1` que lee `AiSpellEval` («reads it before the old flag bits»).
  - 107 `.tres` de `data/` tienen algún `flags*` distinto de 0.
- **`AbilityType`** (31 líneas): los mismos `flags*`, `amount2` y `args: Dictionary` (C8). `ai_rater.gd:111` lee `ability.flags1 & 0x4000` y `ability.flags & 4`.
- **`CreatureType`** (46 `@export`, 107 líneas):
  - Stats en las escalas enteras del original: `melee_accuracy = 800`, `aggressiveness = 1000`, `melee_evasion = 400` (milésimas), `drain`, `spell_order = 498`.
  - 12 diccionarios de clips con `{framerate, frames, tag, attack_ticks}`.
  - **Duplicado:** los mismos clips viven en `BodyModel.clips` de cada `models/<tag>.tscn` y en su `AnimationTree` por rol.
- **`WizardType`**: 6 `Dictionary` de clips más `death_frames`, `corpse_rise_frames`, `float_to_stance_frames` (cuadros de 30 fps).
- **Reemplazo:**
  - Flags a booleanos o enums con nombre, más `ai_use` como única entrada de la IA.
  - `amount2`/`count` a nombres por uso (`hits`, `targets`, `heal_amount`…), según la tabla bit → campo de 055e.
  - Stats en `@export_range(0.0, 1.0)` (precisión, evasión, agresividad).
  - Clips fuera del tipo, en la escena del modelo (`AnimationLibrary` por rol).
- **Corte:** 055e (hechizos), 055c1 (criaturas y clips), **055u** (unidades, ver §3.3).

### 3.3 Tiempo en cuadros y ticks
- **Hoy:**
  - Hay 64 `@export var *_ticks` en `scenes/` (units 31, spells 13, map 2, ai 1 con 6 campos de `AiProfile`) contra 236 `@export *_s`.
  - Ejemplos: `corpse.gd fall_ticks := 55`, `stun_impact.gd cooldown_ticks := 480`, `pull_thread.gd max_life_ticks := 2400`, `halo_of_earth.gd life_ticks := 2100`, `spell_carrier.gd roundtrip_ticks := 540`.
  - En datos: los clips con `frames`/`framerate` a 30 fps y `attack_ticks` (cuadros de clip, no ticks de la sim) en los 72 + 15 `.tres`, más `BodyModel.clips` en los 74 modelos.
- **Qué debe quedar en ticks:** el reloj de la sim. `MatchClock.TICKS_PER_SECOND = Engine.physics_ticks_per_second` (60 Hz). Los contadores internos (`age`, `_left`), el snapshot y la red siguen en ticks enteros: es lo que exige el determinismo con dedicado y es lo que hace cualquier RTS con tick fijo.
- **Qué debe ser segundos en el inspector:** todo knob que edita un humano.
  - Patrón: `@export var stun_s := 8.0` y `var _stun_ticks := MatchClock.ticks_for(stun_s)` en `_ready`. `ticks_for` ya existe y redondea con `ceili(seconds * TPS - 1e-4)`.
  - Si se elige el valor en segundos como `ticks/60` exacto, el digest de `quick` no cambia. Se verifica caso por caso con el banco de humo.
  - El tiempo de un golpe dentro de un clip pasa a un marcador `hit` en la animación (ya decidido en §15 para 055c1).
- **Corte:** **055u unidades humanas** (nuevo, M). Abarca los 64 `_ticks`, los nombres sin unidad de `SpellType`/`CreatureType` (`duration` → `duration_s`, `speed` → `speed_mps`, `*_range` → `*_m`) y las escalas en milésimas pasadas a 0..1. Depende de que terminen 061 (comparte archivos) y no toca la red.

### 3.4 Lecturas de formatos del original en runtime (C13 = 40)
- **Por tipo de lectura:**
  - Código que carga del original: 13 líneas. `original_material.gd:37,86` (parsea `index.json` en runtime), `body_catalog.gd:123` (`OriginalAssets.prop`), `fx_atlas.gd:17` (`OriginalAssets.fx(tag)`), `order_marker.gd:77` (`load("res://assets/original/fx/aura.png")`), `terrain_ground_material.gd:8` (`DEFAULT_GROUND`), `hud_icons.gd:14-17,42` (directorios y `icon_file(tag)`) y `original_assets.gd:8`.
  - Avisos de editor: 4 (`portal_disc`, `tether`, `command_cue`, `cursor_skin`).
  - Comentarios: unos 23.
- **Por qué limita:** el producto arma rutas al original por texto. Sin `assets/original/` el juego cae a rellenos en tiempo de ejecución, y no se puede reemplazar un ícono o una textura arrastrándola en el inspector.
- **Reemplazo:** cada consumidor recibe un `Texture2D`/`Material`/`PackedScene` por `@export`, guardado en su `.tscn` o `.tres`.
  - Materiales: se hornean como `.tres` dentro de cada `models/<x>.tscn` y se borra `original_material.gd`.
  - Íconos: `CreatureType.icon` ya existe. `HudIcons` lee `type.icon`.
  - Atlas: `ParticleType.atlas` ya es `Texture2D`.
  - `OriginalAssets` queda solo para `tools/`.
  - De paso, el lint debería excluir los `##`, porque hoy cuenta comentarios.
- **Corte:**
  - Materiales y `BodyCatalog`: 055s.
  - HUD: **055h**.
  - FX: 055x.
  - `DEFAULT_GROUND`: 062-2.
  - El resto, en la limpieza final **055z**.

### 3.5 Posiciones como números
- **C19 (328):** 320 son `data/catalog/body_sizes/*.tres` (offsets y poses de 396 cuerpos). El resto: `data/look/ground/layers/{grass,path,soil}.tres` (se borran en 062-2), `data/look/sky/aurora_gradient.tres`, `data/fx/{manafount,oil_splash}.tres`, `data/fx/ramps/ice.tres` y `data/bodies/pose_overrides.tres`.
  - Los `hands` de `BodyModel.clips` (offsets por mano dentro de un `Dictionary`) no los cuenta el lint, pero son el mismo problema.
  - **Corte:** 055s (sockets `Marker3D`, `BoneAttachment3D`, `CollisionShape3D`).
- **C16 (41):** units 14, spells 11, sacrifice 3 y otros ≤2. Típico: `FxBus.broadcast("heal", pos + Vector3.UP)`. **Corte:** 055s, con el socket como `Marker3D`.
- **C20 (17):** `soul_collect_distance`, `manafount_radius`, `altar_radius`, `manahoar_radius`/`near`/`far`, `doctor_drop_height`/`distance`, `desecrate_pickup_distance`, `carry_height`/`distance`, `ritual_start_distance`, `ritual_radius`, `ritual_creature_height`, `ritual_push_radius`, `guardian_arm_radius`, `guardian_return_distance`. **Corte:** 055r (forma con gizmo en la escena del altar, el manantial y el doctor).
- **Banco:** `debug/rules/` tiene 113 `.tres` con 73 `Vector3` de posiciones (anclas como `BenchRules.anchor := Vector3(1270, 0, 1270)`, el centro de la grilla de 2 560 m). **Corte:** 055q.

### 3.6 Comentarios que abren citando al original (C9 = 356)
Por sistema: units 117 · ui 58 · ai 34 · audio 28 · spells 24 · orders 15 · fx 15 · map 11 · sacrifice 10 · bodies 9 · look 8 · match 7 · core 7 · net 5 · wizards 2 · gods 2 · camera 2 · structures 1 · souls 1. Cada corte arregla los de su sistema. Lo que quede al final (audio, ui, orders, match) va a **055z**, una pasada mecánica de tamaño S a M que no toca la sim.

### 3.7 Banco de determinismo
- **Hoy:** `agent/run_determinism.sh` con 33 casos (`det_cases.txt`) compara contra **su propia** base (`det_baseline.txt`, 28 digests). No compara contra sacengine.
  - El acople con el original está en otro lado. 15 archivos de `debug/` (43 líneas) fijan valores esperados citando sacengine: `ai_cases.gd` 12, `target_cases.gd` 7, `guardian_cases.gd` 4…
  - Las reglas del banco son posiciones numéricas sobre la grilla de 2 560 m (§3.5).
  - `BenchRules extends MatchRules` mantiene `friendly_fire = false` «para que los digests no cambien» (F139).
- **Por qué limita:** un cambio de diseño que el usuario quiere, como «que no sea un 1 a 1», rompe casos escritos como «igual que state.d». Las anclas fijas no sirven en un mapa de malla de otro tamaño.
- **Reemplazo (ya decidido en la memoria «Godot estándar antes que fidelidad»):** el banco queda como humo de determinismo (mismo digest dos veces). Los casos de la suite expresan reglas propias en segundos y metros, con `## Ref:` al final. Las reglas del banco pasan a escenas con `BenchSquad : Marker3D` sobre cualquier mapa.
- **Corte:** 055q. Depende de 063-3, porque las anclas tienen que funcionar en mapas de malla.

### 3.8 Otros sistemas: ¿calco o decisión razonable?

| Sistema | Evidencia | Veredicto | Corte |
|---|---|---|---|
| **Cámara** `scenes/camera/` | `world_camera.gd` 270 líneas: `@export_group("Formula")` con `distance_per_height 2.32`, `distance_zoom_scale 3.13`, `height_zoom_scale 2.8`, `floating_offset -1.15`, la fórmula de sacengine; `KEY_*` crudos; sin límites de mapa (063 §8) | **El concepto se mantiene**: la cámara detrás del mago es la identidad del juego. **La fórmula es calco:** 15 coeficientes que nadie puede ajustar a ojo | 055k: `Curve` de distancia y altura por zoom, vista previa en el editor, límites desde `GroundSurface.bounds()` (después de 063-1) |
| **HUD/UI** | `hud_scale.gd:21 const SACENGINE_HEIGHT := 480.0` («hudScaling = height/480»): todo el HUD se mide en «unidades de 480 px». Arte del original por directorios (`HudIcons` 4 `const *_DIR`); `bitmap_digits.gd` dibuja dígitos del atlas original; `radial_layout.gd` usa `*_px` en unidades HUD. La geometría del menú de opciones salió de `sacform.d` (031R) | **Calco que limita:** el escalado propio reemplaza el `content_scale` y las anclas de Godot, y un `Theme` no puede gobernar el HUD. La disposición (radial, libro, barras) es diseño del juego y se mantiene | **055h HUD nativo** (nuevo, M): `stretch mode canvas_items` + `aspect expand`, anclas y contenedores, un `Theme` del juego, texturas por `@export`; fuera `HudScale` |
| **Mapas** | `MapDefinition` ya tipado (055d-d2); `player_starts` 1–8; sides derivados de `PlayerStart`; `MatchState` maneja N altares (`match_state.gd:86`). Atados al original: `terrain: MapTerrainData`, `tiles: Image` 256², `native_ground`, tamaño 2 560 m | **Razonable**: un altar por bando, la victoria por altares y las sides derivadas son reglas del juego. **Calco**: el tamaño y el suelo | 063 (tamaño, `terrain`/`tiles` fuera); 062-2 (`native_ground` fuera) |
| **IA** | `ai_perception.gd` 700 líneas, 32 citas; `wizard_brain.gd` 450; `ai_spell_eval.gd` lee bits de `flags1`; `AiTrack` con bits del original (`OWN 1`, `ALLY 2`, `ENEMY 4`, `SEEN 0x80`, status `0x40000`, `enum Kind {NONE, WIZ, CRE, MAHO, STR}`); `AiProfile` «the numbers of the original AI… every `beta*` switch» (41 `@export`); 237 citas en `scenes/ai` | **Calco que limita**: es una traducción de `shiny.d`. Se mantiene que la IA corre en el servidor, con ticks y perfiles `.tres` | 055f (se amplía: `AiTrack` con campos y enums con nombre; `AiProfile` con nombres de diseño; la percepción escucha `Vision`) |
| **Órdenes/selección** | `match_command.gd` ya coordina hijos (RFC-038); `selection.gd` cita `state.d`/`dagonBackend.d` en el doc (C9); input por InputMap (26 usos, 72 acciones) con solo 18 `KEY_`/`MOUSE_BUTTON_` crudos en 3 archivos (`spell_book.gd`, `world_camera.gd`, `nav_regions.gd`) | **Razonable**: la estructura ya es de Godot. Solo quedan comentarios y 3 archivos con teclas crudas | 055z (comentarios + teclas a acciones) |
| **Audio** | `SoundLibrary.find(rel: String)` y `creature(tag)`/`wizard(tag)` buscan por ruta y tag; `data/audio/creatures/<tag>.tres`; `fx_sound_map.gd` mapea el nombre del FX al sonido; `SoundEvent` con 11 claves de texto. El bus, el pool y el `SoundSet` (evento → cue) están bien | **Mixto**: el pool y el bus son razonables. La búsqueda por tag y `FxSoundMap` son calco | 055i (`CreatureType.sounds: SoundSet`) + 055x (el sonido va dentro del `ParticleType`/escena del FX; fuera `FxSoundMap`) |
| **Red** | `MpKit.` en 85 archivos fuera de la allowlist (units 29, ui 15) | **El diseño es razonable** (host autoritativo con dedicado, snapshots, lo que se usa hoy). **La dispersión limita** | Fase 3 (wrapper), sin cambios de protocolo |
| **Escala del mundo** | 1 unidad = 1 m; `sight_range 200`, `running_speed 10` m/s, mapa 2 560 m | **Razonable**: el metro es el estándar de Godot y el balance depende de estos números. Lo único calcado es el tamaño fijo del mapa (063) | — |
| **Animación** | 74 `models/<tag>.tscn` con `AnimationTree` de un estado por rol (023c/036g, nativo; `BodyRig` lo activa al reproducir), pero los clips se llaman con tags del WAD (`AAa1`, `FGst`); `BodyModel.clips: Dictionary` con `framerate/frames/hands` y los mismos datos repetidos en `CreatureType`/`WizardType` | **La base es nativa**; **duplicado y con nombres del WAD** | 055c1: clips con nombre de rol en una `AnimationLibrary` del modelo, marcadores `hit` en la animación, fuera los `Dictionary` de los tipos; `hands` como `BoneAttachment3D` (055s) |
| **Efectos** | `FxBus.broadcast("<nombre>")` (C17 26) busca `data/fx/<nombre>.tres` por texto (`TYPES_DIR`); `ParticleType` con `RAMP_POINTS := 25` y `SpriteParticles` propio sobre atlas del original (128 `.tres`); `GPUParticles3D` en 29 archivos | **El look es razonable**: el brillo del original son sprites aditivos (memoria) y el atlas por hoja también se usa hoy. **Buscar por texto es calco** | 055x: `@export var fx: ParticleType` + socket, sin nombres; los FX nuevos pueden ser escenas `GPUParticles3D` |
| **Cielo/look** | 055b cerrado: un dueño (`EnvironmentLayer`), `LookProfile` por dios; las texturas de banda del original se mantienen | **Razonable**: el usuario pidió conservar el cielo original (memoria) | — |
| **Ritual/doctor** | Ver §1 | Calco | 055g |
| **Tiempo de la sim a 60 Hz** | `MatchClock` = `physics_ticks_per_second` | **Razonable** (ver §3.3) | — |
| **Estructuras de dios** | `GodType.structures: Array[GodStructure]`, `StructureAction` común (Manalith, Shrine) | **Razonable**: ya es «pieza común con knobs» | — |

---

## 4. Orden propuesto (prioridad del usuario: terminar hechizos y suelo/terreno, después la v2 del refactor)

| Paso | Cortes | Por qué en este lugar | Paralelo con |
|---|---|---|---|
| 1 | **061k-2/3** (Volcano, Bore, abolladuras de Bombardment) y los hechizos que falten de 061 | Lo pidió el usuario, y 063 §9.2 recomienda integrarlos antes de 063-1 (`SIDE` y los ids de 256) | 062-2 |
| 2 | **062-2** shader único del suelo (ya con roles en coordenadas de mundo, `ground_size_m`) → **062-3** | Pide 063-4. Borra los dos sistemas de suelo (§2.3) | 1 (otros archivos), 055h |
| 3 | **063-1** `GroundSurface` sobre la grilla (sin cambio de comportamiento) | Saca los 2560/256 de visión, pasto, minimapa y SCAR | 055h, 055k-a |
| 4 | **063-2a/b/c** malla libre (`mesh_test`) | — | 055h, 055i-a (UI y lobby) |
| 5 | **063-3** migrar los 9 mapas con paridad → **063-4** borrar la grilla | Cierra el grupo B | 055c1 + 055i (no tocan el terreno) |
| 6 | **055c1 + 055i** `CreatureType` limpio, clips a la `AnimationLibrary`, identidad por recursos, `.tres` con nombre humano, `bake_catalog` congelado | Base de todo lo que sigue en unidades | 5 |
| 7 | **055s** sockets y cuerpo como escena (C16, C19 `body_sizes`, `original_material` horneado) → 055a-5 ragdoll del cautivo | — | 055h si no terminó |
| 8 | **055c2–c5** (`Vision`, armas, giro, aldeanos) | — | 055x |
| 9 | **055x** FX tipados, fuera `FxSoundMap` · **055r** radios como formas | Después de 061, porque comparte los archivos de hechizos | entre sí, si tocan carpetas distintas |
| 10 | **055e** hechizos: flags → campos, `AimedAction` fuera, checklist de los 15 sin acción · **055u** unidades humanas | Después de 061 y 055c | 055u por carpetas (units/spells) |
| 11 | **055f** IA (con `AiTrack`/`AiProfile`) · **055g** ritual y doctor | La IA lee `ai_use` (055e) y `Vision` (055c2) | entre sí |
| 12 | **055k** cámara (`Curve` + límites) | Puede adelantarse desde el paso 3 | cualquiera |
| 13 | **055q** banco como escena sobre cualquier mapa | Necesita 063-3 | 055z |
| 14 | **055z** limpieza final: C9 restante, C13 = 0, teclas crudas, lint sin comentarios | Cierra la fase 1 | — |
| — | Fase 2 (contenido) y fase 3 (MpKit) como en §13.4 | — | — |

Paralelizar significa developers en worktrees con archivos disjuntos. Las corridas de Godot siguen en la cola FIFO (memoria: como máximo 3 headless y 1 ventana). Los pares seguros son los que no comparten carpeta: terreno (`scenes/map/terrain`, `scenes/look/ground`) frente a HUD (`scenes/ui`), cámara (`scenes/camera`) o unidades (`scenes/units`, `data/catalog`).

## 5. Preguntas abiertas (con recomendación)
1. **¿055i va dentro de 055c1 o en un corte propio?** Recomiendo un corte propio en dos partes. 055i-a toca UI, lobby y `sacrifice_flow` y puede ir en paralelo con 063. 055i-b toca unidades, IA y audio, y va junto a 055c1.
2. **¿055u cambia el digest de `quick`?** No, si cada valor en segundos es `ticks/60` exacto. Recomiendo regrabar sin ceremonia si algún caso cambia (memoria «Godot estándar antes que fidelidad»).
3. **¿Se mantiene el atlas de sprites propio de los FX, o se migra todo a `GPUParticles3D`?** Recomiendo mantenerlo, porque es lo que da el look del original. Solo se tipa (055x), y lo nuevo puede ser `GPUParticles3D`.
4. **¿El lint C13 debe contar comentarios?** Recomiendo que no: hoy 23 de las 40 son comentarios. Se ajusta en 055z, con la base reescrita.
