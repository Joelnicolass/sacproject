extends Node

## Observation only (pt76): after the bench has placed its camera each frame, re-frames the camera on screen
## to watch the wizard of a slot ("wizard") or the creatures of a slot ("army": their centre, pulled back to fit
## them). Touches no actor and no rule. set_mode("", 0) hands the camera back. probe() is a read-only line with
## the creatures of each slot on the field by tag (bodies in "unit", not "corpse"), to cross-check the counts that come from the bench report.

var mode := ""
var slot := 0
var dist := 40.0
var height := 45.0
var yaw_deg := 0.0


func _ready() -> void:
	process_priority = 1000


func set_mode(m: String, s: int = 0, d: float = 40.0, h: float = 45.0, yaw: float = 0.0) -> void:
	mode = m
	slot = s
	dist = d
	height = h
	yaw_deg = yaw


func _wizard(of_slot: int) -> Node3D:
	for node in get_tree().get_nodes_in_group("wizard"):
		if int(node.get("owner_slot")) == of_slot:
			return node as Node3D
	return null


func _creatures(of_slot: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("unit"):
		if node.is_in_group("npc") or int(node.get("owner_slot")) != of_slot:
			continue
		if node.is_in_group("corpse"):
			continue
		out.append(node as Node3D)
	return out


func _process(_delta: float) -> void:
	if mode == "":
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var center := Vector3.ZERO
	var extra := 0.0
	if mode == "wizard":
		var wizard := _wizard(slot)
		if wizard == null:
			return
		center = wizard.global_transform.origin + Vector3(0, 1.5, 0)
	elif mode == "army":
		var bodies := _creatures(slot)
		if bodies.is_empty():
			var wizard := _wizard(slot)
			if wizard == null:
				return
			center = wizard.global_transform.origin
		else:
			for body in bodies:
				center += body.global_transform.origin
			center /= bodies.size()
			for body in bodies:
				extra = maxf(extra, body.global_transform.origin.distance_to(center))
	else:
		return
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0, cos(deg_to_rad(yaw_deg)))
	var scale := 1.0 + extra / maxf(dist, 1.0)
	cam.position = center + (dir * dist + Vector3(0, height, 0)) * scale
	cam.look_at(center, Vector3.UP)


## Creatures on the field per slot and tag, alive ones only: "slot 1 {tag: n} | slot 2 {...}".
func probe() -> String:
	var counts := {}
	for node in get_tree().get_nodes_in_group("unit"):
		if node.is_in_group("npc") or node.is_in_group("corpse"):
			continue
		var s := int(node.get("owner_slot"))
		var tag := str(node.get("creature_tag"))
		if not counts.has(s):
			counts[s] = {}
		counts[s][tag] = int(counts[s].get(tag, 0)) + 1
	var parts := []
	for s in counts:
		parts.append("slot %d %s" % [s, JSON.stringify(counts[s])])
	return " | ".join(parts)
