# map/nav

The map's navmesh (`nav.res`). It is baked in fixed square zones that meet exactly on the zone lines, so a change in a
match re-bakes only the zones it touches (`NavRebake`) and gives the same navmesh as a full bake.
Keep `use_edge_connections` off on the region: the zones already meet, and on it makes each swap much slower.
Edit: every bake number is in `data/nav/nav_bake.tres`. Bake with «Bake navmesh» or
`godot --headless --path . res://tools/bake/bake_nav.tscn -- --map=<tag>` (`--check` twice must give the same hash).
