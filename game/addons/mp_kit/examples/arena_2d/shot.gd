extends Node2D

## A shot: the server moves it and removes it after LIFE_S (MpActor.despawn removes it on every peer); every peer
## draws it smoothly. The player spawns it with MpSpawner.spawn_actor. It hits another player that it touches
## where its shooter SAW that player (lag compensation: `seen_lag` behind the present, MpLagComp), so a shooter
## with a high ping hits what was on their screen.

const SPEED := 600.0
const LIFE_S := 0.6
const HIT_RADIUS := 20.0

@export var direction: Vector2 = Vector2.RIGHT
## How far behind the present its shooter saw the others, in seconds (set by the player when it fires).
@export var seen_lag: float = 0.0

var _age: float = 0.0

@onready var net: MpActor = $MpActor


func _physics_process(delta: float) -> void:
	if not net.is_authority():
		return
	position += direction * SPEED * delta
	_age += delta
	var seen_at := MpNetClock.stamp() - clampf(seen_lag, 0.0, MpLagComp.HISTORY_S)
	for player in get_tree().get_nodes_in_group(&"arena_player"):
		var target := MpActor.of(player)
		if target == null or target.owner_slot == net.owner_slot:
			continue
		var seen: Vector2 = MpLagComp.position_at_like(player, seen_at)
		if seen.distance_to(position) < HIT_RADIUS:
			target.to_all(&"hit")
			net.despawn()
			return
	if _age >= LIFE_S:
		net.despawn()
