# CC0 art in the remaster (RFC-022)

Every file under `assets/cc0/` is public domain (CC0 1.0) and goes through Git LFS (`.gitattributes`).
Each entry: id, name, author/source, license, URL, date downloaded. Add a row when you add a folder.

There is no CC0 art in the game at the moment: the ground's CC0 materials (Grass004, Ground103, Ground108, Rock051,
ambientCG, 2026-10-14) left with the old PBR ground (plan 062-3d). A new folder adds its row here: id, name, author/source,
license, URL, date downloaded.

License text: https://creativecommons.org/publicdomain/zero/1.0/

## Code

| What | Author / source | License | Where |
|---|---|---|---|
| Two-tap offset technique against texture repetition ("Texture Repetition") | Inigo Quilez, https://iquilezles.org/articles/texturerepetition (c) 2017 | MIT (text in the shader header) | `scenes/look/ground/ground_sample.gdshaderinc` (`use_stochastic`, `role_plane`) |
| Grass technique: geometry blades around the camera, density falling with distance, ground of the same color, wind waves that lighten the tips; cells around the camera, curved normals, color by tuft | Nintendo CEDEC 2017 (BotW); E. Wohllaib, GDC 2021 (Ghost of Tsushima); 2Retr0/GodotGrass (MIT) | ideas only, no code copied (CC BY-SA hexaquo series not used) | `scenes/look/grass/grass.gdshader` (header) |
