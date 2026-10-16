extends Node

## Observation only (024b2 playtest, real game): frames the active 3D camera on a ground point and audits NPC and
## houses against the terrain (floating or buried). Moves no actor.

var spot := Vector2.ZERO
var dist := 40.0
var height := 20.0
var yaw := 0.0
var active := false


func _ready() -> void:
	process_priority = 1000


func view(x: float, z: float, d: float, h: float, y: float) -> void:
	spot = Vector2(x, z)
	dist = d
	height = h
	yaw = y
	active = true


func _terrain() -> Node:
	return get_tree().current_scene.find_child("Terrain", true, false)


func _process(_dt: float) -> void:
	if not active:
		return
	var cam := get_viewport().get_camera_3d()
	var t := _terrain()
	if cam == null or t == null:
		return
	var gy: float = t.ground_height(spot.x, spot.y)
	var c := Vector3(spot.x, 0.0 if is_nan(gy) else gy, spot.y)
	cam.position = c + Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw))) * dist + Vector3(0, height, 0)
	cam.look_at(c, Vector3.UP)


func audit() -> String:
	var t := _terrain()
	var out := "scene=%s npc=%d map_building=%d shelter=%d " % [get_tree().current_scene.name, get_tree().get_nodes_in_group("npc").size(), get_tree().get_nodes_in_group("map_building").size(), get_tree().get_nodes_in_group("shelter").size()]
	var modes := {}
	var worst_n := 0.0
	var worst_n_name := ""
	for n in get_tree().get_nodes_in_group("npc"):
		var p := (n as Node3D).global_transform.origin
		var g: float = t.ground_height(p.x, p.z)
		if not is_nan(g) and absf(p.y - g) > worst_n:
			worst_n = absf(p.y - g)
			worst_n_name = n.name
		var k := str(n.get("mode"))
		modes[k] = int(modes.get(k, 0)) + 1
	var worst_b := 0.0
	var worst_b_name := ""
	var bsum := 0.0
	var bn := 0
	for b in get_tree().get_nodes_in_group("map_building"):
		var p := (b as Node3D).global_transform.origin
		var g: float = t.ground_height(p.x, p.z)
		if not is_nan(g):
			var d := p.y - g
			bsum += d
			bn += 1
			if absf(d) > worst_b:
				worst_b = absf(d)
				worst_b_name = b.name
	out += "modes%s worst_npc_dy=%.2f(%s) worst_bld_dy=%.2f(%s) mean_bld_dy=%.2f" % [str(modes), worst_n, worst_n_name, worst_b, worst_b_name, bsum / maxf(1.0, bn)]
	return out


func wiz() -> String:
	var w := get_tree().get_first_node_in_group("local_wizard") as Node3D
	return "mago (%.0f,%.0f)" % [w.global_transform.origin.x, w.global_transform.origin.z] if w else "sin mago"
