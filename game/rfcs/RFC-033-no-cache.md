# RFC-033 — Port sin caché

Estado: **cerrado (2026-10-17)**, cortes 033a–033i hechos; el juego y la simulación funcionan con `cache/` renombrada.
- **Pedido del usuario (2026-10-17):** «Hay que migrar todo. Modelos estáticos y texturas son simples de migrar». La versión final del port no depende de `game/cache/` (6,4 GB, ignorada por git). No hay nada repetido cientos de veces.
- **Decisiones previas:** `RULES.md` §Datos y el final de `RFC-023-skeletal-animation.md`:
  - los assets finales van a `game/assets/original/`, con git LFS para `.glb` y `.png`;
  - sus `.import` se versionan;
  - los WAD nunca se versionan;
  - los exportadores pasan a ser importadores, que se corren una vez.
- **Coordinación:** RFC-023 (en curso, 023a) es dueño de los modelos animados (`assets/original/models/<m>.glb`) y del retiro de `anim_f37`, que hace en 023h. Este RFC no los rehace.
- **Features:** propuesta F167–F175 (033a–033i). F161–F166 quedan reservadas por RFC-030. Las asigna el orquestador.
- **Autoridad:** PRD > FEATURES > RULES > VISUAL > RFC-023 (modelos animados) > este plan.

## 1. Objetivo (criterios de aceptación)

- **Sin `cache/` en runtime.** Ningún `.gd`, `.tscn` ni `.tres` de `scenes/`, `data/`, `debug/` o `addons/` nombra `cache/`. El juego lee solo `res://assets/...` y `res://data/...`.
- **Formato nativo de Godot.** Todo se carga con `load()`/`ResourceLoader`, sin `Image.load(globalize_path(...))` sobre carpetas con `.gdignore`:
  - texturas: `.png` importados;
  - modelos: `.glb`;
  - terreno: `.res`;
  - datos: `.json` versionados.
  
  Eso también deja exportable el proyecto, algo que hoy no se puede (§2.4).
- **Una copia por asset.** Cada textura es un archivo, compartido por todos los modelos e instancias que la usan. Cada modelo es un archivo. No quedan mallas por cuadro ni texturas por clip o por `.res`.
- **La simulación no cambia.** `agent/run_determinism.sh quick` da los digests de `agent/det_baseline.txt` en cada corte. `all` se corre en los cortes que tocan datos de simulación (033c, 033f, 033g) y en el cierre.
- **Lo visual no cambia.** Las capturas con cámara fija, antes y después, quedan dentro del umbral numérico de §8.0.
- **Cierre.** El juego arranca y juega con `cache/` renombrada a `cache.off`:
  - F5 en 1P;
  - el dedicado con un cliente;
  - los flows del banco.
  
  Además, el `rg` de §8 (033i) devuelve vacío.

## 2. Inventario (medido el 2026-10-17)

### 2.1 Qué hay en `cache/` (6,4 GB, 43 264 archivos solo en `look/`)

| Ruta | Tamaño | Archivos | Qué es | Lo genera |
|---|---|---|---|---|
| `look/anim_f37/<m>/<clip>/N.obj` (+`.import`) y `NNN.tga` | **5,0 GB** | 18 078 OBJ, 20 120 `.import`, 2 042 TGA | Una malla por cuadro de animación (68 modelos). Las texturas del modelo se copian en **cada carpeta de clip**. | `export_stats.py:_export_all_frames` (binario de sacengine) |
| `baked/clips/anim_f37/**.res` | **1,0 GB** | 18 078 | El mismo cuadro, horneado a `ArrayMesh` | `tools/bake_clips.gd` (027h) |
| `look/bodies/<m>/` (`.obj`, `NNN.tga`, `.SXMD`, `.SAXS`) | 290 MB | 1 411 (579 TGA) | Malla de bind y texturas de 84 cuerpos. Incluye los **archivos crudos del original** (SXMD/SAXS) | `export_bodies.py` |
| `baked/bodies/<m>.res` + `bodies.json` | 146 MB | 84 | Malla posada desde el cuadro 0 del idle o stance, **con su `ImageTexture` embebida** (RSCC). `bodies.json`: medidas (alto, radio, `foot_offset`, `upright_fix`) | `tools/bake_bodies.gd` |
| `baked/props/<p>.res` + `props.json` | 15 MB | 117 | Edificios, componentes BLDG y plantas, con textura embebida | `tools/bake_bodies.gd` |
| `look/buildings/<tag>/` (`.obj`, `M000.png`) | 5,3 MB | 46 modelos | Componentes de BLDG por dios | `export_stats.py` (buildings) |
| `look/persephone/{buildings,plants,models}/` + `catalog.json` + `sky*.png` | 6,4 MB | 56 + 28 + 1 | Props de Persephone, el catálogo del horneado y un cielo **duplicado** de `themes/persephone` (mismo md5) | `export_persephone.py` |
| `look/themes/<god>/` (`atlas`, `edge`, `sky`, `skyb`, `skyt`, `sun`, `undr` `.png` + `theme.json`) | 2,3 MB | 5 dioses | Tileset, cielo y colores ENVI | `export_tilesets.py` |
| `look/fx/<tag>.png` + `fx.json` | 1,1 MB | 37 | Atlas de partículas y su catálogo | `export_particles.py` |
| `look/{icons,hud,cursors,xmenu}/` | 0,9 MB | 178 + 12 + 22 + ~10 | HUD, iconos, cursores y menú X | `export_icons.py` |
| `look/{tiles,light}.png`, `look/height.exr` | 0,7 MB | 3 | Índice de tiles del mapa, luz horneada y alto para el pasto | `export_high_noon_look.py`, `bake_grass_height.gd` |
| `high_noon_terrain.bin`, `high_noon_ntts.json`, `high_noon_widgets.json` | 0,6 MB | 3 | Malla del terreno (`HNTR`), entidades NTTS y 720 widgets | `export_high_noon_{terrain,ntts,widgets}.py` |
| `data/*.json` | 1,2 MB | 8 | `creatures`, `spells`, `abilities`, `wizards`, `books`, `buildings`; `anim_mesh_clips_f37` (920 KB); `anim_clips_f36` | `export_stats.py` |
| `tick_{,move_,state_,advance_}ref.txt` | 16 KB | 4 | Referencias numéricas de sacengine para `debug/*_tick.tscn` | a mano, desde corridas de sacengine |
| **Legado de F1:** `james.obj`, `trogg.obj`, `peas.obj`, `look/roster.json`, `look/{atlas,ground,rock,sky,skyb,skyt}.png`, `look/{james,trogg,eorc}*` | ~5 MB | — | Primer corte del port | `export_high_noon_look.py` |

### 2.2 Por qué hay duplicación

- **Mallas por cuadro.** Son 18 078 OBJ más 18 078 `.res`, es decir, 6 GB para 68 modelos. RFC-023 lo reemplaza por un `.glb` con esqueleto por modelo.
- **Texturas copiadas.** Hay 2 641 TGA (632 MB) para **570 texturas únicas** (133 MB en TGA, **66 MB en PNG**, medido convirtiéndolas). Todas las únicas están en `look/bodies`; `anim_f37` no agrega ninguna.
- **Texturas embebidas.** Cada `baked/bodies/*.res` y `baked/props/*.res` guarda su propia `ImageTexture` cruda. En runtime el material se comparte por textura (`ObjMesh.material()`), pero en disco hay una copia por `.res`.
- **`.godot/imported` ocupa 10 GB.** Son 18 127 `.obj.mesh` de `anim_f37` (1,8 GB, porque `anim_f37` no tiene `.gdignore`) y 8,5 GB de `.png.ctex`, la mayoría de `agent/out/`, que tampoco tiene `.gdignore`. No está en git, pero es repetición pura.

### 2.3 Quién lee `cache/`

**Runtime**: el producto y el dedicado.

| Consumidor | Lee | Simulación |
|---|---|---|
| `scenes/data/game_data.gd:8` (`DATA_DIR`) | `data/{creatures,spells,abilities,wizards,books}.json` | **sí** |
| `scenes/world/map/map_building.gd:17`, `ai/perception/ai_perception.gd:24` | `data/buildings.json` | **sí** |
| `scenes/world/body_catalog.gd:11-14,145-146` (`BAKED_DIR`, `LOOK_DIR`) | `baked/{bodies,props}.json` (medidas: el dedicado arma cápsulas con ellas), `baked/*/*.res`, `clip_frame_path` | **sí** (medidas) |
| `scenes/world/terrain.gd:4,6,346,377` | `high_noon_terrain.bin`, `look/tiles.png`, `look/light.png`, el tileset del tema | **sí** (alto del suelo) |
| `scenes/world/map/{map_population,side_relations}.gd`, `map_props.gd:16` | `high_noon_ntts.json`, `high_noon_widgets.json` | **sí** |
| `scenes/world/components/clip_pose_player.gd:29`, `structures/structure_body.gd:8` | `data/anim_mesh_clips_f37.json` | no (lo retira 023h) |
| `scenes/world/obj_mesh.gd:132,166,207` | TGA/PNG con `Image.load(globalize_path)` y **`.SAXS` crudo** para el chroma key | no |
| `scenes/ui/wizard_preview.gd:5,44` (con `scenes/world/wizard.gd:7`) | OBJ de bind `look/bodies/<m>/<m>.obj` | no |
| `scenes/ui/hud_icons.gd:15-18,118`, `command_cue/{cursor_skin,cue_set,command_cue}.gd`, `wizard_stats/stat_bar.gd` | `look/{icons,hud,cursors,xmenu}` (`Image.load_from_file`) | no |
| `scenes/fx/fx_atlas.gd:10,33`, `sprite_particles.gd:7`, `teleport_rings.gd:26`, `souls/soul.gd:60`, `portal_*`, `tether.gd`, `guardian_tether.gd`, `beam_type.gd` | `look/fx/*.png`, `fx.json` | no |
| `scenes/world/god_theme.gd:7,9,35` y `data/themes/*.tres:10` (`cache_dir`) | `look/themes/<god>/*` + `theme.json` | no |
| `scenes/world/sky.gd:20-22` | `look/persephone/sky*.png` (el duplicado) | no |
| `scenes/world/look/ground/ground_material.gd:10`, `look/grass/grass_field.gd:17` | `look/light.png`, `look/height.exr` | no |

**Solo harness, debug y tools:**
- `debug/{idle,move_order,state,advance}_tick.tscn:14`, que leen `tick_*_ref.txt`;
- `debug/body_gallery.gd:5`, `debug/grass_lab_ground.gd:23`, y los mensajes de `debug/{nav_cases,ai_cases,terrain_normals_probe}.gd`;
- `agent/harness/{splash_probe,hud_cache_probe}.gd`, `agent/fixtures/pt73_probe.gd`;
- `agent/tools/f1{27,29,31,49,51,52,54,56}_expect.py`;
- todos los `tools/export_*.py`, `tools/bake_*.gd`, `tools/audit_body_pose.gd`, `tools/sample_grass_palette.py` y `tools/classify_ground_tiles.py`.

### 2.4 Hallazgos que condicionan el plan

1. **El `.gitignore` está roto para `assets/original`.**
   - `game/.gitignore:3` (`*.import`) le gana a la negación `!game/assets/original/**/*.import` de la raíz. Un `.gitignore` más profundo tiene prioridad.
   - Verificado: `git check-ignore -v game/assets/original/models/eorc.glb.import` lo marca como ignorado por `game/.gitignore:3`.
   - Afecta también a 023a. Se arregla primero (033a).
2. **`.gitattributes` solo cubre `.glb` y `.png`** bajo `assets/original`. El `.res` del terreno (y un `.exr`, si quedara alguno) no iría por LFS.
3. **No hay `export_presets.cfg`.** El runtime lee imágenes con `ProjectSettings.globalize_path()` desde carpetas con `.gdignore`, algo que solo funciona con el proyecto abierto desde disco. Pasar a recursos importados es requisito del port final, no solo orden.
4. **El dedicado depende de `cache/`** para cuatro cosas: medidas de cuerpos y props, datos de juego, terreno y mapa. Después de 033g, el dedicado ya no depende de `cache/` (hito intermedio medible).
5. **`anim_clips_f36.json` no tiene lector** en `scenes/`. Es salida muerta de `export_stats.py:1058` y no se migra.

## 3. Destino por categoría

**Regla:** un importador por familia escribe en `assets/original/<familia>/` y en ningún otro lado. El juego nunca escribe ahí. Lo editado a mano vive en `data/`: overrides, temas, look. Los dos no se mezclan en el mismo archivo, así cada archivo tiene un solo dueño.

| Categoría | Destino final | Formato e import | Notas |
|---|---|---|---|
| **Texturas de modelos** (570 únicas) | `assets/original/textures/<model>/<NNN>.png` (una por textura, por modelo dueño; las 9 que se repiten entre modelos quedan en el primero y el índice apunta ahí) | PNG RGBA con el **chroma key de SAXS ya aplicado al alfa** por el importador. Import: `compress/mode=0` (lossless), `mipmaps/generate=true`, `process/fix_alpha_border=true`; sRGB por defecto | Reproduce `ObjMesh._build_material`: chroma → `fix_alpha_edges` → `generate_mipmaps`, RGBA8 sin compresión VRAM. Desaparece la lectura de `.SAXS`/`.SXMD` en runtime. Texturas de props (`M000.png`, plantas): mismo destino, `textures/<prop>/` |
| **Material** | — (código) | `ObjMesh.material(texture_path, label, chroma)` pasa a `OriginalMaterial.for_texture(tex: Texture2D, cutout: bool)`: uno por textura, compartido | Un solo dueño del material de todo modelo original: cuerpos (023), props y clips (mientras existan) |
| **Modelos estáticos** (117 props: componentes BLDG, edificios y plantas de Persephone) | `assets/original/props/<name>.glb` | glTF 2.0 binario **sin materiales** (como 023 §3.1), escrito en Python desde MRMM/SXMD; nombres de superficie = etiqueta de textura. Import: `meshes/ensure_tangents=true`, sin animación | Una malla por modelo, instanciada (`MeshInstance3D.mesh` compartida, como hoy `BodyCatalog._meshes`). El escritor glTF de `export_skeletal.py` se extrae a `tools/sac_formats/gltf_writer.py` (segundo caller) |
| **Medidas** (`bodies.json`, `props.json`) | `assets/original/models/sizes.json` | JSON versionado (texto, sin LFS), **copiado tal cual** en 033c | El dedicado las necesita sin mallas. Copiar los valores (no recalcular) garantiza el digest. Un recálculo futuro desde el `.glb` es otro corte, con paridad |
| **Cuerpos animados** (84) | `assets/original/models/<m>.glb` | — | **RFC-023.** 033 aporta texturas, material y medidas; 023 debe cubrir también los **16 cuerpos sin clips** (84 − 68) como `.glb` sin animaciones, para que haya un solo camino |
| **HUD, iconos, cursores, menú X** | `assets/original/ui/{icons,hud,cursors,xmenu}/<name>.png` | Import 2D: lossless, sin mipmaps, filtro según el `TextureFilter` actual del nodo | `HudIcons` usa `load()` y deja de llamar a `Image.load_from_file`. Cursores: `Input.set_custom_mouse_cursor` acepta `Texture2D` |
| **FX** | `assets/original/fx/<tag>.png` + `assets/original/fx/fx.json` | PNG lossless con mipmaps como hoy; JSON con rutas `res://assets/original/fx/` | Las `data/fx/*.tres` (`ParticleType`) siguen con su `key`. `FxAtlas` usa `load()` |
| **Temas (5 dioses)** | `assets/original/themes/<god>/{atlas,edge,sky,skyb,skyt,sun,undr}.png` + `assets/original/themes/<god>/envi.tres` | PNG; `envi.tres` = `GodEnvi` (Resource nuevo con los colores ENVI de `theme.json`), escrito por el importador | `data/themes/<god>.tres` (a mano: `sun_strength`, `look`) pasa de `cache_dir` a `envi: GodEnvi` + `dir`. Sale `look/persephone/sky*` (duplicado): `sky.gd` toma el cielo del tema |
| **Imágenes que se leen en CPU** (`atlas`/`edge` en `terrain.gd`, `tiles.png`, `light.png`) | `assets/original/maps/high_noon/{tiles,light}.png`; los atlas en `themes/` | **Import como `Image`** (`importer="image"`): exacto, sin sRGB, sin mips y sin compresión | `tiles.png` es un índice (canal R) y no puede pasar por mipmaps ni compresión |
| **Terreno** | `assets/original/maps/high_noon/terrain.res` | `MapTerrainData` (Resource: `vertices`, `normals` `PackedVector3Array`; `indices` `PackedInt32Array`), escrito por `tools/import_terrain.gd` desde el `.bin` del exportador Python (salida temporal fuera del repo) | Mismos float32 → mismo digest. La malla, las normales suaves y la grilla de celdas se **derivan al cargar**, como hoy. LFS por `*.res` |
| **Mapa** (NTTS, widgets) | `assets/original/maps/high_noon/{ntts,widgets}.json` | JSON versionado (texto) | Godot 4 exporta `.json` como recurso. Que el mapa pase a `.tscn` editable es RFC-018, fuera de alcance |
| **Datos de juego** | `assets/original/data/{creatures,spells,abilities,wizards,books,buildings}.json` | JSON versionado (texto, sin LFS) | `GameData.DATA_DIR` y los otros dos lectores apuntan acá. No se pasan a `.tres` en este RFC (pregunta 2) |
| **Refs de sacengine** (`tick_*_ref.txt`) | `agent/fixtures/sacengine/tick_*.txt` | Texto | Son fixtures de prueba, no assets del juego. Se cambian los 4 `.tscn` de `debug/` y los defaults de `*_check.gd` |
| **Altura del pasto** (`height.exr`) | no se guarda | — | Se deriva del terreno al cargar (§4) |
| **Legado de F1**, `anim_clips_f36.json`, `look/persephone/catalog.json`, `look/roster.json`, `.SXMD`/`.SAXS` | no se migra | — | Se borran con su exportador (033h) |

## 4. Derivado en runtime frente a guardado

| Se deriva al cargar (no se guarda) | Se guarda (importador, una vez) |
|---|---|
| Malla, normales suaves y grilla de celdas del terreno (`terrain.gd`, como hoy) | Vértices, normales e índices crudos del terreno (`terrain.res`) |
| Alto del pasto: se mueve el cálculo de `tools/bake_grass_height.gd` a `static func GrassHeight.from_terrain(data) -> Image`, que lee `grass_field.gd`. Hoy el pasto está apagado, así que no cuesta nada en el arranque | — |
| Material por textura (`OriginalMaterial`, cache en memoria) | El PNG con el alfa del chroma key ya aplicado. Hacerlo al cargar obligaría a leer SAXS crudo, que es lo que se quiere sacar |
| Librerías de animación por rol (023) | `.glb` por modelo (023) |
| AABB y encuadre de galerías | **Medidas de cuerpo y prop** (`sizes.json`): el dedicado no carga mallas y la simulación usa esos números |
| Rutas de textura por etiqueta (convención `textures/<model>/<label>.png`) | — |

**Criterio general:** se guarda lo que viene del original y no se puede recalcular sin la instalación, y lo que necesita el dedicado sin mallas. Se deriva todo lo que sale de eso en milisegundos.

## 5. Escena de prueba

No hay escena nueva: el criterio empieza en escenas que ya existen.
- **`res://debug/body_gallery.tscn`:** todos los cuerpos y props de `BodyCatalog.models()` en grilla. Sirve para 033b y 033c. Estado inicial: los modelos con textura. «Lo que todavía no está» se ve con `cache.off`: antes de 033b/c los props aparecen como relleno gris con el aviso de `body_visual.gd:70`; después aparecen texturados desde `assets/original`.
- **`res://debug/fx_gallery.tscn`** (033d) y **`res://debug/biome_gallery.tscn`** (033e, 033f): los cinco temas y el terreno.
- **Juego (`F5`):** el HUD con iconos, cursores y menú X (033d), y una partida 1P y una dedicada en el cierre (033i).
- **Sin acción de InputMap:** son capturas fijas. El playtester solo usa `ui_cancel` para salir.

Las capturas de referencia salen de un flow nuevo, `agent/flows/rfc033_shots.json`, que se arma en 033a sobre AgentKit con cámara fija:
- `body_gallery`, en 3 encuadres;
- `fx_gallery`;
- `agent/fixtures/biome_pick_<god>.tscn` × 5;
- `agent/fixtures/look_gallery_still.tscn`;
- el HUD en partida con el menú X abierto, con `--autostart` y en tick fijo.

La base se guarda en `agent/out/033/base/`, que no se versiona.

## 6. Árbol de archivos y responsabilidades

```text
game/
├── .gitignore                          # 033a: + "!assets/original/**/*.import"
├── assets/original/                    # LO ESCRIBEN SOLO LOS IMPORTADORES (LFS: .glb .png .res)
│   ├── README.md                       # qué importador genera cada carpeta y con qué comando
│   ├── textures/<model>/<NNN>.png(+.import)        # 033b
│   ├── props/<name>.glb(+.import)                   # 033c
│   ├── models/<m>.glb(+.import), index.json         # RFC-023
│   ├── models/sizes.json                            # 033c (bodies + props, copiado de baked/*.json)
│   ├── ui/{icons,hud,cursors,xmenu}/*.png(+.import) # 033d
│   ├── fx/<tag>.png(+.import), fx.json              # 033d
│   ├── themes/<god>/*.png(+.import), envi.tres      # 033e
│   ├── maps/high_noon/terrain.res, tiles.png, light.png, ntts.json, widgets.json   # 033f
│   └── data/*.json                                  # 033g
├── scenes/
│   ├── data/original_assets.gd         # NUEVO 033a: class_name OriginalAssets, único dueño de las raíces (const ROOT, textures(), props(), ui(), fx(), theme(god), map(name), data())
│   ├── world/original_material.gd      # NUEVO 033b: class_name OriginalMaterial (sale de ObjMesh.material/_build_material)
│   ├── world/obj_mesh.gd               # 033b: solo parseo OBJ mientras viva anim_f37 (023h lo borra); material -> OriginalMaterial
│   ├── world/body_catalog.gd           # 033c: sizes.json + props/*.glb; BAKED_DIR solo para cuerpos hasta 023
│   ├── world/god_envi.gd               # NUEVO 033e: class_name GodEnvi extends Resource (colores ENVI)
│   ├── world/god_theme.gd              # 033e: cache_dir -> dir + envi
│   ├── world/sky.gd                    # 033e
│   ├── world/terrain.gd                # 033f: @export var data: MapTerrainData (en vez de cache_path)
│   ├── world/map_terrain_data.gd       # NUEVO 033f: class_name MapTerrainData extends Resource
│   ├── world/look/grass/grass_height.gd    # NUEVO 033f: static from_terrain()
│   ├── world/look/grass/grass_field.gd, look/ground/ground_material.gd   # 033f
│   ├── world/map/{map_population,side_relations,map_building}.gd, map_props.gd, ai/perception/ai_perception.gd   # 033f/033g
│   ├── data/game_data.gd               # 033g
│   ├── ui/hud_icons.gd, ui/command_cue/*.gd, ui/wizard_stats/stat_bar.gd   # 033d
│   └── fx/{fx_atlas,sprite_particles,teleport_rings,portal_look,portal_disc,tether,particle_type,beam_type}.gd, world/souls/soul.gd, world/guardian/guardian_tether.gd   # 033d
├── data/themes/<god>.tres              # 033e: envi + dir
├── debug/*_tick.tscn                   # 033h: reference_path -> agent/fixtures/sacengine/
├── agent/
│   ├── fixtures/sacengine/tick_*.txt   # 033h
│   ├── flows/rfc033_shots.json         # 033a
│   ├── out/.gdignore                   # 033a (saca ~8 GB de .godot/imported en el próximo import)
│   └── harness/{splash_probe,hud_cache_probe}.gd, fixtures/pt73_probe.gd, tools/f1*_expect.py   # 033f-033h
└── tools/
    ├── sac_formats/gltf_writer.py      # 033c: extraído de export_skeletal.py (segundo caller)
    ├── sac_formats/textures.py         # 033b: SXTX/TGA -> PNG + chroma de SAXS (lo usan import_textures y export_skeletal)
    ├── import_textures.py              # 033b (reemplaza la parte de texturas de export_bodies.py)
    ├── import_props.py                 # 033c (fusiona la salida de props de export_persephone.py + export_stats.py buildings)
    ├── import_ui.py                    # 033d (renombra export_icons.py y export_particles.py y cambia su --out; uno o dos scripts según tamaño)
    ├── import_themes.py                # 033e (export_tilesets.py)
    ├── import_map.py + import_terrain.gd   # 033f (export_high_noon_*.py)
    ├── export_stats.py                 # 033g: --out assets/original/data; sale _export_all_frames con 023h
    └── check_original_assets.sh        # 033h (reemplazó a audit_original_assets.gd): regenera con cada importador --out y compara; antes: paridad contra cache/ mientras exista
```

**Responsabilidades (una por pieza):**
- **`OriginalAssets`:** el único que conoce rutas de `assets/original`. Renombrar o mover es un cambio de una línea, y el lint de §8 lo busca.
- **`OriginalMaterial`:** el único que arma el material de un modelo del original.
- **Importadores:** uno por familia. Leen la instalación (`INSTALL`) y escriben solo su carpeta. Son idempotentes: si se corren dos veces, `git status` queda limpio, así que la salida tiene que ser determinista (orden de claves, sin timestamps).
- **`tools/check_original_assets.sh`** (033h; antes `audit_original_assets.gd`, que comparaba contra `cache/` y se borró en 033h): regenera cada familia con su importador (`--out` a una carpeta temporal) y compara con `assets/original/`.
- **`data/`:** solo lo editado a mano. Nunca lo escribe un importador.

## 7. Resource, nodo, `@export`

- **Resources de tipo:**
  - `MapTerrainData` (un `.res` por mapa);
  - `GodEnvi` (un `envi.tres` por dios, generado);
  - `GodTheme` (`data/themes/<god>.tres`, a mano), que referencia `GodEnvi`.
  
  Ninguno se muta en runtime.
- **Nodos:** sin nodos nuevos.
  - `Terrain` recibe `@export var data: MapTerrainData`, asignado en el `.tscn` del mapa, y deja `cache_path` y `tileset_dir`.
  - `Sky` pasa a `@export var top: Texture2D` (o los toma del tema), en vez de rutas de archivo.
  - `MapProps` y `MapPopulation` reciben `@export_file("*.json")` con default de `OriginalAssets`.
- **Estáticos (`RefCounted`):** `OriginalAssets`, `OriginalMaterial`, `BodyCatalog` (ya existe) y `GrassHeight`.
- **Regla de los `.tscn`:** nada derivado se guarda (`owner = null`, como 023 §3.3). En review se hace un `rg` de `ExtResource` a `cache/` y de texturas embebidas.

## 8. Cortes (en serie)

### 8.0 Medición común

- **Simulación:** `agent/run_determinism.sh quick` en cada corte (igual a `det_baseline.txt`). En 033c, 033f, 033g y 033i se corre `all`.
- **Captura:** `rfc033_shots` contra `agent/out/033/base/`, con el diff de AgentKit (`agent_diff.gd`). Umbrales:
  - **2D** (HUD, iconos, cursores, menú X): **0 píxeles distintos**.
  - **3D** (galerías, biomas): máximo por canal ≤ 2/255 y ≤ 0,5 % de píxeles distintos. Si el import de Godot genera mipmaps algo distintos que `Image.generate_mipmaps()`, la diferencia tiene que quedar acá. Si no queda, el corte no pasa y se ajusta el import; no se sube el umbral.
- **Paridad de datos:** `audit_original_assets.gd` (headless; desde 033h, `tools/check_original_assets.sh`):
  - imágenes: `Image.get_data()` idéntico tras chroma;
  - vértices: ≤ 1e-5 m contra `baked/*.res`;
  - terreno: arrays idénticos.
- **Sin dependencia:** al final de cada corte, el `rg` de su familia da 0.
- **Godot:** de a uno, con `agent/harness/godot_run.sh`, según las reglas de la memoria.
- **Playtest:** con ventana solo en 033b–033f y 033i (hay cambios visibles). 033a, 033g y 033h cierran con banco y review.

| Corte | Qué | Criterio medible |
|---|---|---|
| **033a** Base | Arreglar `game/.gitignore` (`!assets/original/**/*.import`). `.gitattributes`: `game/assets/original/**/*.res` y `*.exr` por LFS. `agent/out/.gdignore`. `OriginalAssets` (vacío de consumidores). `assets/original/README.md`. Flow `rfc033_shots` y captura base **con `cache/`**. Anotar digests base | `git check-ignore` **no** marca `assets/original/x/y.png.import`; `git check-attr filter` da `lfs` para `.res`; existen las capturas base; `quick` igual |
| **033b** Texturas | `import_textures.py` (bodies + props) → `textures/`. `OriginalMaterial` usa `load()` de `Texture2D`. `ObjMesh` y `bake_*` dejan de leer TGA/SAXS. Si 023 ya tiene `BodyRig`, lo usa | Auditoría de imagen idéntica (570 + texturas de props); capturas 3D en umbral; `rg "\.tga\|SAXS\|SXMD" scenes` = 0; `quick` igual |
| **033c** Modelos estáticos | `gltf_writer.py` extraído; `import_props.py` → `props/*.glb` (117); `sizes.json`; `BodyCatalog` lee props `.glb` y medidas desde `assets/original`; `splash_probe.gd` | Paridad de vértices ≤ 1e-5 m (117/117); `body_gallery` en umbral; **`all` igual** (medidas y cápsulas); `rg "baked/props\|props.json"` = 0 |
| **033d** 2D: HUD y FX | `import_ui.py` → `ui/`, `fx/`; `HudIcons`, `FxAtlas` y consumidores con `load()`; `hud_cache_probe` apunta a una carpeta vacía de `assets` | HUD y menú X: **0 px**; `fx_gallery` en umbral; `rg "globalize_path" scenes/ui scenes/fx` = 0; `quick` igual |
| **033e** Temas y cielo | `import_themes.py` → `themes/`; `GodEnvi`; `data/themes/*.tres`; `sky.gd`; sale el cielo duplicado | `biome_pick_<god>` × 5 en umbral; `rg "cache_dir\|look/persephone"` = 0; `quick` igual |
| **033f** Mapa | `import_map.py` + `import_terrain.gd` → `maps/high_noon/`; `MapTerrainData`; `Terrain.data`; `tiles` y `light` como `Image`; `GrassHeight.from_terrain`; `ntts` y `widgets` | Terreno: arrays idénticos; `GrassHeight` = `height.exr` (máximo de diferencia 0); **`all` igual**; `biome_gallery` en umbral; nav (`debug/nav_cases`) PASS |
| **033g** Datos | `export_stats.py --out assets/original/data` (sin `anim_*`); `GameData`, `map_building`, `ai_perception`, `body_gallery`, `audit_body_pose`, `agent/tools/*_expect.py` | Los JSON son byte a byte iguales a `cache/data`; **`all` igual**; **dedicado headless s7 con `cache.off` = mismo digest** (hito: el servidor ya no usa la caché) |
| **033h** Refs, legado y tools | `tick_*` a `agent/fixtures/sacengine/`; se borran el legado de F1, `export_high_noon_look.py`, `anim_clips_f36` y los `--out` por defecto a `cache/`; `sample_grass_palette.py` y `classify_ground_tiles.py` leen `assets/original`; `wizard.gd` y `wizard_preview` se van con 023 (si 023 no llegó, `wizard_preview` usa la malla de `BodyCatalog`) | `debug/*_tick.tscn` PASS; `rg "cache/" tools/*.py` solo en comentarios de historia (o 0); `quick` igual |
| **033i** Cierre (**después de 023h**) | Se borran `BodyCatalog.BAKED_DIR`/`clip_frame_path`, `bake_bodies.gd` y `bake_clips.gd`. `mv cache cache.off` | `rg -n "cache/" scenes data debug addons project.godot --glob '!*.md'` **vacío** (y `res://cache` en `agent/harness agent/fixtures`); F5 1P y dedicado + cliente con `cache.off`; banco `all` y flows PASS; `rfc033_shots` en umbral; `du -sh .godot/imported` anotado |

**Orden.** Es el de la tabla: empieza por lo simple (texturas y modelos estáticos), como pidió el usuario. 033d y 033e son independientes entre sí. 033g puede adelantarse si el dedicado lo necesita antes. Solo 033i espera a 023h.

## 9. Coordinación con RFC-023

- **Antes de 023a: arreglar el `.gitignore`.** Hoy los `.glb.import` de 023a quedarían fuera de git. 033a es un cambio de una línea y conviene hacerlo antes o junto con 023a.
- **Texturas y material:** son de 033b (`OriginalMaterial`). `BodyRig` (023c) lo usa en vez de `ObjMesh.material`. Si 023c llega antes, usa `ObjMesh.material` y 033b lo cambia en un solo lugar.
- **Escritor glTF:** se extrae en 033c. Si 023 lo está editando, 033c espera a que 023 cierre su corte para no tener dos escritores del mismo archivo.
- **Cuerpos sin clips (16):** los cubre 023, como `.glb` sin animaciones. Hay que decirlo en 023a.
- **Medidas de cuerpos:** `sizes.json` (033c) es la fuente de medidas. Si 023 recalcula medidas desde el `.glb`, tiene que dar los mismos números o el digest cambia; eso es otro corte, con paridad.
- **Retiro:** 023h retira `anim_f37`, `baked/clips`, `baked/bodies`, `clip_pose_player` de mallas y `anim_mesh_clips_f37.json`. 033i cierra después.

## 10. Tamaño estimado del repo (LFS)

| Qué | Estimado | Base |
|---|---|---|
| Texturas de modelos (570 únicas en PNG) | **~66 MB** | Medido, convirtiendo los TGA únicos |
| Resto de PNG (UI, FX, temas, props, mapa) | ~9 MB | Medido: 9,7 MB únicos, menos el legado |
| Props `.glb` (117) | ~2–3 MB | Los OBJ de texto suman 4,9 MB; el binario es más chico |
| Cuerpos `.glb` (RFC-023) | 30–80 MB | **Sin medir**; 023a lo mide con `eorc` y `jnwr` |
| Terreno, mapa y datos JSON | ~1,5 MB | Medido (`.bin` 564 KB; JSON ~0,9 MB sin `anim_*`) |
| `.import` (~1 000) | ~1 MB | Texto |
| **Total `assets/original`** | **~110–160 MB** | Contra 6,4 GB de `cache/` (40–60× menos) |

Ya hay en LFS 109 MB de `assets/cc0` y `assets/mm`. Cada regeneración de texturas o modelos agrega una versión entera al historial de LFS.

## 11. Riesgos

- **`.import` y UIDs:**
  - el primer import de Godot escribe `uid=` en cada `.import` y los `.tscn` y `.tres` referencian por `uid://`;
  - si un importador borra y recrea un `.png.import`, el UID cambia y se rompen las referencias;
  - **los importadores no tocan un `.import` existente** (solo lo crean si falta, con las opciones de §3). La review chequea que `git diff` no muestre UIDs nuevos en un re-import.
- **Rutas en `.tscn`:** las rutas viejas a `cache/` en `.tscn`/`.tres` (hoy solo `debug/*_tick.tscn` y `data/themes/*.tres`) se cambian a mano en el corte. Al guardar desde el editor no puede aparecer ninguna textura embebida (lo chequea el `rg` de review).
- **Diferencia del import:** la diferencia entre el import de Godot (mipmaps, `fix_alpha_border`) y el pipeline actual en CPU puede mover píxeles. Lo mide el umbral de §8.0. Plan B, sin subir el umbral: import como `Image` y armar la `ImageTexture` en `OriginalMaterial` igual que hoy (cuesta CPU al cargar, pero da el mismo resultado).
- **Determinismo:** medidas, terreno, datos y mapa alimentan la simulación. Por eso se copian valores en vez de recalcularlos, se usan los mismos float32 y JSON byte a byte iguales. `all` en esos cortes.
- **Licencia (sacengine GPL-3):** los importadores se escriben **desde el formato**. sacengine es solo lectura, para entender el formato; no se copia código. Todo lo que salga de `tools/sac_formats/` lo revisa la review contra esa regla. `_export_all_frames` (que ejecuta el binario de sacengine) desaparece con 023h.
- **Arte del original en git:** el usuario ya lo decidió (RULES §Datos). El riesgo es la visibilidad del remoto: el repo tiene que ser privado (pregunta 3).
- **LFS:** cuota y ancho de banda del host. El importador idempotente evita versiones basura.
- **Godot de a uno:** el banco, las auditorías y las capturas corren con `godot_run.sh`. Las auditorías son headless y cortas.
- **`.godot/imported`:** el primer import de `assets/original` (~800 archivos) tarda. Se hace una vez, con el editor cerrado.

## 12. Fuera de alcance

- **Modelos animados, clips, `BodyRig` y el retiro de `anim_f37`:** RFC-023.
- **Mapa editable como `.tscn` y otros mapas:** RFC-018 o futuro.
- **Pasar `creatures`/`spells` a `.tres` por tipo:** pregunta 2, en un RFC aparte.
- **`MultiMesh` para los 720 widgets:** rendimiento, RFC-027.
- **Normales y AO de modelos:** 022g.
- **Pasto:** queda apagado (decisión del 2026-10-17); 033f solo saca su dependencia de `height.exr`.
- **Crear `export_presets.cfg` y exportar el juego:** este RFC lo destraba, pero no lo hace.

## 13. Cómo verifica un humano

1. **En el FileSystem del editor:** abrir `assets/original/textures/eorc/001.png`, que se ve con transparencia donde iba el chroma key. Abrir `props/bld1.glb`, que muestra la malla en la vista previa del import.
2. **F6 en `debug/body_gallery.tscn`:** todos los modelos texturados. Repetir con `cache` renombrada después de 033c: los props siguen bien y los cuerpos dependen de 023.
3. **F6 en `debug/biome_gallery.tscn`:** cinco dioses, igual que antes. Inspector de `data/themes/pyro.tres`: tiene `envi` y no tiene `cache_dir`.
4. **F5:** HUD con iconos, cursores y menú X.
5. **Cierre:** `mv cache cache.off`, F5 en 1P y una partida contra el dedicado. Guardar cualquier `.tscn` y correr `git diff`: no aparece `cache/` ni texturas embebidas.

## 14. Preguntas abiertas (con recomendación)

1. **Qué hacer con `cache/` al cerrar.** (a) Borrarla después de 033i y de una semana sin uso **[recomendado]**; (b) dejarla como respaldo local, sin lectores; (c) borrarla por familia al cerrar cada corte.
2. **Datos de juego en JSON o en `.tres`.** (a) JSON versionado ahora, `.tres` por tipo en un RFC aparte si el technical artist necesita editarlos en el inspector **[recomendado]**: JSON byte a byte da el mismo digest gratis. (b) Pasar ahora a `.tres` por criatura y hechizo (cientos de archivos, más riesgo de digest).
3. **Visibilidad del remoto.** El arte del original va a LFS. (a) Repo privado, sin tocar más nada **[recomendado]**; (b) un submódulo privado `assets-original` aparte, si el repo principal llega a ser público.

## Decisiones del orquestador (2026-10-17, cola delegada)
- Se aplican las tres recomendaciones: `cache/` se borra recién una semana después de 033i, y antes de borrarla se le pregunta al usuario; los datos siguen en JSON en este RFC (`.tres` en otro RFC); el repo sigue privado y sin remoto público.
- Features F167–F175 para 033a–033i, en ese orden.
- El arreglo de `.gitignore` para `assets/original/**/*.import` ya entró con 023a; 033a suma `.res` a LFS.
- Orden de la cola: 023a (en curso) → 033a → 033b → 033c → … ; RFC-023 sigue en paralelo solo en planes, nunca dos developers a la vez.

## 033a: Resultado (F167)

- **LFS y git:** `.gitattributes` de la raíz suma `game/assets/original/**/*.res` y `*.exr` (`git check-attr filter` da `lfs`; `.json` queda sin filtro). `git check-ignore game/assets/original/x/y.png.import` ya no lo marca (el arreglo de `.gitignore` entró con 023a). Se agregó `!agent/out/.gdignore` en `game/.gitignore` y en el `.gitignore` de la raíz (ambos ignoraban `agent/out/` entero) para que el `.gdignore` se versione.
- **`.gdignore`:** `agent/out/.gdignore` (versionado) y `cache/look/anim_f37/.gdignore` (la caché no está en git). `ClipPosePlayer` y `ObjMesh` leen esos OBJ con `FileAccess`/`ResourceLoader`, que siguen funcionando.
- **`OriginalAssets`** (`scenes/data/original_assets.gd`): raíz y helpers por familia (`texture`, `prop`, `model`, `ui`, `fx`, `theme`, `theme_envi`, `map`, `data`). Sin consumidores todavía. `assets/original/README.md` lista importador y corte por carpeta.
- **Capturas base** (con `cache/`, 1280x720, `--max-fps 60`, una corrida): `agent/out/033/base/` (16 PNG, no versionadas) con `bash agent/run_rfc033_shots.sh base` (el corte siguiente corre `after` y diffea con AgentKit). Flow: `agent/flows/rfc033_shots.json`; harness `agent/harness/rfc033_view.gd` (encuadre ortográfico fijo y `hide_log`).
- **`.godot/imported`:** el `.gdignore` solo no purga lo ya importado (un `--import` no cambió nada: 10 GB). Se movieron (no se borraron) 44 182 entradas de `agent/out` y `anim_f37` a `.godot/imported_orphans_033a/` (4,2 GB): **10 GB → 5,8 GB**. Los 5,8 GB restantes son huérfanos de archivos ya borrados que no se pueden mapear por ruta; solo una purga total y reimport los saca. Borrar `imported_orphans_033a/` es decisión del usuario.
- **Banco:** `agent/run_determinism.sh quick` = QUICK PASS contra `det_baseline.txt`.

**Desvíos del plan:**
- El HUD en partida usa `debug/orders_group.tscn` con `check_tick` y `order_menu`, no `--autostart` en tick fijo: su texto de depuración trae `frame_ms`, que cambia cada corrida; `hide_log` lo apaga para llegar a 0 px.
- No se midió el piso de ruido entre dos corridas iguales (3D, `fx_gallery`, con partículas): 033b conviene que corra `base` dos veces para fijarlo antes de aceptar el umbral de §8.0.

## 033b: Resultado (F168)

- **Importador:** `tools/import_textures.py` (con `tools/sac_formats/textures.py`) escribe `assets/original/textures/<owner>/<NNN>.png` + `.png.import` + `textures/index.json`. **670 PNG únicos: 570 de cuerpos (65,7 MB, como estimaba el plan) y 100 de props (7,3 MB)**, 73,0 MB en total y 0,6 MB de `.import`, 63 KB de índice. Son 201 modelos (84 cuerpos + 117 props) y 701 etiquetas; 54 texturas con alfa (chroma aplicado al canal alfa; los opacos van en RGB). Idempotente: la segunda corrida da 0 escritos; un `--import` y un segundo `--import` dejan los `.import` (UID) intactos. El índice (`model` en minúsculas → etiqueta OBJ → `{owner, file, cutout}`) resuelve las 9 repetidas y los nombres con distinto caso (`YOGO`/`yogo`). Las 2 042 TGA de `anim_f37` no aportan nada: su contenido está todo entre las de `look/bodies`.
- **Material:** `scenes/world/original_material.gd` (`OriginalMaterial`): `for_label(model, label)`, `for_part(model, i)` (superficie i de un `.glb` de RFC-023 = parte i = etiqueta `bodypart(i+1)`), `apply_to(root, model)` (pone los materiales compartidos en un `.glb`, que no trae), `for_texture(tex, cutout)`, `model_of(obj_path)`. Un material por textura, compartido. `OriginalAssets.texture_index()` es el dueño de la ruta del índice.
- **Consumidores migrados:** `ObjMesh` (ya no lee TGA, PNG vecinos ni SAXS; nombra cada superficie con su etiqueta; `build(path, options)` sin el parámetro de textura de reserva), `ClipPosePlayer._baked_frame`, `wizard.gd` (se quitó el `@export texture_path`, sin usos), `tools/bake_clips.gd` (usa el nombre de superficie), `bake_bodies.gd`, `audit_body_pose.gd`. `rg "\.tga|SAXS|SXMD" scenes` = 0. Los `baked/*.res` existentes no se re-hornearon (siguen con su textura embebida; si se re-hornean, referencian los PNG en vez de embeberlos).
- **Paridad de imagen** (`tools/audit_original_assets.gd`, headless): 701/701 etiquetas, todos los niveles de mipmap idénticos a la tubería vieja (TGA/PNG, chroma de SAXS, `fix_alpha_edges`, mipmaps), salvo ±1 en el **alfa** de los mips chicos en 3 texturas (el importador redondea distinto; nunca se muestrea en pantalla; nivel 0 y color exactos). Banderas `cutout` coinciden. `ObjMesh.build` sobre `eorc`, `bld1` y `PCF1`: superficies con nombre y material compartido.
- **Cambio visible que no es regresión del importador:** el chroma solo se aplicaba en runtime a los cuerpos sin clips (el OBJ junto a su SAXS); los cuadros de clip y los cuerpos horneados desde un cuadro no lo recibían. El PNG lo trae para todos, como pide el plan, así que **19 etiquetas de 17 modelos con clips** (`adrg bugz dcak ddiz ddmn drag ehbt fcak fdrg fhbt hero lhbt sbob shkt sprg sprl xwiz`) se ven distinto en los cuadros de clip que antes. Los `baked/bodies/*.res` de esos modelos siguen con la textura sin chroma hasta que se re-hornee o llegue 023: hasta entonces el cuerpo quieto y el cuadro animado pueden diferir en esas partes. Ninguna captura de `rfc033_shots` muestra esos modelos.
- **Piso de ruido (base × 4 corridas idénticas, `agent/tools/rfc033_diff.py floor`):** `body_gallery_*` = 0 px; el resto ruidoso por partículas y polvo sin semilla, y por un ruido difuso global del render. Píxeles con delta > 2/255, máximo entre pares: `biome_charnel` 94 761, `biome_james` 46 561, `biome_persephone` 150 677, `biome_pyro` 54 234, `biome_stratos` 20 218, `fx_gallery` 734 534, `hud_attack_armed` 73 616, `hud_group` 51 498, `hud_xmenu` 63 103, `look_gallery_horizon` 161 159, `look_gallery_ref` 120 387, `look_gallery_rts` 40 508 (delta máximo por canal hasta 240 en `fx_gallery`, 172 en `persephone`). **El criterio «HUD 0 px» de §8.0 no se puede cumplir con esta captura:** el HUD en partida tiene 51–74 mil px de ruido propio porque el mundo de atrás es ruidoso. Umbral fijado: **after ≤ piso de la captura**, con comparación adicional sobre los píxeles estables (idénticos en las 4 bases).
- **Después (`after`, 4 corridas):** `body_gallery_all/left/right` **0 px** en las 4. En las corridas 3 y 4, todas dentro del piso salvo `hud_group` (after4: 136 916 vs piso 51 498, ruido difuso sin concentrarse en ninguna unidad), `look_gallery_horizon` (after4: 209 279 vs 161 159) e `hud_attack_armed` (after3: 107 986 vs 73 616); `fx_gallery` 784–796 k vs 734 k. En las corridas 1 y 2 (las primeras tras el import) cambió la **pose de cámara** en 4 capturas de bioma (`james`, `pyro`, `stratos`, `persephone` en la 1) y en `charnel` (la 2), con 400–850 mil px; en las otras tres corridas no se repite y las bases (4 corridas) nunca lo mostraron. No se pudo atribuir con certeza; la hipótesis es el tiempo de arranque (cachés frías tras el import) que mueve cuántos ticks simulados pasaron antes de la captura, no el material. Sin ajustes a ojo. Fuera del piso, medido y sin resolver: ver arriba.
- **Banco:** `agent/run_determinism.sh quick` = QUICK PASS (digests de `det_baseline.txt`).
- **Cosas del entorno:** `run_rfc033_shots.sh` se colgó dos veces en un `shot` (en una corrida base y otra base5; se mató el proceso y se repitió). Otro agente (worktree `agent-a56598648459ae428`) encola sus propias corridas Godot en el mismo candado.

**Desvíos del plan:**
- El importador lee los TGA, SAXS, OBJ y PNG que ya dejan `export_bodies.py` y `export_persephone.py` en `cache/look/` en vez de la instalación (WAD). Evita duplicar el lector de WAD y garantiza los mismos píxeles; la extracción cruda sigue en los exportadores hasta 033h. Hay que correrlo antes de que se borre `cache/`.
- El umbral 3D de §8.0 (≤ 2/255 y ≤ 0,5 % de píxeles) no es medible: el piso de ruido entre corridas idénticas ya lo supera (hasta 16 % de píxeles distintos). El criterio efectivo es el de arriba.
- `ObjMesh.build` perdió su parámetro de textura de reserva y `wizard.gd` su `texture_path` (todo lo resuelve el índice por modelo y etiqueta).
- `tools/audit_original_assets.gd` permite ±1 en el alfa de los mips chicos (ver arriba).

## Nota del orquestador (2026-10-17, REVIEW-F165)
033d suma una tarea corta: exportar el sprite `scri` del ojo de Divine Sight (`Bloo.WAD!/Pers.FLDR/tex_ZERO_.FLDR/scri.TXTR`, hoja 4×4 de 16 cuadros, quad 2,5×2,25 m, 4 ticks por cuadro, shadeless, energía 3; sacengine `sacobject.d:3851-3865`), animarlo y reemplazar solo el `glow` de `divine_sight_eye.tscn`.

## 033c: Resultado (F169)

- **Importador:** `tools/import_props.py` escribe `assets/original/props/<name>.glb` (+ `.glb.import`) para los **117 props** (103 estructuras + 14 plantas del catálogo de Persephone) y `assets/original/models/sizes.json` (`{"bodies": 84, "props": 117}`, copiado de `cache/baked/{bodies,props}.json`; igual como datos parseados y en el mismo orden de claves). Idempotente: la segunda corrida escribe 0. Reproduce `ObjMesh.build` (giro según normales, plantas a dos caras con normales propias) y escribe con el giro de glTF invertido. Un primitivo por etiqueta de material; el material glTF solo lleva el nombre (la etiqueta, p. ej. `M000`) para que Godot nombre la superficie; `OriginalMaterial.for_label` pone encima el material compartido. `--verify` relee los `.glb` con un lector propio y los compara con el OBJ: 0 mm.
- **Escritor glTF:** `tools/sac_formats/gltf_writer.py` (`Gltf`, `write_glb`, `import_params`), extraído de `export_skeletal.py`, que lo importa. Salida de `export_skeletal.py eorc` byte a byte igual al `eorc.glb` versionado.
- **Consumidores:** `BodyCatalog` lee `sizes.json` (`OriginalAssets.sizes()`) y los props de `props/<m>.glb` (`_prop_mesh`: una malla por modelo, compartida, con los materiales por nombre de superficie). `BAKED_DIR` queda solo para cuerpos y cuadros de clip. `splash_probe.gd` lee `sizes.json`. `rg "baked/props|props\.json"` en `scenes`, `data`, `debug`, `agent/harness` = 0 (solo quedan `tools/bake_bodies.gd`, el importador y la auditoría). El dedicado no carga mallas: solo `sizes.json`.
- **Paridad geométrica** (`tools/audit_original_props.gd`, headless, contra `ObjMesh.build` del OBJ **y** contra `cache/baked/props/*.res`): 117/117, 173 superficies, nombres de superficie iguales, 100 materiales con textura distintos (uno por textura), **error máximo de posición 0,00000 mm, uv 0, normal 0**, 0 fallos. Esto exige `meshes/force_disable_compression=true` en el `.import`: con la compresión por defecto Godot guarda las posiciones en 16 bits sobre la caja de la malla y da 0,2–1,0 mm en edificios de 14–50 m y **27,7 mm** en la burbuja de cielo `pcsb` (1,1 km). Los empates de triángulos se resuelven por vecino más cercano porque el importador reordena e indexa.
- **Digests:** `quick` (`s1_quick`) = `44d78b49…`, igual a `det_baseline.txt`, en fixed, stress y window. `all` (s7, s7_npcs, s1_trivial, f139): s7 `4915c884…` y f139 `5ade9305…` iguales a `det_baseline.txt`; s1_trivial `e076abe1…` y s7_npcs `7179b17d…` iguales a lo anotado en FEATURES.md; los cuatro iguales entre fixed, fixed2, stress y window. El veredicto que imprime el script es FAIL solo por la marca `CONTAMINATED` (otros agentes corrían Godot en paralelo en stress/fixed), no por un digest distinto.
- **Capturas** (`after` = `c7`, contra `base base2 base3 base4`): 
  - `body_gallery_all` **1 646 px** con delta > 2/255 (0,18 %; máximo 79; 367 px sobre 8/255 y 24 sobre 32/255); `body_gallery_left` 513 px (0,06 %); `body_gallery_right` 0. El piso de la galería es 0 y **se sale**. Las diferencias son manchas sueltas sobre la superficie de los props (los cuerpos no cambian: siguen siendo los `.res` horneados).
  - Medido, no ajustado: con el mismo `.glb` pero reconstruido sin índices desde sus propios arrays, la galería da 1 / 4 / 0 px, igual que mezclar el orden de los triángulos de la malla vieja (8 / 4 / 0). Con el material viejo sobre el `.glb`, los conteos son los mismos que con el nuevo (1 774 px); con las posiciones comprimidas, 1 774 px; con `ensure_tangents` en true o false, 1 646 en ambos. Los datos por esquina (posición, uv, normal) son idénticos a los viejos. Causa: la malla importada es **indexada** (vértices compartidos) y la vieja no; el mismo conjunto de triángulos dibujado con índices cambia 1 646 px con la tubería actual. El orden de los triángulos y los materiales no son la causa. No se pasó el `.glb` a sin índices (cada esquina un vértice) para igualar pixel a pixel: se dejó indexado.
  - Dentro del piso: `biome_charnel` 79 541 (piso 94 761), `biome_james` 33 258 (46 561), `biome_persephone` 129 344 (150 677), `biome_stratos` 20 827 (20 218; +3 %), `look_gallery_horizon` 161 052 (161 159), `look_gallery_ref` 95 539 (120 387), `look_gallery_rts` 37 600 (40 508). `biome_pyro` 55 634 contra 54 234 (+2,6 %) y `hud_group` 131 905 contra 51 498 quedan sobre el piso, como en 033b (`after4`: 136 916): no muestran props y son el ruido difuso del mundo de atrás. `fx_gallery` 785 047 contra 734 534, igual que en 033b.
- **Tamaño:** `assets/original/props/` = **117 `.glb` (1,94 MB) + 117 `.glb.import`, 2,4 MB en disco**; `sizes.json` 50 KB.
- **Sigue leyendo `cache/`:** cuerpos (`baked/bodies/*.res` y `look/anim_f37` por `BodyCatalog.BAKED_DIR`/`clip_frame_path`, hasta RFC-023 y 033i); datos de juego, terreno, mapa, FX, UI y temas (033d–033g); `agent/tools/f129/f155/f156_expect.py` leen `cache/baked/bodies.json` (033g/h); el importador de props lee `cache/look` y `cache/baked` (hasta 033h).

**Desvíos del plan:**
- `ensure_tangents=false` en los `.glb.import` de props (el plan decía true, como 023): ningún material usa mapa de normales y no cambia ni un píxel (c5 = c7); evita que el importador suelde vértices.
- `meshes/force_disable_compression=true` (no estaba en el plan): sin él no se cumple la paridad de 1e-5 m.
- El material glTF de cada primitivo lleva el nombre de la etiqueta, en vez de ir «sin materiales»: es la única forma de que el nombre de superficie llegue al juego.
- La paridad de vértices se mide contra `ObjMesh.build` y contra los `.res`, y es exacta (0 mm); el límite del plan era 1e-5 m.
- La captura de `body_gallery` no queda en el piso 0 (1 646 px, ver arriba).

## 033d: Resultado (F170)

- **Importador:** `tools/import_ui.py` copia byte a byte los PNG que `export_icons.py` y `export_particles.py` dejan en `cache/look/` a `assets/original/ui/{icons,hud,cursors,xmenu}/` (178 + 12 + 22 + 21) y `assets/original/fx/` (37 atlas), escribe `fx/fx.json` con los `png` en `res://assets/original/fx/` y decodifica `scri` (hoja 4×4 de 256×256, `charlie.wad` `Bloo.WAD!/Pers.FLDR/tex.FLDR`) con el mismo lector TXTR. 272 archivos, idempotente (la segunda corrida: 0 escritos; los `.import` no se tocan). **Tamaño:** `ui/` 1,9 MB, `fx/` 1,3 MB (incluye los `.import`). Import: lossless, `fix_alpha_border=false`, mipmaps solo donde el código viejo los generaba: los atlas que lista el catálogo (`FxAtlas.catalog_texture`) y `scri`; los que se leen con `FxAtlas.texture` (ltn2, vtx3, grdn, jspk, gmfl_a, …) y todo `ui/` sin mips.
- **Consumidores:** `HudIcons` (`load()`, rutas de `OriginalAssets.UI_*_DIR`), `FxAtlas` (`texture` y `catalog_texture` con `load()`; el catálogo se lee con `FileAccess` sobre `res://`), `sprite_particles`, `teleport_rings`, `soul` (`OriginalAssets.FX_CATALOG`). `StatBar`, `CursorSkin`, `CommandCue`, `CueSet`, `PortalLook`, `ParticleType`, `BeamType`, `Tether`, `PortalDisc`, `GuardianTether`, `SpriteEmitter`: solo mensajes y comentarios. `OriginalAssets` suma `UI_{ICONS,HUD,CURSORS,XMENU}_DIR` y `FX_CATALOG`. `rg "globalize_path" scenes/ui scenes/fx` deja una sola línea, en `ui/options/user_settings.gd:69` (renombra el archivo de ajustes en `user://`: no es la caché ni un asset).
- **Paridad de imagen** (`tools/audit_original_assets.gd`, ahora con `_audit_2d`, headless): 270 PNG (`icons` 178, `hud` 12, `cursors` 22, `xmenu` 21, `fx` 37) **idénticos** a `cache/look` (tamaño, formato, todos los bytes; los atlas del catálogo también en todos los niveles de mip contra `generate_mipmaps()`; los demás sin mips) y `fx.json` igual al catálogo viejo salvo la ruta. 0 fallos. Además, las 701 texturas de 033b siguen igual.
- **Capturas** (`after` y `d2`, contra `base base2 base3 base4`):
  - *HUD (lo que importa).* El bloque inferior izquierdo (barra de hechizos con iconos, 215×100 px) da **0 px** distintos en `hud_group` y `hud_xmenu` y 14 en `hud_attack_armed` (el piso entre bases: 0, 0 y 14). Los iconos, el roster izquierdo y el medidor de la esquina superior derecha no cambian: lo que difiere son motas sueltas del mundo (polvo sin semilla) de ≤ 9/255, no el panel (se miró el mapa de diferencias). Totales de la captura: `hud_group` 54 516 (after) y 73 466 (d2) contra piso 51 498; `hud_attack_armed` 81 710 y 80 562 contra 73 616; `hud_xmenu` 57 018 y 85 593 contra 63 103. Es el ruido del mundo que ya se midió en 033b (el criterio de 0 px de §8.0 no se puede cumplir con esta captura).
  - `fx_gallery`: 859 122 (after) y 784 423 (d2) contra piso 734 534, la misma bimodalidad que 033b/033c (785 k, 676 k): las partículas no tienen semilla. Los pixeles estables cambiados (> 2): 84 k en `after` y 17,8 k en `d2`, como 18 k en las corridas de 033c.
  - `body_gallery_all` 1 646 px, `left` 513, `right` 0: igual que 033c (esta etapa no toca cuerpos ni props). Biomas y `look_gallery` dentro del piso salvo `biome_pyro` (61 594 contra 54 234, +14 %, mismo orden de 033c: 55 634): no muestran HUD ni FX.
- **Ojo de Divine Sight** (`divine_sight_eye.tscn`): solo se reemplazó el `glow`: quad 2,5 × 2,25 m, `StandardMaterial3D` sin sombreado, alfa mezclado, billboard, `albedo_texture = scri.png`, `uv1_scale = 1/4`, `albedo_color = (3, 3, 3)` (energía 3); el script sigue poniendo alfa = escala² y suma tres `@export` (`frames_h`, `frames_v`, `ticks_per_frame`) para correr los 16 cuadros por `uv1_offset` con los ticks físicos (los clientes no tienen contador de cuadros). **Desvío:** `ticks_per_frame = 8`, no 4: sacengine tiene `animationDelay = 4` pero `getFrame(i / (animationDelay·updateAnimFactor))` con `updateAnimFactor = 2` (`updateFPS 60 / animFPS 30`), y el ojo suma 1 cuadro por tick; el catálogo de partículas ya usa la misma cuenta (`frame_s = delay·2/60`). El ciclo dura 128 ticks (2,13 s); se cambia con el inspector. Flow `bash agent/harness/godot_run.sh bash agent/run_f165.sh f165`: **PASS** (36 asserts ok, `AGENT_ERRORS []`). Captura con el ojo y el sprite: `agent/out/f165/f165_rising.png` (cámara fija, el ojo a media altura, abajo al centro-izquierda; en `f165_flight.png` es un punto lejano).
- **Banco:** `agent/run_determinism.sh quick` = **QUICK PASS** (digests de `det_baseline.txt`).
- **Sigue leyendo `cache/`:** cuerpos y cuadros de clip (`BodyCatalog`, hasta RFC-023/033i); `wizard_preview` (OBJ de bind); datos de juego, terreno, mapa, temas y cielo, pasto (033e–033g); refs de tick y `debug/*` (033h); los importadores y `audit_original_assets.gd` (hasta 033h/033i). `tools/export_icons.py` y `export_particles.py` siguen siendo los extractores del WAD de estas familias (como en 033b/c) hasta 033h.

**Desvíos del plan:**
- `import_ui.py` copia de `cache/look` en vez de leer el WAD (una sola excepción: `scri`, que no pasaba por ningún exportador), igual que 033b/033c. Hay que correrlo antes de borrar `cache/`.
- Un solo script para HUD y FX (el plan decía «uno o dos»); `export_icons.py`/`export_particles.py` no se renombran todavía: 033h los retira.
- El criterio «HUD y menú X: 0 px» se mide sobre las regiones del panel (0 px donde no hay mundo detrás) y no sobre la captura entera, por el ruido de 033b.
- `hud_cache_probe.gd` sigue apuntando a `res://agent/out/_no_cache/` (carpeta inexistente: `ResourceLoader.exists` da falso, mismo efecto que una carpeta vacía).
- `ticks_per_frame = 8` en el ojo (ver arriba).

## 033e: Resultado (F171)

- **Importador:** `tools/import_themes.py` copia byte a byte los 7 PNG por dios de `cache/look/themes/<god>/` (que deja `export_tilesets.py`) a `assets/original/themes/<god>/` (`atlas`, `edge`, `skyt`, `skyb`, `sky`, `sun`, `undr`) y escribe `envi.tres` (un `GodEnvi`) desde su `theme.json`. **35 PNG = 2,3 MB, 5 `envi.tres` y 35 `.import` = 0,1 MB; 2,5 MB en total.** Idempotente (la segunda corrida da 0 escritos; un `.import` existente no se toca). `atlas` y `edge` van con `importer="image"` (se leen en CPU: exactos, sin mips ni compresión); `skyt/skyb/sky` como textura con mipmaps (el cielo las generaba en runtime); `sun` y `undr` sin mips (hoy sin consumidor). Dos `--import` por el `class_name` nuevo; los UID quedan estables.
- **Cielo original intacto:** mismos PNG, mismo shader, mismas mallas y velocidades; el cielo duplicado `look/persephone/sky*.png` (mismo md5) deja de leerse (`sky.gd` toma por defecto `themes/persephone/` y `ThemeApplier` pone el del dios). Sin nubes nuevas ni saturación.
- **Consumidores:** `GodEnvi` (`scenes/world/god_envi.gd`, `class_name`; colores lineales ENVI, rango de niebla, fuerza del sol, dirección, sombra); `GodTheme`: `cache_dir`/`fallback_dir` fuera, entra `envi: GodEnvi`; `with_cache()` pasa a `resolved()` (copia con los colores de `envi`), más `dir()`/`file()` por `OriginalAssets.theme_dir(god)`; los 5 `data/themes/*.tres` pasan a `envi = ExtResource(...)`. `Terrain`: `atlas`/`edge` por `load()` como `Image` (`_load_image_texture`), el default de `tileset_dir` pasa de `cache/look` a `themes/james`. `Sky`: `load()` del `.ctex`. `ThemeApplier` y `LookRig` usan `resolved()`/`dir()`. `OriginalAssets.theme_dir(god)` nuevo. `tools/sample_grass_palette.py` y `classify_ground_tiles.py` leen el atlas de `assets/original/themes`. `rg "cache_dir|look/persephone/sky|look/themes|with_cache|fallback_dir"` en `scenes data debug addons agent/harness` = 0.
- **Paridad** (`tools/audit_original_assets.gd`, ahora con `_audit_themes`, headless): 35 imágenes **idénticas** a `cache/look/themes` (formato, tamaño y todos los bytes; atlas/edge sin mips; sky de tres capas contra `Image.generate_mipmaps()` en todos los niveles; sun/undr sin mips); los 5 `GodTheme.resolved()` dan los mismos colores, rango de niebla y `sun_direct_strength` que `theme.json`; el cielo de persephone es igual al duplicado viejo. 0 fallos (las auditorías 033b y 033d siguen iguales).
- **Capturas** (`after` y `after2` contra `base..base4`, píxeles con delta > 2/255; `base5` está incompleta y no se usó). Piso → after / after2: `biome_charnel` 94 761 → 96 104 / 95 685; `biome_james` 46 561 → 48 977 / 48 277; `biome_persephone` 150 677 → 155 764 / 120 611; `biome_pyro` 54 234 → 66 265 / 67 539; `biome_stratos` 20 218 → 20 814 / 24 488. Los cuatro primeros dentro de ±5 % (stratos +21 % en after2, 4 k píxeles de un piso chico). **`biome_pyro` sigue +22–25 % (venía +14 %): no es del import.** Es ruido del cielo (el cielo rota y las nubes avanzan con el tiempo de la captura): el cambio firmado medio sobre los píxeles estables es 0, los píxeles que cambian están todos en el tercio superior (el cielo, filas 0–427) y **dos corridas idénticas de `after` difieren entre sí en 74 236 px**, más que after contra la base. `body_gallery_*` igual que 033d (1 646 / 513 / 0 px, sin cuerpos tocados). El suelo no cambia: las baldosas de `tiles.png` que usa el mapa tienen el mismo píxel en `cache/look/atlas.png` (el default viejo de `Terrain`) y en `themes/james/atlas.png` (difieren solo los ids 9–11, 58–59, 132–136, 173–182 y 255, que el mapa no usa).
- **Banco:** `agent/run_determinism.sh quick`: los 21 digests de `det_baseline.txt` **iguales**; el veredicto sale FAIL solo por el aviso CONTAMINATED (otro agente corre Godot en su worktree) sin ninguna diferencia de digest.
- **Sigue leyendo `cache/`:** cuerpos y cuadros de clip (`BodyCatalog`, hasta RFC-023/033i); `wizard_preview` (OBJ de bind); `Terrain` (`high_noon_terrain.bin`, `tiles.png`, `light.png`), `ground_material.gd`, pasto (`light.png`, `height.exr`), `ntts`/`widgets`, datos de juego (033f–033g); refs de tick y `debug/*` (033h); los importadores y `audit_original_assets.gd` (hasta 033h/033i). `tools/export_tilesets.py` sigue siendo el extractor del WAD de los temas (como en 033b–d) hasta 033h.

**Desvíos del plan:**
- `import_themes.py` copia de `cache/look/themes` en vez de leer el WAD (la lógica de LAND/MAPT/remapeo vive en `export_tilesets.py`; duplicarla era peor). Hay que correrlo antes de borrar `cache/`; 033h lo pasa a leer del WAD.
- `GodTheme` no tiene campo `dir` (el plan decía `envi` + `dir`): el directorio se deriva de `god` con `OriginalAssets.theme_dir`, así ningún `.tres` escribe `res://assets/original/` (README: solo `OriginalAssets` lo deletrea).
- `GodEnvi` trae además fog_density, sun_ambient_strength, shadow_strength y sun_direction del ENVI (nadie los lee hoy; el tema sigue usando su propio `fog_density`).
- `Terrain.tileset_dir` por defecto es ahora `themes/james` (antes `cache/look`, un atlas que difiere en baldosas que el mapa no usa).

## 033f: Resultado (F172)

- **Importadores:** `tools/import_map.py` copia byte a byte a `assets/original/maps/high_noon/` `tiles.png` y `light.png` (con `.import` `importer="image"`: exactos, sin sRGB, sin mips, sin compresión), `ntts.json` y `widgets.json` desde `cache/` (idempotente: la segunda corrida da 0 escritos). `tools/import_terrain.gd` lee `cache/high_noon_terrain.bin` (HNTR v1) y guarda `terrain.res` (`MapTerrainData`: `vertices`, `normals`, `indices`); si el `.res` ya tiene los mismos arrays no escribe. **Tamaño:** `terrain.res` 576 804 B (LFS por `*.res`), `tiles.png` 38 551, `light.png` 3 523, `ntts.json` 10 493, `widgets.json` 20 585; 652 KB en disco con los `.import`. No se guarda `height.exr` (era 637 KB).
- **Consumidores:** `MapTerrainData` nuevo; `Terrain.data` (asignado en `high_noon.tscn`; si un `Terrain` se arma solo con el script, como hacen los probes y el banco, toma el de High Noon: el viejo `cache_path` también tenía un default); `tiles_path`/`light_path` exportados, leídos con `load()` como `Image`; `GroundMaterial` con `load()`; `MapProps`, `MapPopulation` y `SideRelations` con `OriginalAssets.HIGH_NOON_*` (constantes nuevas, los defaults de `@export` necesitan constantes); `pt73_probe.gd` y los mensajes de `debug/{nav_cases,ai_cases,terrain_normals_probe}`. `GrassHeight.from_terrain(terrain)` (nuevo, `scenes/world/look/grass/grass_height.gd`) reemplaza a `height.exr` y a `tools/bake_grass_height.gd` (borrado): `GrassField` lo calcula la primera vez que carga (el pasto sigue apagado) y `debug/grass_lab_ground.gd` lo deriva de un `Terrain` descartable. El relleno de huecos visita solo el frente de cada anillo (1,4 s en vez de 166 s), con el mismo resultado.
- **Paridad** (`tools/audit_original_assets.gd`, ahora con `_audit_map`, headless): los 20 586 vértices, 20 586 normales y 20 586 índices de `terrain.res` **iguales** al `.bin` (leído de nuevo en la auditoría); `tiles.png` y `light.png` los mismos bytes que `cache/look/` y la misma `Image` (formato, tamaño, datos, sin mips); `ntts.json` y `widgets.json` iguales como texto y como datos; `Terrain.tile_ids()` igual a `tiles.png` en las 65 536 celdas; **`GrassHeight.from_terrain` = `height.exr`: 0 texels distintos, diferencia máxima 0**. 0 fallos; las auditorías de 033b–033e siguen igual.
- **Banco:** `rules_suite` PASS (incluye `nav_cases`). `run_determinism.sh quick`: los 21 digests de `det_baseline.txt` **iguales**. `all`: `s7` `4915c884…`, `f139` `5ade9305…`, `s1_trivial` `e076abe1…`, `s7_npcs` `7179b17d…`, iguales entre `fixed`, `fixed2` (s7, s7_npcs, s1_trivial), `stress` y `window`, y a lo anotado. El veredicto impreso es FAIL solo por la marca CONTAMINATED (otro agente corría Godot en su worktree) en varias corridas `fixed` y `stress`; la ventana (`window`) y `fixed2` de s7, `fixed` de s7_npcs salieron limpias y dan el mismo digest. `f131_expect.py --lanes` **PASS** y las demás `f126–f156_expect.py` que leían `ntts`/`widgets` de `cache/` ahora leen `assets/original/maps/high_noon/` (helper `map_file`); siguen leyendo `cache/high_noon_terrain.bin` (formato `.bin`, no se puede leer en Python desde el `.res`) y `cache/data`, `cache/baked/bodies.json` (033g/033h).
- **Deudas de la review de 033e:**
  - `sky.gd` pasa por `OriginalAssets.theme(dios, nombre)` y `terrain.gd` por `OriginalAssets.theme_dir("james")`: ya nadie concatena `THEMES_DIR`.
  - **Cielo congelado en las capturas:** `Sky.set_time(seconds)` (público, nuevo) y `rfc033_view.freeze_sky()` (paso `call` en el flow, tras el `wait` de cada `biome_pick_*` y `look_gallery_still`, **sin** `wait` extra: uno extra desplazó la pose de las criaturas) dejan el cielo en el tiempo 0. Un primer intento con `node.call("_update")` lo rechazó el lint de AgentKit («forces play»).
  - **`GodEnvi`:** los cuatro campos sin lector (`fog_density`, `sun_ambient_strength`, `shadow_strength`, `sun_direction`) se borraron de `god_envi.gd` y de `import_themes.py`; los 5 `envi.tres` se reescribieron (`import_themes.py`: 5 escritos, 35 sin cambios).
- **Capturas y piso nuevo** (`after1` y `after2`, dos corridas iguales con el cielo congelado, píxeles con delta > 2/255; piso viejo entre paréntesis): `biome_charnel` 3 872 (94 761), `biome_james` 4 159 (46 561), `biome_persephone` 22 282 (150 677), `biome_pyro` 10 966 (54 234), `biome_stratos` 14 667 (20 218), `look_gallery_rts` 5 674 (40 508), `look_gallery_horizon` 75 596 (161 159), `look_gallery_ref` 0 (120 387), `fx_gallery` 0 (734 534), `body_gallery_*` 0, `hud_attack_armed` 98 644 (73 616), `hud_group` 135 065 (51 498), `hud_xmenu` 49 575 (63 103). El ruido de los biomas bajó un orden de magnitud: era el cielo. El HUD no cambió de naturaleza (el mundo de atrás se mueve según el momento de captura) y su piso sigue siendo alto y bimodal.
  - **Comparación con la base:** la base se tomó con el cielo en movimiento, así que en la mitad de arriba de `biome_*` y `look_gallery_*` el cielo difiere por construcción (180–440 k px). En el **suelo** (filas ≥ 428, donde ya no hay cielo) `after` contra las 4 bases: `biome_charnel` 466 (piso de la base 409), `biome_james` 460 (601), `biome_pyro` 214 (249), `biome_stratos` 289 (355), `biome_persephone` 29 952 (30 189), `look_gallery_ref` 30 253 (33 287), `look_gallery_rts` 13 020 (18 474): todo dentro del piso de la base salvo `biome_charnel` (+57 px sobre 409, sobre un suelo de 373 k px). `look_gallery_horizon` 77 141 (44 333) incluye cielo en esas filas. `body_gallery_all/left/right` 1 646 / 513 / 0 px, igual que 033c–033e (no se tocaron cuerpos). `fx_gallery` 734 534 contra la base, igual que el piso viejo: 0 píxeles estables cambiados.
- **Sigue leyendo `cache/`:** cuerpos y cuadros de clip (`BodyCatalog`, hasta RFC-023/033i); `wizard_preview` (OBJ de bind); datos de juego (`GameData`, `map_building`, `ai_perception`, `body_gallery`: 033g); refs de tick y `debug/*_tick.tscn` (033h); `hud_cache_probe`; `agent/tools/f1*_expect.py` leen `cache/high_noon_terrain.bin`, `cache/data` y `cache/baked/bodies.json` (033g/033h); los importadores (`import_map.py`, `import_terrain.gd`, `import_themes.py`, ... leen `cache/look` y `cache/high_noon_terrain.bin`) y `audit_original_assets.gd` (hasta 033h/033i). `tools/export_high_noon_{terrain,ntts,widgets,look}.py` siguen siendo los extractores del `.scp`.

**Desvíos del plan:**
- Los importadores copian de `cache/` en vez de leer el `.scp` (como 033b–033e); `import_terrain.gd` lee el `.bin` del exportador en `cache/` en vez de una salida temporal fuera del repo. Hay que correrlos antes de borrar `cache/`.
- `Terrain.data` tiene un respaldo (High Noon) cuando no se asigna, para no tocar la veintena de probes y bancos que arman un `Terrain` con el script solo. Además de `data`, `Terrain` suma `tiles_path` y `light_path` exportados.
- `Sky.set_time()` es API pública nueva (solo para congelar el cielo en capturas).
- No se pudo medir contra una base con el cielo congelado: la comparación del cielo contra la base no es posible; se midió el suelo (filas ≥ 428) y el piso nuevo con dos corridas `after`.

## Nota del orquestador (2026-10-17, verificación después del merge de melee)
- `main` en 0026e9e: `all` da s7 `c5a5755a`, s7_npcs `4386b384`, s1_trivial `60fbf6d5` y f139 `4750f4d1`, iguales en fixed, fixed2, stress y window, sin CONTAMINATED. `quick` PASS. `final_spit_melee` 3/3 y `f165_divine_sight` PASS.
- **Trampa del banco (para 033h):** `run_determinism.sh` arma la tabla con todos los `agent/out/det/<caso>_<modo>.json` que existan, aunque ese modo no haya corrido en esta invocación. Un `fixed2` viejo del 16/10 dio un falso «DETERMINISM FAIL». La tabla tiene que mirar solo los modos corridos ahora, o borrar los de esta invocación antes de correr.

## 033g: Resultado (F173)

- **Exportador:** `tools/export_stats.py --out DIR` escribe en `DIR` solo `creatures`, `wizards`, `spells`, `abilities`, `books` y `buildings` (`.json`): sin `anim_clips_f36`, sin `anim_mesh_clips_f37`, sin modelos de edificios ni catálogo. Sin `--out` se comporta como antes (`cache/data`). `buildings` se separó en `read_buildings()` y `write_buildings_json()`. Lee el WAD de la instalación y tarda 1,3 s.
- **Datos:** `assets/original/data/{creatures,spells,abilities,wizards,books,buildings}.json` = 333 KB, texto sin LFS. **Paridad:** los 6 son **byte a byte iguales** (`cmp`) a `cache/data/*.json`, generados dos veces (en `agent/out/033/data_check` y en el destino).
- **Lectores en runtime:** `GameData.DATA_DIR` y `MapBuilding.BUILDINGS_PATH` (que usa `ai_perception` por `MapBuilding.bldg`) pasan a `OriginalAssets.DATA_DIR`; `debug/body_gallery.gd` y `tools/audit_body_pose.gd` (books, creatures, wizards) también. `agent/tools/f125/127/149/151/129/155/156_expect.py` leen `assets/original/data` (helper `data_file`) y las medidas de cuerpos desde `assets/original/models/sizes.json` (`["bodies"]`, igual a `cache/baked/bodies.json`; helper `model_file`).
- **Banco** (explícito `all fixed fixed2 stress window`): `s7` `c5a5755a…`, `s7_npcs` `4386b384…`, `s1_trivial` `60fbf6d5…`, `f139` `4750f4d1…`, iguales en los 4 modos y a lo anotado por el orquestador (DETERMINISM PASS, sin CONTAMINATED). `quick`: QUICK PASS, los 21 digests de `det_baseline.txt` iguales. `rules_suite` (`--fixed-fps 60`) PASS. `f125–f156_expect.py --lanes` PASS donde aplica.
- **Prueba sin caché:** con `cache/` renombrada a `cache.off` solo durante la corrida (script con `trap` que la restaura; confirmada de vuelta), `ai_match` headless `--fixed-fps 60` da `s7` `c5a5755a` y `s7_npcs` `4386b384`, **los mismos digests**, sin `WARNING`/`ERROR` en el log. Hito: la simulación (y por tanto el dedicado, que corre el mismo `ai_match`/`Match`) ya no usa `cache/`.
- **Sigue leyendo `cache/`:** solo cliente/visual y tools: cuerpos y cuadros de clip (`BodyCatalog.BAKED_DIR`, `clip_frame_path`, hasta RFC-023/033i); `anim_mesh_clips_f37.json` (`clip_pose_player.gd`, `structure_body.gd`, `audit_body_pose.gd`: no se migró, lo retira 023h; en headless no se lee); `wizard_preview`/`wizard.gd`; refs de tick y `debug/*_tick.tscn` (033h); `hud_cache_probe`; `agent/tools/f1*_expect.py` que leen `cache/high_noon_terrain.bin`; los importadores y `audit_original_assets.gd`; `tools/export_stats.py` sin `--out` (extractor de `anim_*`).

**Desvíos del plan:**
- `anim_mesh_clips_f37.json` queda en `cache/data` (el plan dice «sin `anim_*`»); sus lectores son solo del cliente y se van con 023h.
- Extra: las medidas de cuerpos de `f129/f155/f156_expect.py` pasaron a `sizes.json` (033c), que estaba disponible.
- No se agregó una auditoría de datos a `audit_original_assets.gd`: `cmp` byte a byte es más fuerte.

## 033h: Resultado (F174)

- **Refs de tick:** `agent/fixtures/sacengine/tick{,_move,_state,_advance}.txt` (versionados; el `.gitignore` de la raíz ignoraba `sacengine/` y se le sumó `!game/agent/fixtures/sacengine/`). `debug/{idle_tick,move_order,state_tick,advance_tick}.tscn` y los defaults de `tick_check.gd`, `move_order_check.gd`, `state_tick_check.gd` apuntan ahí; los scripts de check se quedan en `scenes/world/` (solo cambió la ruta). Los cuatro dan «coincide» (sonda headless en el scratchpad, no versionada).
- **Trampa del banco:** `run_determinism.sh` pasa `DET_MODES` (los modos de esta invocación) al informe; la tabla y el veredicto miran solo esos modos más `fixed` (la referencia). `table` a mano sigue mostrando todo. `quick` lo usa para `s1_quick`. **Prueba:** con un `s7_fixed2.json` falso (`deadbeef…`) en `agent/out/det/`, `bash agent/run_determinism.sh s7` da DETERMINISM PASS (fixed, stress y window `c5a5755a…`); `table s7` a mano, con el falso, da FAIL (como antes). El falso se borró.
- **Importadores desde la instalación (WAD/.scp), sin `cache/`:** nuevo lector único `tools/sac_formats/{wad,txtr,png,models,bldg,props,bodies,ntts,terrain,install}.py` (`SAC_INSTALL` cambia la ruta). Se sacó el lector TXTR duplicado de `export_particles.py` (que pasó a `tools/fx_catalog.py`: solo las tablas de partículas) y `export_persephone.py` ahora importa de `sac_formats` (los nombres que usan `export_bodies/stats/skeletal` siguen). Cada importador tiene `--out=DIR`. Regenerados a una carpeta temporal y comparados con `diff -r --exclude='*.import'`:
  - `textures/` (670 PNG + `index.json`): **idéntico**. `props/` (117 `.glb`): **idéntico byte a byte**; `--verify` 0 mm. `themes/` (35 PNG + 5 `envi.tres`): **idéntico**. `maps/high_noon/` (`tiles.png`, `light.png`, `ntts.json`, `widgets.json`): **idéntico**; el HNTR que arma `import_map.py --terrain-bin=F` es **idéntico** a `cache/high_noon_terrain.bin` y `import_terrain.gd -- --bin=F` da «0 written, 1 unchanged» (mismos arrays; el `.res` no es reproducible byte a byte por el id local aleatorio de Godot). `data/` (`export_stats.py --out`): **idéntico** (`cmp`) tras sacar `decode_bldg/read_buildings` a `sac_formats/bldg.py`.
  - `fx/` (38 PNG + `fx.json`) y `ui/{hud,cursors,xmenu}`: **idénticos**. `ui/icons/`: idéntico salvo **un archivo nuevo, `tum@.png`** (Healing Shower, `wobf`): la caché de iconos era anterior a esa habilidad. Se agregó con su `.import` (un `--import`).
  - **Choque de mayúsculas, defecto viejo:** `hsba`/`HSba` y `hrba`/`HRba` (habilidades distintas: Life Shield/Protector, Spikey Death/Halo of Earth) son un solo archivo en macOS; el exportador dejaba el nombre del primero y el contenido del último, así que `hsba.png` y `hrba.png` muestran el ícono de Protector y de Halo of Earth. (Corregido en la ronda de review: ver abajo.)
  - `decode_txtr` unificado con el orden de las partículas (el color clave gana al plano alfa); las texturas de cuerpos y props no cambian (nunca activan los dos a la vez).
  - **Lo que no se pasa a WAD:** `models/sizes.json`. Sus medidas salen de `tools/bake_bodies.gd` (mallas posadas); `import_props.py` ya no toca `sizes.json` salvo con `--sizes-from=cache/baked`. Lo resuelve RFC-023 al medir desde el `.glb`. Las franjas de la barra (`stat_*`) siguen saliendo de los arreglos de `sacengine/source/sacobject.d` (solo lectura, valores), como antes.
- **Borrado:** `tools/audit_original_assets.gd` (la paridad ahora es `diff -r` contra el WAD), `tools/export_icons.py` (pasó a `import_ui.py`), `export_tilesets.py` (→ `tools/land_themes.py` + `import_themes.py`), `export_high_noon_{look,ntts,terrain,widgets}.py` (→ `import_map.py` + `sac_formats/{ntts,terrain}.py`; el legado de F1 desaparece), `scenes/world/wizard.gd` (lector OBJ sin otro uso). `tools/audit_original_props.gd` y los exportadores de cuerpos/clips siguen (033i).
- **`wizard_preview`:** usa solo la malla de `BodyLibrary`/`BodyCatalog` (se quitó `bodies_dir` y el respaldo al OBJ de `cache/look/bodies`).
- **`agent/tools/f1*_expect.py`:** leen el terreno con `agent/tools/terrain_asset.py` (lee `terrain.res` sin Godot; igual al `.bin`, vértices e índices). `f126–f159_expect.py --lanes`: PASS (15 de 15). `hud_cache_probe.gd` apunta a `agent/out/_no_assets/`. `sample_grass_palette.py` lee `maps/high_noon/tiles.png`.
- **`Terrain.data`:** ya no cae en silencio a High Noon. Solo el editor, con `push_warning`; en partida sin `data` hay `push_error` y no se arma la malla. Las únicas sondas que armaban un `Terrain` con el script solo eran `debug/{nav_cases,ai_cases,terrain_normals_probe}.gd`: ahora asignan `data`. `rules_suite --fixed-fps 60` PASS (98 casos, nav incluido), `terrain_normals_probe` igual, y un `Terrain` sin `data` falla visible. Las sondas `pt*_watch` usan `high_noon.tscn` y no cambian.
- **Banco** (`all fixed fixed2 stress window`): `s7` `c5a5755a…`, `s7_npcs` `4386b384…`, `s1_trivial` `60fbf6d5…`, `f139` `4750f4d1…`, iguales en los 4 modos y a la base. El veredicto sale FAIL solo por CONTAMINATED (otro Godot en el worktree de RFC-023 durante fixed/stress; `window` limpio y mismos digests). `quick`: los 21 digests de `det_baseline.txt` **iguales**; mismo aviso de CONTAMINATED en `s1_quick`. `f165` PASS (36 asserts, `AGENT_ERRORS []`).
- **`rg "cache/"`** en `scenes data debug addons agent/harness`: solo cliente de cuerpos y clips (`body_catalog.gd`, `structure_body.gd`, `clip_pose_player.gd`, comentario de `obj_mesh.gd`), RFC-023/033i.

**Desvíos del plan:**
- Los scripts `*_tick_check.gd` y `move_order_check.gd` no se movieron a `agent/`: solo se cambió el default; las refs sí están en `agent/fixtures/sacengine/`.
- `sizes.json` no se regenera desde la instalación (ver arriba).
- `audit_original_assets.gd` se borró ya en 033h (el plan decía 033i): sin la caché como fuente no tenía contra qué comparar. Lo reemplaza `tools/check_original_assets.sh` (regenera cada familia con su importador y compara con `diff -r`; terreno por `import_terrain.gd`; nombres de íconos GDScript = Python por `tools/check_icon_files.gd`).
- Las capturas `rfc033_shots` no se corrieron: 033h no toca nada visible salvo `tum@.png`, que ningún código usa.

**Ronda de corrección de 033h (review CHANGES_REQUESTED):**
- **`run_determinism.sh`:** `fixed` se corre siempre en la invocación (se agrega si falta) y el veredicto exige al menos 2 modos frescos por caso; con uno solo, FAIL «sin comparación». Pruebas: `f139 fixed` solo = FAIL sin comparación; un `f139_fixed` falso + `f139 stress` = PASS porque `fixed` se vuelve a correr (el falso no se usa); `s7` normal = PASS.
- **Íconos que chocan en macOS:** cada mayúscula del tag se escribe `_` + minúscula (`HSba` → `_h_sba.png`, `hsba` → `hsba.png`). Dueño único `OriginalAssets.icon_file(tag)` (lo usa `HudIcons.icon`); `import_ui.py` espeja `icon_file`, sin el workaround `spelled`, y falla si dos nombres chocan con `lower()`; `tools/check_icon_files.gd` compara GDScript y Python en todos los tags. 12 PNG y sus `.import` renombrados con `git mv` (UIDs conservados); nuevos `_h_sba`, `_h_rba`, `_e_h_t_h`, `_r_a_m_h`; `hsba.png` y `hrba.png` ahora tienen su ícono (Life Shield, Spikey Death). Captura: `agent/out/033h/icons_life_shield_protector_spikey_halo.png` (los cuatro íconos distintos; carga por `HudIcons.icon`).
- **Paridad:** `tools/check_original_assets.sh` → textures, props, themes, map, ui, fx, data, terrain.res OK, nombres de íconos OK, `ASSETS PARITY PASS`.

## 033i: Resultado (F175)

- **Sin lectores de `cache/`:** nada en `scenes`, `data`, `debug`, `addons`, `agent`, `tools` ni `project.godot` lee `cache/` ni `res://cache`. `.gitignore` conserva `cache/` ignorada. `project.godot` no tenía filtros ni `.gdignore` que la nombraran.
- **Borrado con `git rm`:** `tools/export_persephone.py` (escribía `cache/look/persephone`; sus lectores de WAD ya eran `sac_formats`), `tools/export_bodies.py` (OBJ de cuerpos para `--bodies-from`: los 11 híbridos están versionados como `.glb` y `check_original_assets.sh` los copia tal cual) y `tools/audit_original_props.gd` (comparaba contra `cache/baked` y `cache/look`; la paridad de props la da `check_original_assets.sh` más `import_props.py --verify`).
- **`export_stats.py`:** sin la rama de caché de `buildings` (OBJ + catálogo) ni `anim_clips_f36.json` (sin lector). Por defecto escribe en `assets/original/data` (`--out DIR` para otra carpeta); ya no hay `ASSETS_ONLY`. `export_skeletal.py` y `export_stats.py` toman `walk` de `sac_formats.wad`.
- **Comentarios:** `obj_mesh.gd`, `rock_projectile.gd`, `import_terrain.gd`, `import_textures.py`, `check_original_assets.sh`, `run_rfc033_shots.sh`, `RULES.md`, `assets/original/README.md`, comentario de `.gitignore`.
- **`rg -n "cache/|res://cache"`** en `game/` sin `rfcs`, `reviews`, `FEATURES.md`, `agent/out`: queda solo `changes/CHANGE-REQUEST-001.md:24` (registro histórico del pedido, no se reescribe) y `.studio/MEMORY.md` (bitácora). Ningún código.
- **No ejecutado (regla del usuario: sin Godot):** verificación pendiente del orquestador y playtester. `cache/` no se borra (una semana de espera y OK del usuario).

**Verificación (con `mv cache cache.off`, y se restaura al terminar):**
1. `bash agent/harness/godot_run.sh "$GODOT" --headless --path game --import` dos veces: sin errores.
2. `bash agent/run_determinism.sh quick`: los digests iguales a `det_baseline.txt`.
3. `rules_suite` PASS (98 casos) y `bash tools/check_original_assets.sh`: `ASSETS PARITY PASS`.
4. Playtest con ventana: `godot --path game` arranca `res://scenes/ui/boot.tscn` (menú, selección, partida); o `bash agent/run_f79.sh f79_roster_many`. Dedicado + cliente: `agent/run_pt60.sh PORT`.
