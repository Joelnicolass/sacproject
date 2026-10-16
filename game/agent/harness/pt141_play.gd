extends Node

## F141 playtest (RFC-031 031b) observer. Read-only: never changes the game.
## Tolerates scene == null.
##   mark()            remembers the units under %Units now.
##   fresh()           one line per unit that was not there at mark(): name and local position.
##   ui()              paused, menu_open, %Battle armed/text, %Selection count, %Stats text, %PauseTitle text.

var _known := {}


func _scene() -> Node:
	var tree := get_tree()
	return tree.current_scene if tree != null else null


func _units() -> Node:
	var scene := _scene()
	return scene.find_child("Units", true, false) if scene != null else null


func mark() -> String:
	_known.clear()
	var units := _units()
	if units != null:
		for child in units.get_children():
			_known[child.name] = true
	var line := "pt141p mark units=%d" % _known.size()
	print(line)
	return line


func fresh() -> String:
	var units := _units()
	if units == null:
		print("pt141p fresh no_units")
		return "no units"
	var parts: PackedStringArray = []
	for child in units.get_children():
		if _known.has(child.name):
			continue
		var n3 := child as Node3D
		parts.append("%s=%s" % [child.name, n3.position if n3 != null else "?"])
	var line := "pt141p fresh %s" % " ".join(parts)
	print(line)
	return line


func ui() -> String:
	var tree := get_tree()
	if tree == null:
		return "no tree"
	var line := "pt141p paused=%s menu_open=%d" % [tree.paused, tree.get_nodes_in_group(WorldInput.MODAL).size()]
	var scene := _scene()
	if scene == null:
		line += " scene=null"
		print(line)
		return line
	line += " scene=%s" % scene.name
	var battle := scene.get_node_or_null("%Battle")
	if battle != null:
		line += " armed='%s' battle='%s'" % [battle.get("armed"), battle.get("text")]
	var sel := scene.get_node_or_null("%Selection")
	if sel != null:
		line += " sel=%s" % sel.get("count")
	var stats := scene.find_child("Stats", true, false) as Label
	if stats != null:
		line += " stats='%s'" % stats.text
	var title := scene.find_child("PauseTitle", true, false) as Label
	if title != null:
		line += " title='%s' title_visible=%s" % [title.text, title.is_visible_in_tree()]
	print(line)
	return line

