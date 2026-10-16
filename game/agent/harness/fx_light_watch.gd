extends Node

## Read-only (playtest F97): watches, every rendered frame, each OmniLight3D of the rig's effect-light
## layer (group "fx_light_pool") and counts the frames where a light the player can see goes out at once
## instead of fading: from energy `prev` to `now` with prev − now > `cut_share` × the peak of that burst
## and prev > `min_energy`. "lugar" = same place (cut where it stood); "salto" = the light jumped to
## another place in that frame (stolen or restarted elsewhere) while it was still bright. Moves nothing,
## plays nothing, changes no rule.

const LIGHT_GROUP := &"fx_light_pool"

var cut_share := 0.4
var min_energy := 1.0

var _on := false
var _frames := 0
var _prev := {}  # instance_id -> [visible, energy, position, peak]
var _cuts_place := 0
var _cuts_jump := 0
var _worst := 0.0
var _max_active := 0
var _jumps_soft := 0
var _log := PackedStringArray()
var _engine_start := 0
var _starts := 0


func start() -> String:
	_on = true
	_starts += 1
	_engine_start = Engine.get_process_frames()
	_frames = 0
	_prev.clear()
	_cuts_place = 0
	_cuts_jump = 0
	_jumps_soft = 0
	_worst = 0.0
	_max_active = 0
	_log.clear()
	return "vigilando luces"


func stop() -> String:
	_on = false
	var engine_frames := Engine.get_process_frames() - _engine_start
	return "fx_cortes cuadros %d motor %d inicios %d max_activas %d cortes_lugar %d cortes_salto %d saltos_suaves %d peor_caida %.2f %s" % [
		_frames, engine_frames, _starts, _max_active, _cuts_place, _cuts_jump, _jumps_soft, _worst, " | ".join(_log.slice(0, 24))]


func _process(_delta: float) -> void:
	if not _on:
		return
	var layer := get_tree().get_first_node_in_group(LIGHT_GROUP)
	if layer == null:
		return
	_frames += 1
	var active := 0
	for child in layer.get_children():
		var light := child as OmniLight3D
		if light == null:
			continue
		var id := light.get_instance_id()
		var vis := light.is_visible_in_tree()
		var energy := light.light_energy if vis else 0.0
		var pos := light.global_transform.origin
		if vis:
			active += 1
		var peak := energy
		if _prev.has(id):
			var p: Array = _prev[id]
			var was_vis: bool = p[0]
			var was_e: float = p[1]
			var was_pos: Vector3 = p[2]
			var was_peak: float = p[3]
			var jumped := vis and was_vis and pos.distance_to(was_pos) > 0.05
			var drop := was_e - energy
			if jumped:
				if was_e > min_energy and was_e > cut_share * was_peak:
					_cuts_jump += 1
					_note("salto f%d %.2f->%.2f px %s" % [_frames, was_e, energy, _px(was_pos)])
				else:
					_jumps_soft += 1
				peak = energy
			else:
				peak = maxf(was_peak, energy) if vis and was_vis else energy
				if was_vis and was_e > min_energy and drop > cut_share * was_peak:
					_cuts_place += 1
					_worst = maxf(_worst, drop)
					_note("lugar f%d %.2f->%.2f" % [_frames, was_e, energy])
		_prev[id] = [vis, energy, pos, peak]
	_max_active = maxi(_max_active, active)


## Frames watched so far (to line up shots with the cuts).
func frame() -> int:
	return _frames


func _px(at: Vector3) -> String:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(at):
		return "fuera"
	var px := camera.unproject_position(at)
	return "%d,%d" % [int(px.x), int(px.y)]


func _note(text: String) -> void:
	_log.append(text)
