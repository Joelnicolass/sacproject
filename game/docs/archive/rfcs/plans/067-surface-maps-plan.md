Estado: **aprobado 2026-10-26** con las 5 recomendaciones de §17: pilotos primero y lote después de verlos en surface_lab; la receta no se guarda (el PNG es la fuente); por defecto solo normal, ORM opcional; mapas en `assets/surfaces/<owner>/` (contenido propio junto a su albedo); el addon nace genérico y va al kit después de los pilotos. El addon es de editor: no forma parte del juego ni del export.


# RFC propuesto: superficies PBR opcionales en todos los modelos (RFC-067)

No toqué el repo ni corrí Godot. El ID está libre (las RFCs y los planes llegan hasta 066). Corrí `bash tools/lint/conventions.sh` solo para tener la base de hoy:
- **C1a** = 83, **C13** = 2.
- **C19 ya está en FAIL (+1) en este worktree.** No lo causa este plan: el ofensor nuevo es `data/look/sky/aurora_gradient.tres`, de la 058 en paralelo.
- Hay 23 `.import` de texturas modificados sin commitear (pasaron de lossless a VRAM por detect_3d). Son ajenos a este RFC y no hay que mezclarlos en sus commits.

## 0. Estado real

**La premisa de que hoy los modelos tienen texturas planas es solo media cierta.** Todo lo que es malla ya usa un `StandardMaterial3D` iluminado, con `roughness = 0.85`, metallic 0 y las normales de los vértices. Eso incluye criaturas, magos, Sac Doctor, aldeanos, edificios, ruinas, rocas, props y árboles o plantas de flora. Lo que falta es solo el contenido: ningún material tiene normal, ORM ni emisión. `StandardMaterial3D` ya es el material PBR de Godot, así que no hace falta un shader nuevo.

**Un solo lugar para todos los modelos.** Son 822 archivos en `scenes/bodies/materials/<owner>_<label>.tres`, uno por textura, compartidos.
- Los modelos esqueletales lo enganchan con `surface_material_override/N` en `scenes/bodies/models/<name>_model.tscn`. El Trogg, por ejemplo, usa `eorc_001..005.tres`.
- Las mallas `.res` de props, edificios y plantas guardan el material dentro de la superficie: `scenes/props/meshes/casp.res` apunta a `casp_M000.tres`, y lo mismo `pcr2.res` y las plantas `*_plant_cutout.tres`.
- Los albedos están en `assets/original/textures/<owner>/<NNN|M00x|plant>.png`. Son 837 PNG que suman unos 55 Mpx; la mayoría mide 256² y el más grande 512×635. Se importan lossless con mipmaps.
- Ningún importador reescribe los `.tres`: `import_props.py` solo nombra la etiqueta. Hoy se editan a mano.

**Tangentes.**
- Los `.glb` animados (`assets/original/models/*.glb.import`) se importan con `meshes/ensure_tangents=true`, así que están bien.
- Las mallas guardadas no deberían tenerlas. 325 de los props `.glb` tienen `ensure_tangents=false` (está anotado en el CHANGELOG). Esas mallas son las 306 de `scenes/props/meshes/*.res` y las 11 híbridas de `scenes/bodies/meshes/*.res`.
- **NO VERIFICADO:** el bit `ARRAY_FORMAT_TANGENT` de esos `.res`, y qué hace Godot 4.7 con un `normal_texture` sobre una malla sin tangentes. Se mide en P3.

**Quién escribe materiales en partida.** Cada uno sobre su propia instancia; ninguno muta los `.tres` compartidos:

| Escritor | Qué hace | Con un normal map en la fuente |
|---|---|---|
| `scenes/look/stone_look.gd` (dueño: Afflictions) | Arma un `ShaderMaterial` de `stone.gdshader` y copia solo el albedo, el color y el scissor | **Pierde el relieve** |
| `scenes/structures/reveal/build_reveal.gd` | Lo mismo con `build_reveal.gdshader` | **Pierde el relieve** |
| `scenes/bodies/see_through_look.gd` | Duplica el material y lo pasa a unshaded | Da igual (unshaded) |
| `scenes/look/vegetation/flora_material.gd` | Duplica el material y le pone `vertex_color_use_as_albedo` | Lo conserva solo |
| `scenes/fx/blood/hit_flash.gd` (060) | Pone un `material_overlay` aditivo encima | No le afecta |

**El suelo ya soporta PBR.**
- `GroundRole` (`scenes/look/ground/ground_role.gd`) tiene `normal` y `orm` opcionales, donde **B = altura**. Los lee el `ground.gdshader` único de la 062.
- Hoy ningún rol de ningún dios carga esos mapas: `data/look/persephone.tres` solo tiene albedo y detail.
- La 062-3 borra `sacrifice_ground.gdshader` y `ground_pbr.gdshader`. No se agrega nada al suelo clásico; el suelo usa los slots que ya tiene.

**Contenido propio desde Blender.** Ya trae PBR completo. glTF lleva normal, metallicRoughness, occlusion y emissive, Godot los convierte en `StandardMaterial3D` al importar, y `tools/bake/new_creature.gd` no pisa materiales. No necesita nada del original. Solo falta documentarlo en `docs/HOWTO.md`.

**Herramientas que ya existen.**
- No hay ningún generador de normales desde el albedo: `grep bump_map_to_normal_map` da 0.
- `tools/material/mm_export.sh` y `mm_gen_grass.py` exportan grafos `.ptex` de Material Maker con la app instalada en la Mac. Sirven para materiales procedurales (`assets/mm/`), no para procesar 837 albedos en lote, y no son portables.
- `tools/look/*` mide (`cloud_stats`, `make_tileable`, `measure_void`).
- `tools/blender/*` es solo de terreno y de la criatura de prueba.
- Ya hay dos addons de editor excluidos del export: `addons/sacrifice_tools` y `addons/terrain_tools`. `export_presets.cfg` tiene **un solo preset** (`dedicated_server`) con `exclude_filter="addons/sacrifice_tools/*, addons/terrain_tools/*, …"`. `DedicatedStrip` dice que Godot ya convierte las texturas en placeholders en modo dedicado.

**Lo que no son mallas.** Las almas son billboards con un `ShaderMaterial` propio (`scenes/souls/soul.gd`), y las partículas, rayos y cicatrices también son sprites. Quedan fuera.

## 1. Contradicciones y quién gana

| # | Choque | Gana | Qué hacer |
|---|---|---|---|
| 1 | VISUAL.md, sección Assets, dice que normales y AO «van al caché, no a git» | RULES (2026-10-17, LFS), RFC-033 y la memoria `cache-off`, más la decisión del usuario de hoy (el juego lee los mapas resultantes) | Reescribir esa línea de VISUAL |
| 2 | La memoria `minimal-source-of-truth` contra guardar los PNG generados | **Se guardan los PNG.** Lo pidió el usuario («poder cargarlas») y el juego no puede depender del generador. Un normal map es una imagen que un humano retoca en Krita: es dato editable, no una sopa derivada. Un modelo sin generar sigue teniendo como única fuente su albedo | La receta no se guarda (pregunta 2) |
| 3 | RFC-022 022g planeaba `SurfaceLook`, `surface_library`, `body_material.gd` y `body_pbr.gdshader` con tangentes por derivadas | Este plan. RFC-023 dejó una malla única con tangentes y los materiales compartidos | Marcar 022g como reemplazada por 067 |
| 4 | El plan 062 §6 dejaba fuera generar normales del albedo con Material Maker | El pedido nuevo | Se hace con este addon, no con MM |
| 5 | El ORM del suelo es (AO, rugosidad, **altura**) y el de Godot es (AO, rugosidad, **metal**) | Se respetan los dos | El generador empaqueta B según el destino. No se toca `GroundRole` (062-3 en curso) |
| 6 | El pilar de VISUAL «Remaster, mapas de normales» contra las memorias `original-look-is-target` y `original-glow-is-additive-sprites` | El original manda por defecto | Todo es opcional y por material. El generador arranca con intensidad baja, rugosidad constante 0.85 y metallic 0 (VISUAL: nada de brillo plástico). La emisión va solo a mano y por debajo del umbral de glow 1.0 |
| 7 | La regla de editar en las escenas reales | Se cumple | La herramienta de edición es el inspector del material real; el addon solo agrega botones |

## 2. Objetivo y criterios medibles

- **C1. Sin mapas, nada cambia.** Un modelo sin mapas se ve como hoy. La captura de cámara fija de `surface_lab`, fila «sin mapas», da 0 px de diferencia contra la de antes del RFC. Esto incluye StoneLook y BuildReveal sobre un modelo sin mapas.
- **C2. Con mapa generado se ve el relieve.** Con luz rasante (15° de elevación), la media del laplaciano de la luminancia dentro de la máscara del modelo sube ≥ 15 % frente a la misma vista sin mapas. Sin píxeles NaN ni negros (luminancia ≤ 2/255) que no estén en la versión sin mapas.
- **C3. Un mapa opcional que falta no rompe nada.**
  - Un caso headless recorre `scenes/bodies/materials/*.tres`: toda textura referenciada existe, y `normal_enabled` implica `normal_texture != null` (lo mismo para AO, rugosidad y emisión). 0 fallos.
  - Al quitar los mapas con el botón no queda ninguna referencia colgada.
  - Godot sí da error si un `.tres` apunta a un PNG borrado. Por eso se exige el validador en vez de prometer «nunca da error».
- **C4. Petrificar o revelar conserva el relieve.** En un Trogg con mapas, StoneLook y BuildReveal mantienen el relieve: el laplaciano sube ≥ 10 % frente a la versión sin mapas en la fila de piedra.
- **C5. El juego no depende del generador.**
  - `grep -r "addons/surface_maps\|ReliefBaker\|ReliefRecipe" scenes data` da 0.
  - Un pack exportado del preset no contiene `addons/surface_maps/` (`unzip -l` o `--main-pack` con un probe).
  - El banco `quick` da igual (es solo presentación).
- **C6. El generador es determinista.** El mismo albedo con la misma receta da los mismos bytes dos veces. Un albedo plano da un normal de (128, 128, 255) ±1. Una rampa horizontal da el signo de X esperado (OpenGL, Y hacia arriba). El borde de un cutout no deja halo: los texels con alfa < umbral copian el vecino.

## 3. Escena de prueba: `res://debug/look/surface_lab.tscn`

- **Qué instancea.**
  - `scenes/bodies/models/trogg_model.tscn`, `sac_doctor_model.tscn` y un mago (`scenes/wizards/bodies/eldred_look.tscn`).
  - `scenes/props/persephone_rock.tscn` y una planta (`scenes/map/props/plant.tscn` con una especie JAW).
  - La malla del edificio `scenes/props/meshes/casp.res` en un `MeshInstance3D`.
  - Un parche de suelo `terrain.tscn` con su propia copia de `ground_roles.png`, solo en P5.
- **Las tres filas.**
  - **Sin mapas:** override a `debug/look/surface_lab/flat/*.tres`, copias exactas de los materiales de hoy hechas en P4 antes de asignar nada.
  - **Producto:** los materiales reales, ya con mapas.
  - **Efectos:** un Trogg con un `StoneLook` y `stone = true`, y una casa con `BuildReveal` a medio revelar.
- **Luz y cámara.** Un `DirectionalLight3D` rasante y una `Camera3D` fija.
- **Estado inicial.** La luz está a 15° de elevación. Lo que todavía no está es el resultado del criterio: el relieve aparece en la fila del producto recién después de P4.
- **Acciones.** El playtester pulsa:
  - `debug_light_turn`: gira la luz 30° de yaw.
  - `debug_light_tilt`: alterna 15°, 45° y 75° de elevación.

  Las dos se agregan al InputMap; hoy solo existen `debug_hit`, `debug_gib` y otras.
- **Medición.** La captura la toma `agent/harness/` con la cámara fija y la mide `tools/look/measure_relief.py`: laplaciano y desvío por máscara, y diferencia contra la de antes.
- **Dónde queda registrada.** En el RFC-067 y en una F nueva de FEATURES.

## 4. Árbol de archivos ([+] nuevo, [~] cambia, [-] se borra)

```
game/addons/surface_maps/                      [+] addon GENÉRICO de editor (sin reglas de Sacrifice), excluido del export
  plugin.cfg                                   [+] "Surface Maps", dev only
  plugin.gd                                    [+] registra el inspector y Project > Tools > «Generar relieve…»; ajustes surface_maps/*
  relief_recipe.gd                             [+] ReliefRecipe (Resource, solo editor): strength, blur_px, flatten_px (paso alto), invert,
                                                   ao_strength, roughness (constante | desde luma), tile_cells (0 = no, N = variantes del rol), pack_b (metal|altura)
  relief_baker.gd                              [+] ReliefBaker (static, puro): Image albedo + receta -> {normal, orm}; luma -> paso alto -> blur
                                                   -> Image.bump_map_to_normal_map; cavidad = luma - blur; relleno del cutout; wrap por celda si tile_cells
  map_writer.gd                                [+] rutas (espejo assets/original/textures -> assets/surfaces, o al lado del albedo), PNG + .import
                                                   (compress VRAM, normal_map=1), reimport, asignación con EditorUndoRedoManager; nunca pisa sin «Sobrescribir»
  surface_inspector.gd                         [+] EditorInspectorPlugin para BaseMaterial3D y GroundRole: «Relieve desde albedo», vista previa, Generar / Quitar
  batch_dialog.gd / batch_dialog.tscn          [+] carpeta o selección del FileSystem, saltear existentes, progreso
  README.md                                    [+] What/Not/Talks to/Edit/Check + referencias
game/assets/surfaces/<owner>/<file>_normal.png [+] solo los generados o pintados (LFS); <file>_orm.png si se pidió
game/assets/surfaces/README.md                 [+] qué es fuente (el PNG, retocable), convención de nombres, no-pisa
game/scenes/look/surface_relief.gd             [+] SurfaceRelief (static, ≤40 líneas): forward(source: BaseMaterial3D, target: ShaderMaterial)
game/scenes/look/surface_relief.gdshaderinc    [+] uniforms relief_normal_tex/relief_normal_scale/use_relief + relief_apply() (NORMAL_MAP)
game/scenes/look/stone.gdshader                [~] #include del inc; llama relief_apply()
game/scenes/look/stone_look.gd                 [~] _stone_for llama SurfaceRelief.forward; balance de líneas ≤ 0 (ya está en C1a: 183)
game/scenes/structures/reveal/build_reveal.gdshader [~] #include + relief_apply()
game/scenes/structures/reveal/build_reveal.gd  [~] _reveal_of llama SurfaceRelief.forward (127 -> ~129)
game/scenes/bodies/materials/<pilotos>.tres    [~] P4: eorc_001..005, sacd_*, del mago, casp_M000, pcr2_M000, una JAW: normal_enabled + normal_texture (+ ORM)
game/scenes/props/meshes/*.res, scenes/bodies/meshes/*.res [~] P3: con tangentes (solo si el check dice que faltan)
game/assets/original/props/*.glb.import        [~] ensure_tangents=true (325)
game/tools/bake/bake_relief.gd                 [+] CLI --script: carpeta|material, --force, --recipe=… (usa ReliefBaker + MapWriter sin UI)
game/tools/bake/add_tangents.gd                [+] one-shot: SurfaceTool.generate_tangents por superficie; conserva AABB y materiales
game/tools/look/measure_relief.py              [+] laplaciano/desvío por máscara, diff contra la captura previa
game/debug/look/surface_lab.tscn (+ .gd ≤80)   [+] escena de prueba (§3)
game/debug/look/surface_lab/flat/*.tres        [+] copias planas de los pilotos (la base de C1)
game/debug/suite/surface_maps_cases.gd         [+] C3 (referencias, flags), tangentes de mallas con normal map, C6 (ReliefBaker)
game/export_presets.cfg                        [~] exclude_filter += "addons/surface_maps/*, assets/surfaces/*.import.src?" (ver §11)
game/project.godot                             [~] plugin habilitado + debug_light_turn/debug_light_tilt
game/docs/HOWTO.md                             [~] «Relieve (mapas PBR) de un modelo» y «PBR desde Blender»
game/VISUAL.md                                 [~] la línea «al caché, no a git» -> assets/surfaces (LFS), opcional
game/scenes/bodies/README.md, scenes/look/README.md [~] una línea Edit/Check cada uno
game/rfcs/RFC-067-surface-maps.md, FEATURES.md [+]/[~]
```

En `export_presets.cfg` el `exclude_filter` queda en `addons/sacrifice_tools/*, addons/terrain_tools/*, addons/surface_maps/*, …`. `assets/surfaces/` **no** se excluye: el juego lee esos PNG.

## 5. Árboles de nodos y recursos

```
<name>_model.tscn  (BodyModel)                 sin cambios de nodos
└─ Skeleton3D/<Mesh> surface_material_override/N -> scenes/bodies/materials/eorc_00N.tres
     StandardMaterial3D: albedo_texture (original, intacto) · normal_enabled · normal_texture · normal_scale
                         ao_texture(R) · roughness_texture(G) · [metallic_texture(B)] · emission(_texture) · heightmap (a mano)
Prop/edificio: Mesh (.res) -> material de superficie embebido -> el mismo .tres
GodGround (data/look/<dios>.tres) -> GroundRole.normal / .orm (B = altura)   ← misma herramienta, otro empaque
StoneLook / BuildReveal -> ShaderMaterial por fuente, con SurfaceRelief.forward(fuente)
```

## 6. Responsabilidades (un dueño por estado)

| Pieza | Hace | No hace |
|---|---|---|
| Material `.tres` | Único dueño del aspecto de una textura, con sus mapas | No sabe del generador |
| `ReliefBaker` | Imagen a imagen, puro y determinista | No escribe archivos |
| `MapWriter` | Escribe el PNG y su `.import` y asigna con undo | No calcula píxeles |
| `surface_inspector` y `batch_dialog` | La interfaz | No hacen lógica de píxeles |
| `SurfaceRelief` | Copia el relieve de la fuente a la copia de StoneLook y BuildReveal | No decide cuándo petrificar ni revelar |
| StoneLook (Afflictions) y BuildReveal | Siguen siendo los únicos que tocan sus overrides | — |
| `GroundRole` | Igual que hoy | — |

## 7. Resource, nodo o `@export`

- **Resource de tipo:** el `StandardMaterial3D` que ya existe, uno por textura. **No se crea un `ModelSurface` ni un `PbrMaps`**: duplicarían `StandardMaterial3D` y obligarían a leer dos lugares, contra las reglas de nada disperso y de no agregar capas.
- **`ReliefRecipe`:** Resource solo del editor, dentro del addon. Su valor por defecto vive en el script; no se guarda por modelo.
- **Convención por nombre** (`<file>_normal.png`, `_orm.png`): la usa **solo** el generador para elegir la ruta de salida. El juego nunca busca un archivo por nombre; sigue la referencia del `.tres` (regla C21).
- **`@export` de instancia:** ninguno nuevo en el producto. La escena de prueba tiene los suyos: `light`, `elevations_deg`, `yaw_step_deg`.

## 8. Cómo lo hace un humano

| Verbo | Cómo |
|---|---|
| **Entender** | Abrir `trogg_model.tscn`, elegir la malla y desplegar el override de superficie (`eorc_001.tres`): ahí están Albedo, Normal Map, AO y Rugosidad. Un solo lugar |
| **Agregar un normal map al Trogg** | Abrir `eorc_001.tres` en el inspector, sección «Relieve desde albedo», y pulsar Generar. Escribe `assets/surfaces/eorc/001_normal.png` y lo asigna; se repite en 002–005. O bien Project > Tools > «Generar relieve…» sobre `eorc_*`. Uno o dos lugares, sin código |
| **Modificar** | Retocar el PNG en Krita (se reimporta solo), o mover `normal_scale` en el inspector |
| **Quitar** | Botón Quitar, o limpiar el slot Normal Map del inspector. El PNG queda o se borra a mano; el validador avisa si queda colgado |
| **Crear (modelo propio)** | Exportar desde Blender con los mapas en el Principled BSDF: el `.glb` los trae. O generar sobre su textura extraída |
| **Escalar (todos)** | Correr el lote sobre `scenes/bodies/materials/` con «saltear existentes» |
| **Suelo** | `data/look/<dios>.tres` > Ground > Roles > Rock: Generar (modo tile-aware) o arrastrar el normal y el ORM de un set CC0 |
| **Encontrar un bug** | Correr `surface_maps_cases` (referencias, flags y tangentes) y abrir `surface_lab` con F6 en la fila del modelo. Si el relieve se ve invertido, usar `invert` en la receta o cambiar `normal_scale` de signo |

## 9. Contratos

- `ReliefBaker.bake(albedo: Image, recipe: ReliefRecipe) -> Dictionary`, con las claves `normal: Image` y `orm: Image` (esta última nula si no se pide). La salida tiene el mismo tamaño que la entrada y es RGBA8, con el normal en convención OpenGL.
- `MapWriter.write(material_or_role: Resource, maps: Dictionary, overwrite := false) -> PackedStringArray` devuelve las rutas escritas y nunca pisa sin `overwrite`.
- `SurfaceRelief.forward(source: BaseMaterial3D, target: ShaderMaterial) -> void` pone `use_relief`, el normal y la escala. Si la fuente no tiene normal, deja `use_relief = false`, y con eso el shader queda idéntico al de hoy (C1).
- El `.import` de cada mapa generado usa `compress/mode=2`, `compress/normal_map=1` para el normal y `mipmaps/generate=true`.

## 10. Cortes y paralelismo

| Corte | Qué | Depende de | Ventana |
|---|---|---|---|
| **P1** | Núcleo del addon (`ReliefBaker`, `ReliefRecipe`, `MapWriter`), el CLI `bake_relief.gd`, el filtro del export y la parte C6 de `surface_maps_cases` | — | No |
| **P2** | Inspector y diálogo de lote, con undo | P1 | Editor |
| **P3** | `SurfaceRelief` con su inc, StoneLook y BuildReveal, el chequeo de tangentes y `add_tangents.gd`, y la parte C3 del suite | — (en paralelo con P1) | No |
| **P4** | Pilotos (Trogg, doctor, un mago, casa, roca y planta), `surface_lab`, `measure_relief.py`, C1, C2 y C4 | P1, P3 | Sí, una pasada |
| **P5** | Roles del suelo (tile-aware, B = altura) | P1 y **la 062-3 integrada** | Sí |
| **P6** | Lote completo y documentación (HOWTO, VISUAL, README) | Visto bueno del usuario (pregunta 1) | No |

Godot se corre de a uno, como siempre.

## 11. Dedicado, web y rendimiento

- **Dedicado.** Godot ya convierte las texturas en placeholders y el addon está excluido. Los `.tres` siguen cargando sus referencias, ahora vacías. Sin RPC y sin cambio de determinismo.
- **Web y Compatibility** (rama `web-port` en `../sacproject-web`).
  - `StandardMaterial3D` con normal y ORM funciona en Compatibility y suma 3 samplers por superficie. El suelo ya va con `Texture2DArray`.
  - Para el normal en web hace falta `rendering/textures/vram_compression/import_etc2_astc=true` en ese worktree, porque BC5 no existe en móviles. Queda anotado para el merge.
- **Memoria.** Hoy el albedo es RGBA8 lossless: unos 55 Mpx × 4 B × 1,33 ≈ 295 MB si todo estuviera cargado.
  - Un normal BC5 cuesta 1 B/px, unos 73 MB si cada textura tuviera uno; un ORM BC1 cuesta 0,5 B/px, unos 37 MB.
  - En partida se carga solo lo del mapa y de los dos o cuatro dioses: calculo un 25–35 % de eso.
- **GPU.** RFC-022 estimó +0,4 ms. Se mide con `debug/look_bench.tscn` (60 cuerpos) antes y después de P6.
- **Presets.** No propongo un interruptor por preset en este RFC: apagar mapas en 822 materiales en partida crearía un segundo escritor. Si `low` no llega, el arreglo va en la importación (`process/size_limit` de los normales) en un corte aparte.

## 12. Riesgos

- **Luz pintada en el albedo.** Las texturas del original traen sombreado pintado, así que la altura sacada de la luma puede doblar la luz o invertir el relieve. Mitigación: paso alto (`flatten_px`), intensidad baja por defecto (0,3), `invert` por material y retoque manual.
- **Tangentes faltantes en props e híbridos** (NO VERIFICADO). Las cubre P3. Agregarlas cambia los bytes de los `.res` en LFS, no la AABB.
- **UV espejadas.** Pueden dar costuras; se miran en `surface_lab`.
- **Cutouts.** Halo en el borde del alfa; se mitiga con el relleno del baker.
- **Lote en GDScript.** La cavidad se calcula píxel a píxel; para 55 Mpx calculo 1–2 minutos. El normal sale en C++ (`bump_map_to_normal_map`).
- **Materiales compartidos.** Un material lo pueden compartir varios modelos (el índice guarda la textura bajo el primero), así que un mapa afecta a todos los que lo usan. Es lo que se busca, pero hay que avisarlo en el README.
- **Tamaño del repo.** Si se corre el lote entero, LFS crece unos 80–120 MB.

## 13. Fuera de alcance

- Almas, partículas, rayos, cicatrices y pasto (no son mallas con material).
- El suelo clásico `sacrifice_ground` (se borra en la 062-3).
- Un shader PBR propio.
- Parallax o heightmap generado para modelos (se puede cargar a mano en el inspector).
- Interruptor de calidad por preset.
- Renombrar `scenes/bodies/materials/` a algo neutro: hoy guarda los materiales de todos los modelos, pero eso es una mudanza aparte con `move_map.py`.
- Material Maker por consola: queda para materiales procedurales.

## 14. Solapes con el trabajo en paralelo

| Trabajo | Dónde choca | Qué hacer |
|---|---|---|
| 058 (`scenes/look/*`) | Misma carpeta que `stone_look`, `stone.gdshader` y los `surface_relief.*` nuevos, pero archivos distintos. Solo `scenes/look/README.md` choca | Merge trivial |
| 060 | `HitFlash` usa `material_overlay` y no toca superficies | Nada |
| 066 (`addons/terrain_tools`) | Es otro addon. Chocan dos líneas compartidas: los plugins habilitados en `project.godot` y el `exclude_filter` de `export_presets.cfg` | Integrar una después de la otra. 066c pinta `ground_roles.png`, que no choca con los mapas de rol |
| 062-3 | Reescribe los cinco `data/look/<dios>.tres` | P5 va recién cuando entre |
| Docs de `scenes/map/terrain` | Sin cruce | — |

## 15. Verificación sin test automático

1. Con F6 en `debug/look/surface_lab.tscn`, pulsar `debug_light_turn` y `debug_light_tilt`. La fila del producto muestra relieve que se mueve con la luz; la fila sin mapas queda igual. La fila de efectos muestra el Trogg de piedra con relieve.
2. En el inspector de `eorc_001.tres`, ver Generar, Quitar y la vista previa. Hacer Ctrl+Z.
3. Correr `surface_maps_cases` headless (rules_suite) y `measure_relief.py` sobre la captura fija para tener los números de C1, C2 y C4.
4. Exportar el preset dedicado y confirmar que no aparece `addons/surface_maps` (C5).
5. Correr `bash tools/lint/conventions.sh`: ningún conteo sube; StoneLook con balance ≤ 0 y el resto de scripts nuevos ≤ 150 líneas.

## 16. Referencias

- La documentación de `StandardMaterial3D` y `ORMMaterial3D` en Godot 4: normal OpenGL con Y hacia arriba, ORM con R = AO, G = rugosidad, B = metal.
- `Image.bump_map_to_normal_map(bump_scale)`, de la API de Godot.
- La importación de texturas en Godot: `compress/normal_map`. El importador de Godot 4 no convierte bump en normal: NO VERIFICADO del todo, por eso se usa la API de `Image`.
- NormalMap-Online (cpetry, MIT): Sobel o Scharr sobre altura en grises, con blur, intensidad e invertir. Es el mismo esquema de la receta.
- Los nodos «Normal Map» y «Occlusion» de Material Maker. Son la alternativa no portable.
- El renglón «Normales de lo original» de la tabla de técnicas de RFC-022 (luminancia suavizada, AO por cavidad, intensidad baja e invert por modelo).

## 17. Preguntas, cada una con mi recomendación

1. **¿Se corre el lote para todos los modelos (822 materiales, +80–120 MB en LFS) o se dejan los pilotos y se genera a pedido?** Recomiendo pilotos primero (P4), mirar `surface_lab` y después el lote con «saltear existentes».
2. **¿Se guarda la receta con la que se generó cada mapa?** Recomiendo que no. El PNG es la fuente y el generador nunca pisa sin «Sobrescribir». Guardarla sería un archivo más por textura o metadatos dispersos.
3. **¿El generador también saca un ORM (AO por cavidad y rugosidad desde la luma) o solo el normal?** Recomiendo solo el normal por defecto y el ORM opcional en la receta. Una rugosidad variable arriesga el brillo plástico que VISUAL prohíbe.
4. **¿Dónde van los mapas?** Recomiendo `assets/surfaces/<owner>/` espejando `assets/original/textures/`, para no mezclar archivos de los importadores, y al lado del albedo para el contenido propio.
5. **¿El addon nace genérico, con idea de subirlo al kit `godot-studio-skills` como RC, como `mp_kit` y las salas?** Recomiendo que sí, ya que no lleva reglas de Sacrifice, pero se sube recién después de P4.
