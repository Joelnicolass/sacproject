@tool
class_name HitFlash
extends Node

## A body lights up for a blink when it loses health: `material` goes over its meshes as
## `material_overlay` and its `hit_flash` falls from `peak` to 0 in `flash_s`; then the overlay
## comes off. Every peer sees it (Health.current is replicated). It does not blink with «Sangre» off
## (FeelPrefs.blood), nor a body that is hidden or faded (stealth, playing dead, a ghost,
## summoning), and nothing headless.
## What it does not do: change the body's own materials (StoneLook owns the surface overrides) or
## its rig's speed (no hit-stop).

const PARAM := &"hit_flash"

@export var health: Health:
	set(value):
		health = value
		update_configuration_warnings()
## What draws the body: its rig's skinned meshes, or its own mesh for a hybrid.
@export var visual: BodyVisual:
	set(value):
		visual = value
		update_configuration_warnings()
## The overlay (scenes/fx/effects/blood/hit_flash.tres, an additive shader with `instance uniform
## float hit_flash`).
@export var material: ShaderMaterial:
	set(value):
		material = value
		update_configuration_warnings()
## The player's «Sangre» (scenes/ui/feel_prefs.tres): off, nothing shows.
@export var prefs: FeelPrefs:
	set(value):
		prefs = value
		update_configuration_warnings()
@export_range(0.0, 2.0, 0.01) var peak := 0.45
@export_range(0.01, 1.0, 0.01, "suffix:s") var flash_s := 0.12
## A drop smaller than this share of the maximum does not blink (a sliver of poison).
@export_range(0.0, 1.0, 0.005) var min_lost := 0.005

## How many blinks this body made (the checks read it).
var flashes := 0

var _active := false
var _last := 0.0
var _meshes: Array[GeometryInstance3D] = []
var _tween: Tween
var _amount := 0.0


func _ready() -> void:
	if Engine.is_editor_hint() or health == null or visual == null or material == null:
		return
	_active = BodyLook.loads_meshes()
	if not _active:
		return
	_last = health.current
	health.changed.connect(_on_health_changed)


## False headless, or with «Sangre» off.
func is_active() -> bool:
	return _active and (prefs == null or prefs.blood())


## Where the blink is now (0 = none).
func amount() -> float:
	return _amount


## True while the overlay is on a mesh.
func is_lit() -> bool:
	return not _meshes.is_empty()


func _on_health_changed(current: float, maximum: float) -> void:
	var drop := _last - current
	_last = current
	if drop <= 0.0 or maximum <= 0.0 or drop / maximum < min_lost or not is_active():
		return
	if not visual.is_visible_in_tree() or visual.transparency > 0.01:
		return
	_flash()


func _flash() -> void:
	if _lay():
		flashes += 1
		_tween = create_tween()
		_tween.tween_method(_set_amount, peak, 0.0, flash_s)
		_tween.tween_callback(_clear)


## Warm-up (the WarmHook child): the overlay over this body for one drawn frame, so the first hit
## compiles nothing (not counted).
func warm(_stage: Node3D) -> void:
	if is_active() and visual.is_visible_in_tree() and _lay():
		await RenderingServer.frame_post_draw
		_clear()


## The overlay over the body's meshes at `peak`. False when there is no mesh to lay it on.
func _lay() -> bool:
	_clear()
	_meshes = _targets()
	for mesh in _meshes:
		mesh.material_overlay = material
	_set_amount(peak)
	return not _meshes.is_empty()


func _targets() -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	if visual.rig != null:
		for mesh in visual.rig.skinned_meshes():
			found.append(mesh)
	if visual.mesh != null:
		found.append(visual)
	return found


func _set_amount(value: float) -> void:
	_amount = value
	for mesh in _meshes:
		if is_instance_valid(mesh):
			InstanceParams.set_on(mesh, PARAM, value)


func _clear() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	for mesh in _meshes:
		if is_instance_valid(mesh):
			InstanceParams.set_on(mesh, PARAM, 0.0)
			mesh.material_overlay = null
	_meshes.clear()
	_amount = 0.0


func _exit_tree() -> void:
	_clear()


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if health == null:
		out.append("Assign `health` (its Health).")
	if visual == null:
		out.append("Assign `visual` (its BodyVisual, Tilt/Mesh).")
	if material == null:
		out.append("Assign `material` (scenes/fx/effects/blood/hit_flash.tres).")
	var prefs_warning := FeelPrefs.socket_warning(prefs)
	if not prefs_warning.is_empty():
		out.append(prefs_warning)
	return out
