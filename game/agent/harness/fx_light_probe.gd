extends Node

## Read-only (RFC-029 029c): reads the rig's effect lights and the ground's brightness around one slot of
## vfx_lab. Plays nothing, moves no actor, edits no rule. The ground points are a grid inside a disc
## around the slot's marker, at the terrain's height, projected with the current camera; each frame of a
## recording keeps the mean luminance (Rec. 709) of those pixels of the viewport.

const LIGHT_GROUP := &"fx_light_pool"

var _points: Array[Vector3] = []
var _recording := false
var _t := 0.0
var _until := 0.0
var _times := PackedFloat32Array()
var _lumas := PackedFloat32Array()
## Per frame of the recording, the luminance of every ring point (-1 = off screen or behind).
var _frames: Array[PackedFloat32Array] = []
var _perf_on := false
var _perf: Dictionary = {}


## "fx_luces activas <n> tope <m> sombras <s>", or a note when the rig has no FxLight layer.
func lights() -> String:
	var layer: Node = get_tree().get_first_node_in_group(LIGHT_GROUP)
	return layer.report() if layer != null else "fx_luces sin capa"


## Every OmniLight3D under the layer and whether any casts a shadow.
func shadows() -> String:
	var layer := get_tree().get_first_node_in_group(LIGHT_GROUP)
	if layer == null:
		return "fx_luces sin capa"
	var total := 0
	var with_shadow := 0
	for child in layer.get_children():
		if child is OmniLight3D:
			total += 1
			if (child as OmniLight3D).shadow_enabled:
				with_shadow += 1
	return "fx_luces nodos %d con_sombra %d" % [total, with_shadow]


## Grid of ground points (step `step_m`) inside `radius_m` of the slot marker named `slot`.
func ring(slot: String, radius_m: float, step_m: float = 0.5) -> String:
	var marker := _find(get_tree().current_scene, slot) as Node3D
	var terrain := Terrain.of(self)
	if marker == null or terrain == null:
		return "sin slot o terreno"
	var center := marker.global_transform.origin
	_points.clear()
	var steps := int(ceil(radius_m / step_m))
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps + 1):
			var offset := Vector2(i, j) * step_m
			if offset.length() > radius_m:
				continue
			var x := center.x + offset.x
			var z := center.z + offset.y
			var y: float = terrain.height_at(x, z)
			if not is_nan(y):
				_points.append(Vector3(x, y, z))
	return "puntos %d centro %s" % [_points.size(), center]


## Records the mean luminance of the ring for `seconds`, one value per rendered frame.
func record(seconds: float) -> String:
	_times.clear()
	_lumas.clear()
	_frames.clear()
	_t = 0.0
	_until = seconds
	_recording = true
	return "grabando %.2f s" % seconds


## "t luma" pairs of the last recording, plus base (first 5 frames), peak and when it is back.
func series() -> String:
	if _lumas.is_empty():
		return "sin serie"
	var base := 0.0
	var n := mini(5, _lumas.size())
	for i in n:
		base += _lumas[i]
	base /= float(n)
	var parts := PackedStringArray()
	var peak := 0.0
	for i in _lumas.size():
		peak = maxf(peak, _lumas[i])
		parts.append("%.3f:%.4f" % [_times[i], _lumas[i]])
	return "base %.4f pico %.4f (+%.0f %%) serie %s" % [base, peak, (peak / maxf(base, 1e-6) - 1.0) * 100.0, " ".join(parts)]


## Viewport pixels of the ring with the current camera, "x,y x,y ...", to mask captures outside Godot.
func ring_pixels() -> String:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return "sin camara"
	var parts := PackedStringArray()
	for p in _points:
		if camera.is_position_behind(p):
			continue
		var px := camera.unproject_position(p)
		parts.append("%d,%d" % [int(px.x), int(px.y)])
	return " ".join(parts)


## Starts averaging, per rendered frame, the viewport's render CPU and GPU ms (the engine's own timer,
## switched on here; Metal gives no GPU time), draw calls and the lights on.
func perf_start() -> String:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_perf = {"n": 0, "cpu": 0.0, "gpu": 0.0, "draws": 0.0, "lights": 0.0, "process": 0.0}
	_perf_on = true
	return "midiendo"


func perf_stop() -> String:
	_perf_on = false
	var n := maxf(float(_perf.get("n", 0)), 1.0)
	return "fx_costo cuadros %d cpu_render %.3f ms gpu %.3f ms draws %.1f process %.3f ms luces_media %.2f" % [
		int(_perf.get("n", 0)), _perf["cpu"] / n, _perf["gpu"] / n, _perf["draws"] / n, _perf["process"] / n, _perf["lights"] / n]


func _process(delta: float) -> void:
	if _perf_on:
		var rid := get_viewport().get_viewport_rid()
		_perf["n"] += 1
		_perf["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		_perf["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_perf["draws"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_perf["process"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var layer: Node = get_tree().get_first_node_in_group(LIGHT_GROUP)
		_perf["lights"] += float(layer.active_count()) if layer != null else 0.0
	if not _recording:
		return
	_t += delta
	if _t > _until:
		_recording = false
		return
	_times.append(_t)
	_lumas.append(_mean_luma())


## Every frame of the last recording, one line each: "t l0 l1 ..." (ring point order, -1 = not on screen).
## For masking out, outside Godot, the points a sprite covers in a run without lights.
func frames() -> String:
	var lines := PackedStringArray()
	for i in _frames.size():
		var parts := PackedStringArray(["%.3f" % _times[i]])
		for l in _frames[i]:
			parts.append("%.4f" % l)
		lines.append(" ".join(parts))
	return "\n".join(lines)


func _mean_luma() -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _points.is_empty():
		return 0.0
	var image := get_viewport().get_texture().get_image()
	var size := Vector2(image.get_width(), image.get_height())
	var scale := size / get_viewport().get_visible_rect().size
	var sum := 0.0
	var count := 0
	var row := PackedFloat32Array()
	for p in _points:
		var px := camera.unproject_position(p) * scale
		if camera.is_position_behind(p) or px.x < 0.0 or px.y < 0.0 or px.x >= size.x or px.y >= size.y:
			row.append(-1.0)
			continue
		var c := image.get_pixelv(Vector2i(px))
		var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		row.append(l)
		sum += l
		count += 1
	_frames.append(row)
	return sum / float(maxi(count, 1))


func _find(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null
