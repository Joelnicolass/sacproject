# assets/original

Assets extracted from the original game's installation, in Godot-native formats (RFC-033). Git LFS for `.glb`, `.png`, `.res` and `.exr` (see `.gitattributes` at the repo root); the `.import` files are versioned.

Only the importers in `tools/` write here, one per family. The game never writes here. What is edited by hand lives in `data/`. Importers are idempotent (deterministic output, no timestamps) and never touch an existing `.import` (it carries the UID).

The paths are owned by `scenes/core/catalog/original_assets.gd` (`OriginalAssets`). Nothing else spells `res://assets/original/`.

| Folder | What | Importer | Cut |
|---|---|---|---|
| `textures/<owner>/<NNN>.png`, `textures/index.json` | One PNG per unique model texture (bodies, buildings, plants), colour key applied to alpha; the index maps model + material label to the PNG (shared ones live under the first model) | `python3 tools/import_textures.py` | 033b |
| `props/<name>.glb` | Static models (buildings, BLDG components, plants): one primitive per material label, a glTF material that only carries the label (the textured one comes from `OriginalMaterial`). Also the 11 hybrid bodies that no clip animates (faez thes the2 sara hoom bane ban2 sirc surt gamm baby): their bind-pose mesh, z mirrored | `python3 tools/import_props.py` (the hybrids need `--bodies-from=DIR`, the OBJ of sacengine's saveObj run by hand with `export:`; the result is versioned and `tools/check_original_assets.sh` copies it as is) | 033c, 023h |
| `models/<m>.glb`, `models/index.json` | Animated bodies with skeleton and clips. `index.json` is read only by `tools/bake_body_scenes.gd`, which writes `scenes/world/body/models/<m>.tscn` (the scenes the game and the editor use) | `tools/export_skeletal.py` | RFC-023, RFC-036 036g |
| `models/sizes.json` | `{bodies, props}` measurements (the dedicated server uses them without meshes; `BodyCatalog` reads them). A versioned datum since 023h: it came out of the posed meshes that `tools/bake_bodies.gd` measured (retired with the baked bodies), and rebuilding it from the .glb files does not give the same numbers (the bind pose of the .glb differs from the OBJ it was measured on: Sirocco's height would be 6.933 m, not 6.699; the posed bodies were measured on sacengine's own frames and the skinning is within 0.5 mm of them, but the values are snapped to 1 mm), and changing it moves the capsules and every digest. Edit it only on purpose | none | 033c, 023h |
| `ui/{icons,hud,cursors,xmenu}/` | HUD, icons, cursors, X menu | `python3 tools/import_ui.py` | 033d |
| `fx/<tag>.png`, `fx/fx.json` | Particle atlases (mipmaps only for the ones the catalog lists) and their catalog; `scri.png` is Divine Sight's eye (4x4 sheet, decoded from charlie.wad) | `python3 tools/import_ui.py` | 033d |
| `themes/<god>/` | Tileset, sky, sun, `envi.tres` per god | `python3 tools/import_themes.py` | 033e |
| `maps/high_noon/` | `terrain.res` (`MapTerrainData`: vertices, normals, indices), `tiles.png` and `light.png` (imported as `Image`, read on the CPU), `ntts.json`, `widgets.json`. The grass height is not stored: `GrassHeight.from_terrain` derives it | `python3 tools/import_map.py --terrain-bin=F` (png, json, and the HNTR bin in a temp file) then `godot --headless --script res://tools/import_terrain.gd -- --bin=F` (`terrain.res`) | 033f |
| `data/*.json` | Creatures, spells, abilities, wizards, books, buildings (game data the simulation reads; the dedicated server needs them) | `python3 tools/export_stats.py --out assets/original/data` (reads the WAD; with `--out` no `anim_*.json`, no models, no catalog) | 033g |

Since 033h every importer reads the installation (the WAD files and High Noon's `.scp`, in `SAC_INSTALL`, default
`~/Downloads/sacgame/Sacrifice/data`) through `tools/sac_formats/`, the only reader of WAD, TXTR, MRMM/WIDG, BLDG, NTTS and the
terrain; there is no cache folder. Each importer takes `--out=DIR` to write somewhere
else, so the result can be compared against this folder (`diff -r --exclude='*.import'`). The WAD files are never versioned.
The ones that lived as exporters (`export_icons`, `export_particles`, `export_tilesets`, `export_high_noon_*`) are now
`import_ui.py`, `fx_catalog.py` (the particle numbers), `land_themes.py` (the tileset logic) and `sac_formats/{ntts,terrain}.py`.

## Editar el mapa (RFC-035)

- **Terreno:** el origen es `maps/high_noon/terrain.glb`. Se puede abrir en Blender, pero solo se mueve la Y: si un vértice se sale de la grilla de 10 m en X/Z, la importación falla y nombra la celda. Al importar, `tools/terrain_import.gd` genera `terrain.res` (alturas y sim), la colisión y la malla visual. Si cambia solo el script de importación, hay que borrar `.godot/imported/terrain.glb-*` para forzar la reimportación.
- **Material del suelo:** `themes/<dios>/ground_classic.tres`, con atlas, edge, light, `light_base` y `light_gain`.
- **Contenido:** edificios, plantas y NPC (`NpcSpawn`) están en `scenes/world/map/high_noon_layout.tscn`. Los bandos están en `maps/high_noon/sides.tres`. La y de un `NpcSpawn` hay que ajustarla a mano si se lo mueve.
- **Navegación:** después de mover el terreno o los edificios, hay que correr `godot --headless --path game res://tools/bake_nav.tscn`. Con `-- --check` se verifica el resultado. El nodo `NavRegion` avisa en el editor si el navmesh quedó viejo. El botón «Bake» del editor no sirve, porque los edificios arman su colisión en partida.
- **Catálogo:** criaturas, hechizos, magos, habilidades y edificios están en `data/catalog/*.tres`. Los regenera `tools/bake_catalog.gd -- --force` a partir de los JSON.
