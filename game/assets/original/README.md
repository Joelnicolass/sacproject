# assets/original

Assets extracted from the original game's installation, in Godot-native formats (RFC-033). Git LFS for `.glb`, `.png`, `.res` and `.exr` (see `.gitattributes` at the repo root); the `.import` files are versioned.

Only the importers in `tools/` write here, one per family. The game never writes here. What is edited by hand lives in `data/`. Importers are idempotent (deterministic output, no timestamps) and never touch an existing `.import` (it carries the UID).

The paths are owned by `scenes/data/original_assets.gd` (`OriginalAssets`). Nothing else spells `res://assets/original/`.

| Folder | What | Importer | Cut |
|---|---|---|---|
| `textures/<owner>/<NNN>.png`, `textures/index.json` | One PNG per unique model texture (bodies, buildings, plants), colour key applied to alpha; the index maps model + material label to the PNG (shared ones live under the first model) | `python3 tools/import_textures.py` | 033b |
| `props/<name>.glb` | Static models (buildings, BLDG components, plants): one primitive per material label, a glTF material that only carries the label (the textured one comes from `OriginalMaterial`) | `python3 tools/import_props.py` | 033c |
| `models/<m>.glb`, `models/index.json` | Animated bodies with skeleton and clips | `tools/export_skeletal.py` | RFC-023 |
| `models/sizes.json` | `{bodies, props}` measurements (the dedicated server uses them without meshes). They come out of the posed meshes that `tools/bake_bodies.gd` measures, so they are not rebuilt from the WAD: copied on request from `cache/baked/*.json` | `python3 tools/import_props.py --sizes-from=cache/baked` | 033c |
| `ui/{icons,hud,cursors,xmenu}/` | HUD, icons, cursors, X menu | `python3 tools/import_ui.py` | 033d |
| `fx/<tag>.png`, `fx/fx.json` | Particle atlases (mipmaps only for the ones the catalog lists) and their catalog; `scri.png` is Divine Sight's eye (4x4 sheet, decoded from charlie.wad) | `python3 tools/import_ui.py` | 033d |
| `themes/<god>/` | Tileset, sky, sun, `envi.tres` per god | `python3 tools/import_themes.py` | 033e |
| `maps/high_noon/` | `terrain.res` (`MapTerrainData`: vertices, normals, indices), `tiles.png` and `light.png` (imported as `Image`, read on the CPU), `ntts.json`, `widgets.json`. The grass height is not stored: `GrassHeight.from_terrain` derives it | `python3 tools/import_map.py --terrain-bin=F` (png, json, and the HNTR bin in a temp file) then `godot --headless --script res://tools/import_terrain.gd -- --bin=F` (`terrain.res`) | 033f |
| `data/*.json` | Creatures, spells, abilities, wizards, books, buildings (game data the simulation reads; the dedicated server needs them) | `python3 tools/export_stats.py --out assets/original/data` (reads the WAD; with `--out` no `anim_*.json`, no models, no catalog) | 033g |

Since 033h every importer reads the installation (the WAD files and High Noon's `.scp`, in `SAC_INSTALL`, default
`~/Downloads/sacgame/Sacrifice/data`) through `tools/sac_formats/`, the only reader of WAD, TXTR, MRMM/WIDG, BLDG, NTTS and the
terrain; `cache/` is not an input (the one exception is `sizes.json`, above). Each importer takes `--out=DIR` to write somewhere
else, so the result can be compared against this folder (`diff -r --exclude='*.import'`). The WAD files are never versioned.
The ones that lived as exporters (`export_icons`, `export_particles`, `export_tilesets`, `export_high_noon_*`) are now
`import_ui.py`, `fx_catalog.py` (the particle numbers), `land_themes.py` (the tileset logic) and `sac_formats/{ntts,terrain}.py`.
