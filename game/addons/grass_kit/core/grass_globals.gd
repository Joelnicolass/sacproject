@tool
class_name GrassGlobals
extends RefCounted

## The global shader uniforms GrassKit writes, so any shader can read them: the wind
## (`field/grass_wind.gdshaderinc`) and where the drawn grass ends and what colour it fades to
## (`field/grass_ground.gdshaderinc`, for the game's ground). The plugin declares them in Project
## Settings > Shader Globals when it is enabled, so a game's shader that reads them compiles from
## the start (and adds any a newer GrassKit brings, each time the editor starts); without the
## plugin a field declares them before its own shaders compile.

const NOISE_PATH := "res://addons/grass_kit/core/grass_wind_noise.tres"
## White: grass everywhere, where no field says otherwise.
const FULL_PATH := "res://addons/grass_kit/core/grass_full.tres"
## Name: [type, default].
const ALL := {
	&"grasskit_wind": [RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(1.0, 0.0, 0.0, 55.0)],
	&"grasskit_wind_offset": [RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2.ZERO],
	&"grasskit_wind_time": [RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
	&"grasskit_wind_noise": [RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, NOISE_PATH],
	&"grasskit_field": [RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0)],
	&"grasskit_grass": [RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.3, 0.45, 0.12, 0.0)],
	&"grasskit_under": [RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.1, 0.0)],
	&"grasskit_density": [RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, FULL_PATH],
	&"grasskit_area": [RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(-1e6, -1e6, 2e6, 2e6)],
}
## The type names Project Settings uses.
const TYPE_NAMES := {
	RenderingServer.GLOBAL_VAR_TYPE_VEC4: "vec4",
	RenderingServer.GLOBAL_VAR_TYPE_VEC2: "vec2",
	RenderingServer.GLOBAL_VAR_TYPE_FLOAT: "float",
	RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D: "sampler2D",
}

static var _declared := false


## Declares, in this process, the ones Project Settings does not: before any shader that reads
## them compiles. Once.
static func declare() -> void:
	if _declared:
		return
	_declared = true
	for name: StringName in ALL:
		if ProjectSettings.has_setting("shader_globals/" + name):
			continue
		var entry: Array = ALL[name]
		var value: Variant = entry[1]
		if entry[0] == RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D:
			value = load(value)
		RenderingServer.global_shader_parameter_add(name, entry[0], value)


## Writes the missing ones into Project Settings, leaving every other shader global as it is (the
## plugin, when enabled). True if any was new.
static func add_to_project() -> bool:
	var added := false
	for name: StringName in ALL:
		var key := "shader_globals/" + name
		if ProjectSettings.has_setting(key):
			continue
		var entry: Array = ALL[name]
		ProjectSettings.set_setting(key, {"type": TYPE_NAMES[entry[0]], "value": entry[1]})
		added = true
	return added
