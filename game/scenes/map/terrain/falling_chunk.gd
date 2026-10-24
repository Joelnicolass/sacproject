class_name FallingChunk
extends MeshInstance3D

## The piece of ground that drops when a vertex is taken away: the triangles that touched it, in the ground's own look, fall
## straight down faster and faster and go out of sight. Played on every peer by FxBus.broadcast_scene (params `vertex`: the lattice
## id). It is only what you see: the hole is already in the ground's numbers and in the collision. Presentation only: a headless
## process shows none. The shape of the piece is FallingChunkRules.
## Ref: sacengine updateFallingLandChunk (state.d:26094-26101).

## How fast it speeds up (sacengine fallingLandChunkAcceleration).
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var gravity := 30.0
## It goes when it is this far below the lowest corner of the piece (twice the depth of the map).
@export_range(10.0, 200.0, 1.0, "suffix:m") var fall_depth_m := 100.0

var _speed := 0.0
var _gone_at := 0.0


func _ready() -> void:
	set_process(false)


## `params["vertex"]`: the lattice id of the vertex that was taken away.
func play(params: Dictionary) -> void:
	var shape := TerrainShape.of(self)
	var terrain := get_tree().get_first_node_in_group(Terrain.GROUP) as Terrain
	if shape == null or terrain == null or DisplayServer.get_name() == "headless":
		queue_free()
		return
	var built := FallingChunkRules.arrays(shape.index, shape.displacement().texels, shape.tile_ids(), int(params["vertex"]))
	if built.is_empty():
		queue_free()
		return
	var piece := ArrayMesh.new()
	piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built)
	mesh = piece
	material_override = terrain.material_override
	# The piece carries its own heights and the ground shader reads the light and the marks from map coordinates: the mesh is in
	# them, and this node stays at the origin and only goes down.
	set_instance_shader_parameter(&"deform_follow", 0.0)
	global_position = Vector3.ZERO
	_gone_at = piece.get_aabb().position.y + FallingChunkRules.SKIRT_M - fall_depth_m
	set_process(true)


func _process(delta: float) -> void:
	_speed += gravity * delta
	position.y -= _speed * delta
	if position.y < _gone_at:
		queue_free()
