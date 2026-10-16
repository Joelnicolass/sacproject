extends Node

## Observation only (RFC-019c playtest): re-frames the world camera on a world point after the game's own
## camera has placed itself. Touches no actor. release() hands the camera back.

var active := false
var target := Vector3.ZERO
var dist := 30.0
var height := 8.0
var yaw_deg := 0.0


func _ready() -> void:
	process_priority = 1000


func frame(x: float, y: float, z: float, d: float = 30.0, h: float = 8.0, yaw: float = 0.0) -> void:
	target = Vector3(x, y, z)
	dist = d
	height = h
	yaw_deg = yaw
	active = true


func release() -> void:
	active = false


func _process(_delta: float) -> void:
	if not active:
		return
	var root := get_tree().current_scene
	var cam := root.get_node_or_null("HighNoon/Camera") as Camera3D if root else null
	if cam == null:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0, cos(deg_to_rad(yaw_deg)))
	cam.position = target + dir * dist + Vector3(0, height, 0)
	cam.look_at(target, Vector3.UP)
