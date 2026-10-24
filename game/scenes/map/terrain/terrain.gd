@tool
class_name Terrain
extends MeshInstance3D

## The map's ground as something to see: the mesh (the instanced terrain.glb, or one built from the data) and the editor
## preview. The body to stand on is a saved child of the map (`Collision`: the glb brings one, a map without glb saves its
## own with ConcavePolygonShape3D `terrain_collision.res`). Heights, holes and tiles are not here: ask the child TerrainShape.
## The material swap is TerrainGroundMaterial.

## The ground as numbers: its `Shape` child.
@export var shape: TerrainShape
## The label that says the map has no ground (shown only when it could not be built).
@export var missing: Label3D
## Which kind of ground lies where: 256x256, one pixel per 10 m cell, R open, G earth, B rock, A path (the map's
## ground_roles.png; paint it in any image editor). The god's look says what each kind looks like.
@export var ground_roles: Texture2D
## The map's own baked light on the ground (the map's light.png). Empty = the ground reads evenly lit.
@export var light_map: Texture2D
## The map sits far from where the editor camera opens: in the editor only, the parent is shifted so the map shows
## at the origin (the shift is taken off while saving).
@export var editor_preview_recenter := true:
	set(value):
		editor_preview_recenter = value
		_apply_preview_offset()
## Normals averaged per grid vertex so the slopes read as one surface; off: one flat normal per triangle. Changing it
## swaps the normals only: collision and heights come from the positions.
@export var smooth_ground := true:
	set(value):
		smooth_ground = value
		if mesh != null and _prepare() != null:
			mesh = _make_mesh()

var _arrays: TerrainMeshArrays
var _material: TerrainGroundMaterial


func _init() -> void:
	_material = TerrainGroundMaterial.new(self)

## A mesh built in memory is rebuilt on load and never written into the scene (only the instanced terrain.glb is).
func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh" and not _mesh_is_file():
		property.usage &= ~PROPERTY_USAGE_STORAGE
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if shape == null:
		warnings.append("Falta el hijo Shape (TerrainShape) en `shape`.")
	if ground_roles == null:
		warnings.append("Falta `ground_roles` (el ground_roles.png del mapa): el suelo del dios no sabe qué va dónde.")
	return warnings


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_set_preview_offset(Vector3.ZERO)
		_material.before_save()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_apply_preview_offset()
		_material.after_save()


func _ready() -> void:
	add_to_group("terrain")
	var built := _load_mesh()
	_apply_preview_offset()
	if missing:
		missing.visible = not built


## The mesh arrays as Terrain builds them at runtime (for the bake tools); empty without usable data.
func bake_arrays() -> Array:
	var built := _prepare()
	return built.with_normals(smooth_ground) if built != null else []


func classic_material() -> ShaderMaterial:
	return _material.classic()


func set_classic_material(material: ShaderMaterial) -> void:
	_material.set_classic(material)


func set_ground_override(material: Material) -> void:
	_material.set_override(material)


func clear_ground_override() -> void:
	_material.set_override(null)


func _mesh_is_file() -> bool:
	return mesh != null and not mesh.resource_path.is_empty()


func _apply_preview_offset() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		var center := mesh.get_aabb().get_center() if editor_preview_recenter and mesh else Vector3.ZERO
		_set_preview_offset(Vector3(-center.x, 0.0, -center.z))


func _set_preview_offset(offset: Vector3) -> void:
	if Engine.is_editor_hint() and get_parent() is Node3D:
		(get_parent() as Node3D).position = offset


func _load_mesh() -> bool:
	if shape == null or shape.data == null:
		push_error("Terrain '%s' has no ground: its `shape` needs a TerrainShape with data (MapTerrainData)." % name)
		return false
	if not shape.data.is_valid():
		push_error("Terrain '%s': data is not a valid MapTerrainData (vertices, normals, indices)." % name)
		return false
	if not _saved_mesh_matches():
		if _prepare() == null:
			return false
		mesh = _make_mesh()
	_material.adopt_scene_material()
	return true


## The mesh the scene holds (the instanced terrain.glb) is shown as it is when it still matches the data and smooth_ground;
## otherwise it is rebuilt from the data (with a warning when a file is stale).
func _saved_mesh_matches() -> bool:
	if not _mesh_is_file() or not (mesh is ArrayMesh) or mesh.get_surface_count() != 1:
		return false
	var fits: bool = mesh.surface_get_array_len(0) == shape.data.vertices.size() \
			and bool(mesh.get_meta("smooth_ground", true)) == smooth_ground
	if not fits:
		push_warning("Terrain '%s': %s is stale (vertices or smooth_ground differ from data); rebuilding it in memory." % [name, mesh.resource_path])
	return fits


## Builds (once) both normal sets from the shape's data and tiles. Null when there is no usable data.
func _prepare() -> TerrainMeshArrays:
	if _arrays == null and shape != null:
		_arrays = TerrainMeshArrays.from_data(shape.data, shape.tile_ids())
	return _arrays


func _make_mesh() -> ArrayMesh:
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays.with_normals(smooth_ground))
	return built


## The ground trimesh of the current mesh (Mesh.create_trimesh_shape): what a saved `Collision` holds. Null without a mesh.
func ground_shape() -> ConcavePolygonShape3D:
	return mesh.create_trimesh_shape() if mesh != null else null


## A StaticBody3D with `ground_shape()`, for code that builds a Terrain from the script alone (the suites): a map saves its own.
func make_collision_body() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape_node := CollisionShape3D.new()
	shape_node.shape = ground_shape()
	body.add_child(shape_node)
	return body
