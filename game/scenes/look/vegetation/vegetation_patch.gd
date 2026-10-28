@tool
class_name VegetationPatch
extends Node3D

## A cluster of one species in one place: drop it on the map, set the species, radius and count (`radius_m` is a circle in
## the editor). It plants its own MultiMesh (internal, never saved): spots from the hash of (seed, tag, i), heights from the
## terrain, none inside a VegetationClear, the density and «Vegetación» switch of the map's FloraField (found by its group);
## again when it moves, is edited, a clear moves, the preset changes or the ground under it settles. Presentation only (never
## headless or dedicated). For a whole map's worth of plants paint a FloraLayer instead.

const GROUP := &"vegetation_patch"

@export var species: VegetationSpecies:
	set(value):
		if species and species.changed.is_connected(_queue):
			species.changed.disconnect(_queue)
		species = value
		if species:
			species.changed.connect(_queue)
		_queue()
@export_range(0.5, 200.0, 0.5, "suffix:m") var radius_m := 8.0:
	set(value):
		radius_m = value
		_queue()
@export_range(1, 2000) var count := 40:
	set(value):
		count = value
		_queue()
## Another seed scatters the same count elsewhere.
@export var seed := 1:
	set(value):
		seed = value
		_queue()

var _queued := false
var _signature := ""
var _multimesh: MultiMeshInstance3D
var _circle: MeshInstance3D
var _bound_rig: LookRig


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(VegetationClear.FIELD_GROUP)
	set_notify_transform(true)
	_queue()


func _exit_tree() -> void:
	_clear_multimesh()
	if is_instance_valid(_bound_rig) and _bound_rig.vegetation_toggled.is_connected(_on_toggled):
		_bound_rig.vegetation_toggled.disconnect(_on_toggled)
	_bound_rig = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_queue()


## `VegetationClear` nodes call this (through the group) when one moves.
func clears_changed() -> void:
	_queue()


## FloraField calls this when the preset, the switch or the layers changed.
func field_changed() -> void:
	_queue()


## FloraGroundWatch calls this when the ground under its circle settled: it plants again at the new heights.
func ground_moved() -> void:
	_signature = ""
	_queue()


func _on_toggled(_enabled: bool) -> void:
	_queue()


func _queue() -> void:
	if is_inside_tree() and not _queued:
		_queued = true
		_plant.call_deferred()


func _plant() -> void:
	_queued = false
	if not is_inside_tree() or FloraField.presentationless():
		return
	_show_circle()
	var field := get_tree().get_first_node_in_group(FloraField.GROUP) as FloraField
	var rig := field.rig if field else null
	var surface := rig.terrain if rig else null
	var quality := _quality(field)
	if species == null or surface == null or quality == null or not rig.vegetation_enabled:
		_clear_multimesh()
		return
	if _bound_rig != rig:
		_bound_rig = rig
		rig.vegetation_toggled.connect(_on_toggled)
	var clears := VegetationClear.world_rows(get_tree())
	var signature := (
		"%s|%s|%s|%s|%s|%s|%s|%s"
		% [
			[
				species.tag,
				species.mesh,
				species.variation(),
				species.visibility_end_m,
				species.cast_shadow
			],
			radius_m,
			count,
			seed,
			quality.density_scale,
			global_transform,
			clears,
			quality.shadows
		]
	)
	if signature == _signature and _multimesh:
		return
	_clear_multimesh()
	if not surface.is_loaded():
		get_tree().create_timer(0.5).timeout.connect(_queue)
		return
	var mesh := FloraMaterial.mesh_for(species.mesh)
	var buffer := (
		PatchPlanner.plan(
			species,
			seed,
			count,
			radius_m,
			global_transform,
			surface,
			MeshPlanter.map_transform_of(surface),
			quality.density_scale,
			clears
		)
		if mesh
		else PackedFloat32Array()
	)
	if buffer.is_empty():
		return
	_signature = signature
	var config := field.configs[0]
	var end_m := config.radius_m * quality.radius_scale
	end_m = minf(species.visibility_end_m, end_m) if species.visibility_end_m > 0.0 else end_m
	var shadows := species.cast_shadow and quality.shadows
	_multimesh = PatchPlanner.instance(
		mesh, buffer, FloraMaterial.for_mesh(mesh, end_m, config.fade_m), shadows, end_m + radius_m
	)
	add_child(_multimesh, false, Node.INTERNAL_MODE_BACK)
	_multimesh.global_transform = Transform3D.IDENTITY


## The preset's entry for the field's first layer (the editor uses the field's `editor_quality`).
func _quality(field: FloraField) -> VegetationQuality:
	var preset := field.preset() if field else null
	if preset == null or field.configs.is_empty() or field.configs[0] == null:
		return null
	var entry := preset.vegetation_for(field.configs[0].id)
	return entry if entry and entry.enabled and entry.density_scale > 0.0 else null


func _clear_multimesh() -> void:
	_signature = ""
	if _multimesh:
		_multimesh.free()
		_multimesh = null


func _show_circle() -> void:
	if not Engine.is_editor_hint():
		return
	if _circle == null:
		_circle = PatchPlanner.ring()
		add_child(_circle, false, Node.INTERNAL_MODE_BACK)
	_circle.scale = Vector3(radius_m, 1.0, radius_m)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if species != null
		else PackedStringArray(["The species is missing (VegetationSpecies)."])
	)
