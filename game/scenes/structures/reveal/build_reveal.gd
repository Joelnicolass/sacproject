class_name BuildReveal
extends Node

## While a tower rises it shows only the part already built: a line climbs from its base to its top as `tower.build_progress`
## goes from 0 to 1, the tower is whole below it and dissolves with a glowing edge above it. When the tower is done (or was
## already done when it appeared, on a late join) the tower's own materials come back and this node stops working.
## Presentation only: it reads the replicated progress and changes nothing of the match; a headless process (the dedicated
## server, the suite) does nothing. The look is the knobs below; the parts are the MeshInstance3D under `visuals`.

@export var tower: CastTower
## The tower's parts (its `Visuals`): every MeshInstance3D below it dissolves.
@export var visuals: Node3D
@export var shader: Shader
@export_group("Look")
@export var edge_color := Color(0.45, 0.7, 1.0)
## Glow of the edge (emission energy).
@export_range(0.0, 16.0, 0.1) var edge_energy := 1.5
## Height of the dissolving band.
@export_range(0.1, 10.0, 0.1, "suffix:m") var edge_width_m := 2.0
## Grey noise that shapes the cut (white = stays longest).
@export var noise: Texture2D
## Noise cells per metre.
@export_range(0.01, 4.0, 0.01) var noise_scale := 0.25
## Part of the band next to the cut that glows.
@export_range(0.0, 1.0, 0.01) var glow_fraction := 0.2
@export_group("")
## Seconds a tower that is already done is watched before this node rests (its progress may arrive a moment after it).
@export var settle_s := 2.0

var _materials: Array[ShaderMaterial] = []
## [MeshInstance3D, surface, the override it had] for every surface that was swapped.
var _swapped: Array[Array] = []
var _dressed := false
var _base_y := 0.0
var _height_m := 0.0
var _done_s := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tower == null:
		warnings.append("Assign `tower` (the tower's root, a CastTower).")
	if visuals == null:
		warnings.append("Assign `visuals` (the tower's Visuals node).")
	if shader == null:
		warnings.append("Assign `shader` (build_reveal.gdshader).")
	return warnings


func _ready() -> void:
	set_process(not Engine.is_editor_hint() and DisplayServer.get_name() != "headless" \
			and tower != null and visuals != null and shader != null)


func _process(delta: float) -> void:
	var progress := clampf(tower.build_progress, 0.0, 1.0)
	if progress >= 1.0:
		_done_s += delta
		if _dressed or _done_s >= settle_s:
			_give_back()
			set_process(false)
		return
	if not _dressed:
		_dress()
	var line := line_y()
	for material in _materials:
		material.set_shader_parameter(&"line_y", line)


## Global Y of the cut line for the current progress: `edge_width_m` under the base at 0, the top at 1 (the tower's own Y before
## the parts were measured). BuildEdge puts the rings and the light on it.
func line_y() -> float:
	if not _dressed:
		return tower.global_position.y if tower != null else 0.0
	var progress := clampf(tower.build_progress, 0.0, 1.0)
	return _base_y - edge_width_m + (_height_m + edge_width_m) * progress


## Every surface under `visuals` that has a StandardMaterial3D gets a reveal copy of it (other materials stay as they are).
func _dress() -> void:
	_dressed = true
	var box := AABB()
	var first := true
	for node in visuals.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null:
			continue
		var placed := part.global_transform * part.mesh.get_aabb()
		box = placed if first else box.merge(placed)
		first = false
		for surface in part.mesh.get_surface_count():
			var source := part.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			_swapped.append([part, surface, part.get_surface_override_material(surface)])
			var copy := _reveal_of(source)
			_materials.append(copy)
			part.set_surface_override_material(surface, copy)
	_base_y = box.position.y
	_height_m = box.size.y


func _reveal_of(source: BaseMaterial3D) -> ShaderMaterial:
	var copy := ShaderMaterial.new()
	copy.shader = shader
	copy.set_shader_parameter(&"albedo_tex", source.albedo_texture)
	copy.set_shader_parameter(&"albedo_color", source.albedo_color)
	copy.set_shader_parameter(&"roughness", source.roughness)
	var scissor := source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	copy.set_shader_parameter(&"alpha_scissor", source.alpha_scissor_threshold if scissor else 0.0)
	SurfaceRelief.forward(source, copy)
	copy.set_shader_parameter(&"noise_tex", noise)
	copy.set_shader_parameter(&"noise_scale", noise_scale)
	copy.set_shader_parameter(&"edge_color", edge_color)
	copy.set_shader_parameter(&"edge_energy", edge_energy)
	copy.set_shader_parameter(&"edge_width_m", edge_width_m)
	copy.set_shader_parameter(&"glow_fraction", glow_fraction)
	return copy


func _give_back() -> void:
	for entry: Array in _swapped:
		var part := entry[0] as MeshInstance3D
		if is_instance_valid(part):
			part.set_surface_override_material(int(entry[1]), entry[2] as Material)
	_swapped.clear()
	_materials.clear()
