extends SceneTree

## 063-2a: what a physics ray finds is what the surface answers, and the ground loads fast. Builds the Surface and the Collision
## of mesh_test by hand and times it (the load criterion: Surface + Collision <= 300 ms), then instances the imported
## ground.glb, lets the physics settle and casts GroundRay.surface_y straight down at 500 seeded points of the land: the ray
## must be within 0.05 m of `GroundSurface.height_at` (on the arch both are the roof). It also checks that the scene the
## import made has what the plan says (a Surface listing every chunk, a Collision with one shape per chunk).
## Needs the project imported once. No autoloads. Always quits; gives up after 120 s.
## Run: Godot --headless --path game --script res://debug/map/mesh_ground_ray.gd   (prints MESH GROUND RAY PASS / FAIL)

const DATA_PATH := "res://scenes/map/maps/mesh_test/ground.res"
const SCENE_PATH := "res://scenes/map/maps/mesh_test/ground.glb"
const POINTS := 500
const TOLERANCE_M := 0.05
const LOAD_LIMIT_MS := 300.0
const TIME_LIMIT_S := 120.0
const SEED := 20261025
const GROUND_LAYER_MASK := 1
const MARGIN_M := 25.0

var _failed := PackedStringArray()


func _initialize() -> void:
	create_timer(TIME_LIMIT_S).timeout.connect(_give_up)
	_time_the_load()
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		printerr("mesh_ground_ray: %s does not load (import the project once)" % SCENE_PATH)
		quit(2)
		return
	var ground := packed.instantiate() as Node3D
	root.add_child(ground)
	for i in 3:
		await physics_frame
	var surface: GroundSurface
	var collision: GroundCollision
	for child in ground.get_children():
		surface = child as GroundSurface if child is GroundSurface else surface
		collision = child as GroundCollision if child is GroundCollision else collision
	if surface == null or collision == null:
		_check("scene_has_surface_and_collision", false, "children: %s" % str(ground.get_children()))
	else:
		_check_scene(ground, surface, collision)
		_check_rays(ground, surface)
	print("MESH GROUND RAY %s %s" % ["PASS" if _failed.is_empty() else "FAIL", ", ".join(_failed)])
	quit(0 if _failed.is_empty() else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failed.append(label)
		printerr("mesh_ground_ray: %s failed: %s" % [label, detail])


## Loading the data and building both parts, the way the map does when it loads (first read of the file, cold).
func _time_the_load() -> void:
	var started := Time.get_ticks_usec()
	var data := load(DATA_PATH) as MeshGroundData
	var surface := GroundSurface.new()
	surface.mesh_data = data
	var surface_done := Time.get_ticks_usec()
	var collision := GroundCollision.new()
	collision.build(data)
	var collision_done := Time.get_ticks_usec()
	var surface_ms := (surface_done - started) / 1000.0
	var collision_ms := (collision_done - surface_done) / 1000.0
	print("mesh_ground_ray: load surface %.0f ms + collision %.0f ms = %.0f ms (limit %.0f), %d triangles in %d chunks" % [
			surface_ms, collision_ms, surface_ms + collision_ms, LOAD_LIMIT_MS, data.triangle_count(), data.chunk_count()])
	_check("load_time", surface_ms + collision_ms <= LOAD_LIMIT_MS, "%.0f ms" % (surface_ms + collision_ms))
	surface.free()
	collision.free()


func _check_scene(ground: Node3D, surface: GroundSurface, collision: GroundCollision) -> void:
	var drawn := ground.find_children("Chunk_*", "MeshInstance3D", true, false)
	_check("surface_lists_the_chunks", drawn.size() > 1 and surface.meshes.size() == drawn.size(), "%d drawn, %d listed" % [drawn.size(), surface.meshes.size()])
	_check("one_shape_per_chunk", collision.chunk_count() == surface.mesh_data.chunk_count(), "%d shapes, %d chunks" % [collision.chunk_count(), surface.mesh_data.chunk_count()])
	_check("surface_loaded", surface.is_loaded(), "no land")


func _check_rays(ground: Node3D, surface: GroundSurface) -> void:
	var bounds := surface.bounds()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var no_exclude: Array[RID] = []
	var tested := 0
	var worst := 0.0
	var misses := 0
	var tries := 0
	while tested < POINTS and tries < POINTS * 20:
		tries += 1
		var x := rng.randf_range(bounds.position.x + MARGIN_M, bounds.end.x - MARGIN_M)
		var z := rng.randf_range(bounds.position.y + MARGIN_M, bounds.end.y - MARGIN_M)
		var height := surface.height_at(x, z)
		if is_nan(height):
			continue
		tested += 1
		var ray_y := GroundRay.surface_y(ground, Vector3(x, 0.0, z), GROUND_LAYER_MASK, no_exclude, NAN)
		if is_nan(ray_y):
			misses += 1
		else:
			worst = maxf(worst, absf(ray_y - height))
	print("mesh_ground_ray: %d points, worst |ray - height_at| %.4f m, %d rays hit nothing" % [tested, worst, misses])
	_check("points_found", tested == POINTS, "only %d land points" % tested)
	_check("ray_matches_height", misses == 0 and worst <= TOLERANCE_M, "worst %s m, %d misses" % [worst, misses])


func _give_up() -> void:
	printerr("mesh_ground_ray: over %d s, giving up" % int(TIME_LIMIT_S))
	quit(2)
