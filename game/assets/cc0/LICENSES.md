# CC0 art in the remaster (RFC-022)

Every file under `assets/cc0/` is public domain (CC0 1.0) and goes through Git LFS (`.gitattributes`).
Each entry: id, name, author/source, license, URL, date downloaded. Add a row when you add a folder.

## Ground (`ground/<id>/`)

Files per material, made from the 2K-JPG zip of the source (only these maps are used):

- `albedo.jpg`: the Color map, as is (sRGB).
- `normal.png`: NormalGL (OpenGL, green up), re-saved as PNG.
- `orm.png`: R = AmbientOcclusion, G = Roughness, B = Displacement (height; used to blend layers). No metallic channel.

The `.import` files next to them are versioned on purpose (VRAM compression and mipmaps on; the default
import would leave them uncompressed and without mipmaps).

| id | Name | Author / source | License | URL | Date |
|---|---|---|---|---|---|
| Grass004 | Grass 004 | ambientCG (ambientcg.com) | CC0 1.0 | https://ambientcg.com/a/Grass004 | 2026-10-14 |
| Ground103 | Ground 103 | ambientCG (ambientcg.com) | CC0 1.0 | https://ambientcg.com/a/Ground103 | 2026-10-14 |
| Rock051 | Rock 051 | ambientCG (ambientcg.com) | CC0 1.0 | https://ambientcg.com/a/Rock051 | 2026-10-14 |
| Ground108 | Ground 108 | ambientCG (ambientcg.com) | CC0 1.0 | https://ambientcg.com/a/Ground108 | 2026-10-14 |

License text: https://creativecommons.org/publicdomain/zero/1.0/ (ambientCG: https://docs.ambientcg.com/license/).

## Code

| What | Author / source | License | Where |
|---|---|---|---|
| Two-tap offset technique against texture repetition ("Texture Repetition") | Inigo Quilez, https://iquilezles.org/articles/texturerepetition (c) 2017 | MIT (text in the shader header) | `scenes/world/look/ground/ground_pbr.gdshader` (`tap_stochastic`) |
| Grass technique: geometry blades around the camera, density falling with distance, ground of the same color, wind waves that lighten the tips; cells around the camera, curved normals, color by tuft | Nintendo CEDEC 2017 (BotW); E. Wohllaib, GDC 2021 (Ghost of Tsushima); 2Retr0/GodotGrass (MIT) | ideas only, no code copied (CC BY-SA hexaquo series not used) | `scenes/world/look/grass/grass.gdshader` (header) |
