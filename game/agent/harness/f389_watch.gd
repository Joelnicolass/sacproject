extends Node

## Observation only (plan 065, F389): what a rising tower shows, as lines for the flow log. Touches no actor.
##   report()  "p=<progress> edge_y=<y> line_y=<y> light=<energy> lit=<bool> visible=<bool> rings=<bool> trauma=<t>" of the
##             first CastTower in play, or "sin torre".
##   moments() the BuildCues moments seen so far: "start@<frame> done@<frame> cut@<frame>" (process frames).
##   sounds()  the SoundLog entries of the cast: incantations, build_start / build_done, explosion, fountain and Manalith loops,
##             as "<frame> <event> <file> <played>".
##   cost_begin() / cost_end(label) / hide_rings(bool)  the rings' render cost: the same moment averaged with and without them.

const KEYS: PackedStringArray = ["cnj", "_s_u_m_n", "fbxp", "incant", "loop", "mlth", "font"]

var _moments: PackedStringArray = []
var _watched: Dictionary = {}
## Frame cost sampling (cost_begin / cost_end): sums of the viewport's measured CPU and GPU render time and of the frame time.
var _sampling := false
var _frames := 0
var _gpu_ms := 0.0
var _cpu_ms := 0.0
var _frame_ms := 0.0


func _process(delta: float) -> void:
	if _sampling:
		var rid := get_viewport().get_viewport_rid()
		_frames += 1
		_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		_frame_ms += delta * 1000.0
	for node in get_tree().get_nodes_in_group(CastTower.TOWER_GROUP):
		var cues := node.get_node_or_null(^"BuildCues") as BuildCues
		if cues == null or _watched.has(cues.get_instance_id()):
			continue
		_watched[cues.get_instance_id()] = true
		cues.start_shown.connect(func(_at: Vector3) -> void: _moments.append("start@%d" % Engine.get_process_frames()))
		cues.done_shown.connect(func(_at: Vector3) -> void: _moments.append("done@%d" % Engine.get_process_frames()))
		cues.cut_shown.connect(func(_at: Vector3) -> void: _moments.append("cut@%d" % Engine.get_process_frames()))


func report() -> String:
	var tower := get_tree().get_first_node_in_group(CastTower.TOWER_GROUP) as CastTower
	if tower == null:
		return "sin torre"
	var edge := tower.get_node_or_null(^"BuildEdge") as BuildEdge
	var reveal := tower.get_node_or_null(^"BuildReveal") as BuildReveal
	var light := tower.get_node_or_null(^"BuildEdge/EdgeLight") as OmniLight3D
	var rings := tower.get_node_or_null(^"BuildEdge/EdgeRings") as SpriteEmitter
	var shake := get_tree().current_scene.find_child("CameraShake", true, false)
	return "p=%.3f edge_y=%.2f line_y=%.2f light=%.3f lit=%s visible=%s rings=%s trauma=%.3f" % [
		tower.build_progress,
		edge.global_transform.origin.y if edge else NAN,
		reveal.line_y() if reveal else NAN,
		light.light_energy if light else NAN,
		str((light as ActorLight).is_lit()) if light is ActorLight else "-",
		str(light.visible) if light else "-",
		str(rings.is_active()) if rings else "-",
		float(shake.get("trauma")) if shake else NAN,
	]


## Starts averaging the render cost of the frames from now on.
func cost_begin() -> String:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_sampling = true
	_frames = 0
	_gpu_ms = 0.0
	_cpu_ms = 0.0
	_frame_ms = 0.0
	return "ok"


## "<label> frames=<n> gpu=<ms> cpu=<ms> frame=<ms>" averaged since cost_begin.
func cost_end(label: String) -> String:
	_sampling = false
	var n := maxf(1.0, float(_frames))
	return "COST %s frames=%d gpu=%.3f cpu=%.3f frame=%.3f" % [label, _frames, _gpu_ms / n, _cpu_ms / n, _frame_ms / n]


## Measurement only: hides (true) or shows the rings of the rising tower so the same moment is measured with and without them.
func hide_rings(hidden: bool) -> String:
	var tower := get_tree().get_first_node_in_group(CastTower.TOWER_GROUP) as CastTower
	var rings := tower.get_node_or_null(^"BuildEdge/EdgeRings") as Node3D if tower else null
	if rings == null:
		return "sin anillos"
	rings.visible = not hidden
	return "rings visible=%s" % rings.visible


func moments() -> String:
	return " ".join(_moments) if not _moments.is_empty() else "ninguno"


func sounds() -> String:
	var bus := get_node_or_null(^"/root/SoundBus")
	var log: SoundLog = bus.get("sound_log") if bus else null
	if log == null:
		return "sin SoundLog"
	var lines := PackedStringArray()
	for entry: Dictionary in log.entries():
		var file := str(entry["stream"]).get_file()
		for key in KEYS:
			if file.containsn(key) or str(entry["event"]).containsn(key):
				lines.append("%d %s %s %s" % [entry["tick"], entry["event"], file, entry["played"]])
				break
	return " | ".join(lines)
