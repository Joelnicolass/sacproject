@tool
class_name TerrainMesh
extends MeshInstance3D

## The map's ground as something to see: a mesh built in memory from the triangles of its `terrain` (again when they are
## derived again in the editor), never saved and never built without a window (headless, the dedicated server).
## Not: the body to stand on (TerrainCollision), heights, holes and roles (its `terrain`), where the editor shows
## the map (MapRoot). The material swap is TerrainGroundMaterial; the look's ground comes from TerrainLayer.

## The ground as numbers: the Terrain this node hangs from.
@export var terrain: Terrain
## The label that says the map has no ground (shown only when the Terrain has no heights).
@export var missing: Label3D
## Normals averaged per lattice vertex so the slopes read as one surface; off: one flat normal per triangle. Changing it
## swaps the normals only: collision and heights come from the triangles.
@export var smooth_ground := true:
	set(value):
		smooth_ground = value
		if _arrays != null:
			mesh = _make_mesh()

var _arrays: TerrainMeshArrays
var _material: TerrainGroundMaterial


func _init() -> void:
	_material = TerrainGroundMaterial.new(self)


## The mesh is made from the heights on every load: it is never written into the scene.
func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh":
		property.usage &= ~PROPERTY_USAGE_STORAGE
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if terrain != null else PackedStringArray(["Falta el socket `terrain` (el Terrain padre)."])


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_material.before_save()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_material.after_save()


func _ready() -> void:
	if terrain != null:
		terrain.derived.connect(_build)
	_build()


## The look's ground (TerrainLayer): shown until `clear_ground`; never saved into the scene.
func set_ground(material: Material) -> void:
	_material.wear(material)


## Back to the terrain's own plain material («no look»).
func clear_ground() -> void:
	_material.wear(null)


## Builds the mesh from the terrain's triangles (none without a window or without heights).
func _build() -> void:
	var started := Time.get_ticks_usec()
	var loaded := terrain != null and terrain.is_loaded()
	_arrays = TerrainMeshArrays.from_data(terrain.data) if loaded and _draws() else null
	mesh = _make_mesh() if _arrays != null else null
	if not loaded and not Engine.is_editor_hint():
		push_error("TerrainMesh '%s' has no ground: its `terrain` needs `heights` (the map's heights.png)." % name)
	if missing:
		missing.visible = not loaded
	if DebugLog.on(&"terrain_load"): print("terrain_load: %s mesh %.0f ms (%s)" % [name, (Time.get_ticks_usec() - started) / 1000.0, "built" if mesh else "none"])


## A mesh is only worth building where something is drawn.
static func _draws() -> bool:
	return DisplayServer.get_name() != "headless"


func _make_mesh() -> ArrayMesh:
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays.with_normals(smooth_ground))
	return built
