extends Node3D

## RFC-055 055b-3: playtest of the actor lights. Spreads the setup's lights (a mix of unit, wizard and spell weights)
## over a floor, puts an ActorLightBudget with the setup's preset and circles a camera over it. The label shows how many
## lights are on (the preset's `actor_max_lights` at most) and the fps.
##   godot --path game res://debug/look/actor_lights_lab.tscn -- --setup=high
## `--setup=<name>` loads res://debug/look/actor_lights_lab_<name>.tres instead of the exported one.

@export var setup: ActorLightsLabSetup
@export var light_scene: PackedScene
@export var budget: ActorLightBudget
@export var camera: Camera3D
@export var label: Label
@export var lights: Node3D

var _time := 0.0
var _total := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--setup="):
			setup = load("res://debug/look/actor_lights_lab_%s.tres" % arg.get_slice("=", 1)) as ActorLightsLabSetup
	if setup == null:
		push_warning("ActorLightsLab: falta el setup.")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in setup.light_count:
		var light := light_scene.instantiate() as ActorLight
		var roll := rng.randf()
		light.priority = 4.0 if roll < 0.02 else (3.0 if roll < 0.1 else 1.0)
		light.position = Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5)) * setup.side_m + Vector3.UP * 1.2
		light.tint(Color.from_hsv(rng.randf(), 0.5, 1.0))
		lights.add_child(light)
	_total = setup.light_count
	budget.apply_look(GameCatalog.shared().god("persephone").look, null)
	budget.apply_quality(setup.quality)


func _process(delta: float) -> void:
	if setup == null:
		return
	_time += delta * 0.2
	camera.position = Vector3(sin(_time), 0.0, cos(_time)) * setup.side_m * 0.4 + Vector3.UP * setup.camera_height_m
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	label.text = "luces %d · encendidas %d · tope %d · fps %d" % [_total, budget.on_count(), budget.max_lights(), Engine.get_frames_per_second()]
