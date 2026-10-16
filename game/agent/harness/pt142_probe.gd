extends Node

## F142 (RFC-031 031c) observer. Read-only: never changes the game. Tolerates scene == null.
##   arm()     starts watching the longest frame (it runs while the tree is paused too).
##   state()   one line: modal count, paused, scene, the shared GraphicsPrefs, what the engine holds (max_fps, VSync,
##             window mode), the HUD scale and, in a match, the rig preset, the viewport read_back vs that preset,
##             the grass fields (preset id, active, cells) and the longest frame since arm().

const PREFS := preload("res://data/ui/graphics_prefs.tres")
const HUD := preload("res://data/ui/hud_scale.tres")

var _max_dt := 0.0
var _armed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _armed:
		_max_dt = maxf(_max_dt, delta)


func arm() -> String:
	_armed = true
	_max_dt = 0.0
	print("pt142 armed")
	return "armed"


func state() -> String:
	var tree := get_tree()
	if tree == null:
		return "no tree"
	var line := "pt142 modal=%d paused=%s" % [tree.get_nodes_in_group(WorldInput.MODAL).size(), tree.paused]
	line += " prefs=%s vsync=%s full=%s fps=%d" % [PREFS.quality_id(), PREFS.vsync(), PREFS.fullscreen(), PREFS.max_fps()]
	line += " engine_fps=%d ds_vsync=%d win_mode=%d hud=%.2f" % [
		Engine.max_fps, DisplayServer.window_get_vsync_mode(), get_window().mode, HUD.get_scale()]
	var scene := tree.current_scene
	if scene == null:
		line += " scene=null"
		print(line)
		return line
	line += " scene=%s" % scene.name
	var rig := scene.find_child("Look", true, false) as LookRig
	if rig != null and rig.quality_preset != null:
		var preset := rig.quality_preset
		var back := QualityApplier.read_back(get_viewport())
		var same: bool = back["mode"] == preset.scaling_mode and is_equal_approx(float(back["scale"]), preset.scale) \
			and back["aa"] == preset.screen_space_aa and back["msaa"] == preset.msaa_3d
		line += " rig=%s read_back=%s same=%s" % [preset.id, back, same]
		var fields := []
		for grass in scene.find_children("*", "GrassField", true, false):
			var grass_preset: LookQuality = grass.get("_preset")
			fields.append("%s/%s/%d" % [grass_preset.id if grass_preset else &"-", grass.get("_active"), (grass.get("_cells") as Dictionary).size()])
		line += " grass=%s enabled=%s" % [fields, preset.grass_enabled]
	var match_state := tree.get_first_node_in_group(&"match_state")
	if match_state != null:
		line += " ended=%s" % match_state.get("ended")
	if _armed:
		line += " max_frame_ms=%.1f" % (_max_dt * 1000.0)
	print(line)
	return line
