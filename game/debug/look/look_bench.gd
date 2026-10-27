extends Node

## RFC-022 bench: the product map, 60 animated bodies and 8 emitters. Without vsync it discards
## `warmup_frames`, averages `sample_frames` and prints one line per case:
##   preset x scale mode (all layers off), then each layer alone and all layers on at each
##   preset's own mode. Exits when done. Run with a window (a headless process has no GPU time).
## Mode CAPTURE writes one crop per scale mode under agent/out/rfc022/022a/ to look for ghosting.
## RFC-054 054e (cases flora_peaks / flora_roads): `--flora` with `--map=peaks` or `--map=roads` measures the high preset
## over the map's densest flora, with the Flora layer off and on (frame mean and p95, draw calls, primitives, VRAM,
## RSS, plants drawn, nodes and `peor_armado_ms`: the worst main-thread time of the planters in one frame, ring plus
## applying finished cells; the planning runs on worker threads since 054e F384). No extra views: the frame time is the measure.
##   godot --path game res://debug/look/look_bench.tscn -- --map=peaks --flora

enum Run { MEASURE, CAPTURE }

const QUALITY_DIR := "res://data/look"
const PRESET_IDS: Array[StringName] = [&"low", &"medium", &"high"]
const MODE_NAMES := {
	Viewport.SCALING_3D_MODE_BILINEAR: "bilinear",
	Viewport.SCALING_3D_MODE_FSR: "fsr1",
	Viewport.SCALING_3D_MODE_FSR2: "fsr2",
	Viewport.SCALING_3D_MODE_METALFX_SPATIAL: "metalfx_spatial",
	Viewport.SCALING_3D_MODE_METALFX_TEMPORAL: "metalfx_temporal",
}
const SPRITE_FX: Array[String] = [
	"manafount", "cast_james", "cast_persephone", "heal", "dirt", "blood", "summon", "spit_trail"]
const CREATURE_TAGS: Array[String] = ["ycro", "amuh"]

@export var run: Run = Run.MEASURE
@export var world: Node3D
@export var view_camera: Camera3D
@export var units: Node3D
@export var emitters: Node3D
@export var unit_scene: PackedScene
@export var emitter_scene: PackedScene
@export var unit_count := 0
@export var unit_columns := 10
@export var unit_spacing := 3.0
@export var center := Vector2(1500.0, 1525.0)
@export var warmup_frames := 120
@export var sample_frames := 300
@export var window_size := Vector2i(2560, 1440)
## Metal returns 0 for GPU timestamps (measured in 022a), so GPU ms is derived: `extra_views`
## SubViewports render the same world with the same preset, the frame goes over the display cap
## and gpu_ms = frame time / (extra_views + 1). Valid only while frame_ms stays above ~9.
@export var extra_views := 8
## One case per preset at its own mode (for the slow 60-body run).
@export var quick := false
@export var out_dir := "res://agent/out/rfc022/022a"
## Biome the map shows (the world would roll a random one, and the layers need its profile).
@export var god: StringName = &"persephone"
## RFC-054 054e: measure the Flora layer (see the header).
@export var flora := false

var _viewport_rid: RID
var _presets: Array[LookQuality] = []
var _views: Array[SubViewport] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--units="):
			unit_count = int(arg.get_slice("=", 1))
		elif arg.begins_with("--size="):
			window_size = Vector2i(int(arg.get_slice("=", 1).get_slice("x", 0)), int(arg.get_slice("=", 1).get_slice("x", 1)))
		elif arg.begins_with("--views="):
			extra_views = int(arg.get_slice("=", 1))
		elif arg.begins_with("--god="):
			god = StringName(arg.get_slice("=", 1))
		elif arg == "--quick":
			quick = true
		elif arg == "--flora":
			flora = true
			extra_views = 0
		elif arg == "--capture":
			run = Run.CAPTURE
		elif arg.begins_with("--samples="):
			sample_frames = int(arg.get_slice("=", 1))
			warmup_frames = sample_frames / 2
	for id in PRESET_IDS:
		_presets.append(load(QUALITY_DIR.path_join("quality_%s.tres" % id)) as LookQuality)
	var hud := world.get_node_or_null("Hud") as CanvasLayer
	if hud:
		hud.visible = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DisplayServer.window_set_size(window_size)
	_viewport_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
	_start.call_deferred()


func _start() -> void:
	await get_tree().process_frame
	var look := GameCatalog.shared().god(String(god)).look
	var rig := world.get_node_or_null("Map/Look") as LookRig
	if rig and look:
		look.sky.material.set_shader_parameter(&"time_override_s", 0.0)  # a still sky: the bench measures frames, not the sky's motion
		rig.apply_profile(look)
	_fill_units()
	_fill_emitters()
	view_camera.global_position = Vector3(center.x, 30.0, center.y - 40.0)
	view_camera.look_at(Vector3(center.x, 18.0, center.y), Vector3.UP)
	_make_views()
	await _frames(90)
	print("bench diag fps %d foco %s modo_ventana %d vsync %d unidades %d" % [
		Engine.get_frames_per_second(), DisplayServer.window_is_focused(),
		DisplayServer.window_get_mode(), DisplayServer.window_get_vsync_mode(), units.get_child_count()])
	var size: Vector2i = get_viewport().size
	print("bench ventana %dx%d gpu %s render %s" % [
		size.x, size.y, RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method()])
	if flora:
		await _measure_flora()
	elif run == Run.CAPTURE:
		await _capture_modes()
	else:
		await _measure_all()
	QualityApplier.apply_to(get_viewport(), load(QUALITY_DIR.path_join("quality_high.tres")))
	print("BENCH_DONE")
	get_tree().quit()


func _measure_all() -> void:
	var rig := world.get_node_or_null("Map/Look") as LookRig
	var layer_count := rig.layer_nodes().size() if rig else 0
	_set_layers(rig, layer_count, -1)
	await _measure_case("nativa", _native(), "todas_apagadas")
	for preset in _presets:
		var modes: Array[Viewport.Scaling3DMode] = [Viewport.SCALING_3D_MODE_BILINEAR]
		if quick:
			modes = [preset.scaling_mode]
		elif preset.scale < 1.0:
			modes = [
				Viewport.SCALING_3D_MODE_BILINEAR, Viewport.SCALING_3D_MODE_FSR,
				Viewport.SCALING_3D_MODE_METALFX_SPATIAL,
				Viewport.SCALING_3D_MODE_FSR2, Viewport.SCALING_3D_MODE_METALFX_TEMPORAL]
		for mode in modes:
			var variant := preset.duplicate() as LookQuality
			variant.scaling_mode = mode
			await _measure_case(String(preset.id), variant, "todas_apagadas")
		for layer in layer_count:
			_set_layers(rig, layer_count, layer)
			await _measure_case(String(preset.id), preset, "capa_%d" % (layer + 1))
		if preset.ssil_enabled and layer_count > 0:
			# Isolates SSIL: the first layer (light) alone, same preset without SSIL.
			var no_ssil := preset.duplicate() as LookQuality
			no_ssil.ssil_enabled = false
			_set_layers(rig, layer_count, 0)
			await _measure_case(String(preset.id), no_ssil, "capa_1_sin_ssil")
		if layer_count > 0:
			_set_layers(rig, layer_count, -2)
			await _measure_case(String(preset.id), preset, "todas_encendidas")
			_set_layers(rig, layer_count, -1)


## only: -1 all off, -2 all on, i = just layer i.
func _set_layers(rig: LookRig, count: int, only: int) -> void:
	for i in count:
		rig.set_layer_enabled(i, only == -2 or i == only)


func _native() -> LookQuality:
	var native := LookQuality.new()
	native.id = &"native"
	return native


func _measure_case(preset_name: String, quality: LookQuality, layers: String) -> void:
	var rig := world.get_node_or_null("Map/Look") as LookRig
	if rig:
		rig.apply_quality(quality)
	QualityApplier.apply_to(get_viewport(), quality)
	for view in _views:
		QualityApplier.apply_to(view, quality)
	await _frames(warmup_frames)
	var cpu := PackedFloat32Array()
	var process := PackedFloat32Array()
	var started := Time.get_ticks_usec()
	var draws := 0.0
	var prims := 0.0
	var vram := 0.0
	for i in sample_frames:
		await RenderingServer.frame_post_draw
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid))
		process.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		vram = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var elapsed := (Time.get_ticks_usec() - started) / 1.0e6
	var applied := QualityApplier.read_back(get_viewport())
	var size: Vector2i = get_viewport().size
	var internal := Vector2i(roundi(size.x * float(applied.scale)), roundi(size.y * float(applied.scale)))
	var fps := sample_frames / elapsed
	var views := _views.size() + 1
	print("bench preset %s modo %s escala %.2f interno %dx%d capas %s vistas %d frame_ms %.2f gpu_ms %.2f cpu_render_ms %.2f proceso_ms %.2f fps %.0f draw %.0f prim %.0f vram_mb %.0f leido_modo %s" % [
		preset_name, MODE_NAMES[quality.scaling_mode], quality.scale, internal.x, internal.y, layers,
		views, 1000.0 / fps, 1000.0 / fps / views, _mean(cpu), _mean(process), fps,
		draws / sample_frames, prims / sample_frames, vram / 1048576.0, MODE_NAMES[applied.mode]])


## RFC-054 054e: the high preset, all layers on, over the densest 32 m cell of the map's FloraLayers; Flora off, then on.
func _measure_flora() -> void:
	var rig := world.get_node_or_null("Map/Look") as LookRig
	var field := rig.get_node_or_null("Layers/Flora") as FloraField if rig else null
	if field == null or field.density().entries() == 0:
		print("bench flora: el mapa no tiene capa Flora o FloraLayer")
		return
	var high := _presets[2]
	var spot := _densest(field.density())
	var terrain := Terrain.of(self)
	var ground := terrain.height_at(spot.x, spot.y) if terrain else 0.0
	ground = 0.0 if is_nan(ground) else ground
	view_camera.global_position = Vector3(spot.x, ground + 6.0, spot.y - 30.0)
	view_camera.look_at(Vector3(spot.x, ground, spot.y), Vector3.UP)
	var map_tag := String(ActiveMatch.map().tag)
	for on in [false, true]:
		field.visible = on
		rig.apply_quality(high)
		QualityApplier.apply_to(get_viewport(), high)
		await _frames(warmup_frames)
		var frames := PackedFloat32Array()
		var draws := 0.0
		var prims := 0.0
		var last := Time.get_ticks_usec()
		for i in sample_frames:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			frames.append((now - last) / 1000.0)
			last = now
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var build := field.build_us()
		print("bench flora_%s flora %s frame_ms %.2f p95_ms %.2f draw %.0f prim %.0f vram_mb %.0f rss_mb %.0f plantas %d nodos %d celdas %d peor_armado_ms %.2f pendientes %d" % [
			map_tag, "si" if on else "no", _mean(frames), _p95(frames), draws / sample_frames, prims / sample_frames,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, OS.get_static_memory_usage() / 1048576.0,
			field.instance_count(), field.node_count(), field.cell_count(), build.y / 1000.0, field.pending_count()])


## Map point (x, z) at the center of the 32 m cell with the most plants.
func _densest(map: FloraDensity) -> Vector2:
	var per := MeshPlanter.DATA_PER_CELL
	var best := Vector2i.ZERO
	var best_sum := -1
	for cz in MeshPlanter.MAP_CELLS:
		for cx in MeshPlanter.MAP_CELLS:
			var sum := 0
			for t in map.entries():
				for dz in per:
					for dx in per:
						sum += map.count_at(t, cx * per + dx, cz * per + dz)
			if sum > best_sum:
				best_sum = sum
				best = Vector2i(cx, cz)
	return (Vector2(best) + Vector2(0.5, 0.5)) * MeshPlanter.CELL_M


func _capture_modes() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var medium := _presets[1]
	for mode in MODE_NAMES:
		var variant := medium.duplicate() as LookQuality
		variant.scaling_mode = mode
		QualityApplier.apply_to(get_viewport(), variant)
		var base := view_camera.global_position
		for frame in 90:
			view_camera.global_position = base + Vector3(sin(frame * 0.12) * 3.0, 0.0, 0.0)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var crop := image.get_region(Rect2i(image.get_width() / 4, image.get_height() / 3, image.get_width() / 2, image.get_height() / 2))
		var path := ProjectSettings.globalize_path(out_dir.path_join("scale_%s.png" % MODE_NAMES[mode]))
		crop.save_png(path)
		view_camera.global_position = base
		print("bench captura %s %s" % [MODE_NAMES[mode], path])


func _make_views() -> void:
	if run != Run.MEASURE:
		return
	for i in extra_views:
		var view := SubViewport.new()
		view.size = get_viewport().size
		view.world_3d = get_viewport().world_3d
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var camera := Camera3D.new()
		camera.fov = view_camera.fov
		camera.far = view_camera.far
		view.add_child(camera)
		add_child(view)
		camera.global_transform = view_camera.global_transform
		camera.current = true
		_views.append(view)


func _fill_units() -> void:
	var terrain := Terrain.of(self)
	var rows := ceili(float(unit_count) / unit_columns)
	for i in unit_count:
		var unit: Node3D = unit_scene.instantiate()
		unit.set("type", GameData.creature(CREATURE_TAGS[i % CREATURE_TAGS.size()]))
		unit.set("owner_slot", 1)
		unit.set("idle_aggro", false)
		var x := center.x + (i % unit_columns - (unit_columns - 1) * 0.5) * unit_spacing
		var z := center.y + (i / unit_columns - (rows - 1) * 0.5) * unit_spacing
		var y := 18.0
		if terrain:
			var found: float = terrain.height_at(x, z)
			y = found if not is_nan(found) else y
		units.add_child(unit)
		unit.global_position = Vector3(x, y + 0.2, z)
		unit.call_deferred("debug_set_clip_state", "run")


func _fill_emitters() -> void:
	for i in SPRITE_FX.size():
		var type := load("res://data/fx/%s.tres" % SPRITE_FX[i]) as ParticleType
		if type == null:
			continue
		var emitter: Node3D = emitter_scene.instantiate()
		emitter.set("type", type)
		emitter.set("start_active", true)
		emitters.add_child(emitter)
		emitter.global_position = Vector3(center.x + (i - 3.5) * 4.0, 19.0, center.y + 12.0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _mean(values: PackedFloat32Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(values.size(), 1.0)


func _p95(values: PackedFloat32Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(sorted.size() * 0.95), 0, sorted.size() - 1)] if sorted.size() > 0 else 0.0
