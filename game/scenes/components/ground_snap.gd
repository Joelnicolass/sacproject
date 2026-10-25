@tool
class_name GroundSnap
extends Node3D

## Rests its parent on the land. Remove this child to place the parent by hand.
## In the editor it follows every move of the parent; in a match it runs once in _ready.
## The height comes from the terrain data (GroundSurface.height_at), not from a physics ray,
## so the dedicated server and every client get the same number.

const TERRAIN_GROUP := &"terrain"

@export var enabled := true:
	set(value):
		enabled = value
		_snap_when_ready()
## Meters above the land.
@export var offset := 0.0:
	set(value):
		offset = value
		_snap_when_ready()


func _ready() -> void:
	set_notify_transform(Engine.is_editor_hint())
	update_configuration_warnings()
	snap()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		snap()


func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is Node3D:
		return PackedStringArray(["GroundSnap apoya a su padre en el suelo: tiene que ser hijo de un Node3D."])
	return PackedStringArray()


## Moves the parent up or down onto the land under it. Over a hole, or with no terrain in
## its scene (a packed scene opened on its own), the parent stays where it is.
func snap() -> void:
	var body := get_parent() as Node3D
	if not enabled or body == null or not is_inside_tree():
		return
	var terrain := _terrain()
	if terrain == null or terrain.shape == null:
		return
	# Terrain-local = map coordinates. In the editor the scene root is shifted (terrain.gd).
	var at := terrain.to_local(body.global_position)
	var height := terrain.shape.height_at(at.x, at.z)
	if is_nan(height):
		return
	var rest := terrain.to_global(Vector3(at.x, height + offset, at.z))
	var frame := body.get_parent() as Node3D
	if frame:
		rest = frame.to_local(rest)
	# Only the height moves, rounded to the millimeter: x and z stay as the artist left them.
	var y := snappedf(rest.y, 0.001)
	if not is_equal_approx(body.position.y, y):
		body.position.y = y


## The terrain of the same scene: the one that hangs from an ancestor of this node.
func _terrain() -> Terrain:
	for node in get_tree().get_nodes_in_group(TERRAIN_GROUP):
		var terrain := node as Terrain
		if terrain and terrain.get_parent() and terrain.get_parent().is_ancestor_of(self):
			return terrain
	return null


func _snap_when_ready() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		snap()
