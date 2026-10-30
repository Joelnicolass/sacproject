class_name HoleWalls
extends MeshInstance3D

## The pits of the holes: while some vertices of the ground are taken away it shows the walls
## HoleWallRules makes around them, with the material the ground's mesh wears (so the cliff texture
## and the lighting are the ground's). It builds nothing until a hole is there and again only when a
## hole came or went. Presentation only: a headless process draws none. It does not make holes
## (Terrain) nor decide where the walls go (HoleWallRules).

## The map's ground: its holes, and the mesh whose material the walls wear.
@export var terrain: Terrain
## The ground shader moves the vertices up to this far (m): the walls are not culled while it does.
@export_range(0.0, 60.0, 1.0, "suffix:m") var lift_margin_m := 30.0

var _built_version := 0


func _ready() -> void:
	extra_cull_margin = lift_margin_m
	set_process(
		not Engine.is_editor_hint() and terrain != null and DisplayServer.get_name() != "headless"
	)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if terrain != null
		else PackedStringArray(["The `terrain` socket is missing (the map's Terrain)."])
	)


func _process(_delta: float) -> void:
	if terrain.mesh != null and material_override != terrain.mesh.material_override:
		material_override = terrain.mesh.material_override
	var ground := terrain.field()
	if ground.holes.version == _built_version:
		return
	_built_version = ground.holes.version
	var built := HoleWallRules.arrays(terrain.index, ground.removed_ids())
	if built.is_empty():
		mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = built[0]
	arrays[Mesh.ARRAY_NORMAL] = built[1]
	arrays[Mesh.ARRAY_COLOR] = built[2]
	arrays[Mesh.ARRAY_INDEX] = built[3]
	arrays[Mesh.ARRAY_TEX_UV] = built[4]
	var walls := ArrayMesh.new()
	walls.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = walls
