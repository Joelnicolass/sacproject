extends RefCounted

## 063D-2a case of rules_suite: the lattice of the ground has one source, TerrainGrid. The one mirror in the shaders
## (terrain_deform.gdshaderinc) says the same numbers, the surface of a map covers SIZE_M from the origin, and the lattice
## arithmetic goes there and back (id, vertex, point) without drift. It needs no map and no tree.

const SHADER_MIRROR := "res://scenes/look/ground/terrain_deform.gdshaderinc"


func run(_host: Node3D) -> Dictionary:
	return {"grid_constants": _grid_constants()}


func _grid_constants() -> Dictionary:
	var checks := {}
	var text := FileAccess.get_file_as_string(SHADER_MIRROR)
	checks["shader_cell"] = _shader_const(text, "DEFORM_CELL") == TerrainGrid.CELL_M
	checks["shader_last"] = _shader_const(text, "DEFORM_LAST") == float(TerrainGrid.SIDE - 1)
	checks["size_is_side_cells"] = TerrainGrid.SIZE_M == float(TerrainGrid.SIDE) * TerrainGrid.CELL_M and TerrainGrid.COUNT == TerrainGrid.SIDE * TerrainGrid.SIDE
	var surface := Terrain.new()
	checks["bounds"] = surface.bounds() == Rect2(0.0, 0.0, TerrainGrid.SIZE_M, TerrainGrid.SIZE_M)
	checks["field"] = surface.field().size == Vector2i(TerrainGrid.SIDE, TerrainGrid.SIDE) and surface.field().cell_m == TerrainGrid.CELL_M
	surface.free()
	var last := Vector2i(TerrainGrid.SIDE - 1, TerrainGrid.SIDE - 1)
	checks["id_round_trip"] = TerrainGrid.vertex_of(TerrainGrid.id_of(Vector2i(126, 127))) == Vector2i(126, 127) and TerrainGrid.id_of(last) == TerrainGrid.COUNT - 1
	checks["point_round_trip"] = TerrainGrid.vertex_near(TerrainGrid.point_of(Vector2i(126, 127))) == Vector2i(126, 127)
	checks["vertex_id_cuts"] = TerrainGrid.vertex_id(-50.0, TerrainGrid.SIZE_M + 50.0) == TerrainGrid.id_of(Vector2i(0, TerrainGrid.SIDE - 1))
	checks["rect_cuts"] = TerrainGrid.vertex_rect(Vector2(5.0, 5.0), 30.0) == Rect2i(0, 0, 5, 5)
	checks["area_of"] = TerrainGrid.area_of(Rect2i(1, 2, 3, 4)) == Rect2(10.0, 20.0, 30.0, 40.0)
	var bad := PackedStringArray()
	for key: String in checks:
		if not bool(checks[key]):
			bad.append(key)
	return {"ok": bad.is_empty(), "failed": bad}


## The value of `const float <name> = <value>;` in a shader text; NAN when it is not there.
func _shader_const(text: String, name: String) -> float:
	var pattern := RegEx.create_from_string("const\\s+float\\s+" + name + "\\s*=\\s*([0-9.]+)\\s*;")
	var found := pattern.search(text)
	return found.get_string(1).to_float() if found != null else NAN
