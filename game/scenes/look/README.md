# look

What: the rig (`look_rig.tscn`) hands a god's `LookProfile` and the quality preset to its layers (Sun, Ground, Environment, Grass, FxLight, Flora, TerrainDeform: the texture with how far the land has moved, which the ground shaders read); each layer is the only writer of its object.
Not: what a god is (GodType), when a biome is drawn (scenes/match/biome_rules.gd), or time of day and weather (empty slots `TimeOfDay` and `Weather`, RFC-058).
Talks to: MatchBiome -> `map.look.apply_profile(god.look)` -> `LookLayer.apply_look(profile, rig)` / `apply_quality(preset)`; the rig emits `profile_applied`.
Edit: `data/look/<god>.tres` (the profile) -> `sky/<god>_sky.tres` (the sky shader's material, fog, ambient), `light/<god>_light.tres`, `glow/<god>_glow.tres`; in the editor open any `scenes/map/maps/<m>/map.tscn`, select `Look` and pick a god in `Preview god`: the map shows its look live (clear it to go back); `Preview quality` (default high) is what lets the plants show. Editor only: the running game ignores both.
Ground: a map made of one god's land holds a `NativeGround` in its rig (`native_ground`); a look of that god (`LookProfile.god`) wears its tiles, any other look its own atlas. `debug/look/persephone_compare.tscn` shows the tutorial's valley from three fixed cameras.
Check: `debug/look/biome_gallery.tscn`, `look_gallery.tscn`, `grass_lab.tscn`, `sky_compare.tscn` (F6).
Ground: a map made of one god's land holds a `NativeGround` in its rig (`native_ground`); a look of that god (`LookProfile.god`) wears its tiles, any other look its own atlas. `debug/look/persephone_compare.tscn` shows the tutorial's valley from three fixed cameras. The classic ground (`sacrifice_ground.gdshader`) keeps each tile inside its own atlas cell (no seams) and lays the land's grain over it (`detail` layers + `detail_ids`, `detail_strength` in `themes/<god>/ground_classic.tres`).
Check: `debug/look/biome_gallery.tscn`, `look_gallery.tscn`, `grass_lab.tscn`, `sky_compare.tscn` (F6); seams and sharpness: match_shots `--views=ground` + `tools/import/measure_seams.py`.

---

# scenes/look/

Apariencia: perfiles, capas, cielo, pasto, luz y calidad. Los temas y looks concretos son `.tres` en `data/look/`.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/look/`.
