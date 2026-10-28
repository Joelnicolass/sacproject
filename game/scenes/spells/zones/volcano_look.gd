@tool
class_name VolcanoLook
extends Node3D

## What the Volcano looks like on every peer once it erupts: the column of lava growing out of the mouth, the smoke umbrella over it and the
## splash of lava on the ground. Every frame it counts the ticks since the eruption from the clock of the `eruption` stamp (the zone
## replicates it, so a peer that joins late draws the same moment), stands on the mound, and hands each shader its frame, its growth and its
## fade; the splash also gets a picture of the land around it, a few angles a frame. It writes nothing of the game; a dedicated server or a
## headless run draws nothing.

const ANGLES := 64

@export var zone: GroundZone
## The stamp that digs the crater: the eruption happens when it starts, and its ticks are the zone's clock.
@export var eruption: TerrainStamp
## The lava and the splash: meshes with a ShaderMaterial of volcano_lava / volcano_spatter.gdshader. `cloud` holds the smoke (the noisy
## layers of CloudLook) and is shown from the eruption.
@export var lava: MeshInstance3D
@export var cloud: Node3D
@export var spatter: MeshInstance3D
@export_group("Timing")
## Steps of growth of the column (the baked original has 16 frames of geometry), and how long it stays on each frame of its skin.
@export_range(2, 32) var growth_steps := 16
@export_range(0.0166, 0.5, 0.0001, "suffix:s") var lava_frame_s := 0.0666
## The splash pulses once in this long.
@export_range(0.0166, 10.0, 0.0001, "suffix:s") var pulse_s := 1.5
## It grows in during the first second after the eruption and shrinks away during the last one.
@export_range(0.1, 5.0, 0.05, "suffix:s") var fade_s := 1.0
@export_group("Ground picture")
## Metres between two columns of the picture of the land under the splash, how many it has, and how many angles of it are renewed a frame.
@export_range(1.0, 10.0, 0.5, "suffix:m") var ground_step_m := 2.0
@export_range(2, 32) var ground_steps := 15
@export_range(1, 64) var angles_per_frame := 4

var _picture: Image
var _texture: ImageTexture
var _next_angle := 0


## This moves by itself every frame, so physics interpolation must leave it alone.
func _init() -> void: physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	set_process(not Engine.is_editor_hint() and zone != null and eruption != null and not LookRig.is_presentationless())
	if not is_processing():
		return
	_picture = Image.create(ground_steps, ANGLES, false, Image.FORMAT_RF)
	_texture = ImageTexture.create_from_image(_picture)
	var splash := spatter.material_override as ShaderMaterial
	splash.set_shader_parameter("ground", _texture)
	splash.set_shader_parameter("ground_step_m", ground_step_m)
	splash.set_shader_parameter("ground_steps", ground_steps)
	for part in [lava, cloud, spatter]:
		part.visible = false


func _process(_delta: float) -> void:
	var since := eruption.ticks - MatchClock.ticks_for(eruption.start_s)
	var remaining := MatchClock.ticks_for(zone.spell.duration_s) - since
	var shown := since > 0 and remaining > 0 and not zone.cancelled
	for part in [lava, cloud, spatter]:
		part.visible = shown
	var land := Terrain.of(self)
	if not shown or land == null:
		return
	var mouth := Vector2(global_position.x, global_position.z)
	var ground := land.height_at(mouth.x, mouth.y)
	if not is_nan(ground):
		global_position.y = ground
	var fade := float(MatchClock.ticks_for(fade_s))
	var steps := float(growth_steps - 1)
	var grown := steps
	if remaining < fade:
		grown = floorf(steps * maxf(0.0, remaining) / fade)
	elif since < fade:
		grown = floorf(float(since) * steps / fade)
	var pulse_ticks := maxi(1, MatchClock.ticks_for(pulse_s))
	_apply(lava, {"extend": grown / steps, "frame": (since / maxi(1, MatchClock.ticks_for(lava_frame_s))) % 8})
	var pulse := float(since % pulse_ticks) / float(pulse_ticks)
	_apply(spatter, {"pulse": pulse, "frame": mini(15, int(16.0 * pulse)), "origin_y": global_position.y})
	_renew_ground(land, mouth)


func _apply(part: MeshInstance3D, values: Dictionary) -> void:
	var material := part.material_override as ShaderMaterial
	for key: String in values:
		material.set_shader_parameter(key, values[key])


## Asks the land for a few more angles of the picture the splash lies on (all of them in `ANGLES / angles_per_frame` frames).
func _renew_ground(land: Terrain, mouth: Vector2) -> void:
	for _n in angles_per_frame:
		var angle := 0.5 * PI + TAU * float(_next_angle) / ANGLES
		for column in ground_steps:
			var reach := column * ground_step_m
			var height := land.height_at(mouth.x + reach * cos(angle), mouth.y + reach * sin(angle))
			_picture.set_pixel(column, _next_angle, Color(global_position.y if is_nan(height) else height, 0.0, 0.0, 1.0))
		_next_angle = (_next_angle + 1) % ANGLES
	_texture.update(_picture)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if zone == null or eruption == null:
		warnings.append("The zone (GroundZone) and the crater stamp (eruption) are missing.")
	if lava == null or cloud == null or spatter == null:
		warnings.append("The three meshes (lava, cloud, spatter) are missing.")
	return warnings
