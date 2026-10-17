# assets/original

Assets extracted from the original game's installation, in Godot-native formats (RFC-033). Git LFS for `.glb`, `.png`, `.res` and `.exr` (see `.gitattributes` at the repo root); the `.import` files are versioned.

Only the importers in `tools/` write here, one per family. The game never writes here. What is edited by hand lives in `data/`. Importers are idempotent (deterministic output, no timestamps) and never touch an existing `.import` (it carries the UID).

The paths are owned by `scenes/data/original_assets.gd` (`OriginalAssets`). Nothing else spells `res://assets/original/`.

| Folder | What | Importer | Cut |
|---|---|---|---|
| `textures/<owner>/<NNN>.png`, `textures/index.json` | One PNG per unique model texture (bodies, buildings, plants), colour key applied to alpha; the index maps model + material label to the PNG (shared ones live under the first model) | `python3 tools/import_textures.py` | 033b |
| `props/<name>.glb` | Static models (buildings, BLDG components, plants): one primitive per material label, a glTF material that only carries the label (the textured one comes from `OriginalMaterial`) | `python3 tools/import_props.py` | 033c |
| `models/<m>.glb`, `models/index.json` | Animated bodies with skeleton and clips | `tools/export_skeletal.py` | RFC-023 |
| `models/sizes.json` | `{bodies, props}` measurements copied from `cache/baked/*.json` (the dedicated server uses them without meshes) | `python3 tools/import_props.py` | 033c |
| `ui/{icons,hud,cursors,xmenu}/` | HUD, icons, cursors, X menu | `python3 tools/import_ui.py` | 033d |
| `fx/<tag>.png`, `fx/fx.json` | Particle atlases (mipmaps only for the ones the catalog lists) and their catalog; `scri.png` is Divine Sight's eye (4x4 sheet, decoded from charlie.wad) | `python3 tools/import_ui.py` | 033d |
| `themes/<god>/` | Tileset, sky, sun, `envi.tres` per god | `python3 tools/import_themes.py` | 033e |
| `maps/high_noon/` | `terrain.res`, `tiles.png`, `light.png`, `ntts.json`, `widgets.json` | `tools/import_map.py` + `tools/import_terrain.gd` | 033f |
| `data/*.json` | Creatures, spells, abilities, wizards, books, buildings | `tools/export_stats.py --out assets/original/data` | 033g |

Until 033h the importers read what the old exporters leave in `cache/look/` (TGA, SAXS, OBJ from `export_bodies.py` / `export_persephone.py`), not the WAD files: do not delete `cache/` before 033h. The WAD files are never versioned. Until each cut lands, its folder does not exist yet.
