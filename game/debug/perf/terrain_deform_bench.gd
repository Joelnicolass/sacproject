extends Node

## Bench of what deforming the ground costs on the main thread (063D perf diagnosis, 2026-10-26). Loads cast_terrain.tscn (High Noon),
## turns the high preset on so the flora listens, and plays three phases of `phase_s` seconds each:
## - baseline: nothing moves; - live: Volcano's mound (`live_stamp` of `live_zone`, 33x33 vertices) shows a new second of its timeline every tick;
## - quakes: `quake_count` Quakes at once (quake_wave.tscn through QuakeWave.launch, the way the Jabberocky fires it: the server's
##   two stamps and the stun), a new batch as soon as the last one ends (RFC-057 criterion 10);
## - holes: a vertex is taken away and given back every `hole_every_s` (Bore), so the navmesh re-bakes and swaps.
## Per phase it prints the script time of each physics tick (from the first to the last _physics_process of the tick, the
## physics server step not included), the frame time and its worst frame, and the wall time of every Terrain call
## (call_ms: it runs on `physics_frame`, just before the tick window, so the cost of a tick is tick_ms + call_ms), and what
## TerrainDeformTexture sent to the GPU each frame (upload_kb) with its CPU time (upload_us; F4 target <= 10 KB, <= 20 us live).
## Measured on an M4 before the fixes: baseline tick 0.42 ms; live tick 1.14 (p95 2.80) + call 0.74; holes worst frame 70 ms.
## Run (window: the look layers only live with one): Godot --path game res://debug/perf/terrain_deform_bench.tscn. Target after
## the 063D fixes: live adds <= 1 ms per tick and the worst frame of every phase stays under 20 ms. Last line: TERRAIN DEFORM
## BENCH PASS when the quakes add <= `quake_tick_ms` to the baseline's average tick and no frame of theirs passes `frame_cap_ms`.

const TAIL_PRIORITY := 100000

@export var world_scene: PackedScene
@export var quality: LookQuality
## The zone whose TerrainStamp (`live_stamp`) plays in the live phase.
@export var live_zone: PackedScene
@export var live_stamp := NodePath("Mound")
@export_range(1.0, 30.0, 0.5, "suffix:s") var warmup_s := 8.0
@export_range(1.0, 30.0, 0.5, "suffix:s") var phase_s := 6.0
@export_range(0.1, 5.0, 0.1, "suffix:s") var hole_every_s := 1.0
@export_range(10.0, 300.0, 1.0, "suffix:m") var stamp_ahead_m := 120.0
## The Quake of the quakes phase (the server's wave with its Ground) and how many play at once, this far apart around the spot.
@export var quake_scene: PackedScene
@export_range(1, 20) var quake_count := 5
@export_range(0.0, 200.0, 1.0, "suffix:m") var quake_spread_m := 60.0
## The verdict of the quakes phase: average tick over the baseline's, and the worst frame.
@export_range(0.0, 10.0, 0.1, "suffix:ms") var quake_tick_ms := 1.0
@export_range(1.0, 100.0, 1.0, "suffix:ms") var frame_cap_ms := 20.0

var _tick_start := 0
var _ticks := PackedFloat32Array()
var _frames := PackedFloat32Array()
var _calls := PackedFloat32Array()
var _upload_kb := PackedFloat32Array()
var _upload_us := PackedFloat32Array()
var _texture: TerrainDeformTexture
var _tail: Node


func _ready() -> void:
	process_physics_priority = -TAIL_PRIORITY
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	add_child(world_scene.instantiate())
	_tail = Node.new()
	_tail.name = "TickTail"
	_tail.process_physics_priority = TAIL_PRIORITY
	_tail.set_script(_tail_script())
	_tail.set_meta("bench", self)
	add_child(_tail)
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	_tick_start = Time.get_ticks_usec()


func _process(delta: float) -> void:
	_frames.append(delta * 1000.0)
	if _texture != null:
		_upload_kb.append(_texture.uploaded_bytes / 1024.0)
		_upload_us.append(float(_texture.upload_usec))


## Called by the tail node, the last _physics_process of the tick.
func tick_ended() -> void:
	_ticks.append(float(Time.get_ticks_usec() - _tick_start) / 1000.0)


func _tail_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc _physics_process(_d: float) -> void:\n\tget_meta(\"bench\").tick_ended()\n"
	script.reload()
	return script


func _run() -> void:
	await _wait(2.0)
	var rig := get_tree().get_first_node_in_group(FloraField.GROUP).get("rig") as LookRig if get_tree().get_first_node_in_group(FloraField.GROUP) else null
	if rig != null and quality != null: rig.apply_quality(quality)
	_texture = rig.find_child("TerrainDeform", true, false) as TerrainDeformTexture if rig != null else null
	await _wait(warmup_s)
	var terrain := Terrain.of(self)
	var wizard := get_tree().get_first_node_in_group(&"wizard") as WizardBody
	var zone := live_zone.instantiate() if live_zone != null else null
	var stamp := zone.get_node_or_null(live_stamp) as TerrainStamp if zone != null else null
	if terrain == null or wizard == null or stamp == null:
		printerr("terrain_deform_bench: no terrain, wizard or live stamp")
		get_tree().quit(1)
		return
	_begin()
	await _wait(phase_s)
	var baseline := _end("baseline")
	var at := wizard.global_position + wizard.facing_flat() * stamp_ahead_m
	var center := TerrainGrid.point_of(TerrainGrid.vertex_near(Vector2(at.x, at.z)))
	var reach := stamp.reach.shape as CylinderShape3D
	var pattern := StampRules.pattern_under(terrain, stamp.profile, center, reach.radius, reach.height) if stamp.profile.has_pattern() else PackedFloat32Array()
	_begin()
	var until := Time.get_ticks_msec() + int(phase_s * 1000.0)
	var step := 0
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		step += 1
		var started := Time.get_ticks_usec()
		terrain.stamp(&"bench", stamp.profile, center, reach.radius, reach.height, fmod(step / 60.0, stamp.profile.duration_s()), pattern)
		_calls.append(float(Time.get_ticks_usec() - started) / 1000.0)
	_end("live %s every tick" % TerrainGrid.vertex_rect(center, reach.radius).size)
	terrain.unstamp(&"bench")
	zone.free()
	await _wait(2.0)
	_begin()
	var launched := await _quakes(terrain, center)
	var quakes := _end("%d quakes x %d" % [quake_count, launched])
	await _wait(2.0)
	_begin()
	until = Time.get_ticks_msec() + int(phase_s * 1000.0)
	var removed := false
	while Time.get_ticks_msec() < until:
		removed = not removed
		var started := Time.get_ticks_usec()
		if removed: terrain.cut_hole(center)
		else: terrain.fill_hole(center)
		_calls.append(float(Time.get_ticks_usec() - started) / 1000.0)
		await _wait(hole_every_s)
	if removed: terrain.fill_hole(center)
	await _wait(4.0)
	_end("holes every %.1f s" % hole_every_s)
	var added := quakes.x - baseline.x
	var ok := launched > 0 and added <= quake_tick_ms and quakes.y <= frame_cap_ms
	print("terrain_deform_bench quakes add %.2f ms per tick (max %.1f), worst frame %.1f ms (max %.1f)" % [added, quake_tick_ms, quakes.y, frame_cap_ms])
	print("TERRAIN DEFORM BENCH %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## `quake_count` Quakes at once around `center`, batch after batch for `phase_s`; returns how many batches were launched (0 when
## the scene or the shot container is missing).
func _quakes(terrain: Terrain, center: Vector2) -> int:
	var batches := 0
	var until := Time.get_ticks_msec() + int(phase_s * 1000.0)
	while quake_scene != null and Time.get_ticks_msec() < until:
		var waves: Array[QuakeWave] = []
		for k in quake_count:
			var spot := center + Vector2.from_angle(TAU * float(k) / float(quake_count)) * quake_spread_m
			var ground := terrain.height_at(spot.x, spot.y)
			var wave := QuakeWave.launch(quake_scene, self, Vector3(spot.x, 0.0 if is_nan(ground) else ground, spot.y), "bench")
			if wave != null:
				waves.append(wave)
		if waves.is_empty():
			return 0
		batches += 1
		while waves.any(func(wave: Variant) -> bool: return is_instance_valid(wave)):
			await get_tree().physics_frame
	return batches


func _begin() -> void:
	_ticks.clear()
	_frames.clear()
	_calls.clear()
	_upload_kb.clear()
	_upload_us.clear()


## Prints the phase and returns (average tick ms, worst frame ms).
func _end(label: String) -> Vector2:
	print("terrain_deform_bench %-24s tick_ms %s | frame_ms %s | call_ms %s | upload_kb %s | upload_us %s" % [label, _stats(_ticks), _stats(_frames), _stats(_calls), _stats(_upload_kb), _stats(_upload_us)])
	var total := 0.0
	for tick in _ticks:
		total += tick
	var worst := 0.0
	for frame in _frames:
		worst = maxf(worst, frame)
	return Vector2(total / maxf(1.0, float(_ticks.size())), worst)


func _stats(values: PackedFloat32Array) -> String:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in values:
		total += v
	return "avg %.2f p95 %.2f max %.2f" % [total / values.size(), sorted[int(sorted.size() * 0.95)], sorted[sorted.size() - 1]]


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
