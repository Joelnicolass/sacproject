@tool
class_name SkyLayer
extends LookLayer

## Sky layer of the rig. The biome's `SkyLook` picks the sky: LEGACY keeps the original sky
## (`sky.tscn`: cylinder, ring, clouds) exactly as it is; SWIRL hides it and draws a shader sky
## built from the original's own textures and palette. Passes (discs, swirl; packed scene
## children, hide one to turn it off) follow the map's `Sun`. It also gives the Environment an invisible source (a gradient `Sky` that no camera sees) for
## ambient, reflections and far fog, because the original cylinder feeds none of them.
## Switching the layer off or handing it a null profile puts the Environment back. Works on a
## copy of a shared Environment; nothing it computes is saved in a scene.

const ENV_PROPS: Array[StringName] = [
	&"sky", &"ambient_light_source", &"ambient_light_sky_contribution", &"reflected_light_source",
	&"fog_aerial_perspective", &"volumetric_fog_albedo", &"fog_light_color"]

## SkyPiece children that follow the sun.
@export var pieces: Array[SkyPiece] = []
## The swirl sky (one of `pieces`): it takes the legacy sky's textures.
@export var swirl: SkyPiece

var _rig: LookRig
var _look: SkyLook
var _env_base := {}
var _env_applied: Environment
var _source_env: Environment
var _applied := false
var _sky: Sky
var _sky_look: SkyLook
var _fresh := false
var _classic_fog := Color.WHITE


func _ready() -> void:
	visibility_changed.connect(_refresh)
	set_process(false)


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	_rig = rig
	_look = profile.sky as SkyLook if profile else null
	_fresh = true
	if not rig.layer_toggled.is_connected(_on_rig_changed):
		rig.layer_toggled.connect(_on_rig_changed)
	_refresh()


func _process(_delta: float) -> void:
	_push_pieces()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_restore()
		if swirl:
			swirl.call("clear_legacy")
			swirl.visible = false
		if _rig and _rig.legacy_sky:
			_rig.legacy_sky.visible = true
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_refresh()


func _on_rig_changed(_index: int, _enabled: bool) -> void:
	# The light layer may have swapped the Environment under us.
	_refresh()


func _refresh() -> void:
	var world_env := _rig.world_environment if _rig else null
	if _look == null or not is_visible_in_tree() or world_env == null:
		set_process(false)
		_restore()
		_apply_legacy_sky()
		_push_pieces()
		return
	if world_env.environment == null:
		world_env.environment = Environment.new()
	if _applied and world_env.environment != _env_applied:
		# Somebody replaced the Environment: the new one is clean.
		_applied = false
		_source_env = null
	if not _applied:
		if world_env.environment.resource_path != "":
			_source_env = world_env.environment
			world_env.environment = world_env.environment.duplicate()
		_env_applied = world_env.environment
		_env_base = _capture(_env_applied)
		_applied = true
	if _fresh:
		# ThemeApplier just wrote the classic fog color: that is what the mix starts from.
		_classic_fog = _env_applied.fog_light_color
		_env_base[&"fog_light_color"] = _classic_fog
		_fresh = false
	_apply_environment(_env_applied)
	_apply_legacy_sky()
	set_process(true)
	_push_pieces()


func _restore() -> void:
	if not _applied:
		return
	_applied = false
	var world_env := _rig.world_environment if _rig else null
	if is_instance_valid(world_env):
		if _source_env != null and world_env.environment == _env_applied:
			world_env.environment = _source_env
		elif world_env.environment == _env_applied:
			for prop in _env_base:
				_env_applied.set(prop, _env_base[prop])
	_source_env = null
	_env_applied = null


func _apply_environment(env: Environment) -> void:
	if _sky == null or _sky_look != _look:
		_sky = _look.make_sky()
		_sky_look = _look
	env.sky = _sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if _look.ambient_sky_contribution > 0.0 else Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = _look.ambient_sky_contribution
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_aerial_perspective = _look.fog_aerial_perspective
	env.volumetric_fog_albedo = _look.haze_tint
	env.fog_light_color = _classic_fog.lerp(_look.horizon_color, _look.fog_horizon_mix)


## Legacy mode (and the classic mode, no look) shows the original sky; Swirl replaces it.
func _apply_legacy_sky() -> void:
	var legacy := _rig.legacy_sky if _rig else null
	var swirl_on := _look != null and _look.sky_mode == 1 and is_visible_in_tree() and legacy != null
	if swirl:
		swirl.visible = swirl_on
	if legacy == null:
		return
	legacy.visible = not swirl_on
	if not swirl_on or swirl == null:
		if swirl:
			swirl.call("clear_legacy")
		return
	var clouds := legacy.get_node_or_null("%Clouds") as MeshInstance3D
	var top := legacy.get_node_or_null("%Top") as MeshInstance3D
	if clouds == null or top == null:
		return
	var cloud_material := clouds.material_override as ShaderMaterial
	var band_material := top.material_override as ShaderMaterial
	swirl.call("bind_legacy", cloud_material.get_shader_parameter("clouds"), band_material.get_shader_parameter("band"),
		legacy.get("background_color"), float(legacy.get("energy")), float(legacy.get("cloud_alpha")))


func _push_pieces() -> void:
	# No look: the neutral SkyLook draws nothing (classic mode).
	var look := _look if _look else SkyLook.new()
	var sun := _rig.sun if _rig else null
	# Toward the sun: the light looks down its -Z, so +Z points at it.
	var dir := sun.global_basis.z if sun else Vector3(0.0, 0.7, 0.7)
	var swirl_on := _look != null and _look.sky_mode == 1
	for piece in pieces:
		if piece == null:
			continue
		if piece != swirl:
			# Legacy and classic draw the original sky with nothing on top.
			piece.visible = swirl_on
		piece.apply_sky(look, dir.normalized())


static func _capture(env: Environment) -> Dictionary:
	var values := {}
	for prop in ENV_PROPS:
		values[prop] = env.get(prop)
	return values


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if pieces.is_empty():
		warnings.append("Faltan las piezas (sky_discs, sky_swirl) en el socket Pieces.")
	return warnings
