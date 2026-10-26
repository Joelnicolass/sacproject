extends Node

## No necesita el juego original. «--to-blend» y «--from-blend» necesitan Blender (en el PATH o la variable BLENDER).
## The ground tools of a map's Terrain without the editor, the same steps its inspector buttons take:
##   --to-blend             the map's pictures -> <folder>/terrain_work/terrain.blend (BlenderBridge)
##   --from-blend [--force] terrain.blend -> heights.png + void.png (refused with the reasons, nothing written)
##   --flat=<m>             a new flat ground at <m> metres, no void (heights.png, void.png goes)
##   --flatten-bases        levels the land under every GroundFootprint of the map scene (TerrainEdits) and writes it
##   --validate             checks the map scene as check_map does (MapChecks); prints TERRAIN VALIDATE <scene> PASS/FAIL
## The map is `--map=<tag>` (scenes/map/maps/<tag>/) or `--scene=<res://…tscn>` (any map scene, e.g. the edit bed); the
## pictures are those its Terrain reads (`--out=<folder>` writes --flat and --flatten-bases there instead). Exit 0 when it worked, 1 when it failed, 2 on bad arguments. It writes pictures
## but does not import them: run `--import` (or focus the editor) after a write. Not: brushes (the editor only).
## "$GODOT" --headless --path game res://tools/terrain/terrain_cli.tscn -- --map=<tag> --validate

const BlenderBridge := preload("res://addons/terrain_tools/blender_bridge.gd")
const TerrainEdits := preload("res://addons/terrain_tools/terrain_edits.gd")
const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const MapChecks := preload("res://tools/audit/map_checks.gd")
const MAPS_DIR := "res://scenes/map/maps"
const USAGE := "usage: -- (--map=<tag> | --scene=<res://map.tscn>) (--to-blend | --from-blend [--force] | --flat=<m> | --flatten-bases | --validate) [--out=<folder>]"


func _ready() -> void:
	_quit.call_deferred()


func _quit() -> void:
	get_tree().quit(await run(OS.get_cmdline_user_args(), self))


## Does what `arguments` ask, with `host` (a node in the tree) to hold a map scene. Returns the exit code.
static func run(arguments: PackedStringArray, host: Node) -> int:
	var options := {}
	for argument in arguments:
		var pair := argument.trim_prefix("--").split("=", true, 1)
		options[pair[0]] = pair[1] if pair.size() > 1 else ""
	var tag: String = options.get("map", "")
	var scene: String = options.get("scene", "%s/%s/map.tscn" % [MAPS_DIR, tag] if not tag.is_empty() else "")
	if scene.is_empty():
		printerr(USAGE)
		return 2
	if options.has("flat") and not tag.is_empty():
		return _written(TerrainEdits.write_flat(options.get("out", "%s/%s" % [MAPS_DIR, tag]), float(options["flat"])))
	var root := _enter(scene, tag, host)
	if root == null or root.terrain == null:
		printerr("terrain_cli: %s is no map scene with a Terrain (MapRoot.terrain)" % scene)
		return 1
	var folder: String = options.get("out", TerrainEdits.folder_of(root.terrain))
	for _frame in 2:
		await host.get_tree().physics_frame
	var code := 2
	if options.has("flat"):
		code = _written(TerrainEdits.write_flat(folder, float(options["flat"])))
	elif options.has("to-blend"):
		code = _blender(BlenderBridge.make_blend(folder))
	elif options.has("from-blend"):
		code = _blender(BlenderBridge.export_images(folder, options.has("force")))
	elif options.has("flatten-bases"):
		code = _flatten_bases(root, folder)
	elif options.has("validate"):
		var catalog := MapCatalog.shared()
		var problems: Array[String] = await MapChecks.check(root, catalog.find(StringName(tag)) if catalog.has(StringName(tag)) else null)
		for problem in problems:
			print("terrain_cli: %s" % problem)
		print("TERRAIN VALIDATE %s %s" % [scene, "PASS" if problems.is_empty() else "FAIL"])
		code = 0 if problems.is_empty() else 1
	else:
		printerr(USAGE)
	root.queue_free()
	return code


static func _enter(scene: String, tag: String, host: Node) -> MapRoot:
	var packed := load(scene) as PackedScene if ResourceLoader.exists(scene) else null
	if packed == null:
		return null
	if MapCatalog.shared().has(StringName(tag)):
		ActiveMatch.choose_ids(StringName(tag), ActiveMatch.mode_tag())
	var root := packed.instantiate() as MapRoot
	if root != null:
		host.add_child(root)
	return root


static func _flatten_bases(root: MapRoot, folder: String) -> int:
	var source := root.terrain.heights
	if source == null or not source.is_valid():
		printerr("terrain_cli: the Terrain has no valid heights")
		return 1
	var edit := TerrainEdits.level_bases(root, root.terrain, source.heights_m, source.void_mask)
	var levelled := TerrainHeights.new()
	var heights := source.heights_m.duplicate()
	var mask := source.void_mask.duplicate()
	for patch: BrushStroke.Patch in edit["after"]:
		patch.write(heights, mask)
	levelled.heights_m = heights
	levelled.void_mask = mask
	print("terrain_cli: %d bases levelled" % (edit["after"] as Array).size())
	return _written(MapImages.write(levelled, folder))


static func _written(result: MapImages.Result) -> int:
	if not result.error.is_empty():
		printerr("terrain_cli: " + result.error)
		return 1
	print("terrain_cli: wrote %s; import again (--import) to use it" % (", ".join(result.written) if not result.written.is_empty() else "nothing (unchanged)"))
	return 0


static func _blender(run: BlenderBridge.Run) -> int:
	print(run.summary())
	return 0 if run.ok() else 1
