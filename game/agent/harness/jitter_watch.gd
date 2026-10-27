extends Node

## 072 1d: render-frame jitter recorder (agent/tools/jitter_stats.py reads its CSV). Idle unless the process has `--jitter-out=<file.csv>`.
## It only reads the world: one row per rendered frame for up to three bodies and the active camera, written from `_process` with a priority above the
## MpActor's (10000), so the pose it reads is the one the frame draws.
##   t_usec, frame, who, name, x, z, rtt_ms, last_correction, tick, corr_offset, guessed
##   who = own (the local wizard) | rival (the other wizard) | creature (see below) | camera (the active Camera3D, drawn pose) | mark (rows of the
##   marks, label in `name`: walk_start / walk_end from hold(), mark_walk() labels)
## The creature: `--jitter-creature=<node name>`, else the first live non-wizard unit of the lowest seat that has one (in the
## jitter flows the host summons it, so the host sees its own and the client sees the rival's).
## rtt_ms: Mp.net_quality() (on a server the rival's slot). last_correction, corr_offset: the own wizard's MpActor (last_correction() and
## correction_offset(), empty without one). tick: Engine.get_physics_frames() of that frame (a mark carries the tick it was written in).
## guessed (072 step 2, on a server only, refreshed once a second, on the rival row): the frames the rival's MpInput queue had to guess
## (private `_queue.guessed`, read here only to measure).
## Flow API: mark_walk(label), flush(), aim_far(meters) (the cursor on the ground ahead of the own creature, on screen),
## hold("move_forward,turn_right", seconds, label) (the actions are held, pressed again every physics frame like a key held down, while the
## flow goes on; writes the marks <label>_start / <label>_end).
## Props for wait_until: creature_ready (a creature is being followed), rows (rows written), holding (hold() still running).

const HEADER := "t_usec,frame,who,name,x,z,rtt_ms,last_correction,tick,corr_offset,guessed"
const FLUSH_EVERY := 30

var creature_ready := false
var rows := 0
var holding := false

var _file: FileAccess
var _creature_name := ""
var _creature: Node3D
var _actor: MpActor
var _actor_next := 0.0
var _rtt := ""
var _rtt_next := 0.0
var _guessed := ""
var _guessed_next := 0.0
var _hold_actions := PackedStringArray()
var _hold_label := ""
var _hold_left := 0.0
var _hold_started := false


func _ready() -> void:
	process_priority = 20000
	process_mode = Node.PROCESS_MODE_ALWAYS
	var path := MpBoot.user_value("jitter-out", "")
	_creature_name = MpBoot.user_value("jitter-creature", "")
	if path.is_empty():
		set_process(false)
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("jitter_watch: cannot open %s" % path)
		set_process(false)
		return
	_file.store_line(HEADER)


func _process(_delta: float) -> void:
	if _file == null or get_tree().current_scene == null:
		return
	var me := get_tree().get_first_node_in_group("local_wizard") as Node3D
	if me == null:
		return
	var now := Time.get_ticks_usec()
	var frame := Engine.get_process_frames()
	var mine := int(me.get("owner_slot"))
	var rival := _rival(mine)
	var secs := now / 1000000.0
	if secs >= _rtt_next:
		_rtt_next = secs + 0.25
		_rtt = _read_rtt(int(rival.get("owner_slot")) if rival != null else 0)
	if _actor == null and secs >= _actor_next:
		_actor_next = secs + 1.0
		var found := me.find_children("*", "MpActor", true, false)
		_actor = found[0] as MpActor if not found.is_empty() else null
	var correction := ""
	var offset := ""
	if _actor != null and is_instance_valid(_actor):
		correction = "%.5f" % _actor.last_correction()
		offset = "%.5f" % _actor.correction_offset()
	_row(now, frame, "own", me, _rtt, correction, offset)
	if rival != null:
		if secs >= _guessed_next:
			_guessed_next = secs + 1.0
			_guessed = _read_guessed(rival)
		_row(now, frame, "rival", rival, _rtt, "", "", _guessed)
	if _creature == null or not is_instance_valid(_creature) or not _creature.is_inside_tree():
		_creature = _find_creature()
	creature_ready = _creature != null
	if _creature != null:
		_row(now, frame, "creature", _creature, _rtt, "")
	var view := get_viewport().get_camera_3d()
	if view != null:
		_row(now, frame, "camera", view, _rtt, "")


func _row(now: int, frame: int, who: String, node: Node3D, rtt: String, correction: String, offset := "", guessed := "") -> void:
	# What is drawn: with physics interpolation on, the node's transform is the tick's pose, not the drawn one (kit 0.15).
	var at := node.get_global_transform_interpolated().origin
	_file.store_line("%d,%d,%s,%s,%.5f,%.5f,%s,%s,%d,%s,%s" % [now, frame, who, node.name, at.x, at.z, rtt, correction, Engine.get_physics_frames(), offset, guessed])
	rows += 1
	if rows % FLUSH_EVERY == 0:
		_file.flush()


func _read_rtt(rival_slot: int) -> String:
	var quality: Dictionary = Mp.net_quality(rival_slot) if MpKit.is_server() else Mp.net_quality()
	return "%.1f" % float(quality["rtt_ms"]) if quality.has("rtt_ms") else ""


## A server: how many frames of the rival's input the kit had to guess so far (its private queue, read only to measure). "" elsewhere.
func _read_guessed(rival: Node3D) -> String:
	if not MpKit.is_server():
		return ""
	var actor := MpActor.of(rival)
	var mp_input: MpInput = actor.input() if actor != null else null
	if mp_input == null:
		return ""
	var queue: Variant = mp_input.get(&"_queue")
	if queue == null:
		return ""
	return str(int(queue.get(&"guessed")))


func _rival(mine: int) -> Node3D:
	for node in get_tree().get_nodes_in_group("wizard"):
		if is_instance_valid(node) and node.is_inside_tree() and int(node.get("owner_slot")) != mine:
			return node as Node3D
	return null


func _find_creature() -> Node3D:
	var best: Node3D
	var best_slot := 1 << 30
	for node in get_tree().get_nodes_in_group("unit"):
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_in_group("wizard"):
			continue
		if not _creature_name.is_empty():
			if String(node.name) == _creature_name:
				return node as Node3D
			continue
		var slot := int(node.get("owner_slot"))
		if slot < best_slot:
			best_slot = slot
			best = node as Node3D
	return best


# --- flow API ----------------------------------------------------------------------------------------------------------

## A special row in the CSV (walk_start / walk_end) and a PTNET-style line.
func mark_walk(label: String) -> String:
	if _file == null:
		return "jitter off"
	_mark_row(label)
	print("JITTER mark %s" % label)
	return "mark %s" % label


func _mark_row(label: String) -> void:
	if _file == null:
		return
	_file.store_line("%d,%d,mark,%s,,,,,%d,," % [Time.get_ticks_usec(), Engine.get_process_frames(), label, Engine.get_physics_frames()])
	_file.flush()


## Holds the actions (comma separated InputMap names) for `seconds` of physics time and goes on at once (the flow waits with
## wait_until holding=false). The press is renewed every physics frame, as AgentKit's own `press hold` does; the marks go in the
## physics frame of the press and of the release, so the tick of the key is in the CSV. 072 step 2 (the flow also needs to cast
## while the keys are down, which a blocking `press hold` cannot do).
func hold(actions: String, seconds: float, label: String) -> String:
	if holding:
		return "hold: busy"
	var names := actions.split(",", false)
	for action in names:
		if not InputMap.has_action(action):
			return "hold: unmapped input %s" % action
	_hold_actions = names
	_hold_label = label
	_hold_left = seconds
	_hold_started = false
	holding = true
	return "hold %s %.1f s" % [actions, seconds]


func _physics_process(delta: float) -> void:
	if not holding:
		return
	if not _hold_started:
		_hold_started = true
		_mark_row(_hold_label + "_start")
		print("JITTER hold %s %s" % [",".join(_hold_actions), _hold_label])
	_hold_left -= delta
	if _hold_left > 0.0:
		for action in _hold_actions:
			Input.action_press(action)
		return
	for action in _hold_actions:
		Input.action_release(action)
	holding = false
	_mark_row(_hold_label + "_end")


func flush() -> String:
	if _file != null:
		_file.flush()
	return "rows %d" % rows


## The cursor on the ground up to `meters` ahead (the camera's flat forward) of the own creature, as far as the screen shows
## (the creature then walks away in a straight line). The flow presses order_units after it.
func aim_far(meters: float) -> String:
	var scene := get_tree().current_scene
	var me := get_tree().get_first_node_in_group("local_wizard")
	var cam: Camera3D
	for node in scene.find_children("*", "Camera3D", true, false):
		if "debug_pointer" in node:
			cam = node as Camera3D
			break
	var terrain: Terrain = Terrain.of(scene)
	if cam == null or terrain == null or me == null:
		return "aim_far: no camera/terrain/wizard"
	var mine := int(me.get("owner_slot"))
	var from: Node3D
	for node in get_tree().get_nodes_in_group("unit"):
		if is_instance_valid(node) and not node.is_in_group("wizard") and int(node.get("owner_slot")) == mine:
			from = node as Node3D
			break
	if from == null:
		return "aim_far: no own creature"
	var ahead := -cam.global_transform.basis.z
	var flat := Vector3(ahead.x, 0.0, ahead.z).normalized()
	var rect := cam.get_viewport().get_visible_rect().grow(-0.12 * cam.get_viewport().get_visible_rect().size.y)
	var d := meters
	while d >= 6.0:
		var spot := from.global_transform.origin + flat * d
		var y := terrain.height_at(spot.x, spot.z)
		spot.y = 0.0 if is_nan(y) else y
		if not cam.is_position_behind(spot):
			var screen := cam.unproject_position(spot)
			if rect.has_point(screen):
				cam.set("debug_pointer", screen)
				var line := "JITTER aim_far %.0f m at %d,%d (%.1f, %.1f)" % [d, int(screen.x), int(screen.y), spot.x, spot.z]
				print(line)
				return line
		d -= 4.0
	return "aim_far: nothing on screen"
