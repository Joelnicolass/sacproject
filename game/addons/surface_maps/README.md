# addons/surface_maps
What: guesses a relief from a colour picture and saves it as maps a material can use: a normal map (OpenGL, green up) and, on request, an ORM (R occlusion, G roughness, B metal or height). Generic (no game rules) and dev only: the export excludes it and nothing in `scenes/` or `data/` refers to it.
Not: how a model looks in a match (its `StandardMaterial3D` `.tres` is the only owner), the ground's shader, Material Maker graphs (tools/material).
Talks to: `ReliefRecipe` (the knobs) -> `ReliefBaker.bake(image, recipe)` (pure pixels: brightness -> high-pass -> blur -> `Image.bump_map_to_normal_map`; cavity occlusion; cutout fill; per-tile wrap) -> `MapWriter` (path, PNG + `.import`, assign with `EditorUndoRedoManager`). `plugin.gd` adds the settings `surface_maps/mirror_from` and `surface_maps/mirror_to`; the inspector section and the batch dialog come in RFC-067 P2. CLI: `tools/bake/bake_relief.gd`.
Edit: the recipe's defaults in `relief_recipe.gd` (strength 0.3, blur 1, high-pass 12, no ORM, roughness 0.85, metallic 0); where maps go in Project Settings `surface_maps/*`; the maps themselves are PNGs under `assets/surfaces/` (retouch them in any image editor).
Check: rules_suite `surface_maps_cases` (determinism, flat, ramp sign, cutout halo, paths) · `Godot --headless --path . --script res://tools/bake/bake_relief.gd -- <material.tres>`.

---

Where maps go: a picture under `assets/original/textures/<owner>/` gets `assets/surfaces/<owner>/<file>_normal.png` (and `_orm.png`); any other picture (your own content) gets them beside it. A PNG that exists is never replaced unless you ask (`overwrite`, `--force`); its `.import` is written only the first time (VRAM compressed, mipmaps, `compress/normal_map=1` for the normal), so its uid and your import settings stay.

Assigning: on a `BaseMaterial3D` the normal goes to Normal Map (`normal_enabled`), the ORM to Ambient Occlusion (channel R) and Roughness (channel G, `roughness` set to 1 because Godot multiplies them). Metallic is left alone: with the default metallic 0 there is nothing to show. Any other Resource with `normal` / `orm` Texture2D fields gets those fields. A material can be shared by several models: its maps show on all of them.

Turning the relief upside down: `invert` in the recipe, or a negative `normal_scale` on the material.

References:
- NormalMap-Online (cpetry, MIT): https://cpetry.github.io/NormalMap-Online/ — the same chain (grey height, blur, strength, invert).
- Godot `Image.bump_map_to_normal_map`: https://docs.godotengine.org/en/stable/classes/class_image.html#class-image-method-bump-map-to-normal-map
- Godot `BaseMaterial3D` (normal map is OpenGL, Y up; ORM is R occlusion, G roughness, B metal): https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html
- Godot texture import (`compress/normal_map`): https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html
