# look

What: the rig (`look_rig.tscn`) hands a god's `LookProfile` and the quality preset to its layers (Sun, Ground, Environment, Grass, FxLight, Flora, TerrainDeform: the texture with how far the land has moved, which the ground shaders read; Underside: the god's `undr` picture far under the island, seen through the void and the pits, from `SkyLook.under_texture`; Atmosphere: the hour and the weather of now, see `atmosphere/README.md`; AmbientLife: swarms by hour and weather, see `life/README.md`); each layer is the only writer of its object.
Not: what a god is (GodType), when a biome is drawn (scenes/match/biome_rules.gd); the atmosphere writes no light itself (Sun and Environment read its sample).
Talks to: MatchBiome -> `map.look.apply_profile(god.look)` -> `LookLayer.apply_look(profile, rig)` / `apply_quality(preset)`; the rig emits `profile_applied`. `Atmosphere.changed(sample)` -> Sun, Environment and AmbientLife (sockets `atmosphere`).
Edit: `data/look/<god>.tres` (the profile) -> `sky/<god>_sky.tres` (the sky shader's material, fog, ambient), `light/<god>_light.tres`, `glow/<god>_glow.tres`; in the editor open any `scenes/map/maps/<m>/map.tscn`, select `Look` and pick a god in `Preview god`: the map shows its look live (clear it to go back); `Preview quality` (default high) is what lets the plants show. Editor only: the running game ignores both. Relief of the models (RFC-067): not a layer here; each texture's `StandardMaterial3D` in `scenes/bodies/materials/` owns its normal map, and `surface_relief.gd` forwards it into the stone and build copies.
Ground (plan 062): a look with a `GodGround` (`data/look/<god>.tres` -> Ground: four embedded `GroundRole`, open/earth/rock/path) wears it on the map's `Terrain.ground_roles` (ground_roles.png, R G B A) and `Terrain.light_map` through the one shader `ground/ground.gdshader`; a look without one keeps its classic ground (`themes/<god>/ground_classic.tres`, and the map's `NativeGround` for a map of that god's land) until cut 3.
Check: `debug/look/ambience_lab.tscn` (day, night and weather in a loop), `debug/look/ground_roles_lab.tscn` (High Noon's hills, `Map/Look` Preview god), `persephone_compare.tscn` (tutorial, 3 fixed cameras, `tools/import/measure_ground.py`), `biome_gallery.tscn`, `look_gallery.tscn`, `grass_lab.tscn`, `sky_compare.tscn`, `surface_lab.tscn` (relief under an orbiting light) (F6); seams and sharpness: match_shots `--views=ground` + `tools/import/measure_seams.py`.

---

# scenes/look/

Apariencia: perfiles, capas, cielo, pasto, luz y calidad. Los temas y looks concretos son `.tres` en `data/look/`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/look/`.
