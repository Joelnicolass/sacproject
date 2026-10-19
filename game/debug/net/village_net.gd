extends Node

## Test bed of the villages over the network (RFC-024 addendum 1, 024b2): High Noon with its NPC and houses. The
## server (or a solo game) knocks the jhut of (1255, 1214) down `fall_after_ticks` physics ticks after the world is
## ready, so a client that joins later has to find it already fallen. Clients do nothing here.

@export var world: Node
@export var fall_after_ticks := 180
@export var hut_at := Vector2(1255.0, 1214.0)


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		return
	_fall.call_deferred()


func _fall() -> void:
	for _tick in fall_after_ticks:
		await get_tree().physics_frame
	for node in get_tree().get_nodes_in_group(MapBuilding.SHELTER_GROUP):
		var hut := node as MapBuilding
		if hut != null and Vector2(hut.global_position.x, hut.global_position.z).distance_to(hut_at) < 3.0:
			hut.health.damage(hut.health.maximum, 1)
			print("servidor: jhut derribada")
			return
