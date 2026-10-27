# assets/original

Assets extracted from the original game's installation, in Godot-native formats (RFC-033). Git LFS for `.glb`, `.png`, `.res` and `.exr` (see `.gitattributes` at the repo root); the `.import` files are versioned.

Only the importers in `tools/` write here, one per family. The game never writes here. What is edited by hand lives in `data/`. Importers are idempotent (deterministic output, no timestamps) and never touch an existing `.import` (it carries the UID).

Only the tools spell `res://assets/original/` (`tools/import/original_assets.gd`); the game never reads it.

| Folder | What | Importer | Cut |
|---|---|---|---|
| `textures/<owner>/<NNN>.png`, `textures/index.json` | One PNG per unique model texture (bodies, buildings, plants), colour key applied to alpha; the index maps model + material label to the PNG (shared ones live under the first model) | `python3 tools/import/import_textures.py` | 033b |
| `props/<name>.glb` | Static models (buildings, BLDG components, plants): one primitive per material label, a glTF material that only carries the label (the textured one is in `scenes/bodies/materials/`). Also the 11 hybrid bodies that no clip animates (faez thes the2 sara hoom bane ban2 sirc surt gamm baby): their bind-pose mesh, z mirrored | `python3 tools/import/import_props.py` (the hybrids need `--bodies-from=DIR`, the OBJ of sacengine's saveObj run by hand with `export:`; the result is versioned and `tools/audit/check_original_assets.sh` copies it as is) | 033c, 023h |
| `models/<m>.glb`, `models/index.json` | Animated bodies with skeleton and clips. `index.json` is read only by `tools/bake/bake_body_scenes.gd`, which writes `scenes/bodies/models/<m>.tscn` (the scenes the game and the editor use) | `tools/import/export_skeletal.py` | RFC-023, RFC-036 036g |
| `models/sizes.json` | `{bodies, props}` measurements (the game no longer reads them: the size of a body is its `BodyFrame` scene; only `agent/tools/f1*_expect.py` do). A versioned datum since 023h: it came out of the posed meshes that `tools/bake_bodies.gd` measured (retired with the baked bodies), and rebuilding it from the .glb files does not give the same numbers (the bind pose of the .glb differs from the OBJ it was measured on: Sirocco's height would be 6.933 m, not 6.699; the posed bodies were measured on sacengine's own frames and the skinning is within 0.5 mm of them, but the values are snapped to 1 mm), and changing it moves the capsules and every digest. Edit it only on purpose | none | 033c, 023h |
| `ui/{icons,hud,cursors,xmenu}/` | HUD, icons, cursors, X menu | `python3 tools/import/import_ui.py` | 033d |
| `fx/<tag>.png`, `fx/fx.json` | Particle atlases (mipmaps only for the ones the catalog lists) and their catalog; `scri.png` is Divine Sight's eye (4x4 sheet, decoded from charlie.wad) | `python3 tools/import/import_ui.py` | 033d |
| `scars/<tag>.png` | The 19 ground marks (burns, cracks, craters, blood, god emblems), RGBA, alpha already in 0..255; 0.15625 m per pixel. The game reads them from `ScarMark` nodes | `python3 tools/import/import_scars.py` | 061k-5 |
| `themes/<god>/` | Tileset, sky, sun, `envi.tres` per god | `python3 tools/import/import_themes.py` | 033e |
| `maps/high_noon/` | `tiles.png` and `light.png` (imported as `Image`, read on the CPU), `ntts.json`, `widgets.json`. The grass height is not stored: `GrassHeight.from_terrain` derives it | `python3 tools/import/import_map.py` (png, json); the ground is not here: `scenes/map/maps/<tag>/heights.png` + `void.png` (`tools/terrain/heights_from_original.gd`) | 033f |
| `data/*.json` | Creatures, spells, abilities, wizards, books, buildings (game data the simulation reads; the dedicated server needs them) | `python3 tools/import/export_stats.py --out assets/original/data` (reads the WAD; with `--out` no `anim_*.json`, no models, no catalog) | 033g |

Since 033h every importer reads the installation (the WAD files and High Noon's `.scp`, in `SAC_INSTALL`, default
`~/Downloads/sacgame/Sacrifice/data`) through `tools/import/sac_formats/`, the only reader of WAD, TXTR, MRMM/WIDG, BLDG, NTTS and the
terrain; there is no cache folder. Each importer takes `--out=DIR` to write somewhere
else, so the result can be compared against this folder (`diff -r --exclude='*.import'`). The WAD files are never versioned.
The ones that lived as exporters (`export_icons`, `export_particles`, `export_tilesets`, `export_high_noon_*`) are now
`import_ui.py`, `fx_catalog.py` (the particle numbers), `land_themes.py` (the lands: tiles, groups, ENVI) and `sac_formats/{ntts,terrain}.py`.

## Editar el mapa (RFC-035)

- **Terreno:** el origen es `maps/high_noon/terrain.glb`. Se puede abrir en Blender, pero solo se mueve la Y: si un vértice se sale de la grilla de 10 m en X/Z, la importación falla y nombra la celda. Al importar, `tools/terrain_import.gd` genera `terrain.res` (alturas y sim), la colisión y la malla visual. Si cambia solo el script de importación, hay que borrar `.godot/imported/terrain.glb-*` para forzar la reimportación.
- **Suelo:** `themes/<dios>/roles/<rol>.png` (las hojas de abierto, tierra, roca y camino; `tools/import/bake_role_sheets.py`), que usa el `GodGround` de `data/look/<dios>.tres` junto con `themes/<dios>/edge.png`; la luz horneada es la `light.png` de cada mapa.
- **Contenido:** edificios, plantas y NPC (`NpcSpawn`) están en `scenes/map/maps/high_noon/layout.tscn`. Los bandos están en `maps/high_noon/sides.tres`; la `MapDefinition` del mapa (`scenes/map/maps/high_noon/high_noon.tres`) nombra todos estos archivos. La y de un `NpcSpawn` hay que ajustarla a mano si se lo mueve.
- **Navegación:** después de mover el terreno o los edificios, hay que correr `godot --headless --path game res://tools/bake/bake_nav.tscn` (con `-- --map=<tag>` para otro mapa). Con `-- --check` se verifica el resultado. El nodo `NavRegion` avisa en el editor si el navmesh quedó viejo. El botón «Bake» del editor no sirve, porque los edificios arman su colisión en partida.
- **Catálogo:** criaturas, hechizos, magos, habilidades y edificios están en `data/catalog/*.tres`. Son la fuente: se editan en el inspector.
