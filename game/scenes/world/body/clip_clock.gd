class_name ClipClock
extends RefCounted

## RFC-023 (023c): the logical clock of the clip a body plays: role, tag, frame, framerate and impact frame, with no
## mesh and no node. It runs the same on the dedicated server and on a client; the visual (BodyRig) READS it and
## travels/seeks to what it says, never the other way round. It replaces the headless clock ClipPosePlayer used to
## carry. Presentation only: the simulation takes its ticks from CreatureType and never reads this.
## Clip data (frames, framerate, impact) comes from assets/original/models/index.json; a model that is not there yet
## falls back to the clip list the baked player reads (cache/data/anim_mesh_clips_f37.json) until RFC-023h retires it.

## The active clip went past its last frame and started again. Emitted by advance() on the tick that wraps.
signal looped(role: String)

## model -> tag -> {frames, framerate, impact}; filled on first use, shared by every clock.
static var _data: Dictionary = {}
static var _fallback: Dictionary = {}
static var _fallback_loaded := false

## Holds the clip: advance() does nothing and play() does not switch (a petrified body).
var frozen := false

var _model := ""
var _roles: Dictionary = {}
var _role := ""
var _clip: Dictionary = {}
var _tag := ""
var _frame := 0
var _tick_left := 0.0


## Sets the model and its role -> tag map and keeps the role that was playing (idle/run when none was).
func setup(model: String, role_to_tag: Dictionary) -> void:
	_model = model
	_roles = role_to_tag.duplicate()
	var preferred := _role
	if preferred.is_empty() and _roles.has("idle"):
		preferred = "idle"
	elif preferred.is_empty() and _roles.has("run"):
		preferred = "run"
	_apply(preferred, true)


func play(role: String, restart := false) -> void:
	if frozen:
		return
	_apply(role, restart)


## One physics tick. Returns true when the clip wrapped on it.
func advance(delta: float) -> bool:
	if frozen or _clip.is_empty():
		return false
	var frame_time := 1.0 / maxf(float(_clip["framerate"]), 1.0)
	var count := int(_clip["frames"])
	var wrapped := false
	_tick_left -= delta
	while _tick_left <= 0.0:
		_tick_left += frame_time
		_frame = (_frame + 1) % count
		wrapped = wrapped or _frame == 0
	if wrapped:
		looped.emit(_role)
	return wrapped


func active_role() -> String:
	return _role


## True when the model has a playable clip (more than one frame) for `role`.
func has_role(role: String) -> bool:
	return not _clip_of(role).is_empty()


## True when `model` has a playable clip (more than one frame) called `tag`, whatever the roles.
static func has_clip(model: String, tag: String) -> bool:
	return int(clip_data(model, tag).get("frames", 0)) > 1


func active_tag() -> String:
	return _tag


func active_framerate() -> int:
	return int(_clip.get("framerate", 0))


func active_frame() -> int:
	return _frame


## The frame of the first attack event of the active clip (the strike lands on it), -1 without one.
func impact_frame() -> int:
	return int(_clip.get("impact", -1))


## Seconds into the active clip, within one pass of it (what a visual seeks to).
func time_s() -> float:
	var fps := maxf(float(_clip.get("framerate", 1)), 1.0)
	return float(_frame) / fps


## {frames, framerate, impact} of one clip of `model`, {} when the model has no such clip.
static func clip_data(model: String, tag: String) -> Dictionary:
	if model.is_empty() or tag.is_empty():
		return {}
	return _model_data(model).get(tag, {})


static func _model_data(model: String) -> Dictionary:
	if _data.has(model):
		return _data[model]
	var made := _from_index(model) if BodyCatalog.has_skeletal(model) else {}
	if made.is_empty():
		made = _from_baked_list(model)
	_data[model] = made
	return made


static func _from_index(model: String) -> Dictionary:
	var made: Dictionary = {}
	var clips: Dictionary = BodyRig.model_info(model).get("clips", {})
	for tag: String in clips:
		var clip: Dictionary = clips[tag]
		var frames := int(clip.get("frames", 0))
		var impact := -1
		for event: Dictionary in clip.get("events", []):
			if str(event.get("kind", "")) == "attack":
				impact = mini(int(event["frame"]), frames - 1)
				break
		made[tag] = {"frames": frames, "framerate": int(clip.get("framerate", 30)), "impact": impact}
	return made


## Models the skeleton does not draw (no asset, did not close, or `--baked-bodies`): the clip list of the baked player.
static func _from_baked_list(model: String) -> Dictionary:
	if not _fallback_loaded:
		_fallback_loaded = true
		var path := "res://cache/data/anim_mesh_clips_f37.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_fallback = parsed
	var made: Dictionary = {}
	var clips: Dictionary = _fallback.get(model, {})
	for tag: String in clips:
		var clip: Dictionary = clips[tag]
		var impact: Array = clip.get("impact_frames", [])
		made[tag] = {"frames": int(clip.get("frames", 0)), "framerate": int(clip.get("framerate", 30)),
			"impact": int(impact[0]) if not impact.is_empty() else -1}
	return made


func _clip_of(role: String) -> Dictionary:
	if role.is_empty():
		return {}
	var clip := clip_data(_model, str(_roles.get(role, "")))
	return clip if int(clip.get("frames", 0)) > 1 else {}


func _apply(role: String, restart: bool) -> void:
	var clip := _clip_of(role)
	var wanted := role if not clip.is_empty() else ""
	if not restart and wanted == _role:
		return
	_role = wanted
	_clip = clip
	_tag = str(_roles.get(wanted, "")) if not clip.is_empty() else ""
	_frame = 0
	_tick_left = 0.0
