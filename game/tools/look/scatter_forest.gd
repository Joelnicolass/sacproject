extends Node

## Runs the «Scatter» of a map's ForestScatter (MapProps/Forest, PropKit) headless and writes the
## trees into the map's map.tscn as plain instance nodes, so the scene keeps every other line as it
## was. The same as pressing the button in the editor and saving. Bake the navmesh after it.
## "$GODOT" --headless --path game res://tools/look/scatter_forest.tscn -- --map=<tag>

const FOREST_PATH := "MapProps/Forest"
const FOREST_LINE := '[node name="Forest" parent="MapProps"'
const TREE_ID := "6_tree"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := ActiveMatch.new().map()
	if map == null or map.map_scene == null:
		_fail("no map scene")
		return
	var world := map.map_scene.instantiate()
	add_child(world)
	var forest := world.get_node_or_null(FOREST_PATH) as ForestScatter
	if forest == null:
		_fail("%s has no %s (ForestScatter)" % [map.tag, FOREST_PATH])
		return
	await get_tree().process_frame
	if forest.scatter(world) == 0:
		_fail("no tree planted")
		return
	var path := map.map_scene.resource_path
	var text := FileAccess.get_file_as_string(path)
	var start := text.find(FOREST_LINE)
	if start < 0:
		_fail("%s: no Forest node line" % path)
		return
	# drop the trees of an earlier run
	var cleaned := PackedStringArray()
	var skipping := false
	for line in text.split("\n"):
		if line.begins_with("[node "):
			skipping = line.contains('parent="%s"' % FOREST_PATH)
		if not skipping:
			cleaned.append(line)
	text = "\n".join(cleaned)
	var tree_path := forest.variants[0].scene.resource_path
	if not text.contains('id="%s"' % TREE_ID):
		var first_node := text.find("\n[node ")
		var header_end := text.rfind("[ext_resource", first_node)
		header_end = text.find("\n", header_end) + 1
		text = (
			text.substr(0, header_end)
			+ '[ext_resource type="PackedScene" path="%s" id="%s"]\n' % [tree_path, TREE_ID]
			+ text.substr(header_end)
		)
	var nodes := PackedStringArray()
	for planted: Node3D in forest.get_children():
		nodes.append(
			(
				'[node name="%s" parent="%s" instance=ExtResource("%s")]\ntransform = %s\n'
				% [planted.name, FOREST_PATH, TREE_ID, var_to_str(planted.transform)]
			)
		)
	# after the Forest node's own lines
	start = text.find(FOREST_LINE)
	var after := text.find("\n[", start) + 1
	text = text.substr(0, after) + "\n".join(nodes) + "\n" + text.substr(after)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("scatter_forest: %d trees written into %s" % [forest.get_child_count(), path])
	get_tree().quit(0)


func _fail(why: String) -> void:
	push_error("scatter_forest: " + why)
	get_tree().quit(1)
