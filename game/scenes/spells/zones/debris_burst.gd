class_name DebrisBurst
extends Node3D

## A shower of rocks thrown from one point, played on every peer by FxBus.broadcast_scene: each rock is a DebrisPiece
## scene flying in a random direction at about `speed`, spinning. The sprites of the burst (rock dust, the light) are
## bursts the zone plays beside it; the sound is the one of this scene's file name in the sound table. Presentation only;
## it frees itself. It does not hurt anyone (ZoneErupt).

## The rock that flies off, and how many.
@export var piece: PackedScene
@export_range(0, 128) var pieces := 64
## Speed of a rock and how much it can differ.
@export_range(1.0, 100.0, 0.5, "suffix:m/s") var speed := 30.0
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var jitter := 7.5
## The up part of the direction goes between these two values, against 1 sideways.
@export var rise := Vector2(-1.0, 2.0)
## Spin of a rock, in turns per second.
@export var spin_turns := Vector2(0.5, 2.0)
@export_range(0.5, 20.0, 0.5, "suffix:s") var life_s := 5.0


func play(_params: Dictionary) -> void:
	if piece == null:
		return
	var rng := MatchSeed.rng(["debris_burst", global_position])
	for i in pieces:
		var angle := rng.randf_range(-PI, PI)
		var direction := Vector3(cos(angle), rng.randf_range(rise.x, rise.y), sin(angle)).normalized()
		var rock := piece.instantiate() as DebrisPiece
		add_child(rock)
		var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		rock.launch(direction * (speed + rng.randf_range(-jitter, jitter)), axis, TAU * rng.randf_range(spin_turns.x, spin_turns.y))
	get_tree().create_timer(life_s).timeout.connect(queue_free)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if piece != null else PackedStringArray(["Falta la roca (piece): una escena de DebrisPiece."])
