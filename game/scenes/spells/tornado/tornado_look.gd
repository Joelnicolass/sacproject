@tool
class_name TornadoLook
extends Node3D

## What the tornado looks like on every peer: every frame it computes the axis of the funnel (500 m tall, its top fixed, its foot where the
## tornado is, bent by the winds) and hands it, with the turn and the fade, to the shader of each part (upper wall, lower wall, ragged edge);
## it raises dust where the foot touches the ground (its light is a StateLight of the scene that follows the zone). Presentation only: it reads the
## replicated position and size and writes nothing of the game. A dedicated server or a headless run draws nothing.

@export var zone: GroundZone
@export var drift: TornadoDrift
@export var winds: TornadoWinds
## The meshes of the funnel, with a ShaderMaterial of tornado_funnel.gdshader each: the upper wall, the lower wall and the edge, in that order.
@export var parts: Array[MeshInstance3D] = []
## The dust at the foot (rate set here from how high the foot is).
@export var dust: SpriteEmitter
## The edge strip changes frame this many times a second (4 frames).
@export_range(1.0, 60.0, 0.5, "suffix:/s") var edge_fps := 15.0
## Seconds the funnel takes to turn once around its axis.
@export_range(0.2, 20.0, 0.1, "suffix:s") var turn_s := 1.0
## Dust a tick at a foot on the ground (the original: up to 2), and the height above which there is none, m.
@export_range(0.0, 10.0, 0.1) var dust_per_tick := 2.0
@export_range(0.5, 20.0, 0.5, "suffix:m") var dust_height_m := 5.0

var _radii := TornadoRules.radii()


func _ready() -> void:
	if Engine.is_editor_hint() or zone == null:
		set_physics_process(false)
		return
	if LookRig.is_presentationless():
		set_physics_process(false)
		return
	for part in parts:
		(part.material_override as ShaderMaterial).set_shader_parameter("radii", _radii)


func _physics_process(_delta: float) -> void:
	var home := zone.points[0]
	var axis := TornadoRules.axis(
		home + Vector3.UP * TornadoRules.COLUMN_M, zone.global_position, drift.size, winds.phases()
	)
	var local := PackedVector3Array()
	for point in axis:
		local.append(point - global_position)
	var seconds := winds.seconds()
	var fade := sqrt(sqrt(minf(1.0, 1.5 * drift.size)))
	for i in parts.size():
		var material := parts[i].material_override as ShaderMaterial
		material.set_shader_parameter("axis", local)
		material.set_shader_parameter("spin", TAU * seconds / turn_s)
		material.set_shader_parameter("edge_frame", float(int(seconds * edge_fps) % 4))
		material.set_shader_parameter("alpha_scale", fade)
		parts[i].visible = drift.size > 0.0
	if dust != null:
		var foot := axis[6].y - global_position.y
		dust.set_rate(
			MatchClock.TICKS_PER_SECOND_F * clampf(0.4 * (dust_height_m - foot), 0.0, dust_per_tick)
		)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if zone != null and drift != null and winds != null
		else PackedStringArray(["The zone, the drift and the winds are missing."])
	)
