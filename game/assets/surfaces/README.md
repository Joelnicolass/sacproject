# assets/surfaces
What: the optional relief maps of the models' textures: `<owner>/<file>_normal.png` (OpenGL, green up) and `<owner>/<file>_orm.png` (R occlusion, G roughness, B metal), mirroring `assets/original/textures/<owner>/<file>.png`. Stored in git LFS; the game reads them through the materials that point at them.
Not: the albedos (assets/original/textures), the maps of your own content (they sit beside its albedo), the ground's roles (data/look).
Talks to: a `StandardMaterial3D` in `scenes/bodies/materials/` points at a map; nothing looks a map up by its name. The generator (`addons/surface_maps`, `tools/bake/bake_relief.gd`) uses the name only to choose where to write.
Edit: the PNG is the source: retouch it in Krita or any image editor and Godot reimports it. A map is generated once; the generator never replaces a PNG that exists unless asked (`overwrite` / `--force`), and the recipe it used is not kept.
Check: rules_suite `surface_maps_cases`. Delete a map only after taking it off its material (otherwise the material points at a missing file).
