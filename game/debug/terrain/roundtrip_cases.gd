extends Node

## Checks the round trips of a map's ground headless (plan 063D S4c/S5b), on copies in user:// (the repo is never written):
##  - heights and voids through heights.png and void.png (MapImages): within half a 0.1 m step, voids bit for bit, an
##    unchanged picture is not written again and a void.png goes once no void is left;
##  - the named refusals of reading the pictures (missing, not a PNG, wrong size, bad height step) and, with Blender, of
##    bringing a .blend back (a vertex moved, a vertex missing, a moved object, pictures changed since): exit 1, nothing written;
##  - terrain_cli on the edit bed: --validate passes, --flat writes flat land, --flatten-bases writes the bed levelled;
##  - on the bed: «Aplanar bases» brings a bump under the fount within 0.05 m and its before puts it back exactly, and the
##    checks name the fount over a painted void and its footprint when it is not level.
## Prints ROUNDTRIP CASES PASS or FAIL. Needs the project imported (the bed's heights.png).
## "$GODOT" --headless --path game res://debug/terrain/roundtrip_cases.tscn

const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const TerrainEdits := preload("res://addons/terrain_tools/terrain_edits.gd")
const MapChecks := preload("res://tools/audit/map_checks.gd")
const MapGroundChecks := preload("res://tools/audit/map_ground_checks.gd")
const TerrainCli := preload("res://tools/terrain/terrain_cli.gd")
const RoundtripPictures := preload("res://debug/terrain/roundtrip_pictures.gd")
const BlenderRefusals := preload("res://debug/terrain/roundtrip_blender.gd")
const BED := "res://debug/terrain/edit_bed.tscn"
const BED_DIR := "res://debug/terrain/edit_bed"
const WORK := "user://roundtrip_cases"
const FOUNT := "MapProps/Founts/Fount1"

var _failed := PackedStringArray()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for folder in ["pictures", "flat", "levelled", "blend"]:
		DirAccess.make_dir_recursive_absolute(WORK.path_join(folder))
	_failed.append_array(RoundtripPictures.check(WORK.path_join("pictures"), WORK.path_join("none")))
	_failed.append_array(BlenderRefusals.check(BED_DIR, WORK.path_join("blend")))
	await _cli()
	await _bed()
	_rebuild_times()
	for name in _failed:
		print("  FAIL ", name)
	print("ROUNDTRIP CASES %s" % ("PASS" if _failed.is_empty() else "FAIL (%d)" % _failed.size()))
	get_tree().quit(0 if _failed.is_empty() else 1)


func _check(name: String, ok: bool) -> void:
	if not ok:
		_failed.append(name)


func _cli() -> void:
	_check("cli_validate_bed", await TerrainCli.run(["--scene=" + BED, "--validate"], self) == 0)
	await get_tree().process_frame
	var flat := WORK.path_join("flat")
	_check("cli_flat_exit", await TerrainCli.run(["--scene=" + BED, "--flat=12.5", "--out=" + flat], self) == 0)
	await get_tree().process_frame
	var back := MapImages.read(flat.path_join(MapImages.HEIGHTS_FILE)).heights
	_check("cli_flat_heights", back != null and back.heights_m.count(12.5) == TerrainGrid.COUNT and not back.void_mask.has(1))
	var levelled := WORK.path_join("levelled")
	_check("cli_flatten_bases", await TerrainCli.run(["--scene=" + BED, "--flatten-bases", "--out=" + levelled], self) == 0
			and MapImages.read(levelled.path_join(MapImages.HEIGHTS_FILE)).error.is_empty())
	await get_tree().process_frame
	_check("cli_bad_arguments", await TerrainCli.run(["--validate"], self) == 2)


func _bed() -> void:
	var bed := (load(BED) as PackedScene).instantiate() as MapRoot
	add_child(bed)
	for _frame in 2:
		await get_tree().physics_frame
	var terrain := bed.terrain
	var fount := bed.get_node(FOUNT) as Node3D
	var vertex := TerrainGrid.vertex_near(Vector2(fount.global_position.x, fount.global_position.z))
	var bumped := _copy(terrain.heights)
	var heights := bumped.heights_m.duplicate()
	heights[TerrainGrid.id_of(vertex)] += MapGroundChecks.MAX_SPREAD_M + 2.0  # past the most the checks allow, so they must name the fount
	bumped.heights_m = heights
	terrain.heights = bumped
	var problems: Array[String] = await MapChecks.check(bed, null)
	_check("bump_named %s" % [problems], _names(problems, FOUNT + "/GroundFootprint is not level"))
	var edit := TerrainEdits.level_bases(bed, terrain, bumped.heights_m, bumped.void_mask)
	var levelled := heights.duplicate()
	var mask := bumped.void_mask.duplicate()
	for patch: BrushStroke.Patch in edit["after"]:
		patch.write(levelled, mask)
	var rect := FootprintRules.vertices_under((fount.get_node("GroundFootprint") as GroundFootprint).area())
	_check("level_within_0.05_m", (edit["after"] as Array).size() == 2 and FootprintRules.spread_m(levelled, rect) <= 0.05)
	for patch: BrushStroke.Patch in edit["before"]:
		patch.write(levelled, mask)
	_check("level_undo_exact", levelled == heights and mask == bumped.void_mask)
	var voided := _copy(terrain.heights)
	var void_mask := voided.void_mask.duplicate()
	void_mask[TerrainGrid.id_of(vertex)] = 1
	voided.void_mask = void_mask
	terrain.heights = voided
	problems = await MapChecks.check(bed, null)
	_check("void_named %s" % [problems], _names(problems, FOUNT + " stands over a void"))
	bed.queue_free()
	await get_tree().process_frame


## What the editor rebuilds after a stroke (triangles, index, mesh arrays: RefreshBudget measures the same on a worker),
## for the bed and for the map with the most land. Over RefreshBudget.LIMIT_MS a stroke stays a draft until saved.
func _rebuild_times() -> void:
	for path in [BED_DIR.path_join(MapImages.HEIGHTS_FILE), "res://scenes/map/maps/winter_wonder/heights.png"]:
		var started := Time.get_ticks_usec()
		var faces := TerrainFaces.build(load(path) as TerrainHeights)
		TerrainRules.index(faces)
		TerrainMeshArrays.from_data(faces).with_normals(true)
		print("  rebuild %s: %.0f ms (%d triangles)" % [path.get_base_dir().get_file(), (Time.get_ticks_usec() - started) / 1000.0, faces.indices.size() / 3])


static func _copy(source: TerrainHeights) -> TerrainHeights:
	var copy := TerrainHeights.new()
	copy.heights_m = source.heights_m.duplicate()
	copy.void_mask = source.void_mask.duplicate()
	return copy


static func _names(problems: Array[String], said: String) -> bool:
	return problems.any(func(problem: String) -> bool: return problem.contains(said))
