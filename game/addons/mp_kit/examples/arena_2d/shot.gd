extends Node2D

## A shot: the server moves it and removes it after LIFE_S (MpActor.despawn removes it on every peer); every peer
## draws it smoothly. The player spawns it with MpSpawner.spawn_actor.

const SPEED := 600.0
const LIFE_S := 0.6

@export var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0

@onready var net: MpActor = $MpActor


func _physics_process(delta: float) -> void:
	if not net.is_authority():
		return
	position += direction * SPEED * delta
	_age += delta
	if _age >= LIFE_S:
		net.despawn()
