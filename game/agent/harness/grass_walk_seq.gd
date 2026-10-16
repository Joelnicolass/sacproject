extends Node

## Observation only (agent harness): waits for the match to settle, then holds `move_forward` for
## `walk_s` seconds and `turn_right` for `turn_s`, saving a frame every `every` rendered frames
## (`seq_NNN.png` in `--out=` dir), then quits. Presses the real InputMap actions, as a player.

@export var settle_s := 10.0
@export var walk_s := 4.0
@export var turn_s := 2.0
@export var every := 12

var _out := ""
var _t := 0.0
var _frames := 0
var _n := 0


func _ready() -> void:
	# AgentKit mounts every harness in every flow: stay inert unless asked for.
	var wanted := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--grass-seq":
			wanted = true
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	if not wanted:
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(_out)


func _process(delta: float) -> void:
	_t += delta
	if _t < settle_s:
		return
	var local := _t - settle_s
	if local < walk_s:
		Input.action_press(&"move_forward")
	elif local < walk_s + turn_s:
		Input.action_release(&"move_forward")
		Input.action_press(&"turn_right")
	else:
		Input.action_release(&"turn_right")
	_frames += 1
	if _frames % every == 0:
		get_viewport().get_texture().get_image().save_png("%s/seq_%03d.png" % [_out, _n])
		_n += 1
	if local > walk_s + turn_s + 0.5:
		get_tree().quit()
