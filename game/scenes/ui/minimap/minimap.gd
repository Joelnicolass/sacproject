@tool
class_name Minimap
extends Control

## RFC-037: the circle at the bottom right of the HUD (sacengine renderMinimap). It builds the frame's state (center, turn,
## zoom) and hands it to its children: `Ground` draws the baked terrain, `Markers` the icons. It knows no unit type.
## Local presentation: nothing is replicated and no order starts here (037c adds input).
##
## Everything is laid out in HUD units (sized by the shared `hud_scale`, like SpellBook and SelectionRoster) and
## `scale` grows it from the bottom-right corner. Heading up (the default) turns the map with the camera so up is where
## it looks; the center is `lead_factor` camera distances ahead of the followed wizard. `view.heading_up = false`
## keeps north up and centers on the wizard.
## Map axes: world (x, z) → local units. A top view has +x right and +z down, so no flip is needed.

## `Minimap.zoom` changed (037c wheel).
signal zoom_changed(zoom: float)

@export_group("Sockets")
## The world camera (WorldCamera). Reads its turn and the wizard it follows.
@export var camera: Camera3D
@export var terrain_bake: MinimapTerrainBake
## Parent of the structures a player builds (%Structures): the Manaliths. The map's own buildings (hundreds of houses) are not on the map.
@export var structures_root: Node
@export var ground: Control
@export var markers: Control
@export_group("Resources")
@export var style: MinimapStyleSet
@export var view: MinimapView
## Shared HUD size (the spell book, the roster and the cursor read the same one).
@export var hud_scale: HudScale = preload("res://data/ui/hud_scale.tres")

## Meters of the world per HUD unit in play (starts at `view.zoom`).
var zoom := 2.7
## World x/z drawn at the circle's center, this frame.
var center_world := Vector2.ZERO
## Unit vector the camera looks along on the ground, world x/z.
var heading := Vector2(0.0, 1.0)
## HUD scale in use (screen pixels per HUD unit).
var factor := 1.0

var _to_local := Transform2D.IDENTITY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if camera == null or terrain_bake == null or ground == null or markers == null:
		warnings.append("Asigná camera, terrain_bake, ground y markers.")
	if style == null or view == null:
		warnings.append("Asigná style y view (data/ui/minimap/).")
	var scale_warning := HudScale.socket_warning(hud_scale)
	if not scale_warning.is_empty():
		warnings.append(scale_warning)
	return warnings


func _ready() -> void:
	if view:
		zoom = view.zoom
	if Engine.is_editor_hint():
		return
	# No local player on the dedicated server: nothing to show.
	if MpKit.local_slot() <= 0:
		visible = false
		set_process(false)
		return
	get_viewport().size_changed.connect(_fit_screen)
	if hud_scale:
		hud_scale.changed.connect(_fit_screen)
	_fit_screen()
	_update_state()


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_state()
	if ground:
		ground.queue_redraw()
	if markers:
		markers.queue_redraw()


## Radius of the circle in HUD units.
func radius() -> float:
	return view.radius_px if view else 80.0


## Local position (HUD units, this control's origin) of a world point.
func world_to_minimap(point: Vector3) -> Vector2:
	return _to_local * Vector2(point.x, point.z)


## World x/z under a local position (the inverse; 037c uses it to aim from the minimap).
func local_to_world(local: Vector2) -> Vector2:
	return _to_local.affine_inverse() * local


## Local direction on the map of a world x/z direction (unit in, unit out).
func world_dir_to_local(direction: Vector2) -> Vector2:
	return _to_local.basis_xform(direction).normalized()


## Maps world x/z to local units; the ground draws under it.
func world_transform() -> Transform2D:
	return _to_local


func set_zoom(value: float) -> void:
	var next := clampf(value, view.min_zoom, view.max_zoom) if view else value
	if is_equal_approx(next, zoom):
		return
	zoom = next
	zoom_changed.emit(zoom)


func _update_state() -> void:
	var meters_per_unit := maxf(zoom, 0.001)
	var scale_px := 1.0 / meters_per_unit
	var target := Vector2.ZERO
	if camera and camera.is_inside_tree():
		var forward3 := -camera.global_transform.basis.z
		var forward := Vector2(forward3.x, forward3.z)
		# Looking straight down has no heading: keep the last one.
		if forward.length() > 0.01:
			heading = forward.normalized()
		var eye := Vector2(camera.global_position.x, camera.global_position.z)
		target = eye
		var followed: Variant = camera.get("follow") if "follow" in camera else null
		if followed is Node3D and (followed as Node3D).is_inside_tree():
			target = Vector2((followed as Node3D).global_position.x, (followed as Node3D).global_position.z)
		var lead := eye.distance_to(target) * (view.lead_factor if view else 0.0)
		center_world = target + heading * lead if (view and view.heading_up) else target
	var x_axis := Vector2(1.0, 0.0) * scale_px
	var y_axis := Vector2(0.0, 1.0) * scale_px
	if view == null or view.heading_up:
		x_axis = Vector2(-heading.y, -heading.x) * scale_px
		y_axis = Vector2(heading.x, -heading.y) * scale_px
	var middle := Vector2.ONE * radius()
	_to_local = Transform2D(x_axis, y_axis, middle - Transform2D(x_axis, y_axis, Vector2.ZERO) * center_world)


## The size knob: the control keeps its bottom-right corner and grows with the shared HUD scale.
func _fit_screen() -> void:
	var height := get_viewport().get_visible_rect().size.y
	factor = hud_scale.factor(height) if hud_scale else height / HudScale.SACENGINE_HEIGHT
	pivot_offset = size
	scale = Vector2(factor, factor)
