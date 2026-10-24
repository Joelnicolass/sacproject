extends Node

## Observation only (RFC-021b playtest): after the world camera has placed itself each frame, re-frames it
## on the middle of the beam between a tied creature and its building. Touches no actor. Call release() to
## hand the camera back (picking with the pointer needs the game's own camera).

var creature_name := ""
var dist := 30.0
var height := 8.0
var yaw_deg := 90.0
## 0 = on the creature, 1 = on the building.
var along := 0.5


func _ready() -> void:
	process_priority = 1000


func frame(creature: String, d: float = 30.0, h: float = 8.0, yaw: float = 90.0, at: float = 0.5) -> void:
	creature_name = creature
	along = at
	dist = d
	height = h
	yaw_deg = yaw


func release() -> void:
	creature_name = ""


func _process(_delta: float) -> void:
	if creature_name.is_empty():
		return
	var root := get_tree().current_scene
	var cam := root.get_node_or_null("HighNoon/Camera") as Camera3D if root else null
	var body := root.find_child(creature_name, true, false) as Node3D if root else null
	if cam == null or body == null:
		return
	var bond := body.get_node_or_null("GuardianBond")
	var guard_bond := bond as GuardianBond
	var post: GuardPost = guard_bond.get_node_or_null(guard_bond.post_path) as GuardPost if guard_bond and not guard_bond.post_path.is_empty() else null
	var center := body.global_transform.origin + Vector3.UP
	if post:
		center = center.lerp(post.attach_position(), along)
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0, cos(deg_to_rad(yaw_deg)))
	cam.position = center + dir * dist + Vector3(0, height, 0)
	cam.look_at(center, Vector3.UP)
