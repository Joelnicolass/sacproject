extends Node

## RFC-037 037b measures for the flow `f037_minimap`: where the local wizard's icon landed against an independent
## calculation, how the Druid's bearing changes when the camera turns, and what the draw costs. Read only.
## It also holds a button that shows the baked terrain full screen (a player action the flow clicks, for the 037a capture).
##
##   wizard_err_px    screen px between the wizard's icon and where the formula (camera yaw, HudScale, bottom-right corner) says it goes
##   bearing_deg      bearing of the first creature of another side from the circle's center (0 = up, clockwise)
##   bearing_change_deg  absolute change of that bearing since the first frame it was seen (wrapped to 0…180)
##   vision_err_deg   degrees between the wedge's bearing and where the wizard faces relative to the camera (formula: facing against the camera's forward and right)
##   turned_deg       how far the camera turned since then (absolute, wrapped to 0…180)

@export var minimap: Minimap
@export var bake: MinimapTerrainBake
@export var terrain_button: Button
@export var bake_view: TextureRect

var wizard_err_px := INF
var bearing_deg := 0.0
var bearing_change_deg := 0.0
var turned_deg := 0.0
var icons := 0
var arrows := 0
## Average microseconds one marker `_draw` took (exponential average).
var draw_us := 0.0
var foe_found := false
var vision_err_deg := INF

## Headless check without a window: waits, turns the camera with the InputMap action, prints the measures and quits.
@export var auto_report := false

var _bearing_start := INF
var _yaw_start := INF


func _ready() -> void:
	if terrain_button:
		terrain_button.pressed.connect(_toggle_terrain)
	if auto_report:
		_auto_report.call_deferred()


func _auto_report() -> void:
	await get_tree().create_timer(3.0).timeout
	print("MINIMAP_PROBE start ", _line())
	Input.action_press(&"turn_left")
	await get_tree().create_timer(0.5).timeout
	Input.action_release(&"turn_left")
	await get_tree().create_timer(1.5).timeout
	print("MINIMAP_PROBE turned ", _line())
	get_tree().quit()


func _line() -> String:
	return "wizard_err_px=%.3f vision_err_deg=%.2f icons=%d arrows=%d draw_us=%.1f bearing=%.1f change=%.1f turned=%.1f foe=%s" % [
		wizard_err_px, vision_err_deg, icons, arrows, draw_us, bearing_deg, bearing_change_deg, turned_deg, foe_found]


func _toggle_terrain() -> void:
	if bake_view == null or bake == null:
		return
	bake_view.texture = bake.texture
	bake_view.visible = not bake_view.visible


func _process(_delta: float) -> void:
	if minimap == null or minimap.markers == null or minimap.camera == null:
		return
	var markers := minimap.markers
	icons = int(markers.get("icons_drawn"))
	arrows = int(markers.get("arrows_drawn"))
	var us := float(markers.get("draw_us"))
	draw_us = us if draw_us == 0.0 else lerpf(draw_us, us, 0.05)
	_measure_wizard(markers)
	_measure_vision(markers)
	_measure_foe()


func _measure_wizard(markers: Control) -> void:
	var icon: Vector2 = markers.get("local_wizard_icon")
	var camera := minimap.camera
	var followed: Variant = camera.get("follow")
	if icon.x == INF or not (followed is Node3D):
		wizard_err_px = INF
		return
	var yaw := float(camera.get("yaw"))
	var forward := Vector2(sin(yaw), cos(yaw))
	var right := Vector2(-cos(yaw), sin(yaw))
	var wizard := Vector2((followed as Node3D).global_position.x, (followed as Node3D).global_position.z)
	var eye := Vector2(camera.global_position.x, camera.global_position.z)
	var center_world := wizard + forward * eye.distance_to(wizard) * minimap.view.lead_factor
	var offset := wizard - center_world
	var height := minimap.get_viewport().get_visible_rect().size
	var factor := minimap.hud_scale.factor(height.y)
	var screen_center := height - Vector2.ONE * minimap.radius() * factor
	var expected := screen_center + Vector2(offset.dot(right), -offset.dot(forward)) * factor / minimap.zoom
	var actual := markers.get_global_transform() * icon
	wizard_err_px = actual.distance_to(expected)


func _measure_vision(markers: Control) -> void:
	var direction: Vector2 = markers.get("vision_direction")
	var wizard: WizardBody = null
	for node in get_tree().get_nodes_in_group(&"wizard"):
		if node is WizardBody and (node as WizardBody).is_local():
			wizard = node as WizardBody
	if wizard == null or direction == Vector2.ZERO:
		vision_err_deg = INF
		return
	var yaw := float(minimap.camera.get("yaw"))
	var forward := Vector2(sin(yaw), cos(yaw))
	var right := Vector2(-cos(yaw), sin(yaw))
	var facing := Vector2(wizard.facing_flat().x, wizard.facing_flat().z)
	var expected_deg := rad_to_deg(atan2(facing.dot(right), facing.dot(forward)))
	var shown_deg := rad_to_deg(atan2(direction.x, -direction.y))
	vision_err_deg = absf(wrapf(shown_deg - expected_deg, -180.0, 180.0))


func _measure_foe() -> void:
	var foe: Node3D = null
	for node in get_tree().get_nodes_in_group(&"unit"):
		if int(node.get("owner_slot")) != MpKit.local_slot():
			foe = node as Node3D
			break
	foe_found = foe != null
	if foe == null:
		return
	var offset := minimap.world_to_minimap(foe.global_position) - Vector2.ONE * minimap.radius()
	bearing_deg = rad_to_deg(atan2(offset.x, -offset.y))
	var yaw := rad_to_deg(float(minimap.camera.get("yaw")))
	if _bearing_start == INF:
		_bearing_start = bearing_deg
		_yaw_start = yaw
	bearing_change_deg = absf(wrapf(bearing_deg - _bearing_start, -180.0, 180.0))
	turned_deg = absf(wrapf(yaw - _yaw_start, -180.0, 180.0))
