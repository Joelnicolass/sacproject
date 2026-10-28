@tool
class_name SurfaceReliefLayer
extends LookLayer

## The one global switch of the relief maps. On when the preset's `relief_maps` and the player's
## «Relieve» option (GraphicsPrefs; ignored under AgentKit like GraphicsApplier, so a test never
## inherits the player's file) both say so. Off, it turns off in memory the normal map of every
## material drawn (shared .tres or a copy) and of every mesh that enters the tree later, and the
## relief of the StoneLook / BuildReveal copies (`use_relief`); on again (or when the layer leaves
## with its map), exactly those come back. The only runtime writer of `normal_enabled`; it never
## saves (the .tres on disk keeps its maps). Inert in the editor. Cost: none while on.
## Not: which maps a material has (its .tres), how they are made (addons/surface_maps).

## The shared player preference (scenes/ui/graphics_prefs.tres). Empty = only the preset decides (a
## debug scene).
@export var prefs: GraphicsPrefs

var _preset_on := true
var _on := true
## What this layer turned off, to give back exactly that.
var _off: Array[BaseMaterial3D] = []
var _copies: Array[ShaderMaterial] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if _player() and not prefs.changed.is_connected(_refresh):
		prefs.changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	_restore()


func apply_quality(preset: LookQuality) -> void:
	_preset_on = preset == null or preset.relief_maps
	_refresh()


## Turns the relief maps of everything drawn on or off, in memory only.
func set_relief(on: bool) -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or on == _on:
		return
	_on = on
	var tree := get_tree()
	if on:
		_restore()
		return
	for node in tree.root.find_children("*", "GeometryInstance3D", true, false):
		_dress(node)
	tree.node_added.connect(_dress)


func _refresh() -> void:
	set_relief(_preset_on and (not _player() or prefs.relief_enabled()))


func _player() -> bool:
	return prefs != null and not UserSettings.sandboxed()


func _restore() -> void:
	for material in _off:
		material.normal_enabled = true
	for copy in _copies:
		copy.set_shader_parameter(&"use_relief", true)
	_off.clear()
	_copies.clear()
	if is_inside_tree() and get_tree().node_added.is_connected(_dress):
		get_tree().node_added.disconnect(_dress)


func _dress(node: Node) -> void:
	for material in _materials_of(node):
		if material is BaseMaterial3D and SurfaceRelief.is_on(material) and not _off.has(material):
			(material as BaseMaterial3D).normal_enabled = false
			_off.append(material)
		elif (
			material is ShaderMaterial
			and (material as ShaderMaterial).get_shader_parameter(&"use_relief") == true
		):
			(material as ShaderMaterial).set_shader_parameter(&"use_relief", false)
			_copies.append(material)


## Every material a mesh draws with: its override, its surface overrides and its mesh's own
## surfaces.
static func _materials_of(node: Node) -> Array[Material]:
	var out: Array[Material] = []
	var geometry := node as GeometryInstance3D
	if geometry == null:
		return out
	out.append(geometry.material_override)
	var mesh: Mesh = null
	if geometry is MeshInstance3D:
		var instance := geometry as MeshInstance3D
		mesh = instance.mesh
		for i in instance.get_surface_override_material_count():
			out.append(instance.get_surface_override_material(i))
	elif geometry is MultiMeshInstance3D and (geometry as MultiMeshInstance3D).multimesh != null:
		mesh = (geometry as MultiMeshInstance3D).multimesh.mesh
	if mesh != null:
		for i in mesh.get_surface_count():
			out.append(mesh.surface_get_material(i))
	return out
