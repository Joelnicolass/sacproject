extends Node

## Observation only (RFC-020e): after the world camera has placed itself each frame, re-frames it to
## watch a Convert: the red soul, the victim, the carrier doctor, the pair, the ritual or the altar.
## Touches no actor. set_mode("") hands the camera back to the game (picking with the pointer works on
## whatever camera is in place, so "soul" mode also lets a click land on the soul at the screen center).
## probe() reads the state of the Convert as a string.

var mode := ""
var dist := 14.0
var height := 3.0
var yaw_deg := 0.0


func _ready() -> void:
	process_priority = 1000


func set_mode(m: String, d: float = 14.0, h: float = 3.0, yaw: float = 0.0) -> void:
	mode = m
	dist = d
	height = h
	yaw_deg = yaw


func _root() -> Node:
	return get_tree().current_scene


func _find(node_name: String) -> Node3D:
	var root := _root()
	return root.find_child(node_name, true, false) as Node3D if root else null


func _first(group: StringName) -> Node3D:
	for node in get_tree().get_nodes_in_group(group):
		if node is Node3D and not (node as Node).is_queued_for_deletion():
			return node as Node3D
	return null


func _carrier() -> Node3D:
	for node in get_tree().get_nodes_in_group("doctor"):
		if node is Node3D and node.get_node_or_null("Errand") != null:
			return node as Node3D
	return null


func _center() -> Variant:
	match mode:
		"soul":
			var soul := _first("soul")
			return soul.global_transform.origin + Vector3(0, 1.4, 0) if soul else null
		"victim":
			var victim := _find("Victim")
			return victim.global_transform.origin + Vector3(0, 1.2, 0) if victim else null
		"doctor":
			var doctor := _carrier()
			return doctor.global_transform.origin + Vector3(0, 1.5, 0) if doctor else null
		"pair":
			var d := _carrier()
			var v := _find("Victim")
			if d and v:
				return (d.global_transform.origin + v.global_transform.origin) * 0.5 + Vector3(0, 2.0, 0)
			return null
		"altar":
			var start := _find("Start1")
			var altar := start.get_node_or_null("Altar") as Node3D if start else null
			return altar.global_transform.origin + Vector3(0, 8.0, 0) if altar else null
		"ritual":
			var ritual := get_tree().get_first_node_in_group("ritual") as Node3D
			return ritual.global_transform.origin + Vector3(0, 9.0, 0) if ritual else null
		"vortex":
			var vortices := _root().find_child("Vortices", true, false)
			if vortices and vortices.get_child_count() > 0:
				return (vortices.get_child(0) as Node3D).global_transform.origin
			return null
		"pillar":
			var pillar := _find("Pillar")
			return pillar.global_transform.origin if pillar else null
		"wizard2":
			var wizard2 := _find("Wizard2")
			return wizard2.global_transform.origin + Vector3(0, 1.5, 0) if wizard2 else null
		"wizard":
			var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
			return wizard.global_transform.origin + Vector3(0, 1.5, 0) if wizard else null
	return null


func _process(_delta: float) -> void:
	if mode == "":
		return
	var root := _root()
	## The camera on screen: HighNoon/Camera in the game scenes, the bench camera in ai_match / doctor_path.
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = root.get_node_or_null("HighNoon/Camera") as Camera3D if root else null
	var center: Variant = _center()
	if cam == null or center == null:
		return
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0, cos(deg_to_rad(yaw_deg)))
	cam.position = (center as Vector3) + dir * dist + Vector3(0, height, 0)
	cam.look_at(center as Vector3, Vector3.UP)


## One line with what a Convert is doing: creature, soul, doctor, ritual and the caster's souls.
func probe() -> String:
	var out := "t=%.1f " % (Time.get_ticks_msec() / 1000.0)
	var victim := _find("Victim")
	if victim != null:
		var health := victim.get_node_or_null("Health")
		out += "victim[mode=%s hp=%s owner=%s grp_unit=%s y=%.1f] " % [
			victim.get("mode"), health.get("current") if health else "-", victim.get("owner_slot"),
			victim.is_in_group("unit"), victim.global_transform.origin.y]
	else:
		out += "victim[libre] "
	for soul in get_tree().get_nodes_in_group("soul"):
		out += "soul[%s state=%s owner=%s] " % [soul.name, soul.get("state"), soul.get("owner_slot")]
	var d := _carrier()
	if d != null:
		out += "doctor[pose=%s hp=%s pos=(%.0f,%.0f)] " % [d.get("pose"), d.get_node("Health").get("current"), d.global_transform.origin.x, d.global_transform.origin.z]
	var ritual := get_tree().get_first_node_in_group("ritual")
	if ritual != null:
		out += "ritual[kind=%s phase=%s round=%s outcome=%s] " % [ritual.get("kind"), ritual.get("phase"), ritual.get("round_index"), ritual.get("outcome")]
	var wizard := get_tree().get_first_node_in_group("local_wizard")
	if wizard != null:
		var purse := wizard.get_node_or_null("SoulPurse")
		out += "almas=%s" % (purse.get("count") if purse else "-")
	return out
