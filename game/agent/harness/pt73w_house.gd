extends Node

## Observation only (024b2 playtest): aims the world camera's pointer at the nearest house (or a ground point) so the
## next order_units goes there, and reports its state. Moves no actor, edits no rule.


func _root() -> Node:
	return get_tree().current_scene


func _cam() -> Camera3D:
	return _root().get_node_or_null("HighNoon/Camera") as Camera3D


func _nearest(x: float, z: float, tag: String) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for b in get_tree().get_nodes_in_group("map_building"):
		if tag != "" and str(b.get("tag")) != tag:
			continue
		var p := (b as Node3D).global_transform.origin
		var d := Vector2(p.x - x, p.z - z).length()
		if d < best_d:
			best_d = d
			best = b
	return best


func aim_house(x: float, z: float, tag: String = "jhut") -> String:
	var b := _nearest(x, z, tag)
	var cam := _cam()
	if b == null or cam == null:
		return "sin casa"
	var spot := cam.unproject_position(b.global_transform.origin + Vector3(0, 1.5, 0))
	cam.set("debug_pointer", spot)
	return "pointer (%d,%d) en %s" % [spot.x, spot.y, b.name]


func aim_ground(x: float, z: float) -> String:
	var cam := _cam()
	var terrain: Variant = _root().find_child("Terrain", true, false)
	var y: float = terrain.ground_height(x, z) if terrain else 0.0
	var spot := cam.unproject_position(Vector3(x, 0.0 if is_nan(y) else y, z))
	cam.set("debug_pointer", spot)
	return "pointer suelo (%d,%d)" % [spot.x, spot.y]


func report(x: float, z: float, tag: String = "jhut") -> String:
	var b := _nearest(x, z, tag)
	var out := "casa=%s " % (b.name if b else "-")
	if b != null:
		var h := b.get("health") as Node
		out += "vida=%s en_shelter=%s en_structure=%s " % [h.get("current") if h else "-", b.is_in_group("shelter"), b.is_in_group("structure")]
	out += "shelters=%d structures=%d souls=%d " % [get_tree().get_nodes_in_group("shelter").size(), get_tree().get_nodes_in_group("structure").size(), get_tree().get_nodes_in_group("soul").size()]
	var wiz := get_tree().get_first_node_in_group("local_wizard")
	var purse := wiz.get_node_or_null("SoulPurse") if wiz else null
	out += "almas_mago=%s " % (purse.get("count") if purse else "-")
	var hunter := _root().find_child("Hunter", true, false) as Node3D
	if hunter:
		out += "Hunter(%.1f,%.1f) mode=%s" % [hunter.global_transform.origin.x, hunter.global_transform.origin.z, hunter.get("mode")]
	return out
