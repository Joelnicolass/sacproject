@tool
class_name GrassWind
extends Resource

## The wind of a world, shared by every shader that wants it: a GrassField3D's blades, and the
## game's own ground, trees or particles through `field/grass_wind.gdshaderinc` (global shader
## uniforms). Bands of wind travel across the ground along `direction` at `speed`, shaped by a
## seamless `noise`; their crests are gusts. A new direction or strength is reached over
## `blend_time` (a storm rising), and the pattern never jumps: its position is carried frame by
## frame. A field ticks its wind once a frame; several fields can share one. The uniforms are in
## GrassGlobals.

## Where the wind blows to on the ground plane (x, z).
@export var direction := Vector2(0.8, 0.6)
## 0 calm, 1 a storm.
@export_range(0.0, 2.0, 0.01) var strength := 0.5
## How fast the bands travel (m/s).
@export_range(0.0, 50.0, 0.1, "suffix:m/s") var speed := 4.0
## Size of a band of wind on the ground (m).
@export_range(1.0, 500.0, 1.0, "suffix:m") var scale := 55.0
## A seamless noise: the shape of the bands. Null = the kit's.
@export var noise: Texture2D
## Seconds to reach a new direction or strength, so a change does not make the field jump.
@export_range(0.0, 30.0, 0.1, "suffix:s") var blend_time := 2.0
## 0 or more: the wind stands still at that moment (tests, screenshots). Negative: it runs.
@export var time_override := -1.0

## The direction and strength blowing now, on their way to `direction` and `strength`.
var current_direction := Vector2.ZERO
var current_strength := -1.0
## How far the wind has carried its pattern (m), and its clock (s).
var offset := Vector2.ZERO
var time := 0.0

var _ticked_frame := -1


## Calm: what a world without a GrassWind blows.
static func write_calm() -> void:
	GrassGlobals.declare()
	RenderingServer.global_shader_parameter_set(&"grasskit_wind", Vector4(1.0, 0.0, 0.0, 55.0))


## Moves the wind on by `delta` seconds and writes it to the global uniforms. Once a frame, however
## many fields share it.
func tick(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _ticked_frame:
		return
	_ticked_frame = frame
	var target := direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	if current_strength < 0.0 or time_override >= 0.0:
		# The first frame, or a frozen moment: the wind as set, all of it.
		current_direction = target
		current_strength = strength
	var follow := 1.0 if blend_time <= 0.0 else 1.0 - exp(-delta * 3.0 / blend_time)
	current_direction = current_direction.slerp(target, follow).normalized()
	current_strength = lerpf(current_strength, strength, follow)
	if time_override >= 0.0:
		time = time_override
		offset = current_direction * speed * time_override
	else:
		time += delta
		offset += current_direction * speed * delta
	write()


## Writes the wind as it blows now to the global uniforms.
func write() -> void:
	GrassGlobals.declare()
	var blowing := current_direction if current_strength >= 0.0 else direction.normalized()
	var force := current_strength if current_strength >= 0.0 else strength
	RenderingServer.global_shader_parameter_set(
		&"grasskit_wind", Vector4(blowing.x, blowing.y, force, scale)
	)
	RenderingServer.global_shader_parameter_set(&"grasskit_wind_offset", offset)
	RenderingServer.global_shader_parameter_set(&"grasskit_wind_time", time)
	if noise != null:
		RenderingServer.global_shader_parameter_set(&"grasskit_wind_noise", noise)
