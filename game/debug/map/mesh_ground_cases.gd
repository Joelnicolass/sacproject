extends SceneTree

## 063-2a: the mesh ground answers what Blender built. Loads scenes/map/maps/mesh_test/ground.res (written by the import of
## ground.glb) and checks, with no scene and no physics: the footprint and the lowest land, the height at known points of the
## island (flat ground, hill top, pit floor, plateau), that on the arch `height_at` returns the roof and not the ground under
## it, that walls, the rim and the outside answer «no land», the normals, that `sampler()` equals `height_at`, and that the data
## is consistent (chunks, indices). Prints the time of 100 000 `height_at`. The expected numbers come from
## debug/map/mesh_test_spec.json, which tools/blender/make_mesh_test.py writes next to the island.
## Needs the project imported once. No autoloads. Always quits; gives up after 90 s.
## Run: Godot --headless --path game --script res://debug/map/mesh_ground_cases.gd   (prints MESH GROUND CASES PASS / FAIL)

const DATA_PATH := "res://scenes/map/maps/mesh_test/ground.res"
const SPEC_PATH := "res://debug/map/mesh_test_spec.json"
const TIME_LIMIT_S := 90.0
const ROOF_TOLERANCE_M := 0.05
const HEIGHT_TOLERANCE_M := 0.01
const SPEED_POINTS := 100000
const SEED := 20261025

var _failed := PackedStringArray()
var _surface: GroundSurface


func _initialize() -> void:
	create_timer(TIME_LIMIT_S).timeout.connect(_give_up)
	var data := load(DATA_PATH) as MeshGroundData
	var spec_text := FileAccess.get_file_as_string(SPEC_PATH)
	var spec_value: Variant = JSON.parse_string(spec_text)
	if data == null or not spec_value is Dictionary:
		printerr("mesh_ground_cases: cannot read %s or %s (import the project once)" % [DATA_PATH, SPEC_PATH])
		quit(2)
		return
	var spec: Dictionary = spec_value
	_surface = GroundSurface.new()
	_surface.mesh_data = data
	_check("loaded", _surface.is_loaded() and data.is_valid(), "the data is not valid")
	_check_data(data)
	_check_footprint(spec)
	_check_points(spec)
	_check_arch(spec)
	_check_outside(spec)
	_check_sampler()
	_speed()
	_surface.free()
	print("MESH GROUND CASES %s %s" % ["PASS" if _failed.is_empty() else "FAIL", ", ".join(_failed)])
	quit(0 if _failed.is_empty() else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failed.append(label)
		printerr("mesh_ground_cases: %s failed: %s" % [label, detail])


func _near(label: String, got: float, want: float, tolerance: float) -> void:
	_check(label, not is_nan(got) and absf(got - want) <= tolerance, "got %s, want %s" % [got, want])


func _check_data(data: MeshGroundData) -> void:
	var total := 0
	var sorted := true
	for row in data.chunk_count():
		total += data.chunks[row * 4 + 3]
		if row > 0:
			var before := Vector2i(data.chunks[row * 4 - 4], data.chunks[row * 4 - 3])
			var now := Vector2i(data.chunks[row * 4], data.chunks[row * 4 + 1])
			sorted = sorted and (before.y < now.y or (before.y == now.y and before.x < now.x))
	_check("chunks_cover_triangles", total == data.triangle_count() and data.chunk_count() > 1, "chunks hold %d of %d" % [total, data.triangle_count()])
	_check("chunks_sorted", sorted, "the chunk rows are not ordered by z then x")
	var inside := true
	for id in data.indices:
		inside = inside and id >= 0 and id < data.vertices.size()
	_check("indices_inside", inside, "an index points past the vertices")


func _check_footprint(spec: Dictionary) -> void:
	var size: Array = spec["size_m"]
	_check("bounds", _surface.bounds() == Rect2(0.0, 0.0, float(size[0]), float(size[1])), str(_surface.bounds()))
	_near("lowest", _surface.lowest(), float(spec["pit_floor_y"]), HEIGHT_TOLERANCE_M)
	_check("no_change_yet", _surface.version() == 0, "version %d" % _surface.version())


func _check_points(spec: Dictionary) -> void:
	var starts: Dictionary = spec["starts"]
	for key: String in starts:
		var at: Array = starts[key]
		_near("flat_" + key, _surface.height_at(float(at[0]), float(at[1])), float(spec["base_y"]), HEIGHT_TOLERANCE_M)
	var hill: Dictionary = spec["hill"]
	_near("hill_top", _surface.height_at(float(hill["x"]), float(hill["z"])), float(spec["hill_top_y"]), HEIGHT_TOLERANCE_M)
	var pit: Dictionary = spec["pit"]
	_near("pit_floor", _surface.height_at(float(pit["x"]), float(pit["z"])), float(spec["pit_floor_y"]), HEIGHT_TOLERANCE_M)
	var plateau: Dictionary = spec["plateau"]
	var px: Array = plateau["x"]
	var pz: Array = plateau["z"]
	_near("plateau", _surface.height_at((float(px[0]) + float(px[1])) * 0.5, (float(pz[0]) + float(pz[1])) * 0.5), float(spec["plateau_y"]), HEIGHT_TOLERANCE_M)
	_check("cliff_is_a_wall", not _surface.is_on_ground(float(px[0]) - 10.0, (float(pz[0]) + float(pz[1])) * 0.5), "the cliff gives a height")
	var up := _surface.normal_at(float(starts["start1"][0]), float(starts["start1"][1]))
	_check("flat_normal_up", up.is_equal_approx(Vector3.UP), str(up))
	var slope := _surface.normal_at(float(hill["x"]) + 60.0, float(hill["z"]))
	_check("hill_normal_leans", slope.y > 0.5 and slope.y < 0.999 and is_equal_approx(slope.length(), 1.0), str(slope))


## On the arch the answer is the roof, over the whole span; beside it, the ground.
func _check_arch(spec: Dictionary) -> void:
	var arch: Dictionary = spec["arch"]
	var ax: Array = arch["x"]
	var az: Array = arch["z"]
	var worst := 0.0
	var count := 0
	var x := float(ax[0]) + 2.0
	while x < float(ax[1]):
		var z := float(az[0]) + 2.0
		while z < float(az[1]):
			var height := _surface.height_at(x, z)
			worst = maxf(worst, absf(height - float(arch["roof_y"])) if not is_nan(height) else INF)
			count += 1
			z += 4.0
		x += 4.0
	_check("arch_roof", count > 0 and worst <= ROOF_TOLERANCE_M, "%d points, worst %s m from the roof" % [count, worst])
	var middle := (float(ax[0]) + float(ax[1])) * 0.5
	_near("beside_the_arch", _surface.height_at(middle, float(az[0]) - 20.0), float(arch["floor_y"]), HEIGHT_TOLERANCE_M)
	_near("roof_normal_up", _surface.normal_at(middle, (float(az[0]) + float(az[1])) * 0.5).y, 1.0, 0.001)


func _check_outside(spec: Dictionary) -> void:
	var size: Array = spec["size_m"]
	for label_and_point: Array in [["rim_skirt", 5.0, 5.0], ["off_west", -3.0, 100.0], ["off_east", float(size[0]) + 3.0, 100.0],
			["off_north", 100.0, -3.0], ["off_south", 100.0, float(size[1]) + 3.0], ["nan", NAN, 100.0]]:
		var label: String = label_and_point[0]
		var x: float = label_and_point[1]
		var z: float = label_and_point[2]
		_check(label, not _surface.is_on_ground(x, z) and is_nan(_surface.height_at(x, z)) and _surface.normal_at(x, z) == Vector3.UP, "answers land")


func _check_sampler() -> void:
	var sampler := _surface.sampler()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var same := true
	for i in 1000:
		var x := rng.randf_range(-20.0, 1220.0)
		var z := rng.randf_range(-20.0, 820.0)
		var direct := _surface.height_at(x, z)
		var sampled: float = sampler.call(x, z)
		same = same and (is_nan(direct) and is_nan(sampled) or direct == sampled)
	_check("sampler_equals_height_at", same, "the sampler differs from height_at")


func _speed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var started := Time.get_ticks_usec()
	var land := 0
	for i in SPEED_POINTS:
		if not is_nan(_surface.height_at(rng.randf_range(0.0, 1200.0), rng.randf_range(0.0, 800.0))):
			land += 1
	print("mesh_ground_cases: %d height_at in %.0f ms (%d on land)" % [SPEED_POINTS, (Time.get_ticks_usec() - started) / 1000.0, land])


func _give_up() -> void:
	printerr("mesh_ground_cases: over %d s, giving up" % int(TIME_LIMIT_S))
	quit(2)
