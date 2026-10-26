extends SceneTree

## Dumps what the ground answers at 10 000 seeded points on each of the 9 maps, so the answers before and after a cut can be
## compared bit by bit (a folder starting with "_", like the _template of «Mapa nuevo», is not a map). It loads terrain.gd (the Terrain) and gives it each map's heights.png (imported as TerrainHeights: import
## first), and only calls height_at / is_on_ground / lowest. It reads the ground files straight (no autoloads, no scenes),
## always quits, and gives up after 120 s. (Before 063D S3b it read each map's saved triangles: a dump taken then compares the same.)
## Run: Godot --headless --path game --script res://debug/map/ground_dump.gd -- --label=before
##   --label=<name>    writes res://debug/map/ground_dump_<name>.json (default "before")
##   --out=<path>      writes there instead (res:// or absolute)
##   --compare=<path>  also compares with that dump, bit by bit, and prints GROUND DUMP PASS / FAIL
## The heights are the raw bytes of 64-bit floats (one NaN pattern) in base64, next to one byte per point for is_on_ground.

const POINTS := 10000
const SEED := 20261025
const TIME_LIMIT_MS := 120000
const MAPS_DIR := "res://scenes/map/maps/"
const SURFACE_SCRIPT := "res://scenes/map/terrain/terrain.gd"
## The seeded points reach a little past the 2560 m map on every side, so the rim and off-map answers are covered too.
const REACH_MIN := -60.0
const REACH_MAX := 2620.0

var _started := 0
var _args := {}


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	create_timer(TIME_LIMIT_MS / 1000.0).timeout.connect(_give_up)
	_read_args()
	var out := _output_path()
	var result := {"script": _surface_script(), "points": POINTS, "seed": SEED, "maps": {}}
	var ok := true
	var tags := Array(DirAccess.get_directories_at(MAPS_DIR)).filter(func(tag: String) -> bool: return not tag.begins_with("_"))
	tags.sort()
	for index in tags.size():
		var entry := _dump_map(str(tags[index]), index)
		(result["maps"] as Dictionary)[tags[index]] = entry
		ok = ok and bool(entry.get("ok", false))
		if Time.get_ticks_msec() - _started > TIME_LIMIT_MS:
			ok = false
			break
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		printerr("ground_dump: cannot write %s" % out)
		quit(1)
		return
	file.store_string(JSON.stringify(result))
	file.close()
	print("ground_dump: %d maps -> %s (%s)" % [tags.size(), out, "OK" if ok else "FAILED"])
	var compare: String = _args.get("compare", _default_compare())
	if not compare.is_empty():
		ok = _compare(compare, result) and ok
	quit(0 if ok else 1)


## Where the dump goes when `--label` and `--out` are absent (the label "before": the cut has not happened yet).
func _default_label() -> String:
	return "before"


## The dump to compare with when `--compare` is absent ("" = do not compare).
func _default_compare() -> String:
	return ""


## Extra checks on the surface of one map, after its points were dumped. False fails the run.
func _extra_checks(_tag: String, _surface: Node) -> bool:
	return true


func _give_up() -> void:
	printerr("ground_dump: over %d s, giving up" % (TIME_LIMIT_MS / 1000))
	quit(2)


func _read_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			_args[arg.get_slice("=", 0).trim_prefix("--")] = arg.get_slice("=", 1)


func _output_path() -> String:
	return _args.get("out", "res://debug/map/ground_dump_%s.json" % _args.get("label", _default_label()))


func _surface_script() -> String:
	return SURFACE_SCRIPT


func _dump_map(tag: String, index: int) -> Dictionary:
	var path := MAPS_DIR + "%s/heights.png" % tag
	var source: Resource = load(path) if ResourceLoader.exists(path) else null
	if source == null:
		return {"ok": false, "error": "no heights.png (import first)"}
	var surface := (load(_surface_script()) as GDScript).new() as Node
	surface.set("heights", source)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + index
	var heights := PackedByteArray()
	heights.resize(POINTS * 8)
	var on_ground := PackedByteArray()
	on_ground.resize(POINTS)
	var land := 0
	for i in POINTS:
		var x := rng.randf_range(REACH_MIN, REACH_MAX)
		var z := rng.randf_range(REACH_MIN, REACH_MAX)
		var height: float = surface.call("height_at", x, z)
		heights.encode_double(i * 8, NAN if is_nan(height) else height)
		var on: bool = surface.call("is_on_ground", x, z)
		on_ground[i] = 1 if on else 0
		land += int(on)
	var entry := {
		"ok": surface.call("is_loaded") and _extra_checks(tag, surface), "terrain": path, "land_points": land,
		"lowest": surface.call("lowest"), "heights": Marshalls.raw_to_base64(heights), "on_ground": Marshalls.raw_to_base64(on_ground),
	}
	surface.free()
	return entry


## Every map's heights and land flags equal, byte for byte, to the dump at `path`.
func _compare(path: String, now: Dictionary) -> bool:
	var before: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not before is Dictionary or not (before as Dictionary).has("maps"):
		printerr("GROUND DUMP FAIL: cannot read %s" % path)
		return false
	var ok := true
	var before_maps: Dictionary = (before as Dictionary)["maps"]
	for tag: String in (now["maps"] as Dictionary):
		var a: Dictionary = before_maps.get(tag, {})
		var b: Dictionary = (now["maps"] as Dictionary)[tag]
		var same: bool = a.get("heights", "x") == b.get("heights", "y") and a.get("on_ground", "x") == b.get("on_ground", "y") \
				and float(a.get("lowest", NAN)) == float(b.get("lowest", INF)) and not a.is_empty()
		print("%s %s: %d points, land %s -> %s" % ["OK  " if same else "FAIL", tag, POINTS, a.get("land_points"), b.get("land_points")])
		ok = ok and same
	print("GROUND DUMP %s (against %s)" % ["PASS" if ok else "FAIL", path])
	return ok
