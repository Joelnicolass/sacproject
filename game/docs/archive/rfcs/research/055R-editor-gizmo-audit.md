# 055R: auditoría «todo en el editor, movible con gizmo» (2026-10-23)

Pedido del usuario: todo directamente en el editor y movible con gizmos, sin capas de abstracción; simple y consistente en todo el proyecto. Medido sobre `main` a37c34f4 (`game/scenes`: 488 `.gd`, 510 `.tscn`). Informe del tech lead; las rutas tienen línea.

## (a) Huecos que no están en ningún plan
| # | Sistema | Hoy (evidencia) | Arreglo | T | Corte |
|---|---|---|---|---|---|
| 1 | Puntos de enganche del cuerpo | 0 `Marker3D` en `unit.tscn`/`wizard_body.tscn`; `creature_fx.gd:12` offset (0,2.2,0); `unit_health_bar.gd:55 place_above(height)` (4 dueños); `damage_numbers.gd:29`; `soul_anchor()` calculado (`unit_body.gd:702-709`); 27 `UP*altura` + 5 `UP*literal` | `BodySockets` con `Marker3D` `Overhead`, `Chest`, `Feet`, `SoulAnchor` en `models/<x>.tscn` | M | **055s** |
| 2 | Manos / origen del hechizo | manos como `Dictionary` por clip (`body_rig.gd:274-283`); `HAND_HEIGHT := 0.65` (`aimed_action.gd:14,55-63`) | `BoneAttachment3D HandL/HandR` + `Marker3D Muzzle` guardados en el modelo | M | 055s |
| 3 | Tamaño y pose del modelo | 396 `data/catalog/body_sizes/*.tres` (`box`, `upright_fix`, `foot_offset`) + `pose_overrides.tres`; 59 `BodyCatalog.*` | transform del nodo `Model` + `CollisionShape3D Hitbox`; borrar `BodySize`/`pose_overrides` | L | 055s |
| 4 | Cápsula de la unidad | `body_collider.gd:20-57` la arma en código | cápsula guardada por criatura (handles) | S | 055s |
| 5 | Áreas de efecto | 0 `Area3D`; radios en `MatchRules` (`manafount_radius`, `altar_radius`, `ritual_radius`…) | `Reach` (`CollisionShape3D` con gizmo, `monitoring` off, consulta ordenada igual) | M | **055r** |
| 6 | Geometría del ritual | `ritual_fx.gd:113-145` crea `Marker3D` en código; alturas en `MatchRules` | `Marker3D` en `altar.tscn` y `doctor.tscn` | S | 055g |
| 7 | Visuales de proyectiles/efectos | `MeshInstance3D.new()` en fireball/rock/swarm/ranged_shot/rockform/vined/order_marker/soul; const de altura | hijo guardado en su `.tscn`; const → `@export` | M | 055e / 055c5 / 055s |
| 8 | Dónde aparece un FX | 25 `FxBus.*("texto")` + 22 `@export *_fx` String; `UP * fire_height_m` | `@export var fx: ParticleType` + socket | M | **055x** |
| 9 | Partículas invisibles en escena | 50 `data/fx/*.tres` a `CPUParticles3D` en runtime | `debug/fx/fx_gallery.tscn` `@tool` con botón «Emitir» | S | 055x |
| 10 | Manalith/Shrine | una `structure.tscn` para todas; `if spell_tag == MANALITH`; posición por `Dictionary` | una escena por estructura + `Marker3D StructureSpot` en el manantial | M | 055e |
| 11 | Dónde aparece el mago | `player_start.gd:23 wizard_distance := 30.0` | `Marker3D WizardSpot` hijo de `PlayerStart` | S | 055d-d2 |
| 12 | Bandos del mapa | `map_sides.gd` con `PackedInt64Array` | derivar de los nodos `Starts` (`slot`, `team`) | S | 055d-d2 |
| 13 | `MapDefinition` por texto | 9 `@export_file` | `PackedScene`/`NavigationMesh` tipados; `MapCatalog` lee carpetas | S | 055d-d2 |
| 14 | Cámara como fórmula | 15 coeficientes (`world_camera.gd:28-42`) | `Curve` por zoom + `@tool` que la ubica en el editor | M | **055k** |
| 15 | Banco por números | 103 `debug/rules/*.tres`: 740 offsets | `BenchSquad : Marker3D` en escena; migración conserva posiciones | L | **055q** |
| 16 | Colisión del terreno en código | `terrain.gd:144-149` | nodo guardado con `ConcavePolygonShape3D` `.res` | S | 055d-d2 |

## (b) Planes con una abstracción a cambiar
| Plan | Abstracción | Veredicto |
|---|---|---|
| 055d-d4 `BiomeProp`+`PropSet`+`PropLayer`+`PropKind` | nodo gris resuelto en runtime | **Cambiar**: el mapa instancia la escena del prop directo; swap por dios solo para mapas neutros y con vista previa real |
| 055d `MapBuilding` + `BuildingType.scene` | partes `INTERNAL_MODE` sin guardar | **Cambiar**: se arrastra `structures/buildings/<x>.tscn` (raíz `MapBuilding`, `@export type`); partes visibles con «Hijos editables» |
| 055d-d1 `BuildingFootprint.hit_box: AABB` | caja como número | **Cambiar**: `CollisionShape3D` con `BoxShape3D` guardada |
| 055d-d3 `FloraLayer` PNG | pintado fuera de Godot | **Mantener** (16 000 plantas); `VegetationPatch` es la herramienta diaria; evaluar un scatter dentro del editor |
| 055c1 `ClipTiming` | frames de golpe como números | **Cambiar**: marcador `hit` en la animación, leído una vez |
| `TypeRef`/`GameData.creature(tag)` (73 usos) | lookup texto→recurso | **Mantener solo en la frontera** (red, spawners); adentro, `@export` tipado |
| 055c `CreatureType.scene` opcional | 72 criaturas en una escena, modelo por texto | **Cambiar**: escena heredada por criatura, obligatoria (ahí viven sockets, colisión, armas) |
| 055c3 `ShotLook` | visual del disparo como números | **Cambiar**: `PackedScene` |
| `FxBus`/`FxSoundMap` por nombre | bus resuelve texto | **Cambiar `FxBus`** (tipado, el pool queda); `FxSoundMap` se borra; `SoundBus` se queda |
| `NpcSpawn` con vista previa | no se guarda | Mantener (el spawn es del servidor) |
| 059 `native_ground` | regla del bioma | Mantener, tipado |

## (c) Capas a eliminar
`BodyCatalog`+`BodySize`+`pose_overrides` → escena del modelo (055s) · `FxSoundMap` → `ParticleType.sound` · `FxBus` por nombre → tipado · `AbilityCatalog`, `FormationCatalog`, `ShakeMap` (0 usos) → borrar · `PropSet/PropLayer/PropKind` → no crear · `MapCatalog`/`GameModeCatalog` por texto → `Array[MapDefinition]` exportado · `GameData` en gameplay (150 lookups) → solo frontera · `INTERNAL_MODE` en edificios → escenas instanciadas · `bake_body_scenes.gd` como fuente → congelar.

## (d) Choques honestos
Flora/pasto (rendimiento: MultiMesh con hilos) · áreas (orden de `body_entered` no estable: gizmo + consulta ordenada) · unidades/proyectiles/almas (los crea el servidor: la escena sí está en el editor; en el mapa solo puntos) · tags por red (frontera) · pools de partículas y luces (se quedan; vista previa `@tool`) · navmesh (botón).

## (e) Reglas nuevas C15–C21 (baseline de hoy)
| # | Regla | Baseline |
|---|---|---|
| C15 | Ningún nodo de contenido con `.new()` fuera de pools y vistas previas | 30 |
| C16 | Posiciones como nodos, nunca `Vector3.UP * altura` ni const de altura/offset | 57 |
| C17 | FX y sonidos por Resource, nunca por texto | 47 |
| C18 | Sin lookup texto→recurso en gameplay (solo spawners, red, catálogo) | 150 |
| C19 | Ningún `.tres` de `data/` guarda posiciones/offsets/transforms | 331 archivos (`debug/`: 740 offsets) |
| C20 | Radios de lugar/efecto en `CollisionShape3D`, no en `MatchRules` | ≈14 |
| C21 | Referencias tipadas, no `@export_file` | 14 |

## (f) Orden actualizado
0 · 055-0b C15–C21 en el lint → 1 · 055d-d2 ampliado (ítems 11, 12, 13, 16 + edificios como escenas) → 2 · 059b/059c (nacen con la forma nueva) → 3 · 055d-d3 + d4 sin `PropSet` → 4 · 055c1 + escena heredada por criatura → 5 · 055s sockets → 6 · 055c2–c5 → 7 · 055x FX tipado → 8 · 055r reach → 9 · 055e (+ proyectiles en escena, estructuras propias) → 10 · 055f, 055g (+ marcadores del ritual) → 11 · 055k cámara (puede adelantarse) → 12 · 055q banco en escena.
