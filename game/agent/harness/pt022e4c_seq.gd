extends Node

## Observation only (agent harness, playtest 022e4c). Inert unless `--pt-seq=DIR,SECS,WALK_S,DT` is passed
## (DIR left|right|none; turns SECS with the real InputMap action, then walks forward WALK_S, shooting a
## frame every DT seconds of game time into --out=/seqNNN.png, then quits). `--pt-preset=low|medium|high`
## applies that quality preset to the world's look rig (a player's graphics setting) before the sequence.
## Presses only actions of the InputMap, as a player.

@export var settle_s := 13.0

var _out := ""
var _dir := "none"
var _turn := 0.0
var _walk := 0.0
var _dt := 0.3
var _preset := ""
var _wanted := false
var _t := 0.0
var _next_shot := 0.0
var _n := 0
var _preset_done := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pt-seq="):
			var p := arg.get_slice("=", 1).split(",")
			_dir = p[0]
			_turn = float(p[1])
			_walk = float(p[2])
			_dt = float(p[3])
			_wanted = true
		elif arg.begins_with("--pt-preset="):
			_preset = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--pt-settle="):
			settle_s = float(arg.get_slice("=", 1))
	if _preset.is_empty() and not _wanted:
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))


func _process(delta: float) -> void:
	_t += delta
	if not _preset.is_empty() and not _preset_done and _t > 3.0:
		_preset_done = true
		var rig = get_tree().current_scene.get_node_or_null("HighNoon/Map/Look")
		var q := load("res://data/look/quality_%s.tres" % _preset)
		if rig and q:
			rig.apply_quality(q)
			print("PT_PRESET applied ", _preset)
		else:
			print("PT_PRESET missing rig or preset")
	if not _wanted or _t < settle_s:
		return
	var local := _t - settle_s
	var action := &"turn_left" if _dir == "left" else &"turn_right"
	if local < _turn and _dir != "none":
		Input.action_press(action)
	else:
		Input.action_release(action)
		if local < _turn + _walk:
			Input.action_press(&"move_forward")
		else:
			Input.action_release(&"move_forward")
	if local >= _next_shot:
		_next_shot += _dt
		get_viewport().get_texture().get_image().save_png("%s/seq%03d.png" % [_out, _n])
		_n += 1
	if local > _turn + _walk + 0.5:
		get_tree().quit()
