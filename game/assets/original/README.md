# assets/original

Assets extracted from the original game's installation, in Godot-native formats (RFC-033). Git LFS for `.glb`, `.png`, `.res` and `.exr` (see `.gitattributes` at the repo root); the `.import` files are versioned.

Only the importers in `tools/` write here, one per family. The game never writes here. What is edited by hand lives in `data/`. Importers are idempotent (deterministic output, no timestamps) and never touch an existing `.import` (it carries the UID).

The paths are owned by `scenes/data/original_assets.gd` (`OriginalAssets`). Nothing else spells `res://assets/original/`.

| Folder | What | Importer | Cut |
|---|---|---|---|
| `textures/<model>/<NNN>.png` | One PNG per unique model texture, chroma key applied to alpha | `tools/import_textures.py` | 033b |
| `props/<name>.glb` | Static models (buildings, BLDG components, plants), no materials | `tools/import_props.py` | 033c |
| `models/<m>.glb`, `models/index.json` | Animated bodies with skeleton and clips | `tools/export_skeletal.py` | RFC-023 |
| `models/sizes.json` | Body and prop measurements (the dedicated server uses them without meshes) | `tools/import_props.py` | 033c |
| `ui/{icons,hud,cursors,xmenu}/` | HUD, icons, cursors, X menu | `tools/import_ui.py` | 033d |
| `fx/<tag>.png`, `fx/fx.json` | Particle atlases and their catalog | `tools/import_ui.py` | 033d |
| `themes/<god>/` | Tileset, sky, sun, `envi.tres` per god | `tools/import_themes.py` | 033e |
| `maps/high_noon/` | `terrain.res`, `tiles.png`, `light.png`, `ntts.json`, `widgets.json` | `tools/import_map.py` + `tools/import_terrain.gd` | 033f |
| `data/*.json` | Creatures, spells, abilities, wizards, books, buildings | `tools/export_stats.py --out assets/original/data` | 033g |

The WAD files are never versioned. Until each cut lands, its folder does not exist yet.
