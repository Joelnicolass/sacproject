extends Node

## RFC-022 gallery: the product map, six bodies (three in the sun, three in the altar's shade),
## a looping emitter and three fixed cameras. Starts in classic mode with every layer off.
## Debug-only actions are registered here (not in project.godot): F1 next biome, F2 next camera,
## F3 next quality, KP1..KP8 toggle layer N. Prints `look <god> cam <n> capas <mask> calidad <q>`.

const ThemeApplier := preload("res://scenes/look/theme/theme_applier.gd")
const QUALITY_DIR := "res://data/look"
const QUALITY_IDS: Array[StringName] = [&"low", &"medium", &"high"]
const ACTIONS := {
	&"debug_next_biome": KEY_F1,
	&"debug_next_camera": KEY_F2,
	&"debug_next_quality": KEY_F3,
	&"debug_toggle_layer_1": KEY_KP_1,
	&"debug_toggle_layer_2": KEY_KP_2,
	&"debug_toggle_layer_3": KEY_KP_3,
	&"debug_toggle_layer_4": KEY_KP_4,
	&"debug_toggle_layer_5": KEY_KP_5,
	&"debug_toggle_layer_6": KEY_KP_6,
	&"debug_toggle_layer_7": KEY_KP_7,
	&"debug_toggle_layer_8": KEY_KP_8,
}

@export var world: Node3D
@export var view_camera: Camera3D
## Marker3D children: ref, rts, horizonte.
@export var camera_markers: Node3D
@export var bodies: Node3D
@export var start_god: StringName = &"persephone"
## Classic mode keeps look = null: no profile is handed to the rig.
@export var classic := true
## Freezes the original sky at time 0 so captures from two runs compare.
@export var freeze_sky := true
@export var hide_hud := true
## Hides every particle node (also the ones that appear later): the sprites are random, so a
## capture without them can be compared byte for byte against another run.
@export var hide_particles := false
## Replaces the biome's sky look (to compare the Swirl sky with the Legacy one).
@export var sky_override: SkyLook

var _god_index := 0
var _camera_index := 0
var _quality_index := -1


func _ready() -> void:
	_register_actions()
	_god_index = maxi(0, GameData.gods().find(start_god))
	if hide_hud:
		var hud := world.get_node_or_null("Hud") as CanvasLayer
		if hud:
			hud.visible = false
	if hide_particles:
		get_tree().node_added.connect(_hide_if_particles)
		_hide_existing(self)
	_settle.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_next_biome"):
		_god_index = (_god_index + 1) % GameData.gods().size()
		_show_biome()
	elif event.is_action_pressed(&"debug_next_camera"):
		_camera_index = (_camera_index + 1) % camera_markers.get_child_count()
		_show_camera()
	elif event.is_action_pressed(&"debug_next_quality"):
		_quality_index = (_quality_index + 1) % QUALITY_IDS.size()
		_show_quality()
	else:
		for n in range(1, 9):
			if event.is_action_pressed(StringName("debug_toggle_layer_%d" % n)):
				_toggle_layer(n - 1)


func _settle() -> void:
	_place_bodies()
	_show_biome()
	_show_camera()
	if freeze_sky:
		var sky := world.get_node_or_null("Sky")
		if sky:
			sky.set_process(false)


func _hide_existing(node: Node) -> void:
	_hide_if_particles(node)
	for child in node.get_children():
		_hide_existing(child)


func _hide_if_particles(node: Node) -> void:
	if node is CPUParticles3D or node is GPUParticles3D:
		(node as Node3D).visible = false


func _show_biome() -> void:
	var god := GameData.gods()[_god_index]
	var theme: Resource = ThemeApplier.theme_for(god)
	if theme == null:
		print("bioma %s sin tema" % god)
		return
	if classic and theme.get("look") != null:
		theme = theme.duplicate()
		theme.look = null
	if sky_override and theme.get("look") != null:
		theme = theme.duplicate()
		theme.look = theme.look.duplicate()
		theme.look.sky = sky_override
	ThemeApplier.apply(theme, world)
	_report()


func _show_camera() -> void:
	var marker := camera_markers.get_child(_camera_index) as Marker3D
	view_camera.global_transform = marker.global_transform
	view_camera.fov = float(marker.get_meta(&"fov", 75.0))
	_report()


func _show_quality() -> void:
	var quality := load(QUALITY_DIR.path_join("quality_%s.tres" % QUALITY_IDS[_quality_index])) as LookQuality
	var rig := _rig()
	if rig:
		rig.apply_quality(quality)
	QualityApplier.apply_to(get_viewport(), quality)
	_report()


func _toggle_layer(index: int) -> void:
	var rig := _rig()
	if rig == null:
		return
	var nodes: Array[Node] = rig.layer_nodes()
	if index >= nodes.size():
		return
	var shown: Variant = nodes[index].get("visible")
	rig.set_layer_enabled(index, not bool(shown) if shown != null else false)
	_report()


func _rig() -> LookRig:
	return world.get_node_or_null("Look") as LookRig


## Feet on the terrain: the scene sets x and z, the terrain gives y.
func _place_bodies() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain == null or not terrain.has_method("ground_height"):
		return
	for body in bodies.get_children():
		var found: float = terrain.ground_height(body.global_position.x, body.global_position.z)
		if not is_nan(found):
			body.global_position.y = found


func _report() -> void:
	var rig := _rig()
	var quality := "nativa" if _quality_index < 0 else String(QUALITY_IDS[_quality_index])
	print("look %s cam %d capas %d calidad %s" % [
		GameData.gods()[_god_index], _camera_index, rig.layer_mask() if rig else 0, quality])


func _register_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.keycode = ACTIONS[action]
		InputMap.action_add_event(action, key)
