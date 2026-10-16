extends Node

## Read-only observer for the F141 check (RFC-031 031b, pause menu). Never changes the game. Tolerates scene == null.
##   state(path)  one line: tree paused, how many nodes are in `menu_open`, the units under %Units, the local
##                position of the node named `path` (searched under the current scene; empty = skip) and the AI decision ticks so far.


func state(path: String = "") -> String:
	var tree := get_tree()
	if tree == null:
		return "pt141 no tree"
	var scene := tree.current_scene
	var line := "pt141 paused=%s menu_open=%d" % [tree.paused, tree.get_nodes_in_group(WorldInput.MODAL).size()]
	if scene == null:
		line += " scene=null"
		print(line)
		return line
	line += " scene=%s" % scene.name
	var units := scene.find_child("Units", true, false)
	if units != null:
		line += " units=%d" % units.get_child_count()
	if not path.is_empty():
		var node := scene.find_child(path, true, false) as Node3D
		line += (" %s=%s" % [path, node.position]) if node != null else (" %s=missing" % path)
	line += " ai_ticks=%d" % _ai_ticks(scene)
	print(line)
	return line


## Sum of AiSide.ticks (its decision clock): it stays put while the AI gives no orders.
func _ai_ticks(scene: Node) -> int:
	var total := 0
	for node in scene.find_children("*", "Node", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path.ends_with("ai/ai_side.gd"):
			total += int(node.get("ticks"))
	return total
