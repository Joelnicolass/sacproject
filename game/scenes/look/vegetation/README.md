# look/vegetation

The mesh plants of a map, drawn as MultiMeshes around the camera. Presentation only: none of it exists on a dedicated
or headless process.
- `FloraLayer`: a species plus a painted density PNG (1 px = 8 m, white = `max_per_cell`). Paint it with «Flora» in the
  3D toolbar or in any image editor.
- `VegetationPatch`: a cluster of one species in a circle. `VegetationClear` (in `look/grass/`) clears plants around a house.
- Placement is a pure hash of seed and species tag (no RNG), so every run plants the same.
Edit: species in `data/vegetation/species/`; LOD and fade in `data/look/vegetation/original_plants.tres` and the preset.
