class_name RockBurst
extends Node3D

## Rocks thrown up and out from a point, played on every peer by FxBus.broadcast_scene: the cow bursting on the land. Each rock is a DebrisPiece
## that flies, spins and bounces. Presentation only; it frees itself. It hurts nobody (the quake wave stuns, CarrierLanding).
## Ref: sacengine cowExplosion EruptDebris (state.d:21752-21761): 16 rocks at 20 ± 7.5 m/s, sideways and up.

@export var piece: PackedScene
@export_range(0, 64) var pieces := 16
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var throw_speed := 20.0
@export_range(0.0, 20.0, 0.5, "suffix:m/s") var throw_jitter := 7.5
## Spin of a rock, in turns per second.
@export var spin_turns := Vector2(0.5, 2.0)


func play(_params: Dictionary) -> void:
	var rng := MatchSeed.rng(["rock_burst", global_position])
	for i in pieces:
		var angle := rng.randf_range(-PI, PI)
		var direction := Vector3(cos(angle), rng.randf_range(1.0, 2.0), sin(angle)).normalized()
		var rock := piece.instantiate() as DebrisPiece
		add_child(rock)
		rock.launch(direction * (throw_speed + rng.randf_range(-throw_jitter, throw_jitter)), _axis(rng), TAU * rng.randf_range(spin_turns.x, spin_turns.y))
	get_tree().create_timer(4.0).timeout.connect(queue_free)


func _axis(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if piece != null else PackedStringArray(["Falta la roca (piece)."])
