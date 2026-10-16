extends Node

## Observation only: after the world camera has placed itself each frame, re-frames it to watch
## the Desecrate carry from the side. Does not touch any actor. Call set_mode("") to hand the
## camera back to the game (picking with the pointer needs the game's own camera).

var mode := ""
var dist := 14.0
var height := 3.0
var yaw_deg := 90.0


func _ready() -> void:
	process_priority = 1000


func set_mode(m: String, d: float = 14.0, h: float = 3.0, yaw: float = 90.0) -> void:
	mode = m
	dist = d
	height = h
	yaw_deg = yaw


func _find(name: String) -> Node3D:
	var root := get_tree().current_scene
	return root.find_child(name, true, false) as Node3D if root else null


func _process(_delta: float) -> void:
	if mode == "":
		return
	var root := get_tree().current_scene
	var cam := root.get_node_or_null("HighNoon/Camera") as Camera3D if root else null
	if cam == null:
		return
	var doctor := _find("Doctor1")
	var off := _find("Offering")
	var center := Vector3.ZERO
	if mode == "vortex":
		var v := _find("Vortex1")
		if v == null:
			return
		center = v.global_transform.origin
	elif mode == "creature" or (mode != "ground" and doctor == null and off != null):
		if off == null:
			return
		center = off.global_transform.origin + Vector3(0, 1.2, 0)
	elif doctor == null:
		return
	elif mode == "ground":
		if off == null:
			return
		center = off.global_transform.origin + Vector3(0, 0, -8)
	elif mode == "doctor":
		center = doctor.global_transform.origin + Vector3(0, 1.2, 0)
	else:
		center = doctor.global_transform.origin
		if off:
			center = (doctor.global_transform.origin + off.global_transform.origin) * 0.5
		center.y += 1.5
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0, cos(deg_to_rad(yaw_deg)))
	cam.position = center + dir * dist + Vector3(0, height, 0)
	cam.look_at(center, Vector3.UP)


## Read-only probe: where on the screen the doctor's origin and the creature land.
func probe() -> String:
	var root := get_tree().current_scene
	var cam := root.get_node_or_null("HighNoon/Camera") as Camera3D if root else null
	var out := ""
	for n in ["Doctor1", "Offering"]:
		var t := _find(n)
		if cam and t:
			var p := t.global_transform.origin
			out += "%s origin=%s screen0=%s screen1=%s | " % [n, p, cam.unproject_position(p), cam.unproject_position(p + Vector3(0, 1.0, 0))]
	return out
