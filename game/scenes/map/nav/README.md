# map/nav

The map's navmesh (`maps/<tag>/nav.res`, a PropKit `PropNavBake`), on the map's `Nav` node (`MapNav`, an instance of
`map_nav.tscn`, PropKit's `PropNavZones3D`). It is baked in fixed square zones that meet exactly on the zone lines, so a
change in a match re-bakes only the zones it touches (NavService asks, PropKit bakes on worker threads) and gives the
same navmesh as a full bake. The forest trees cut it as projected obstructions (layer 8, group `prop_obstruction`).
Edit: every bake number is in `map_nav.tscn`. Bake with «Bake» on the Nav node or
`godot --headless --path . res://addons/prop_kit/tools/bake_scene.tscn -- --scene=res://scenes/map/maps/<tag>/map.tscn` (`--check` twice must give the same hash).
