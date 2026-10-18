extends RefCounted

## Applies a GodTheme (res://data/themes/<god>.tres) to a High Noon world.
## Online: the dedicated server calls pick_random(match_seed) once per match and
## replicates theme.god; every peer then calls apply(theme_for(god), world).

const GODS: Array[StringName] = [&"persephone", &"pyro", &"james", &"stratos", &"charnel"]
const THEME_DIR := "res://data/themes"
const SKY_NODE := ^"Sky"
const ENVIRONMENT_NODE := ^"Environment"
const SUN_NODE := ^"Sun"
const TERRAIN_NODE := ^"Terrain"


static func has_theme(god: StringName) -> bool:
	return ResourceLoader.exists(THEME_DIR.path_join("%s.tres" % god))


static func theme_for(god: StringName) -> Resource:
	var path := THEME_DIR.path_join("%s.tres" % god)
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## The god a match seed picks, without loading its theme (the dedicated server only needs the name,
## and a theme now pulls in the biome's look: ground textures).
static func pick_god(match_seed: int) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	return GODS[rng.randi_range(0, GODS.size() - 1)]


static func pick_random(match_seed: int) -> Resource:
	return theme_for(pick_god(match_seed))


## Returns the theme with its ENVI colours, as applied.
static func apply(theme: Resource, world_root: Node) -> Resource:
	var resolved: Resource = theme.resolved()
	var sky := world_root.get_node_or_null(SKY_NODE)
	if sky:
		sky.set("background_color", resolved.background_color)
		if sky.has_method("set_textures"):
			sky.call("set_textures", resolved.file("skyt.png"), resolved.file("skyb.png"), resolved.file("sky.png"))
	var world_env := world_root.get_node_or_null(ENVIRONMENT_NODE) as WorldEnvironment
	if world_env and world_env.environment:
		# The base Environment is a shared .tres: work on a copy so the resource is never mutated.
		if world_env.environment.resource_path != "":
			world_env.environment = world_env.environment.duplicate()
		_apply_environment(world_env.environment, resolved)
	var sun := world_root.get_node_or_null(SUN_NODE) as DirectionalLight3D
	if sun:
		sun.light_color = _engine_color(resolved.sun_color)
		sun.light_energy = resolved.sun_energy()
	var terrain := world_root.get_node_or_null(TERRAIN_NODE)
	if terrain and terrain.has_method("set_classic_material") and resolved.ground_material:
		terrain.call("set_classic_material", resolved.ground_material)
	# Also with a null look (classic mode): a layer that was on puts the classic values back.
	LookApplier.apply(resolved.look, world_root)
	return resolved


static func _apply_environment(env: Environment, theme: Resource) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = theme.background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _engine_color(theme.ambient_color)
	env.ambient_light_energy = theme.ambient_light_energy()
	env.fog_enabled = theme.fog_enabled
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = theme.fog_color
	env.fog_density = theme.fog_density
	env.fog_depth_begin = theme.fog_begin
	env.fog_depth_end = theme.fog_end
	env.fog_sky_affect = 0.0
	_publish_fx_fog(theme)


## RFC-029 029a (H2): additive sprites keep `fog_disabled` (Godot adds the fog's light to them) and
## fade with the same depth fog through these shader globals. Written next to the Environment so
## both always agree; density 0 (no fog) leaves the sprites as before.
static func _publish_fx_fog(theme: Resource) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.global_shader_parameter_set(&"fx_fog_density", theme.fog_density if theme.fog_enabled else 0.0)
	RenderingServer.global_shader_parameter_set(&"fx_fog_begin", theme.fog_begin)
	RenderingServer.global_shader_parameter_set(&"fx_fog_end", theme.fog_end)


## sacengine lights with the ENVI ambient and sun colors as linear values (ambientConstant,
## renderer.d:1156; sunColor, 1174-1176; deferred.d:383, 403-411, against toLinear albedo).
## Godot reads a light Color as sRGB, so it gets the sRGB encoding of that linear value.
static func _engine_color(linear: Color) -> Color:
	return linear.linear_to_srgb()
