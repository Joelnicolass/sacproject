# structures/breaking

What a building does when it falls, on every peer and with no RPC: `StructureBreak` bursts its parts and `BuildingRuin`
shows the ruin. Both are children of `map_building.tscn`.
Add a reaction (smoke, a sound when hurt): a new child with `@export var building: MapBuilding` that connects to
`building.damaged(fraction_left)` (every hit) and `building.destroyed` (once). `MapBuilding` itself does not change.
