class_name SeeThroughLook
extends RefCounted

## The see-through look of ONE body (the ghost of a wizard): transparency, no shadow and the
## shadeless material with energy that follows the fade. It works on the meshes of that instance
## only: a BodyVisual with a BodyRig draws with the skeleton's skinned meshes, a baked body with its
## own mesh. The materials the other bodies share (scenes/bodies/materials/) are never touched: the
## shadeless copy goes on each MeshInstance3D as a surface override.

var visual: GeometryInstance3D
## Converts a shadeless energy to Godot's light scale (GhostForm.energy_scale).
var energy_scale := 0.224
## The end of the fade.
var ghost_alpha := 0.36
var ghost_energy := 10.0

## 0 opaque, 1 invisible: the last value given to set_transparency().
var transparency := 0.0

var _shadeless := false
## MeshInstance3D -> its shadeless copies, one per surface; the meshes the look was dressed on.
var _dressed: Dictionary = {}
var _dressed_meshes: Dictionary = {}


func _init(target: GeometryInstance3D = null) -> void:
	visual = target


## Transparency of the whole body (the rig's meshes too: GeometryInstance3D.transparency does not
## inherit).
func set_transparency(value: float) -> void:
	transparency = value
	if visual == null:
		return
	if visual is BodyVisual:
		(visual as BodyVisual).set_fade(value)
	else:
		visual.transparency = value


func set_shadow(on: bool) -> void:
	var mode := (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if on
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	for instance in meshes():
		instance.cast_shadow = mode


## Dresses (or undresses) every mesh of the body with the unshaded copy of its material.
func set_shadeless(on: bool) -> void:
	_shadeless = on
	_undress()
	if on:
		for instance in meshes():
			_dress(instance)


## Energy follows the fade: 1 at alpha 1, ghost_energy at ghost_alpha. A mesh that loaded after the
## stage began (the rig shows its model later) is dressed here.
func update() -> void:
	if not _shadeless or visual == null:
		return
	for instance in meshes():
		if not _dressed.has(instance) or instance.mesh != _dressed_meshes.get(instance):
			_dress(instance)
	var progress := clampf(transparency / (1.0 - ghost_alpha), 0.0, 1.0)
	var energy := lerpf(1.0, ghost_energy, progress) * energy_scale
	for entry: Dictionary in _dressed.values():
		for mat: StandardMaterial3D in entry["copies"]:
			mat.albedo_color = Color(energy, energy, energy, 1.0)


## The MeshInstance3D nodes that draw this body: the rig's skinned meshes, or the visual's own.
func meshes() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if visual == null:
		return found
	var rig: Variant = visual.get("rig")
	if rig is BodyRig and (rig as BodyRig).is_loaded():
		found.append_array((rig as BodyRig).skinned_meshes())
	var own := visual as MeshInstance3D
	if own != null and (own.mesh != null or found.is_empty()):
		found.append(own)
	return found


func _undress() -> void:
	for instance: MeshInstance3D in _dressed:
		if not is_instance_valid(instance):
			continue
		var originals: Array = _dressed[instance]["originals"]
		for i in mini(originals.size(), instance.get_surface_override_material_count()):
			instance.set_surface_override_material(i, originals[i])
	_dressed.clear()
	_dressed_meshes.clear()


## The unshaded copy of what the surface shows (its override, as the skeleton's meshes carry the
## shared material there, or the mesh's own); the previous overrides are kept to put back.
func _dress(instance: MeshInstance3D) -> void:
	if instance.mesh == null:
		return
	if _dressed.has(instance):
		var kept: Array = _dressed[instance]["originals"]
		for i in mini(kept.size(), instance.get_surface_override_material_count()):
			instance.set_surface_override_material(i, kept[i])
	var originals: Array = []
	var copies: Array = []
	for i in instance.mesh.get_surface_count():
		var current := instance.get_surface_override_material(i)
		originals.append(current)
		var base := (
			(current if current != null else instance.mesh.surface_get_material(i))
			as StandardMaterial3D
		)
		var copy: StandardMaterial3D = base.duplicate() if base else StandardMaterial3D.new()
		copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		instance.set_surface_override_material(i, copy)
		copies.append(copy)
	_dressed[instance] = {"originals": originals, "copies": copies}
	_dressed_meshes[instance] = instance.mesh
