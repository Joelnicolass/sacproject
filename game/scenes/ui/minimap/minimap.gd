@tool
class_name Minimap
extends Control

## The circle at the bottom right of the HUD. It builds the frame's state (center, turn, zoom) and hands it to its children:
## `Ground` draws the baked terrain, `Markers` the icons. It knows no unit type.
## Local presentation: nothing is replicated. Input: the wheel over the circle zooms the map, `M` shows or hides it, and a
## click gives a ground point (`ground_pointed`); MatchCommand turns it into an order or an aim, so no order starts here.
##
## Everything is laid out in canvas pixels of the 1280×720 base, anchored to the bottom-right corner; Godot's stretch scales it.
## Heading up (the default) turns the map with the camera so up is where it looks; the center is `lead_factor` camera distances
## ahead of the followed wizard. `view.heading_up = false` keeps north up and centers on the wizard.
## Map axes: world (x, z) → local pixels. A top view has +x right and +z down, so no flip is needed.

## `Minimap.zoom` changed (wheel).
signal zoom_changed(zoom: float)
## `select` or `order_units` was released over the circle on the ground at `point` (world; y is the ground height there).
## The camera does not jump: in Sacrifice it always follows the wizard.
signal ground_pointed(point: Vector3, action: StringName)

## Height the ground ray starts from (meters); the map is far lower.
const GROUND_RAY_TOP := 1500.0

## Slot of the player of this process (0 until `bind`); the markers read it to tell your things from the foe's.
var local_slot := 0

@export_group("Sockets")
## The world camera (WorldCamera). Reads its turn and the wizard it follows.
@export var camera: Camera3D
@export var terrain_bake: MinimapTerrainBake
## Parent of the structures a player builds (%Structures): the Manaliths. The map's own buildings (hundreds of houses) are not on the map.
@export var structures_root: Node
@export var ground: Control
@export var markers: Control
## Compass gem on the frame; it rides the edge at the map's north as the map turns. Empty = none.
@export var compass: Control
@export_group("Resources")
@export var style: MinimapStyleSet
@export var view: MinimapView

## Meters of the world per canvas pixel in play (starts at `view.view_radius_m` over the radius).
var zoom := 2.25
## World x/z drawn at the circle's center, this frame.
var center_world := Vector2.ZERO
## Unit vector the camera looks along on the ground, world x/z.
var heading := Vector2(0.0, 1.0)

var _to_local := Transform2D.IDENTITY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if camera == null or terrain_bake == null or ground == null or markers == null:
		warnings.append("Assign camera, terrain_bake, ground and markers.")
	if style == null or view == null:
		warnings.append("Assign style and view (data/ui/minimap/).")
	return warnings


func _ready() -> void:
	if view:
		zoom = _zoom_of(view.view_radius_m)
	if Engine.is_editor_hint():
		return
	# No local player until `bind`, and never on the dedicated server: nothing to show.
	_set_active(false)


## The local wizard arrived (MatchWorld.local_wizard_changed): the map shows for its side.
func bind(wizard: WizardBody) -> void:
	local_slot = wizard.owner_slot if wizard != null else 0
	_set_active(local_slot > 0)
	if local_slot > 0:
		_update_state()


func _set_active(on: bool) -> void:
	visible = on
	set_process(on)
	set_process_unhandled_input(on)


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_state()
	if ground:
		ground.queue_redraw()
	if markers:
		markers.queue_redraw()


## The wheel zooms the map and a button gives a ground point. The event is consumed here (`mouse_filter` STOP over the circle).
func _gui_input(event: InputEvent) -> void:
	if WorldInput.blocked(self):
		return
	if event.is_action_pressed(&"minimap_zoom_in") or event.is_action_pressed(&"minimap_zoom_out"):
		var notches := 1.0
		if event is InputEventMouseButton and (event as InputEventMouseButton).factor > 0.0:
			notches = (event as InputEventMouseButton).factor
		var step := pow(view.zoom_step if view else 1.15, notches)
		set_zoom(zoom / step if event.is_action_pressed(&"minimap_zoom_in") else zoom * step)
		accept_event()
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var button := event as InputEventMouseButton
		var action: StringName = &""
		if button.is_action_released(&"select"):
			action = &"select"
		elif button.is_action_released(&"order_units"):
			action = &"order_units"
		else:
			return
		var ground: Variant = _ground_at(local_to_world(button.position))
		if ground != null:
			ground_pointed.emit(ground, action)
		accept_event()


## Only the circle takes the mouse; the corners of the square around it belong to the world.
func _has_point(point: Vector2) -> bool:
	return point.distance_to(Vector2.ONE * radius()) <= radius()


## True when a screen position is over the circle (the world camera asks before it zooms).
func covers(screen: Vector2) -> bool:
	return is_visible_in_tree() and _has_point(get_global_transform().affine_inverse() * screen)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or WorldInput.blocked(self):
		return
	if event.is_action_pressed(&"minimap_toggle", false, true):
		visible = not visible
		get_viewport().set_input_as_handled()


## The ground point under a world x/z: a ray straight down on the ground layer. Null when there is none (off the map).
func _ground_at(xz: Vector2) -> Variant:
	if camera == null or not camera.is_inside_tree() or camera.get_world_3d() == null:
		return null
	return GroundRay.surface_point(camera, Vector3(xz.x, 0.0, xz.y), 1, [], GROUND_RAY_TOP)


## Radius of the circle in canvas pixels.
func radius() -> float:
	return view.radius_px if view else 96.0


## Local position (canvas pixels, this control's origin) of a world point.
func world_to_minimap(point: Vector3) -> Vector2:
	return _to_local * Vector2(point.x, point.z)


## World x/z under a local position (the inverse; used to aim from the minimap).
func local_to_world(local: Vector2) -> Vector2:
	return _to_local.affine_inverse() * local


## Local direction on the map of a world x/z direction (unit in, unit out).
func world_dir_to_local(direction: Vector2) -> Vector2:
	return _to_local.basis_xform(direction).normalized()


## Maps world x/z to local pixels; the ground draws under it.
func world_transform() -> Transform2D:
	return _to_local


func set_zoom(value: float) -> void:
	var next := clampf(value, _zoom_of(view.min_radius_m), _zoom_of(view.max_radius_m)) if view else value
	if is_equal_approx(next, zoom):
		return
	zoom = next
	zoom_changed.emit(zoom)


func _update_state() -> void:
	var scale_px := 1.0 / maxf(zoom, 0.001)
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
		# The followed wizard can be freed (e.g. after leaving the match) before the camera drops it.
		if is_instance_valid(followed) and followed is Node3D and (followed as Node3D).is_inside_tree():
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
	if compass:
		var north := world_dir_to_local(Vector2(0.0, -1.0))
		compass.pivot_offset = compass.size * 0.5
		compass.position = middle + north * (radius() - (view.compass_inset if view else 4.0)) - compass.pivot_offset
		compass.rotation = atan2(north.x, -north.y)


## Meters per pixel that make the circle's radius show `radius_m` meters.
func _zoom_of(radius_m: float) -> float:
	return radius_m / maxf(radius(), 1.0)
