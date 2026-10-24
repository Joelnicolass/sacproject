class_name ZoneGround
extends RefCounted

## The height of the land under a point, for what falls from a cloud: the map's terrain when the world has one, else `fallback` (the
## flat floor of a check). It does not move or hurt anything.


static func height(node: Node, x: float, z: float, fallback: float) -> float:
	var shape := TerrainShape.of(node)
	var land := shape.height_at(x, z) if shape != null else NAN
	return fallback if is_nan(land) else land
