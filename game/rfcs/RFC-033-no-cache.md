# RFC-033 — Port sin caché

Estado: plan del tech lead (Opus), pendiente de OK. Arquitectura **estándar**. MP online con dedicado: sin RPC nuevas ni cambios en `addons/mp_kit`.
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
    └── audit_original_assets.gd        # NUEVO 033b/c: paridad numérica (texturas e imágenes, vértices) contra cache/ mientras exista
```

**Responsabilidades (una por pieza):**
- **`OriginalAssets`:** el único que conoce rutas de `assets/original`. Renombrar o mover es un cambio de una línea, y el lint de §8 lo busca.
- **`OriginalMaterial`:** el único que arma el material de un modelo del original.
- **Importadores:** uno por familia. Leen la instalación (`INSTALL`) y escriben solo su carpeta. Son idempotentes: si se corren dos veces, `git status` queda limpio, así que la salida tiene que ser determinista (orden de claves, sin timestamps).
- **`audit_original_assets.gd`:** compara la salida nueva contra `cache/` mientras exista. Se borra en 033i.
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
- **Paridad de datos:** `audit_original_assets.gd` (headless):
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
| **033i** Cierre (**después de 023h**) | Se borra `audit_original_assets.gd`, `BodyCatalog.BAKED_DIR`/`clip_frame_path`, `bake_bodies.gd` y `bake_clips.gd`. `mv cache cache.off` | `rg -n "cache/" scenes data debug addons project.godot --glob '!*.md'` **vacío** (y `res://cache` en `agent/harness agent/fixtures`); F5 1P y dedicado + cliente con `cache.off`; banco `all` y flows PASS; `rfc033_shots` en umbral; `du -sh .godot/imported` anotado |

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
